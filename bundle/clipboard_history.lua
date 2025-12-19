-- Clipboard History Preset
-- Persistent clipboard history with fuzzy search

local searchUtils = require 'lib.search'
local chooserManager = require 'lib.chooser'
local toast = require 'lib.toast'
local icons = require 'lib.icons'
local events = require 'lib.events'
local thumbnailCache = require 'lib.thumbnail_cache'

local M = {
  watcher = nil,
  maxEntries = 150,
  historyFile = '~/.martillo_clipboard_history',
  historyAssets = '~/.martillo_clipboard_history_assets',
  currentQuery = '',
  historyBuffer = {},
  lastFocusedApp = nil,
  lastFocusedWindow = nil,
  logger = hs.logger.new('ClipboardHistory', 'debug'),
}

-- Map file extensions to appropriate 3D icons
local extensionToIcon = {
  -- Documents
  pdf = 'file-text',
  doc = 'file-text',
  docx = 'file-text',
  txt = 'file-text',
  rtf = 'file-text',
  md = 'file-text',
  markdown = 'file-text',
  -- Spreadsheets
  xls = 'file-text',
  xlsx = 'file-text',
  csv = 'file-text',
  -- Code files
  js = 'file-text',
  ts = 'file-text',
  jsx = 'file-text',
  tsx = 'file-text',
  py = 'file-text',
  lua = 'file-text',
  rb = 'file-text',
  java = 'file-text',
  c = 'file-text',
  cpp = 'file-text',
  h = 'file-text',
  hpp = 'file-text',
  go = 'file-text',
  rs = 'file-text',
  swift = 'file-text',
  kt = 'file-text',
  php = 'file-text',
  html = 'file-text',
  css = 'file-text',
  scss = 'file-text',
  json = 'file-text',
  xml = 'file-text',
  yaml = 'file-text',
  yml = 'file-text',
  toml = 'file-text',
  sh = 'file-text',
  bash = 'file-text',
  zsh = 'file-text',
  -- Audio
  mp3 = 'music',
  wav = 'music',
  flac = 'music',
  aac = 'music',
  ogg = 'music',
  m4a = 'music',
  -- Video
  mp4 = 'video-camera',
  mov = 'video-camera',
  avi = 'video-camera',
  mkv = 'video-camera',
  wmv = 'video-camera',
  flv = 'video-camera',
  webm = 'video-camera',
  m4v = 'video-camera',
  -- Design files
  psd = 'paint-brush',
  ai = 'paint-brush',
  sketch = 'paint-brush',
  xd = 'paint-brush',
  fig = 'figma',
  -- Archives
  zip = 'file',
  rar = 'file',
  tar = 'file',
  gz = 'file',
  ['7z'] = 'file',
  bz2 = 'file',
}

-- Escape special characters for YAML-like format
local function escapeYamlString(str)
  if not str then
    return ''
  end
  return str:gsub('\\', '\\\\'):gsub('\n', '\\n'):gsub('\r', '\\r')
end

-- Unescape special characters from YAML-like format
local function unescapeYamlString(str)
  if not str then
    return ''
  end
  return str:gsub('\\r', '\r'):gsub('\\n', '\n'):gsub('\\\\', '\\')
end

-- Load clipboard history from plain text file
local function loadHistory()
  M.historyBuffer = {}

  local file = io.open(M.historyFile, 'r')
  if not file then
    return
  end

  local currentEntry = nil
  for line in file:lines() do
    if line:match '^%- content: ' then
      if currentEntry then
        table.insert(M.historyBuffer, currentEntry)
      end
      currentEntry = {
        content = unescapeYamlString(line:match '^%- content: (.*)$'),
      }
    elseif line:match '^  when: ' then
      if currentEntry then
        currentEntry.timestamp = tonumber(line:match '^  when: (.*)$')
      end
    elseif line:match '^  type: ' then
      if currentEntry then
        currentEntry.type = line:match '^  type: (.*)$'
      end
    end
  end

  if currentEntry then
    table.insert(M.historyBuffer, currentEntry)
  end

  file:close()
  M.logger:d(string.format('Loaded %d entries from history file', #M.historyBuffer))
end

-- Save clipboard history to plain text file
local function saveHistory()
  local file = io.open(M.historyFile, 'w')
  if not file then
    M.logger:e('Failed to open history file for writing: ' .. M.historyFile)
    return
  end

  for _, entry in ipairs(M.historyBuffer) do
    file:write(string.format('- content: %s\n', escapeYamlString(entry.content)))
    file:write(string.format('  when: %d\n', entry.timestamp or 0))
    file:write(string.format('  type: %s\n', entry.type or 'text'))
  end

  file:close()
end

-- Generate macOS-style screenshot name
local function generateScreenshotName(timestamp)
  timestamp = timestamp or os.time()
  return os.date('Screenshot %Y-%m-%d at %H.%M.%S', timestamp)
end

-- Extract display name from file path
local function getFileDisplayName(filePath)
  if not filePath then
    return nil
  end
  local filename = filePath:match '([^/]+)$'
  return filename
end

-- Handle clipboard content changes
local function onClipboardChange()
  local content = hs.pasteboard.getContents()
  local contentType = 'text'
  local displayName = nil

  -- Check for file URLs from Finder
  local contentTypes = hs.pasteboard.contentTypes()
  local hasFileURL = false

  if contentTypes then
    for _, uti in ipairs(contentTypes) do
      if uti == 'public.file-url' then
        hasFileURL = true
        break
      end
    end
  end

  if hasFileURL then
    -- Resolve file URL using AppleScript
    local handle = io.popen [[
      osascript -e 'try
      set theFile to the clipboard as «class furl»
      return POSIX path of theFile
      end try' 2>&1
    ]]
    local result = handle:read '*a'
    handle:close()

    result = result:gsub('^%s+', ''):gsub('%s+$', '')

    if result and result ~= '' and result:match '^/' then
      content = result
      contentType = 'file'
      M.logger:d('Captured file from Finder: ' .. result)
    else
      M.logger:e('Failed to extract file path - osascript returned: ' .. tostring(result))
      return
    end
  elseif not hasFileURL and hs.pasteboard.readImage() then
    M.logger:d '=== Processing clipboard image (screenshot) ==='
    local imageData = hs.pasteboard.readImage()
    local timestamp = os.time()

    displayName = generateScreenshotName(timestamp)
    local imagePath = M.historyAssets .. '/' .. displayName .. '.png'

    -- Create images directory
    os.execute("mkdir -p '" .. M.historyAssets .. "'")

    -- Check if image already exists
    for i, entry in ipairs(M.historyBuffer) do
      if entry.type == 'image' then
        local existingName = getFileDisplayName(entry.content)
        if existingName == displayName then
          local movedEntry = table.remove(M.historyBuffer, i)
          movedEntry.timestamp = timestamp
          table.insert(M.historyBuffer, 1, movedEntry)
          saveHistory()
          M.logger:d('Moved existing image to top: ' .. displayName)
          return
        end
      end
    end

    -- Save full image (thumbnail will be generated on-demand when displayed)
    imageData:saveToFile(imagePath)

    content = imagePath
    contentType = 'image'
  elseif not content or content == '' then
    return
  end

  -- Validate text content
  if contentType == 'text' then
    local trimmedContent = content:match '^%s*(.-)%s*$'
    if not trimmedContent or trimmedContent == '' then
      return
    end
  end

  -- Check if content already exists (move to top)
  for i, entry in ipairs(M.historyBuffer) do
    if entry.type == contentType and entry.content == content then
      local movedEntry = table.remove(M.historyBuffer, i)
      movedEntry.timestamp = os.time()
      table.insert(M.historyBuffer, 1, movedEntry)
      saveHistory()
      return
    end
  end

  -- Add new entry
  local newEntry = {
    content = content,
    timestamp = os.time(),
    type = contentType,
  }

  table.insert(M.historyBuffer, 1, newEntry)

  -- Keep only maxEntries
  while #M.historyBuffer > M.maxEntries do
    table.remove(M.historyBuffer)
  end

  saveHistory()
end

-- Get image thumbnail using the shared thumbnail cache
-- For screenshots, generates and caches a thumbnail in /tmp
-- For other images, resizes to icon size and caches
local function getImageFromCache(imagePath, isScreenshot)
  if not imagePath then
    return nil
  end

  local image = thumbnailCache.getCachedImageThumbnail(imagePath)

  -- If nil, we've reached the limit - use fallback icon
  if not image then
    return thumbnailCache.getFallbackIcon('image', function()
      return icons.getIcon(icons.preset.image)
    end)
  end

  return image
end

-- Fuzzy search on raw entries
local function fuzzySearchRawEntries(query, entries)
  if not query or query == '' then
    return entries
  end

  local now = os.time()

  local rankedEntries = searchUtils.rank(query, entries, {
    getFields = function(entry)
      if entry.type ~= 'text' and entry.content then
        local filename = getFileDisplayName(entry.content)
        if filename and filename ~= '' then
          return {
            { value = filename,            weight = 1.0, key = 'filename' },
            { value = entry.content or '', weight = 0.4, key = 'path' },
          }
        end
        return { { value = entry.content or '', weight = 1.0, key = 'path' } }
      end

      return { { value = entry.content or '', weight = 1.0, key = 'content' } }
    end,
    adjustScore = function(entry, context)
      local score = context.score
      if entry.timestamp and now then
        local ageSeconds = now - entry.timestamp
        if ageSeconds < 0 then
          ageSeconds = 0
        end
        local recencyBoost = math.max(0, 1 - (ageSeconds / (24 * 60 * 60)))
        score = score * (1 + recencyBoost * 0.1)
      end
      return score
    end,
    fuzzyMinQueryLength = 4,
    maxResults = M.maxEntries,
  })

  return rankedEntries
end

-- Build formatted choice from raw entry
-- Note: Images are loaded lazily only for filtered results to improve performance
local function buildFormattedChoice(rawEntry, loadImages)
  -- loadImages parameter allows caller to defer image loading if needed
  loadImages = loadImages == nil and true or loadImages

  local function getFileExtension(filePath)
    if not filePath then
      return nil
    end
    return filePath:match '%.([^%.]+)$'
  end

  local function getFileTypeFromExtension(extension)
    if not extension then
      return 'file'
    end
    extension = extension:lower()

    local imageExts = { 'png', 'jpg', 'jpeg', 'gif', 'bmp', 'tiff', 'webp', 'svg', 'ico' }
    local videoExts = { 'mp4', 'mov', 'avi', 'mkv', 'wmv', 'flv', 'webm', 'm4v', '3gp', 'mpg', 'mpeg' }

    for _, ext in ipairs(imageExts) do
      if extension == ext then
        return 'image'
      end
    end
    for _, ext in ipairs(videoExts) do
      if extension == ext then
        return 'video'
      end
    end

    return 'file'
  end

  local function truncateText(text, maxLength)
    if not text then
      return ''
    end
    maxLength = maxLength or 200
    if #text <= maxLength then
      return text
    end
    return text:sub(1, maxLength) .. '...'
  end

  local entry = rawEntry
  local preview = entry.content or ''

  if entry.type == 'text' then
    preview = truncateText(preview, 200)
  end

  local dateDisplay = ''
  if entry.timestamp then
    local timestamp = tonumber(entry.timestamp) or 0
    local today = os.time()
    local daysDiff = math.floor((today - timestamp) / 86400)

    if daysDiff == 0 then
      dateDisplay = 'Today'
    elseif daysDiff == 1 then
      dateDisplay = 'Yesterday'
    else
      dateDisplay = os.date('%b %d', timestamp)
    end
  end

  local timeDisplay = ''
  if entry.timestamp then
    timeDisplay = os.date('%H:%M', entry.timestamp)
  end

  -- Calculate size for display
  local sizeDisplay = ''
  if entry.type == 'text' and entry.content then
    local contentLength = #entry.content
    local sizeStr = ''
    if contentLength < 1024 then
      sizeStr = string.format('%d bytes', contentLength)
    elseif contentLength < 1024 * 1024 then
      sizeStr = string.format('%.1f KB', contentLength / 1024)
    else
      sizeStr = string.format('%.1f MB', contentLength / (1024 * 1024))
    end

    -- Count lines
    local lineCount = 1
    for _ in entry.content:gmatch '\n' do
      lineCount = lineCount + 1
    end

    sizeDisplay = string.format('%s, %d %s', sizeStr, lineCount, lineCount == 1 and 'line' or 'lines')
  elseif (entry.type == 'image' or entry.type == 'file') and entry.content then
    -- Try to get file size
    local filePath = entry.content
    local file = io.open(filePath, 'r')
    if file then
      local size = file:seek 'end'
      file:close()
      if size < 1024 then
        sizeDisplay = string.format('%d bytes', size)
      elseif size < 1024 * 1024 then
        sizeDisplay = string.format('%.1f KB', size / 1024)
      else
        sizeDisplay = string.format('%.1f MB', size / (1024 * 1024))
      end
    end
  end

  local subText = string.format('%s • %s %s', sizeDisplay, dateDisplay, timeDisplay)

  local choiceEntry = {
    text = preview,
    subText = subText,
    content = entry.content,
    timestamp = entry.timestamp,
    type = entry.type,
  }

  -- Handle different content types for preview
  -- Only load images if requested (for performance)
  if entry.type == 'image' and entry.content then
    choiceEntry.text = getFileDisplayName(entry.content) or 'Image'

    if loadImages then
      local imagePath = entry.content
      -- Pass true for isScreenshot since entry.type == 'image' means it's a screenshot
      local image = getImageFromCache(imagePath, true)
      if image then
        choiceEntry.image = image
      end
    end
  elseif entry.type == 'file' and entry.content then
    local filePath = entry.content
    local extension = getFileExtension(filePath)
    local fileType = getFileTypeFromExtension(extension)

    choiceEntry.text = getFileDisplayName(filePath) or preview

    if (fileType == 'image' or fileType == 'video') and loadImages then
      -- For file type images/videos, load thumbnail
      local image = getImageFromCache(filePath, fileType == 'image')
      if image then
        choiceEntry.image = image
      else
        choiceEntry.text = (getFileDisplayName(filePath) or preview) .. ' (file not found)'
      end
    elseif fileType ~= 'image' and fileType ~= 'video' then
      local file = io.open(filePath, 'r')
      if not file then
        choiceEntry.text = (getFileDisplayName(filePath) or preview) .. ' (file not found)'
      else
        file:close()
        -- Get file type icon for non-image/video files
        if loadImages and extension then
          extension = extension:lower()

          local iconName = extensionToIcon[extension] or 'file'

          -- Get icon from icons helper (no fallback, let it handle missing icons)
          local icon = icons.getIcon(iconName)
          if icon then
            choiceEntry.image = icon
          end
        end
      end
    end
  elseif entry.type == 'text' and loadImages then
    -- Show text icon for text entries
    local icon = icons.getIcon(icons.preset.copy)
    if icon then
      choiceEntry.image = icon
    end
  end

  return choiceEntry
end

-- Capture focus before showing chooser
local function captureFocus()
  M.lastFocusedWindow = hs.window.frontmostWindow()
  local app = hs.application.frontmostApplication()
  M.lastFocusedApp = app or nil
end

-- Restore focus
local function restoreFocus()
  local restored = false

  if M.lastFocusedWindow and M.lastFocusedWindow:application() then
    restored = M.lastFocusedWindow:focus() or restored
  end

  if not restored and M.lastFocusedApp then
    restored = M.lastFocusedApp:activate() or restored
  end

  M.lastFocusedWindow = nil
  M.lastFocusedApp = nil

  return restored
end

-- Check if app is in copy-only list
local function shouldOnlyCopyForApp()
  local app = M.lastFocusedApp or hs.application.frontmostApplication()
  if not app then
    return true
  end

  local appName = app:name() or ''
  local copyOnlyApps = {
    'System Preferences',
    'System Settings',
    'Activity Monitor',
    'Console',
  }

  for _, copyApp in ipairs(copyOnlyApps) do
    if appName == copyApp then
      return true
    end
  end

  return false
end

-- Copy content to clipboard
local function copyToClipboard(choice)
  if choice.type == 'image' then
    local imagePath = choice.content
    local file = io.open(imagePath, 'r')
    if file then
      file:close()
      local imageData = hs.image.imageFromPath(imagePath)
      if imageData then
        hs.pasteboard.writeObjects(imageData)
      else
        hs.pasteboard.setContents(choice.content)
      end
    else
      hs.pasteboard.setContents(choice.content)
    end
  elseif choice.type == 'file' then
    local filePath = choice.content
    local escapedPath = filePath:gsub("'", "'\\''")
    os.execute(string.format([[osascript -e 'set the clipboard to POSIX file "%s"']], escapedPath))
    M.logger:d('Copied file to clipboard: ' .. filePath)
  else
    hs.pasteboard.setContents(choice.content)
    M.logger:d 'Copied text to clipboard'
  end

  toast.copied()
  restoreFocus()
end

-- Paste content
local function pasteContent(choice)
  M.logger:d('pasteContent called - type: ' .. tostring(choice.type))

  if choice.type == 'image' then
    M.logger:d('Pasting image from: ' .. tostring(choice.content))
    local imagePath = choice.content
    local file = io.open(imagePath, 'r')
    if file then
      file:close()
      local imageData = hs.image.imageFromPath(imagePath)
      if imageData then
        hs.pasteboard.writeObjects(imageData)
        M.logger:d 'Image written to clipboard'
      else
        hs.pasteboard.setContents(choice.content)
        M.logger:d 'Failed to load image, wrote path instead'
      end
    else
      hs.pasteboard.setContents(choice.content)
      M.logger:d 'Image file not found, wrote path instead'
    end
  elseif choice.type == 'file' then
    M.logger:d('Pasting file: ' .. tostring(choice.content))

    local filePath = choice.content
    local extension = filePath:match '%.([^%.]+)$'
    local isImage = extension
        and (
          extension:lower() == 'png'
          or extension:lower() == 'jpg'
          or extension:lower() == 'jpeg'
          or extension:lower() == 'gif'
          or extension:lower() == 'webp'
          or extension:lower() == 'bmp'
        )

    if isImage then
      M.logger:d 'File is an image, loading as image data'
      local imageData = hs.image.imageFromPath(filePath)
      if imageData then
        hs.pasteboard.writeObjects(imageData)
        M.logger:d 'Image written to clipboard'
      else
        M.logger:d 'Failed to load image, using AppleScript fallback'
        local escapedPath = filePath:gsub("'", "'\\''")
        os.execute(string.format([[osascript -e 'set the clipboard to POSIX file "%s"']], escapedPath))
      end
    else
      M.logger:d 'File is not an image, using AppleScript'
      local escapedPath = filePath:gsub("'", "'\\''")
      os.execute(string.format([[osascript -e 'set the clipboard to POSIX file "%s"']], escapedPath))
    end
  else
    M.logger:d 'Pasting text'
    hs.pasteboard.setContents(choice.content)
  end

  restoreFocus()
  hs.eventtap.keyStroke({ 'cmd' }, 'v', 0)
end

-- Expand tilde in path
local function expandPath(path)
  if path:sub(1, 1) == '~' then
    local home = os.getenv 'HOME'
    return home .. path:sub(2)
  end
  return path
end

-- Initialize clipboard monitoring
local function initClipboardMonitoring()
  if M.watcher then
    return -- Already initialized
  end

  -- Expand paths
  M.historyFile = expandPath(M.historyFile)
  M.historyAssets = expandPath(M.historyAssets)

  -- Set up clipboard watcher
  M.watcher = hs.pasteboard.watcher.new(onClipboardChange)
  M.watcher:start()

  -- Load history
  loadHistory()

  M.logger:d 'Clipboard monitoring started'
end

-- Start monitoring when preset is loaded
initClipboardMonitoring()

-- Return action definition
return {
  {
    id = 'clipboard_history',
    name = 'Clipboard History',
    icon = icons.preset.copy,
    description = 'Search and paste from clipboard history',
    handler = function()
      -- Check if history is empty
      if #M.historyBuffer == 0 then
        toast.info 'Clipboard history is empty'
        return
      end

      -- Capture focus for paste functionality
      captureFocus()

      -- Set thumbnail memory limit for images (reduced for faster initial load)
      thumbnailCache.setMaxLoaded('images', 30)

      spoon.ActionsLauncher:openChildChooser {
        placeholder = 'Clipboard History (↩ paste, ⇧↩ copy)',
        parentAction = 'clipboard_history',
        handler = function(query, launcher)
          -- Reset image count for each query to limit memory usage
          thumbnailCache.resetLoadedCount 'images'

          -- Update current query for filtering
          M.currentQuery = query or ''

          -- Get filtered entries
          local filteredRawEntries = fuzzySearchRawEntries(M.currentQuery, M.historyBuffer)

          -- Build choices with handlers
          local choices = {}
          for i, rawEntry in ipairs(filteredRawEntries) do
            local formattedChoice = buildFormattedChoice(rawEntry, true)

            local uuid = launcher:generateUUID()
            formattedChoice.uuid = uuid

            launcher.handlers[uuid] = events.custom(function(choice)
              local shiftHeld = chooserManager.isShiftHeld()

              if shiftHeld then
                -- Shift+Enter: Copy only
                copyToClipboard(formattedChoice)
              else
                -- Enter: Copy and paste
                local shouldJustCopy = shouldOnlyCopyForApp()
                if shouldJustCopy then
                  copyToClipboard(formattedChoice)
                else
                  pasteContent(formattedChoice)
                end
              end
            end)

            table.insert(choices, formattedChoice)
          end

          return choices
        end,
      }
    end,
  },
}
