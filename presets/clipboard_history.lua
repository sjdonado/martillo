-- Clipboard History Preset
-- Persistent clipboard history with fuzzy search
-- All-in-one solution without requiring a separate spoon

local searchUtils = require("lib.search")
local navigation = require("lib.navigation")

local M = {
	watcher = nil,
	maxEntries = 300,
	historyFile = nil,
	currentQuery = "",
	historyBuffer = {},
	imageCache = {},
	thumbnailSize = { w = 32, h = 32 }, -- Smaller thumbnails for better performance
	maxCacheSize = 50, -- Limit cache to 50 images
	lastFocusedApp = nil,
	lastFocusedWindow = nil,
	logger = hs.logger.new("ClipboardHistory", "debug"),
}

-- Escape special characters for YAML-like format
local function escapeYamlString(str)
	if not str then
		return ""
	end
	return str:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\r", "\\r")
end

-- Unescape special characters from YAML-like format
local function unescapeYamlString(str)
	if not str then
		return ""
	end
	return str:gsub("\\r", "\r"):gsub("\\n", "\n"):gsub("\\\\", "\\")
end

-- Load clipboard history from plain text file
local function loadHistory()
	M.historyBuffer = {}

	local file = io.open(M.historyFile, "r")
	if not file then
		return
	end

	local currentEntry = nil
	for line in file:lines() do
		if line:match("^%- content: ") then
			if currentEntry then
				table.insert(M.historyBuffer, currentEntry)
			end
			currentEntry = {
				content = unescapeYamlString(line:match("^%- content: (.*)$")),
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

	if currentEntry then
		table.insert(M.historyBuffer, currentEntry)
	end

	file:close()
	M.logger:d(string.format("Loaded %d entries from history file", #M.historyBuffer))
end

-- Save clipboard history to plain text file
local function saveHistory()
	local file = io.open(M.historyFile, "w")
	if not file then
		M.logger:e("Failed to open history file for writing: " .. M.historyFile)
		return
	end

	for _, entry in ipairs(M.historyBuffer) do
		file:write(string.format("- content: %s\n", escapeYamlString(entry.content)))
		file:write(string.format("  when: %d\n", entry.timestamp or 0))
		file:write(string.format("  type: %s\n", entry.type or "text"))
	end

	file:close()
end

-- Generate macOS-style screenshot name
local function generateScreenshotName(timestamp)
	timestamp = timestamp or os.time()
	return os.date("Screenshot %Y-%m-%d at %H.%M.%S", timestamp)
end

-- Extract display name from file path
local function getFileDisplayName(filePath)
	if not filePath then
		return nil
	end
	local filename = filePath:match("([^/]+)$")
	return filename
end

-- Handle clipboard content changes
local function onClipboardChange()
	local content = hs.pasteboard.getContents()
	local contentType = "text"
	local displayName = nil

	-- Check for file URLs from Finder
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
		-- Resolve file URL using AppleScript
		local handle = io.popen([[
            osascript -e 'try
            set theFile to the clipboard as «class furl»
            return POSIX path of theFile
            end try' 2>&1
        ]])
		local result = handle:read("*a")
		handle:close()

		result = result:gsub("^%s+", ""):gsub("%s+$", "")

		if result and result ~= "" and result:match("^/") then
			content = result
			contentType = "file"
			M.logger:d("Captured file from Finder: " .. result)
		else
			M.logger:e("Failed to extract file path - osascript returned: " .. tostring(result))
			return
		end
	elseif not hasFileURL and hs.pasteboard.readImage() then
		M.logger:d("=== Processing clipboard image (screenshot) ===")
		local imageData = hs.pasteboard.readImage()
		local timestamp = os.time()
		local presetsPath = os.getenv("HOME") .. "/.martillo/presets"

		displayName = generateScreenshotName(timestamp)
		local imagePath = presetsPath .. "/clipboard_images/" .. displayName .. ".png"

		-- Create images directory
		os.execute("mkdir -p '" .. presetsPath .. "/clipboard_images'")

		-- Check if image already exists
		for i, entry in ipairs(M.historyBuffer) do
			if entry.type == "image" then
				local existingName = getFileDisplayName(entry.content)
				if existingName == displayName then
					local movedEntry = table.remove(M.historyBuffer, i)
					movedEntry.timestamp = timestamp
					table.insert(M.historyBuffer, 1, movedEntry)
					saveHistory()
					M.logger:d("Moved existing image to top: " .. displayName)
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

	-- Validate text content
	if contentType == "text" then
		local trimmedContent = content:match("^%s*(.-)%s*$")
		if not trimmedContent or trimmedContent == "" then
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

-- Get image from cache or load and cache it
local function getImageFromCache(imagePath)
	if M.imageCache[imagePath] then
		return M.imageCache[imagePath]
	end

	-- Check cache size and evict oldest if necessary
	local cacheSize = 0
	for _ in pairs(M.imageCache) do
		cacheSize = cacheSize + 1
	end

	if cacheSize >= M.maxCacheSize then
		-- Simple eviction: clear entire cache when limit reached
		M.logger:d("Image cache full, clearing cache")
		M.imageCache = {}
	end

	local file = io.open(imagePath, "r")
	if not file then
		return nil
	end
	file:close()

	local image = hs.image.imageFromPath(imagePath)
	if not image then
		return nil
	end

	-- Resize to fixed thumbnail size for consistent performance
	local resized = image:setSize(M.thumbnailSize)

	M.imageCache[imagePath] = resized
	return resized
end

-- Fuzzy search on raw entries
local function fuzzySearchRawEntries(query, entries)
	if not query or query == "" then
		return entries
	end

	local now = os.time()

	local rankedEntries = searchUtils.rank(query, entries, {
		getFields = function(entry)
			if entry.type ~= "text" and entry.content then
				local filename = getFileDisplayName(entry.content)
				if filename and filename ~= "" then
					return {
						{ value = filename, weight = 1.0, key = "filename" },
						{ value = entry.content or "", weight = 0.4, key = "path" },
					}
				end
				return { { value = entry.content or "", weight = 1.0, key = "path" } }
			end

			return { { value = entry.content or "", weight = 1.0, key = "content" } }
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
		return filePath:match("%.([^%.]+)$")
	end

	local function getFileTypeFromExtension(extension)
		if not extension then
			return "file"
		end
		extension = extension:lower()

		local imageExts = { "png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp", "svg", "ico" }
		local videoExts = { "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v", "3gp", "mpg", "mpeg" }

		for _, ext in ipairs(imageExts) do
			if extension == ext then
				return "image"
			end
		end
		for _, ext in ipairs(videoExts) do
			if extension == ext then
				return "video"
			end
		end

		return "file"
	end

	local function truncateText(text, maxLength)
		if not text then
			return ""
		end
		maxLength = maxLength or 200
		if #text <= maxLength then
			return text
		end
		return text:sub(1, maxLength) .. "..."
	end

	local entry = rawEntry
	local preview = entry.content or ""

	if entry.type == "text" then
		preview = truncateText(preview, 200)
	end

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

	local timeDisplay = ""
	if entry.timestamp then
		timeDisplay = os.date("%H:%M", entry.timestamp)
	end

	local subText = string.format("%s • %s %s", entry.type or "text", dateDisplay, timeDisplay)

	local choiceEntry = {
		text = preview,
		subText = subText,
		content = entry.content,
		timestamp = entry.timestamp,
		type = entry.type,
	}

	-- Handle different content types for preview
	-- Only load images if requested (for performance)
	if entry.type == "image" and entry.content then
		choiceEntry.text = getFileDisplayName(entry.content) or "Image"

		if loadImages then
			local imagePath = entry.content
			local image = getImageFromCache(imagePath)
			if image then
				choiceEntry.image = image
			end
		end
	elseif entry.type == "file" and entry.content then
		local filePath = entry.content
		local extension = getFileExtension(filePath)
		local fileType = getFileTypeFromExtension(extension)

		choiceEntry.text = getFileDisplayName(filePath) or preview

		if (fileType == "image" or fileType == "video") and loadImages then
			local image = getImageFromCache(filePath)
			if image then
				choiceEntry.image = image
			else
				choiceEntry.text = (getFileDisplayName(filePath) or preview) .. " (file not found)"
			end
		elseif fileType ~= "image" and fileType ~= "video" then
			local file = io.open(filePath, "r")
			if not file then
				choiceEntry.text = (getFileDisplayName(filePath) or preview) .. " (file not found)"
			else
				file:close()
			end
		end
	end

	return choiceEntry
end

-- Capture focus before showing picker
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

	local appName = app:name() or ""
	local copyOnlyApps = {
		"System Preferences",
		"System Settings",
		"Activity Monitor",
		"Console",
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
		local filePath = choice.content
		local escapedPath = filePath:gsub("'", "'\\''")
		os.execute(string.format([[osascript -e 'set the clipboard to POSIX file "%s"']], escapedPath))
		M.logger:d("Copied file to clipboard: " .. filePath)
	else
		hs.pasteboard.setContents(choice.content)
		M.logger:d("Copied text to clipboard")
	end

	hs.alert.show("📋 Copied to clipboard", 0.5)
	restoreFocus()
end

-- Paste content
local function pasteContent(choice)
	M.logger:d("pasteContent called - type: " .. tostring(choice.type))

	if choice.type == "image" then
		M.logger:d("Pasting image from: " .. tostring(choice.content))
		local imagePath = choice.content
		local file = io.open(imagePath, "r")
		if file then
			file:close()
			local imageData = hs.image.imageFromPath(imagePath)
			if imageData then
				hs.pasteboard.writeObjects(imageData)
				M.logger:d("Image written to clipboard")
			else
				hs.pasteboard.setContents(choice.content)
				M.logger:d("Failed to load image, wrote path instead")
			end
		else
			hs.pasteboard.setContents(choice.content)
			M.logger:d("Image file not found, wrote path instead")
		end
	elseif choice.type == "file" then
		M.logger:d("Pasting file: " .. tostring(choice.content))

		local filePath = choice.content
		local extension = filePath:match("%.([^%.]+)$")
		local isImage = extension
			and (
				extension:lower() == "png"
				or extension:lower() == "jpg"
				or extension:lower() == "jpeg"
				or extension:lower() == "gif"
				or extension:lower() == "webp"
				or extension:lower() == "bmp"
			)

		if isImage then
			M.logger:d("File is an image, loading as image data")
			local imageData = hs.image.imageFromPath(filePath)
			if imageData then
				hs.pasteboard.writeObjects(imageData)
				M.logger:d("Image written to clipboard")
			else
				M.logger:d("Failed to load image, using AppleScript fallback")
				local escapedPath = filePath:gsub("'", "'\\''")
				os.execute(string.format([[osascript -e 'set the clipboard to POSIX file "%s"']], escapedPath))
			end
		else
			M.logger:d("File is not an image, using AppleScript")
			local escapedPath = filePath:gsub("'", "'\\''")
			os.execute(string.format([[osascript -e 'set the clipboard to POSIX file "%s"']], escapedPath))
		end
	else
		M.logger:d("Pasting text")
		hs.pasteboard.setContents(choice.content)
	end

	restoreFocus()
	hs.eventtap.keyStroke({ "cmd" }, "v", 0)
end

-- Initialize clipboard monitoring
local function initClipboardMonitoring()
	if M.watcher then
		return -- Already initialized
	end

	-- Set up history file path
	local presetsPath = os.getenv("HOME") .. "/.martillo/presets"
	M.historyFile = presetsPath .. "/clipboard_history"

	-- Set up clipboard watcher
	M.watcher = hs.pasteboard.watcher.new(onClipboardChange)
	M.watcher:start()

	-- Load history
	loadHistory()

	M.logger:d("Clipboard monitoring started")
end

-- Start monitoring when preset is loaded
initClipboardMonitoring()

-- Return action definition
return {
	{
		id = "clipboard_history",
		name = "Clipboard History",
		description = "Search and paste from clipboard history",
		handler = function()
			-- Check if history is empty
			if #M.historyBuffer == 0 then
				hs.alert.show("📋 Clipboard history is empty", 1)
				return
			end

			-- Capture focus for paste functionality
			captureFocus()

			-- Use ActionsLauncher's openChildPicker for consistency
			spoon.ActionsLauncher:openChildPicker({
				placeholder = "Search clipboard history...",
				parentAction = "clipboard_history",
				handler = function(query, launcher)
					-- Update current query for filtering
					M.currentQuery = query or ""

					-- Get filtered entries
					local filteredRawEntries = fuzzySearchRawEntries(M.currentQuery, M.historyBuffer)

					-- Build choices with handlers
					-- Only load images for first 30 results to improve performance
					local maxImagesLoad = 30
					local choices = {}
					for i, rawEntry in ipairs(filteredRawEntries) do
						local shouldLoadImages = i <= maxImagesLoad
						local formattedChoice = buildFormattedChoice(rawEntry, shouldLoadImages)

						-- Generate UUID for this choice
						local uuid = launcher:generateUUID()
						formattedChoice.uuid = uuid

						-- Register handler for this choice
						launcher.handlers[uuid] = function()
							local shiftHeld = navigation.isShiftHeld()

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

							-- Return empty string to prevent default copy/paste behavior
							return ""
						end

						table.insert(choices, formattedChoice)
					end

					return choices
				end,
			})

			return "OPEN_CHILD_PICKER"
		end,
	},
}
