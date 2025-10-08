--- === ClipboardHistory ===
---
--- Persistent clipboard history with fuzzy search and optimized loading
---
--- Performance Features:
--- • Loads most recent items initially using fast Objective-C component
--- • Unlimited scalable SQLite database with FTS5 full-text search
--- • Smart memory buffer for instant access
--- • Native Objective-C SQLite integration for maximum performance

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "ClipboardHistory"
obj.version = "1.0"
obj.author = "sjdonado"
obj.homepage = "https://github.com/sjdonado/martillo/spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.chooser = nil
obj.hotkeys = {}
obj.watcher = nil
obj.maxEntries = 300          -- Maximum number of entries to keep in memory and display
obj.historyBuffer = {}        -- Memory buffer with most recent entries
obj.dbFile = nil
obj.currentQuery = ""
obj.clipboardMonitorTask = nil
obj.sqliteReaderBinary = nil
obj.clipboardMonitorBinary = nil
obj.logger = hs.logger.new('ClipboardHistory')

--- ClipboardHistory:init()
--- Method
--- Initialize the spoon
function obj:init()
    -- Set up database paths
    local spoonPath = hs.spoons.scriptPath()
    self.dbPath = spoonPath .. "/clipboard_rocksdb"
    self.usearchPath = spoonPath .. "/clipboard_usearch"

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

    -- Reset to show only historyBuffer (most recent entries)
    self.currentQuery = ""
    self:initializeBuffer()
end

--- ClipboardHistory:start()
--- Method
--- Start monitoring clipboard changes
function obj:start()
    -- Set up clipboard watcher that triggers Objective-C monitor
    self.watcher = hs.pasteboard.watcher.new(function()
        self:onClipboardChange()
    end)
    self.watcher:start()

    -- Initialize buffer with first entries
    self:initializeBuffer()

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
    if self.clipboardMonitorTask then
        self.clipboardMonitorTask:terminate()
        self.clipboardMonitorTask = nil
    end
    -- Clear cached binary references (don't delete - they're managed by compile())
    self.sqliteReaderBinary = nil
    self.clipboardMonitorBinary = nil
    return self
end

--- ClipboardHistory:compileClipboardMonitor()
--- Method
--- Compile the clipboard monitor binary if needed (deprecated - use compile() instead)
function obj:compileClipboardMonitor()
    -- Use cached binary if available
    if self.clipboardMonitorBinary then
        return self.clipboardMonitorBinary
    end

    -- Check if binary exists (should be compiled by compile() method)
    local spoonPath = hs.spoons.scriptPath()
    local binaryPath = spoonPath .. "/clipboard_monitor_sqlite_bin"

    local binaryAttr = hs.fs.attributes(binaryPath)
    if binaryAttr then
        self.clipboardMonitorBinary = binaryPath
        return binaryPath
    end

    -- Binary not found
    self.logger:e("Clipboard monitor binary not found. Run compile() first.")
    return nil
end

--- ClipboardHistory:onClipboardChange()
--- Method
--- Handle clipboard content changes using cached Objective-C component
function obj:onClipboardChange()
    -- Cancel any existing monitoring task
    if self.clipboardMonitorTask then
        self.clipboardMonitorTask:terminate()
        self.clipboardMonitorTask = nil
    end

    local rocksdbBinary = self:getRocksDBBinary()
    if not rocksdbBinary then
        self.logger:e("RocksDB binary not available")
        return
    end

    -- Run the RocksDB clipboard monitor
    local spoonPath = hs.spoons.scriptPath()
    local monitorPath = spoonPath .. "/clipboard_monitor_rocksdb_bin"
    local command = string.format('"%s" "%s" "%s"', monitorPath, rocksdbBinary, self.dbPath)

    self.clipboardMonitorTask = hs.task.new("/bin/sh", function(exitCode, stdOut, stdErr)
        self.clipboardMonitorTask = nil

        if exitCode == 0 and stdOut then
            -- Parse the new entry from stdout and add to buffer
            self:addToBuffer(stdOut)
            -- Also add to USearch index for semantic search
            self:addToUSearchIndex(stdOut)
        else
            self.logger:e("RocksDB monitor failed: " .. (stdErr or "unknown error"))
        end
    end, { "-c", command })

    self.clipboardMonitorTask:start()
end

--- ClipboardHistory:addToUSearchIndex()
--- Method
--- Add entry to USearch index for semantic similarity search
function obj:addToUSearchIndex(jsonEntry)
    local usearchBinary = self:getUSearchBinary()
    if not usearchBinary then
        return -- USearch not available, skip indexing
    end

    local success, entry = pcall(hs.json.decode, jsonEntry)
    if not success or not entry or not entry.id or not entry.content then
        return
    end

    -- Add to USearch index
    local command = string.format('"%s" "%s" add "%s" "%s"',
        usearchBinary, self.usearchPath, entry.id, entry.content:gsub('"', '\\"'))

    hs.task.new("/bin/sh", function(exitCode, stdOut, stdErr)
        if exitCode ~= 0 and stdErr then
            self.logger:d("USearch indexing warning: " .. stdErr)
        end
    end, { "-c", command }):start()
end

--- ClipboardHistory:compile()
--- Method
--- Compile both SQLite reader and clipboard monitor binaries
function obj:compile()
    self.logger:i("🔨 Compiling RocksDB + USearch binaries...")

    local spoonPath = hs.spoons.scriptPath()

    -- Validate required dependencies
    local requiredLibs = {
        { path = "/opt/homebrew/lib/librocksdb.dylib", name = "RocksDB" },
        { path = "/opt/homebrew/lib/libjsoncpp.dylib", name = "jsoncpp" },
        { path = "/opt/homebrew/include/rocksdb",      name = "RocksDB headers" },
        { path = spoonPath .. "/usearch_index.hpp",    name = "USearch header" }
    }

    for _, lib in ipairs(requiredLibs) do
        if not hs.fs.attributes(lib.path) then
            local errorMsg = "❌ Missing dependency: " .. lib.name .. " (" .. lib.path .. ")"
            print(errorMsg)
            print("Install with: brew install rocksdb jsoncpp")
            error(errorMsg)
        end
    end

    -- Compile RocksDB manager
    local rocksdbSource = spoonPath .. "/rocksdb_manager.cpp"
    local rocksdbBinary = spoonPath .. "/rocksdb_manager_bin"

    local file = io.open(rocksdbSource, "r")
    if not file then
        local errorMsg = "❌ RocksDB manager source file not found: " .. rocksdbSource
        print(errorMsg)
        print("Current spoon path: " .. spoonPath)
        print("Stack trace:")
        print(debug.traceback())
        error(errorMsg)
    end
    file:close()

    local sourceAttr = hs.fs.attributes(rocksdbSource)
    local binaryAttr = hs.fs.attributes(rocksdbBinary)

    if not binaryAttr or not sourceAttr or binaryAttr.modification < sourceAttr.modification then
        local compileCmd = string.format(
            "/usr/bin/clang++ -std=c++17 -O3 -I/opt/homebrew/include -L/opt/homebrew/lib " ..
            "-lrocksdb -ljsoncpp -o %s %s",
            rocksdbBinary, rocksdbSource)
        local output, success = hs.execute(compileCmd)
        if not success then
            local errorMsg = "❌ Failed to compile RocksDB manager"
            print(errorMsg)
            print("Command: " .. compileCmd)
            print("Output: " .. (output or "no output"))
            print("Stack trace:")
            print(debug.traceback())
            error(errorMsg)
        end
        self.logger:i("✅ RocksDB manager compiled")
    else
        self.logger:i("✅ RocksDB manager up to date")
    end

    -- Compile USearch manager
    local usearchSource = spoonPath .. "/usearch_manager.cpp"
    local usearchBinary = spoonPath .. "/usearch_manager_bin"

    file = io.open(usearchSource, "r")
    if not file then
        local errorMsg = "❌ USearch manager source file not found: " .. usearchSource
        print(errorMsg)
        print("Current spoon path: " .. spoonPath)
        print("Stack trace:")
        print(debug.traceback())
        error(errorMsg)
    end
    file:close()

    sourceAttr = hs.fs.attributes(usearchSource)
    binaryAttr = hs.fs.attributes(usearchBinary)

    if not binaryAttr or not sourceAttr or binaryAttr.modification < sourceAttr.modification then
        local compileCmd = string.format(
            "/usr/bin/clang++ -std=c++17 -O3 -I/opt/homebrew/include -I%s -L/opt/homebrew/lib " ..
            "-lrocksdb -ljsoncpp -o %s %s",
            spoonPath, usearchBinary, usearchSource)
        local output, success = hs.execute(compileCmd)
        if not success then
            local errorMsg = "❌ Failed to compile USearch manager"
            print(errorMsg)
            print("Command: " .. compileCmd)
            print("Output: " .. (output or "no output"))
            print("Stack trace:")
            print(debug.traceback())
            error(errorMsg)
        end
        self.logger:i("✅ USearch manager compiled")
    else
        self.logger:i("✅ USearch manager up to date")
    end

    -- Compile clipboard monitor
    local monitorSource = spoonPath .. "/clipboard_monitor_rocksdb.m"
    local monitorBinary = spoonPath .. "/clipboard_monitor_rocksdb_bin"

    file = io.open(monitorSource, "r")
    if not file then
        local errorMsg = "❌ Clipboard monitor source file not found: " .. monitorSource
        print(errorMsg)
        print("Current spoon path: " .. spoonPath)
        print("Stack trace:")
        print(debug.traceback())
        error(errorMsg)
    end
    file:close()

    sourceAttr = hs.fs.attributes(monitorSource)
    binaryAttr = hs.fs.attributes(monitorBinary)

    if not binaryAttr or not sourceAttr or binaryAttr.modification < sourceAttr.modification then
        local compileCmd = string.format(
            "/usr/bin/clang -framework Cocoa -I/opt/homebrew/include -L/opt/homebrew/lib " ..
            "-lrocksdb -ljsoncpp -o %s %s",
            monitorBinary, monitorSource)
        local output, success = hs.execute(compileCmd)
        if not success then
            local errorMsg = "❌ Failed to compile clipboard monitor"
            print(errorMsg)
            print("Command: " .. compileCmd)
            print("Output: " .. (output or "no output"))
            print("Stack trace:")
            print(debug.traceback())
            error(errorMsg)
        end
        self.logger:i("✅ Clipboard monitor compiled")
    else
        self.logger:i("✅ Clipboard monitor up to date")
    end

    -- Verify binaries were created successfully
    local finalRocksdbAttr = hs.fs.attributes(rocksdbBinary)
    local finalUsearchAttr = hs.fs.attributes(usearchBinary)
    local finalMonitorAttr = hs.fs.attributes(monitorBinary)

    if not finalRocksdbAttr then
        local errorMsg = "❌ RocksDB binary was not created: " .. rocksdbBinary
        print(errorMsg)
        print("Binary path: " .. rocksdbBinary)
        print("Stack trace:")
        print(debug.traceback())
        error(errorMsg)
    end

    if not finalUsearchAttr then
        local errorMsg = "❌ USearch binary was not created: " .. usearchBinary
        print(errorMsg)
        print("Binary path: " .. usearchBinary)
        print("Stack trace:")
        print(debug.traceback())
        error(errorMsg)
    end

    if not finalMonitorAttr then
        local errorMsg = "❌ Clipboard monitor binary was not created: " .. monitorBinary
        print(errorMsg)
        print("Binary path: " .. monitorBinary)
        print("Stack trace:")
        print(debug.traceback())
        error(errorMsg)
    end

    -- Cache binary paths
    self.rocksdbBinary = rocksdbBinary
    self.usearchBinary = usearchBinary
    self.clipboardMonitorBinary = monitorBinary

    self.logger:i("✅ All binaries compiled and verified")
end

--- ClipboardHistory:getRocksDBBinary()
--- Method
--- Get the compiled RocksDB binary path
function obj:getRocksDBBinary()
    if self.rocksdbBinary then
        return self.rocksdbBinary
    end

    local spoonPath = hs.spoons.scriptPath()
    local binaryPath = spoonPath .. "/rocksdb_manager_bin"

    -- Check if binary exists
    local binaryAttr = hs.fs.attributes(binaryPath)
    if binaryAttr then
        self.rocksdbBinary = binaryPath
        return self.rocksdbBinary
    end

    -- Binary not found
    self.logger:e("RocksDB binary not found. Run compile() first.")
    return nil
end

--- ClipboardHistory:getUSearchBinary()
--- Method
--- Get the compiled USearch binary path
function obj:getUSearchBinary()
    if self.usearchBinary then
        return self.usearchBinary
    end

    local spoonPath = hs.spoons.scriptPath()
    local binaryPath = spoonPath .. "/usearch_manager_bin"

    -- Check if binary exists
    local binaryAttr = hs.fs.attributes(binaryPath)
    if binaryAttr then
        self.usearchBinary = binaryPath
        return self.usearchBinary
    end

    -- Binary not found
    self.logger:e("USearch binary not found. Run compile() first.")
    return nil
end

--- ClipboardHistory:compileSqliteReader()
--- Method
--- Compile the SQLite reader binary if needed (deprecated - use compile() instead)
function obj:compileSqliteReader()
    -- Use cached binary if available
    if self.sqliteReaderBinary then
        return self.sqliteReaderBinary
    end

    -- Check if binary exists (should be compiled by compile() method)
    local spoonPath = hs.spoons.scriptPath()
    local binaryPath = spoonPath .. "/sqlite_reader_bin"

    local binaryAttr = hs.fs.attributes(binaryPath)
    if binaryAttr then
        self.sqliteReaderBinary = binaryPath
        return binaryPath
    end

    -- Binary not found
    self.logger:e("SQLite reader binary not found. Run compile() first.")
    return nil
end

--- ClipboardHistory:initializeBuffer()
--- Method
--- Initialize buffer with first entries from RocksDB
function obj:initializeBuffer()
    local rocksdbBinary = self:getRocksDBBinary()
    if not rocksdbBinary then
        self.historyBuffer = {}
        return
    end

    -- Load first entries using RocksDB manager
    local command = string.format('"%s" "%s" recent %d', rocksdbBinary, self.dbPath, self.maxEntries)

    local handle = io.popen(command, "r")
    if handle then
        local output = handle:read("*all")
        local success, exitCode = handle:close()

        if output and output ~= "" then
            -- Clean the output
            output = output:gsub("^%s+", ""):gsub("%s+$", "")

            if output:match("^%[") then
                local parseSuccess, data = pcall(hs.json.decode, output)
                if parseSuccess and data and type(data) == "table" then
                    self.historyBuffer = data
                else
                    self.historyBuffer = {}
                end
            else
                self.historyBuffer = {}
            end
        else
            self.historyBuffer = {}
        end
    else
        self.historyBuffer = {}
    end
end

--- ClipboardHistory:addToBuffer(newEntryStr)
--- Method
--- Add new entry to buffer from clipboard monitor output
function obj:addToBuffer(newEntryStr)
    if not newEntryStr or newEntryStr == "" then
        return
    end

    -- Parse the new entry (SQLite monitor outputs the entry with action info)
    local success, newEntry = pcall(hs.json.decode, newEntryStr)
    if success and newEntry and type(newEntry) == "table" then
        if newEntry.action == "moved" then
            -- Find and move existing entry to top
            for i = 1, #self.historyBuffer do
                if self.historyBuffer[i] and self.historyBuffer[i].id == newEntry.id then
                    local existingEntry = table.remove(self.historyBuffer, i)
                    existingEntry.timestamp = newEntry.timestamp
                    existingEntry.time = newEntry.time
                    table.insert(self.historyBuffer, 1, existingEntry)
                    break
                end
            end
        elseif newEntry.action == "added" then
            -- Add new entry to beginning of buffer
            table.insert(self.historyBuffer, 1, newEntry)

            -- Keep only recent entries
            if #self.historyBuffer > self.maxEntries then
                table.remove(self.historyBuffer)
            end
        end

        -- No need to save - SQLite handles persistence
    end
end

--- ClipboardHistory:updateChoices()
--- Method
--- Update chooser choices based on current query and loaded history
function obj:updateChoices()
    local choices = {}

    -- Apply search if query exists
    local filteredEntries = {}
    if self.currentQuery == "" then
        -- No query, show all entries from buffer
        filteredEntries = self.historyBuffer
    else
        -- Use hybrid RocksDB + USearch for search
        local query = self.currentQuery
        self.logger:d("Searching for query: '" .. query .. "'")

        -- First try exact/prefix search with RocksDB
        local rocksdbBinary = self:getRocksDBBinary()
        if rocksdbBinary then
            local command = string.format('"%s" "%s" search "%s" %d',
                rocksdbBinary, self.dbPath, query:gsub('"', '\\"'), self.maxEntries)
            self.logger:d("Executing RocksDB search command: " .. command)

            local handle = io.popen(command, "r")
            if handle then
                local output = handle:read("*all")
                local success, exitType, exitCode = handle:close()

                if output and output ~= "" then
                    output = output:gsub("^%s+", ""):gsub("%s+$", "")

                    if output:match("^%[") then
                        local parseSuccess, searchResults = pcall(hs.json.decode, output)
                        if parseSuccess and searchResults and type(searchResults) == "table" then
                            filteredEntries = searchResults
                            self.logger:d(string.format("RocksDB search returned %d results", #filteredEntries))
                        end
                    end
                end
            end
        end

        -- If RocksDB search didn't return enough results, try USearch for semantic similarity
        if #filteredEntries < 5 then
            local usearchBinary = self:getUSearchBinary()
            if usearchBinary then
                local remainingSlots = math.max(self.maxEntries - #filteredEntries, 0)
                if remainingSlots > 0 then
                    local command = string.format('"%s" "%s" search "%s" %d',
                        usearchBinary, self.usearchPath, query:gsub('"', '\\"'), remainingSlots)
                    self.logger:d("Executing USearch semantic search command: " .. command)

                    local handle = io.popen(command, "r")
                    if handle then
                        local output = handle:read("*all")
                        local success, exitType, exitCode = handle:close()

                        if output and output ~= "" then
                            output = output:gsub("^%s+", ""):gsub("%s+$", "")

                            if output:match("^%[") then
                                local parseSuccess, semanticResults = pcall(hs.json.decode, output)
                                if parseSuccess and semanticResults and type(semanticResults) == "table" then
                                    -- Merge semantic results with exact matches, avoiding duplicates
                                    local existingIds = {}
                                    for _, entry in ipairs(filteredEntries) do
                                        if entry.id then
                                            existingIds[entry.id] = true
                                        end
                                    end

                                    for _, entry in ipairs(semanticResults) do
                                        if entry.id and not existingIds[entry.id] then
                                            table.insert(filteredEntries, entry)
                                            existingIds[entry.id] = true
                                        end
                                    end

                                    self.logger:d(string.format("Combined search: %d total results", #filteredEntries))
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Fallback to buffer search if SQLite search fails
        if #filteredEntries == 0 then
            self.logger:d("Using fallback buffer search")
            local queryLower = query:lower()
            local prefixMatches = {}
            local containsMatches = {}

            for _, entry in ipairs(self.historyBuffer) do
                local searchableContent = (entry.content or ""):lower()
                local searchablePreview = (entry.preview or ""):lower()
                local searchableType = (entry.type or ""):lower()

                -- Check for prefix matches first
                if searchableContent:find("^" .. queryLower:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")) or
                    searchablePreview:find("^" .. queryLower:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")) or
                    searchableType:find("^" .. queryLower:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")) then
                    table.insert(prefixMatches, entry)
                    -- Then check for contains matches
                elseif searchableContent:find(queryLower, 1, true) or
                    searchablePreview:find(queryLower, 1, true) or
                    searchableType:find(queryLower, 1, true) then
                    table.insert(containsMatches, entry)
                end
            end

            -- Combine prefix matches first, then contains matches
            for _, entry in ipairs(prefixMatches) do
                table.insert(filteredEntries, entry)
            end
            for _, entry in ipairs(containsMatches) do
                table.insert(filteredEntries, entry)
            end

            self.logger:d(string.format("Fallback search: %d prefix + %d contains = %d total results",
                #prefixMatches, #containsMatches, #filteredEntries))
        end
    end

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
        local codeExts = { "js", "html", "css", "py", "lua", "swift", "java", "cpp", "c", "rb", "go",
            "rs" }

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

    -- Helper function to create file type icon image
    local function getFileTypeIcon(fileType, extension)
        -- Create a simple colored square icon for different file types
        local iconSize = { w = 64, h = 64 }
        local canvas = hs.canvas.new(iconSize)

        -- Use Hammerspoon's consistent blue color for all file types
        local hammerspoonBlue = { red = 0.0, green = 0.47, blue = 1.0, alpha = 1.0 }

        local symbols = {
            image = "🖼",
            video = "🎬",
            audio = "🎵",
            document = "📄",
            code = "⌨",
            file = "📁"
        }

        local color = hammerspoonBlue
        local symbol = symbols[fileType] or symbols.file

        -- Draw background rectangle
        canvas[1] = {
            type = "rectangle",
            action = "fill",
            fillColor = color,
            roundedRectRadii = { xRadius = 8, yRadius = 8 }
        }

        -- Draw symbol
        canvas[2] = {
            type = "text",
            text = symbol,
            textAlignment = "center",
            textSize = 32,
            textColor = { white = 1.0, alpha = 1.0 },
            frame = { x = 0, y = 12, w = 64, h = 40 }
        }

        return canvas:imageFromCanvas()
    end

    -- Convert to chooser format
    for i, entry in ipairs(filteredEntries) do
        local preview = entry.preview or entry.content or ""

        -- Use full preview without truncation
        -- preview = self:truncatePreviewSmartly(preview)

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

        -- Add size info to subtext if available
        local subText = string.format("%s • %s %s",
            entry.type or "Unknown",
            dateDisplay,
            entry.time or "")

        if entry.size and entry.size ~= "" then
            subText = string.format("%s • %s • %s %s",
                entry.type or "Unknown",
                entry.size,
                dateDisplay,
                entry.time or "")
        end

        -- Create choice entry
        local choiceEntry = {
            text = preview,
            subText = subText,
            content = entry.content,
            timestamp = entry.timestamp,
            type = entry.type
        }

        -- Handle different content types for preview
        if entry.type == "File path" and entry.content then
            -- For file paths, determine the actual file type and add appropriate preview
            local filePath = entry.content
            local extension = getFileExtension(filePath)
            local fileType = getFileTypeFromExtension(extension)
            local fileIcon = getFileTypeIcon(fileType, extension)

            -- Set the file type icon as image instead of text
            choiceEntry.image = fileIcon

            -- Check if file exists
            local file = io.open(filePath, "r")
            if file then
                file:close()

                if fileType == "image" then
                    -- Try to load image preview
                    local image = hs.image.imageFromPath(filePath)
                    if image then
                        -- Resize image to a reasonable size for preview (max 64x64)
                        local size = image:size()
                        if size.w > 64 or size.h > 64 then
                            local scale = math.min(64 / size.w, 64 / size.h)
                            image = image:setSize({ w = size.w * scale, h = size.h * scale })
                        end
                        choiceEntry.image = image
                    end
                elseif fileType == "video" then
                    -- For videos, try to generate a thumbnail or use a default video icon
                    -- Hammerspoon doesn't have built-in video thumbnail generation,
                    -- but we can use the system to generate one
                    local tempThumbPath = os.tmpname() .. ".jpg"
                    local thumbnailCmd = string.format(
                        'qlmanage -t -s 64 -o "%s" "%s" 2>/dev/null && mv "%s"/*.jpg "%s" 2>/dev/null',
                        os.tmpname(), filePath, os.tmpname(), tempThumbPath
                    )

                    -- Try to generate thumbnail using Quick Look
                    local result = os.execute(thumbnailCmd)
                    if result == 0 then
                        local thumbImage = hs.image.imageFromPath(tempThumbPath)
                        if thumbImage then
                            choiceEntry.image = thumbImage
                            -- Clean up temp file after a delay
                            hs.timer.doAfter(1, function()
                                os.remove(tempThumbPath)
                            end)
                        end
                    else
                        -- Fallback to video icon image
                        choiceEntry.image = fileIcon
                    end
                else
                    -- For other file types, we could add specific icons or handling
                    -- For now, just use the file icon
                end
            else
                -- File doesn't exist, create a broken file icon
                local iconSize = { w = 64, h = 64 }
                local canvas = hs.canvas.new(iconSize)
                canvas[1] = {
                    type = "rectangle",
                    action = "fill",
                    fillColor = { red = 0.0, green = 0.47, blue = 1.0, alpha = 1.0 },
                    roundedRectRadii = { xRadius = 8, yRadius = 8 }
                }
                canvas[2] = {
                    type = "text",
                    text = "❌",
                    textAlignment = "center",
                    textSize = 32,
                    textColor = { white = 1.0, alpha = 1.0 },
                    frame = { x = 0, y = 12, w = 64, h = 40 }
                }
                choiceEntry.image = canvas:imageFromCanvas()
                choiceEntry.text = preview .. " (file not found)"
            end
        elseif entry.type and entry.type:find("image") and entry.content then
            -- Handle clipboard images (existing logic)
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
                end
            end
        end

        table.insert(choices, choiceEntry)
    end

    self.logger:d(string.format("updateChoices() called with %d entries", #filteredEntries))
    if self.currentQuery ~= "" then
        self.logger:d(string.format("Query: '%s', using filtered %d entries", self.currentQuery,
            #filteredEntries))
    else
        self.logger:d(string.format("No query, using all %d entries", #filteredEntries))
    end

    self.logger:d(string.format("Setting %d choices in chooser", #choices))
    self.chooser:choices(choices)
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
--- Toggle the clipboard history chooser visibility with fresh initialization
function obj:toggle()
    if self.chooser and self.chooser:isVisible() then
        self:hide()
    else
        -- Reinitialize chooser for fresh start (resets scroll, search, shows recent entries)
        self:initializeChooser()
        self:show()
    end
end

--- ClipboardHistory:shouldOnlyCopy()
--- Method
--- Check if we should only copy (not paste) - be conservative, only copy when certain we shouldn't paste
function obj:shouldOnlyCopy()
    local app = hs.application.frontmostApplication()
    if not app then
        return true -- No app, just copy
    end

    local appName = app:name()

    -- Don't paste in certain apps where it might be disruptive
    local copyOnlyApps = {
        "Finder",
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

    -- For all other cases, try to paste
    return false
end

--- ClipboardHistory:copyToClipboard(choice)
--- Method
--- Copy content to clipboard without pasting
function obj:copyToClipboard(choice)
    if choice.type == "File path" then
        -- For file paths, check if we should copy as path or file:// URI
        local filePath = choice.content

        -- Check if file exists
        local file = io.open(filePath, "r")
        if file then
            file:close()
            -- File exists, copy as file:// URI for drag and drop compatibility
            if not filePath:match("^file://") then
                filePath = "file://" .. filePath
            end
            hs.pasteboard.setContents(filePath)
        else
            -- File doesn't exist, copy as plain text path
            hs.pasteboard.setContents(choice.content)
        end
    elseif choice.type and choice.type:find("image") then
        -- For clipboard images, copy the file path or recreate the image data
        local imagePath = choice.content
        local file = io.open(imagePath, "r")
        if file then
            file:close()
            -- If it's a temp file, try to set the actual image data
            local imageData = hs.image.imageFromPath(imagePath)
            if imageData then
                hs.pasteboard.setContents(imageData)
            else
                -- Fallback to file path
                local fileURL = imagePath
                if not fileURL:match("^file://") then
                    fileURL = "file://" .. fileURL
                end
                hs.pasteboard.setContents(fileURL)
            end
        else
            hs.pasteboard.setContents(choice.content)
        end
    else
        -- For text and other types, set the content normally
        hs.pasteboard.setContents(choice.content)
    end

    -- Show a silent notification that content was copied
    hs.alert.show("📋 Copied to clipboard", 0.5)
end

--- ClipboardHistory:pasteContent(choice)
--- Method
--- Paste content based on its type
function obj:pasteContent(choice)
    -- Copy content to clipboard without showing alert
    if choice.type == "File path" then
        local filePath = choice.content
        local file = io.open(filePath, "r")
        if file then
            file:close()
            if not filePath:match("^file://") then
                filePath = "file://" .. filePath
            end
            hs.pasteboard.setContents(filePath)
        else
            hs.pasteboard.setContents(choice.content)
        end
    elseif choice.type and choice.type:find("image") then
        local imagePath = choice.content
        local file = io.open(imagePath, "r")
        if file then
            file:close()
            local imageData = hs.image.imageFromPath(imagePath)
            if imageData then
                hs.pasteboard.setContents(imageData)
            else
                local fileURL = imagePath
                if not fileURL:match("^file://") then
                    fileURL = "file://" .. fileURL
                end
                hs.pasteboard.setContents(fileURL)
            end
        else
            hs.pasteboard.setContents(choice.content)
        end
    else
        hs.pasteboard.setContents(choice.content)
    end

    hs.timer.doAfter(0, function()
        hs.eventtap.keyStroke({ "cmd" }, "v", 0)
    end)
end

--- ClipboardHistory:saveHistory()
--- Method
--- No-op since SQLite handles persistence automatically
function obj:saveHistory()
    -- SQLite handles persistence automatically, no action needed
end

--- ClipboardHistory:clear()
--- Method
--- Clear clipboard history
function obj:clear()
    self.historyBuffer = {}
    -- Clear SQLite database
    local binaryPath = self:compileSqliteReader()
    if binaryPath then
        local command = string.format(
            "sqlite3 %s 'DELETE FROM clipboard_history; DELETE FROM clipboard_fts;'", self.dbFile)
        os.execute(command)
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
    -- Clear cached binary references (don't delete - they're managed by compile())
    self.sqliteReaderBinary = nil
    self.clipboardMonitorBinary = nil
end

--- ClipboardHistory:bindHotkeys(mapping)
--- Method
--- Bind hotkeys for ClipboardHistory
---
--- Parameters:
---  * mapping - A table containing hotkey mappings. Supported keys:
---    * show - Show the clipboard history chooser (default: no hotkey)
---    * toggle - Toggle the clipboard history chooser visibility (default: no hotkey)
---    * clear - Clear clipboard history (default: no hotkey)
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
