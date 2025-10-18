--- === ClipboardHistory ===
---
--- Persistent clipboard history with fuzzy search using plain text storage
---
--- Features:
--- • Simple plain text file storage (similar to fish_history format)
--- • Pure Lua fuzzy search - no external dependencies
--- • Supports text and multimedia file paths
--- • Fast and lightweight

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "ClipboardHistory"
obj.version = "2.0"
obj.author = "sjdonado"
obj.homepage = "https://github.com/sjdonado/martillo/spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.chooser = nil
obj.hotkeys = {}
obj.watcher = nil
obj.maxEntries = 300 -- Maximum number of entries to keep
obj.historyFile = nil
obj.currentQuery = ""
obj.logger = hs.logger.new('ClipboardHistory', 'debug')
obj.historyBuffer = {} -- Lightweight raw entries {content, timestamp, type}

--- ClipboardHistory:init()
--- Method
--- Initialize the spoon
function obj:init()
    -- Set up history file path
    local spoonPath = hs.spoons.scriptPath()
    self.historyFile = spoonPath .. "/clipboard_history"

    -- Initialize chooser
    self:initializeChooser()

    return self
end

--- ClipboardHistory:initializeChooser()
--- Method
--- Initialize or reinitialize the chooser with fresh state
function obj:initializeChooser()
    -- Destroy existing chooser if it exists
    if self.chooser then
        self.chooser:delete()
        self.chooser = nil
    end

    -- Create new chooser
    self.chooser = hs.chooser.new(function(choice)
        if not choice then
            return
        end

        -- Try to paste by default, fall back to copy only in specific cases
        local shouldJustCopy = self:shouldOnlyCopy()

        if shouldJustCopy then
            -- Just copy to clipboard without pasting
            self:copyToClipboard(choice)
        else
            -- Handle different content types for pasting
            self:pasteContent(choice)
        end
    end)

    self.chooser:rows(10)
    self.chooser:width(40)
    self.chooser:searchSubText(true)
    self.chooser:queryChangedCallback(function(query)
        self.currentQuery = query
        self:updateChoices()
    end)

    -- Reset query and load history
    self.currentQuery = ""
    self:loadHistory()
end

--- ClipboardHistory:start()
--- Method
--- Start monitoring clipboard changes
function obj:start()
    -- Set up clipboard watcher
    self.watcher = hs.pasteboard.watcher.new(function()
        self:onClipboardChange()
    end)
    self.watcher:start()

    -- Load history from file
    self:loadHistory()

    return self
end

--- ClipboardHistory:stop()
--- Method
--- Stop clipboard monitoring
function obj:stop()
    if self.watcher then
        self.watcher:stop()
        self.watcher = nil
    end
    return self
end

--- ClipboardHistory:escapeYamlString(str)
--- Method
--- Escape special characters for YAML-like format
function obj:escapeYamlString(str)
    if not str then return "" end
    -- Replace newlines with \n and backslashes with \\
    str = str:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\r", "\\r")
    return str
end

--- ClipboardHistory:unescapeYamlString(str)
--- Method
--- Unescape special characters from YAML-like format
function obj:unescapeYamlString(str)
    if not str then return "" end
    -- Replace \n with newlines and \\ with backslashes
    str = str:gsub("\\r", "\r"):gsub("\\n", "\n"):gsub("\\\\", "\\")
    return str
end

--- ClipboardHistory:loadHistory()
--- Method
--- Load clipboard history from plain text file
function obj:loadHistory()
    self.historyBuffer = {}

    local file = io.open(self.historyFile, "r")
    if not file then
        return
    end

    local currentEntry = nil
    for line in file:lines() do
        if line:match("^%- content: ") then
            -- Save previous entry if exists
            if currentEntry then
                table.insert(self.historyBuffer, currentEntry)
            end
            -- Start new entry
            currentEntry = {
                content = self:unescapeYamlString(line:match("^%- content: (.*)$"))
            }
        elseif line:match("^  when: ") then
            if currentEntry then
                currentEntry.timestamp = tonumber(line:match("^  when: (.*)$"))
            end
        elseif line:match("^  type: ") then
            if currentEntry then
                currentEntry.type = line:match("^  type: (.*)$")
            end
        end
    end

    -- Save last entry
    if currentEntry then
        table.insert(self.historyBuffer, currentEntry)
    end

    file:close()

    self.logger:d(string.format("Loaded %d entries from history file", #self.historyBuffer))
end

--- ClipboardHistory:saveHistory()
--- Method
--- Save clipboard history to plain text file
function obj:saveHistory()
    local file = io.open(self.historyFile, "w")
    if not file then
        self.logger:e("Failed to open history file for writing: " .. self.historyFile)
        return
    end

    for _, entry in ipairs(self.historyBuffer) do
        file:write(string.format("- content: %s\n", self:escapeYamlString(entry.content)))
        file:write(string.format("  when: %d\n", entry.timestamp or 0))
        file:write(string.format("  type: %s\n", entry.type or "text"))
    end

    file:close()
end

--- ClipboardHistory:generateScreenshotName(timestamp)
--- Method
--- Generate macOS-style screenshot name
--- Format: "Screenshot 2025-10-18 at 09.33.22"
function obj:generateScreenshotName(timestamp)
    timestamp = timestamp or os.time()
    -- Format: "Screenshot YYYY-MM-DD at HH.MM.SS"
    return os.date("Screenshot %Y-%m-%d at %H.%M.%S", timestamp)
end

--- ClipboardHistory:getFileDisplayName(filePath)
--- Method
--- Extract display name from file path with extension
function obj:getFileDisplayName(filePath)
    if not filePath then return nil end
    -- Extract filename with extension
    local filename = filePath:match("([^/]+)$")
    if filename then
        return filename
    end
    return nil
end

--- ClipboardHistory:onClipboardChange()
--- Method
--- Handle clipboard content changes
function obj:onClipboardChange()
    local content = hs.pasteboard.getContents()
    local contentType = "text"
    local displayName = nil

    -- Check for file URLs (from Finder) FIRST - this takes priority over everything
    -- When copying files from Finder, the pasteboard contains "public.file-url" UTI
    local contentTypes = hs.pasteboard.contentTypes()
    local hasFileURL = false

    if contentTypes then
        for _, uti in ipairs(contentTypes) do
            if uti == "public.file-url" then
                hasFileURL = true
                break
            end
        end
    end

    if hasFileURL then
        -- When copying files from Finder, macOS provides file URLs that may be file ID references
        -- like file:///.file/id=6571367. We need to resolve these using AppleScript.
        -- Try using shell command with osascript to resolve file URL
        local handle = io.popen([[
            osascript -e 'try
            set theFile to the clipboard as «class furl»
            return POSIX path of theFile
            end try' 2>&1
        ]])
        local result = handle:read("*a")
        handle:close()

        result = result:gsub("^%s+", ""):gsub("%s+$", "") -- trim whitespace

        if result and result ~= "" and result:match("^/") then
            content = result
            contentType = "file"
            self.logger:d("Captured file from Finder: " .. result)
        else
            self.logger:e("Failed to extract file path - osascript returned: " .. tostring(result))
            return
        end
        -- Only check for clipboard images if there's NO file URL
        -- This handles screenshots and images copied TO clipboard (not FROM Finder)
    elseif not hasFileURL and hs.pasteboard.readImage() then
        self.logger:d("=== Processing clipboard image (screenshot) ===")
        local imageData = hs.pasteboard.readImage()
        local timestamp = os.time()
        local spoonPath = hs.spoons.scriptPath()

        -- Generate macOS-style screenshot name
        displayName = self:generateScreenshotName(timestamp)
        local imagePath = spoonPath .. "/images/" .. displayName .. ".png"

        -- Create images directory if it doesn't exist
        os.execute("mkdir -p '" .. spoonPath .. "/images'")

        -- Check if this exact image already exists by extracting name from path
        for i, entry in ipairs(self.historyBuffer) do
            if entry.type == "image" then
                local existingName = self:getFileDisplayName(entry.content)
                if existingName == displayName then
                    -- Move existing entry to top
                    local movedEntry = table.remove(self.historyBuffer, i)
                    movedEntry.timestamp = timestamp
                    table.insert(self.historyBuffer, 1, movedEntry)
                    self:saveHistory()
                    self.logger:d("Moved existing image to top: " .. displayName)
                    return
                end
            end
        end

        -- Save image
        imageData:saveToFile(imagePath)
        content = imagePath
        contentType = "image"
    elseif not content or content == "" then
        return
    end

    -- Validate text content: check if it's empty or whitespace-only
    if contentType == "text" then
        local trimmedContent = content:match("^%s*(.-)%s*$")
        if not trimmedContent or trimmedContent == "" then
            return
        end
    end

    -- Check if content already exists (move to top if it does)
    for i, entry in ipairs(self.historyBuffer) do
        if entry.type == contentType and entry.content == content then
            -- Move to top
            local movedEntry = table.remove(self.historyBuffer, i)
            movedEntry.timestamp = os.time()
            table.insert(self.historyBuffer, 1, movedEntry)
            self:saveHistory()
            return
        end
    end

    -- Add new entry
    local newEntry = {
        content = content,
        timestamp = os.time(),
        type = contentType
    }

    table.insert(self.historyBuffer, 1, newEntry)

    -- Keep only maxEntries
    while #self.historyBuffer > self.maxEntries do
        table.remove(self.historyBuffer)
    end

    self:saveHistory()
end

--- ClipboardHistory:fuzzySearchRawEntries(query, entries)
--- Method
--- Pure Lua fuzzy search on raw entries (lightweight, no formatting)
function obj:fuzzySearchRawEntries(query, entries)
    if not query or query == "" then
        return entries
    end

    local queryLower = query:lower()
    local results = {}

    for _, entry in ipairs(entries) do
        -- For non-text files (images, videos, etc.), search by filename; for text, search by content
        local searchText = ""
        if entry.type ~= "text" and entry.content then
            -- Extract filename from path for all file types
            local filename = self:getFileDisplayName(entry.content)
            searchText = (filename or entry.content):lower()
        else
            searchText = (entry.content or ""):lower()
        end

        local score = 0

        -- Exact match gets highest score
        if searchText == queryLower then
            score = 1000
            -- Prefix match gets high score
        elseif searchText:sub(1, #queryLower) == queryLower then
            score = 500
            -- Contains match gets medium score
        elseif searchText:find(queryLower, 1, true) then
            score = 200
        else
            -- Fuzzy match: check if query characters appear in order
            local queryPos = 1
            local lastMatchPos = 0
            local gaps = 0

            for i = 1, #searchText do
                if queryPos <= #queryLower and searchText:sub(i, i) == queryLower:sub(queryPos, queryPos) then
                    gaps = gaps + (i - lastMatchPos - 1)
                    lastMatchPos = i
                    queryPos = queryPos + 1
                end
            end

            -- If all query characters were found
            if queryPos > #queryLower then
                -- Lower score for more gaps between matches
                score = math.max(0, 100 - gaps)
            end
        end

        if score > 0 then
            table.insert(results, {
                entry = entry,
                score = score
            })
        end
    end

    -- Sort by score (descending)
    table.sort(results, function(a, b)
        return a.score > b.score
    end)

    -- Extract entries
    local filteredEntries = {}
    for _, result in ipairs(results) do
        table.insert(filteredEntries, result.entry)
    end

    return filteredEntries
end

--- ClipboardHistory:buildFormattedChoice(rawEntry)
--- Method
--- Build a formatted choice from a raw entry
function obj:buildFormattedChoice(rawEntry)
    -- Helper function to get file extension
    local function getFileExtension(filePath)
        if not filePath then return nil end
        return filePath:match("%.([^%.]+)$")
    end

    -- Helper function to determine file type from extension
    local function getFileTypeFromExtension(extension)
        if not extension then return "file" end
        extension = extension:lower()

        local imageExts = { "png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp", "svg", "ico" }
        local videoExts = { "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v", "3gp", "mpg", "mpeg" }
        local audioExts = { "mp3", "wav", "flac", "aac", "ogg", "m4a", "wma" }
        local docExts = { "pdf", "doc", "docx", "txt", "rtf", "pages" }
        local codeExts = { "js", "html", "css", "py", "lua", "swift", "java", "cpp", "c", "rb", "go", "rs" }

        for _, ext in ipairs(imageExts) do
            if extension == ext then return "image" end
        end
        for _, ext in ipairs(videoExts) do
            if extension == ext then return "video" end
        end
        for _, ext in ipairs(audioExts) do
            if extension == ext then return "audio" end
        end
        for _, ext in ipairs(docExts) do
            if extension == ext then return "document" end
        end
        for _, ext in ipairs(codeExts) do
            if extension == ext then return "code" end
        end

        return "file"
    end

    -- Helper function to truncate text for display
    local function truncateText(text, maxLength)
        if not text then return "" end
        maxLength = maxLength or 200
        if #text <= maxLength then
            return text
        end
        return text:sub(1, maxLength) .. "..."
    end

    local entry = rawEntry
    local preview = entry.content or ""

    -- For text entries, truncate long content for performance
    if entry.type == "text" then
        preview = truncateText(preview, 200)
    end

    -- Format date for display
    local dateDisplay = ""
    if entry.timestamp then
        local timestamp = tonumber(entry.timestamp) or 0
        local today = os.time()
        local daysDiff = math.floor((today - timestamp) / 86400)

        if daysDiff == 0 then
            dateDisplay = "Today"
        elseif daysDiff == 1 then
            dateDisplay = "Yesterday"
        else
            dateDisplay = os.date("%b %d", timestamp)
        end
    end

    -- Format time
    local timeDisplay = ""
    if entry.timestamp then
        timeDisplay = os.date("%H:%M", entry.timestamp)
    end

    local subText = string.format("%s • %s %s",
        entry.type or "text",
        dateDisplay,
        timeDisplay)

    -- Create choice entry
    local choiceEntry = {
        text = preview,
        subText = subText,
        content = entry.content,
        timestamp = entry.timestamp,
        type = entry.type
    }

    -- Handle different content types for preview
    if entry.type == "image" and entry.content then
        -- Saved clipboard screenshot
        local imagePath = entry.content
        local file = io.open(imagePath, "r")
        if file then
            file:close()
            local image = hs.image.imageFromPath(imagePath)
            if image then
                -- Resize image to a reasonable size for preview (max 64x64)
                local size = image:size()
                if size.w > 64 or size.h > 64 then
                    local scale = math.min(64 / size.w, 64 / size.h)
                    image = image:setSize({ w = size.w * scale, h = size.h * scale })
                end
                choiceEntry.image = image
                -- Extract filename from path
                choiceEntry.text = self:getFileDisplayName(entry.content) or "Image"
            end
        end
    elseif entry.type == "file" and entry.content then
        -- File copied from Finder
        local filePath = entry.content
        local extension = getFileExtension(filePath)
        local fileType = getFileTypeFromExtension(extension)

        -- choiceEntry.image = fileIcon
        -- Extract and display filename for all file types
        choiceEntry.text = self:getFileDisplayName(filePath) or preview

        -- Check if file exists
        local file = io.open(filePath, "r")
        if file then
            file:close()

            -- For image files from Finder, show preview
            if fileType == "image" or fileType == 'video' then
                local image = hs.image.imageFromPath(filePath)
                if image then
                    local size = image:size()
                    if size.w > 64 or size.h > 64 then
                        local scale = math.min(64 / size.w, 64 / size.h)
                        image = image:setSize({ w = size.w * scale, h = size.h * scale })
                    end
                    choiceEntry.image = image
                end
            end
        else
            choiceEntry.text = (self:getFileDisplayName(filePath) or preview) .. " (file not found)"
        end
    elseif entry.content and entry.content:match("^/") then
        -- Legacy: old entries that might have paths but no proper type
        -- Looks like a file path
        local filePath = entry.content
        local extension = getFileExtension(filePath)
        local fileType = getFileTypeFromExtension(extension)

        -- Extract and display filename for all file types
        choiceEntry.text = self:getFileDisplayName(filePath) or preview

        -- Check if file exists
        local file = io.open(filePath, "r")
        if file then
            file:close()

            if fileType == "image" or fileType == 'video' then
                local image = hs.image.imageFromPath(filePath)
                if image then
                    local size = image:size()
                    if size.w > 64 or size.h > 64 then
                        local scale = math.min(64 / size.w, 64 / size.h)
                        image = image:setSize({ w = size.w * scale, h = size.h * scale })
                    end
                    choiceEntry.image = image
                end
            end
        else
            choiceEntry.text = (self:getFileDisplayName(filePath) or preview) .. " (file not found)"
        end
    end

    return choiceEntry
end

--- ClipboardHistory:getFilteredChoices()
--- Method
--- Get filtered choices based on current query with fuzzy search
--- This does: fuzzy search on raw entries → format only the filtered results
function obj:getFilteredChoices()
    -- Step 1: Fuzzy search on lightweight raw entries
    local filteredRawEntries = self:fuzzySearchRawEntries(self.currentQuery, self.historyBuffer)

    -- Step 2: Format only the filtered results (load images only for displayed items)
    local formattedChoices = {}
    for _, rawEntry in ipairs(filteredRawEntries) do
        local formattedChoice = self:buildFormattedChoice(rawEntry)
        table.insert(formattedChoices, formattedChoice)
    end

    return formattedChoices
end

--- ClipboardHistory:updateChoices()
--- Method
--- Update chooser choices based on current query
function obj:updateChoices()
    local filteredChoices = self:getFilteredChoices()
    self.logger:d(string.format("Setting %d filtered choices in chooser", #filteredChoices))
    self.chooser:choices(filteredChoices)
end

--- ClipboardHistory:show()
--- Method
--- Show the clipboard history chooser
function obj:show()
    if #self.historyBuffer == 0 then
        hs.alert.show("📋 Clipboard history is empty", 1)
        return
    end

    self.currentQuery = ""
    self:updateChoices()
    self.chooser:show()
end

--- ClipboardHistory:hide()
--- Method
--- Hide the clipboard history chooser
function obj:hide()
    self.chooser:hide()
end

--- ClipboardHistory:toggle()
--- Method
--- Toggle the clipboard history chooser visibility
function obj:toggle()
    if self.chooser and self.chooser:isVisible() then
        self:hide()
    else
        self:initializeChooser()
        self:show()
    end
end

--- ClipboardHistory:shouldOnlyCopy()
--- Method
--- Check if we should only copy (not paste)
function obj:shouldOnlyCopy()
    local app = hs.application.frontmostApplication()
    if not app then
        return true
    end

    local appName = app:name()

    local copyOnlyApps = {
        "System Preferences",
        "System Settings",
        "Activity Monitor",
        "Console"
    }

    for _, copyApp in ipairs(copyOnlyApps) do
        if appName == copyApp then
            return true
        end
    end

    return false
end

--- ClipboardHistory:copyToClipboard(choice)
--- Method
--- Copy content to clipboard without pasting
function obj:copyToClipboard(choice)
    if choice.type == "image" then
        local imagePath = choice.content
        local file = io.open(imagePath, "r")
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
    elseif choice.type == "file" then
        -- For files from Finder, write the file URL back to clipboard using AppleScript
        local filePath = choice.content
        local escapedPath = filePath:gsub("'", "'\\''") -- Escape single quotes
        os.execute(string.format([[osascript -e 'set the clipboard to POSIX file "%s"']], escapedPath))
        self.logger:d("Copied file to clipboard: " .. filePath)
    else
        hs.pasteboard.setContents(choice.content)
        self.logger:d("Copied text to clipboard")
    end

    hs.alert.show("📋 Copied to clipboard", 0.5)
end

--- ClipboardHistory:pasteContent(choice)
--- Method
--- Paste content based on its type
function obj:pasteContent(choice)
    self.logger:d("pasteContent called - type: " .. tostring(choice.type))

    if choice.type == "image" then
        self.logger:d("Pasting image from: " .. tostring(choice.content))
        local imagePath = choice.content
        local file = io.open(imagePath, "r")
        if file then
            file:close()
            local imageData = hs.image.imageFromPath(imagePath)
            if imageData then
                hs.pasteboard.writeObjects(imageData)
                self.logger:d("Image written to clipboard")
            else
                hs.pasteboard.setContents(choice.content)
                self.logger:d("Failed to load image, wrote path instead")
            end
        else
            hs.pasteboard.setContents(choice.content)
            self.logger:d("Image file not found, wrote path instead")
        end
    elseif choice.type == "file" then
        self.logger:d("Pasting file: " .. tostring(choice.content))

        -- Try treating image files like screenshots - load as image and write to pasteboard
        local filePath = choice.content
        local extension = filePath:match("%.([^%.]+)$")
        local isImage = extension and (extension:lower() == "png" or extension:lower() == "jpg" or
            extension:lower() == "jpeg" or extension:lower() == "gif" or
            extension:lower() == "webp" or extension:lower() == "bmp")

        if isImage then
            self.logger:d("File is an image, loading as image data")
            local imageData = hs.image.imageFromPath(filePath)
            if imageData then
                hs.pasteboard.writeObjects(imageData)
                self.logger:d("Image written to clipboard")
            else
                self.logger:d("Failed to load image, using AppleScript fallback")
                local escapedPath = filePath:gsub("'", "'\\''")
                os.execute(string.format([[osascript -e 'set the clipboard to POSIX file "%s"']], escapedPath))
            end
        else
            self.logger:d("File is not an image, using AppleScript")
            local escapedPath = filePath:gsub("'", "'\\''")
            os.execute(string.format([[osascript -e 'set the clipboard to POSIX file "%s"']], escapedPath))
        end
    else
        self.logger:d("Pasting text")
        hs.pasteboard.setContents(choice.content)
    end

    hs.timer.doAfter(0, function()
        self.logger:d("Executing paste command")
        hs.eventtap.keyStroke({ "cmd" }, "v", 0)
    end)
end

--- ClipboardHistory:clear()
--- Method
--- Clear clipboard history
function obj:clear()
    self.historyBuffer = {}
    local file = io.open(self.historyFile, "w")
    if file then
        file:close()
    end
    hs.alert.show("🗑️ Clipboard history cleared", 1)
end

--- ClipboardHistory:delete()
--- Method
--- Clean up the spoon
function obj:delete()
    self:stop()
    if self.chooser then
        self.chooser:delete()
        self.chooser = nil
    end
end

--- ClipboardHistory:bindHotkeys(mapping)
--- Method
--- Bind hotkeys for ClipboardHistory
---
--- Parameters:
---  * mapping - A table containing hotkey mappings. Supported keys:
---    * show - Show the clipboard history chooser
---    * toggle - Toggle the clipboard history chooser visibility
---    * clear - Clear clipboard history
function obj:bindHotkeys(mapping)
    local def = {
        show = hs.fnutils.partial(self.show, self),
        toggle = hs.fnutils.partial(self.toggle, self),
        clear = hs.fnutils.partial(self.clear, self)
    }
    hs.spoons.bindHotkeysToSpec(def, mapping)
    return self
end

return obj
