--- === KillProcess ===
---
--- Kill processes with fuzzy search - like Raycast Kill Process

local searchUtils = require("lib.search")

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "KillProcess"
obj.version = "1.0"
obj.author = "sjdonado"
obj.homepage = "https://github.com/sjdonado/martillo/spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.chooser = nil
obj.hotkeys = {}
obj.refreshTimer = nil
obj.refreshIntervalSeconds = 1
obj.currentQuery = ""
obj.logger = hs.logger.new("KillProcess", "info")

-- Configuration options
obj.maxResults = 1000 -- Maximum number of results to show

--- KillProcess:init()
--- Method
--- Initialize the spoon
function obj:init()
	return self
end

--- KillProcess:createChooser()
--- Method
--- Create a new chooser instance
function obj:createChooser()
	if self.chooser then
		self.chooser:delete()
	end

	self.chooser = hs.chooser.new(function(choice)
		if choice then
			local success = hs.execute(string.format("kill %d", choice.pid))
			if success then
				hs.alert.show(string.format("Killed: %s", choice.name), 2)
			else
				hs.alert.show(string.format("❌ Failed to kill: %s", choice.name), 2)
			end
		end
	end)

	self.chooser:rows(10)
	self.chooser:width(40)
	self.chooser:searchSubText(true)
	self.chooser:queryChangedCallback(function(query)
		self.currentQuery = query
	end)

	-- Set choices to use a function for real-time updates
	self.chooser:choices(function()
		return self:getFilteredChoices()
	end)

	-- Automatically cleanup when chooser is hidden
	self.chooser:hideCallback(function()
		if self.refreshTimer then
			self.refreshTimer:stop()
			self.refreshTimer = nil
		end
		if self.chooser then
			self.chooser:delete()
			self.chooser = nil
		end
	end)
end

--- KillProcess:getFilteredChoices()
--- Method
--- Get filtered choices based on current query with priority-based search
function obj:getFilteredChoices()
	local allProcesses = self:getProcessList()
	local choices = {}

	-- Safety check
	if not allProcesses or #allProcesses == 0 then
		return {}
	end

	-- No search query - return all processes
	if not self.currentQuery or self.currentQuery == "" then
		local appProcesses = {}
		local otherProcesses = {}

		for _, process in ipairs(allProcesses) do
			if process then
				if self:isAppProcessEntry(process) then
					table.insert(appProcesses, process)
				else
					table.insert(otherProcesses, process)
				end
			end
		end

		for _, process in ipairs(appProcesses) do
			table.insert(choices, process)
		end
		for _, process in ipairs(otherProcesses) do
			table.insert(choices, process)
		end
		return choices
	end

	-- Search filtering
	local rankedProcesses = searchUtils.rank(self.currentQuery, allProcesses, {
		getFields = function(process)
			return {
				{ value = process.name or process.text or "", weight = 1.0, key = "name" },
				{ value = process.fullPath or "",             weight = 0.6, key = "path" },
				{ value = process.subText or "",              weight = 0.3, key = "details" },
			}
		end,
		adjustScore = function(process, context)
			local score = context.score
			local matchType = context.match and context.match.matchType or nil

			if matchType == "prefix" then
				score = score * 1.1
			elseif matchType == "word_prefix" then
				score = score * 1.05
			end

			if self:isAppProcessEntry(process) then
				score = score * 1.1
			end

			if process.mem and process.mem > 0 then
				score = score + (process.mem / (1024 * 50))
			end

			return score
		end,
		tieBreaker = function(procA, procB)
			local aIsApp = self:isAppProcessEntry(procA)
			local bIsApp = self:isAppProcessEntry(procB)
			if aIsApp ~= bIsApp then
				return aIsApp
			end

			local aMem = procA.mem or 0
			local bMem = procB.mem or 0
			if aMem ~= bMem then
				return aMem > bMem
			end

			return (procA.pid or math.huge) < (procB.pid or math.huge)
		end,
		fuzzyMinQueryLength = 4,
		maxResults = self.maxResults,
	})

	return rankedProcesses
end

--- KillProcess:getProcessList()
--- Method
--- Get list of running processes
function obj:getProcessList()
	-- Get ALL processes including kernel tasks and parent info
	local success, output = pcall(hs.execute, "ps -axo pid,ppid,pcpu,rss,command")
	if not success or not output then
		self.logger:e("Failed to execute ps command: " .. tostring(output))
		return {}
	end

	local processes = {}
	local appProcesses = {} -- Map app names to their processes
	local lineCount = 0
	local processedCount = 0
	local function formatMemory(memKB)
		if memKB >= 1024 * 1024 then -- >= 1GB
			return string.format("%.1f GB", memKB / (1024 * 1024))
		elseif memKB >= 1024 then  -- >= 1MB
			return string.format("%.0f MB", memKB / 1024)
		else
			return string.format("%.0f KB", memKB)
		end
	end

	for line in output:gmatch("[^\r\n]+") do
		lineCount = lineCount + 1

		-- Skip header line
		if not line:match("^%s*PID") then
			-- Parse: PID PPID %CPU RSS COMMAND (handle all processes including 0 memory ones)
			local pid, ppid, cpu, rss, command = line:match("^%s*(%d+)%s+(%d+)%s+([%d%.]+)%s+(%d+)%s+(.*)")

			-- Also try to capture processes that might have 0 or missing RSS
			if not pid then
				pid, ppid, cpu, command = line:match("^%s*(%d+)%s+(%d+)%s+([%d%.]+)%s+%-%s+(.*)")
				rss = "0"
			end

			if pid and cpu and tonumber(pid) and tonumber(pid) >= 0 then
				processedCount = processedCount + 1

				local pidNum = tonumber(pid)
				local ppidNum = tonumber(ppid) or 0

				-- Get base app name for grouping
				local baseAppName = self:getBaseAppName(command)

				-- Store process info for app grouping
				if not appProcesses[baseAppName] then
					appProcesses[baseAppName] = {}
				end
				table.insert(appProcesses[baseAppName], {
					pid = pidNum,
					ppid = ppidNum,
					command = command,
					cpu = cpu,
					rss = rss,
				})

				-- Extract process name with app grouping logic
				local processName = self:extractProcessName(command, baseAppName, appProcesses[baseAppName])

				-- Ensure we have a valid process name
				if processName and processName ~= "" then
					-- Get memory usage (allow 0 memory processes)
					local memKB = tonumber(rss) or 0

					-- Convert RSS (KB) to MB or GB for display
					local memDisplay = formatMemory(memKB)

					-- Create process entry with safe values
					local pidNum = tonumber(pid)
					local cpuNum = tonumber(cpu)

					if pidNum and cpuNum then
						table.insert(processes, {
							text = processName or "Unknown",
							subText = string.format(
								"PID: %s | CPU: %s%% | Memory: %s | %s",
								pid,
								cpu,
								memDisplay,
								command or ""
							),
							pid = pidNum,
							ppid = ppidNum,
							cpu = tonumber(cpu),
							mem = memKB, -- Store raw KB for sorting
							memDisplay = memDisplay,
							name = processName,
							fullPath = command,
						})
					end
				end
			end
		end
	end

	local rawProcessCount = #processes

	-- Aggregate processes with the same display name
	local nameBuckets = {}
	for _, process in ipairs(processes) do
		local key = process.name or process.text or "Unknown"
		if not nameBuckets[key] then
			nameBuckets[key] = { name = key, processes = {} }
		end
		table.insert(nameBuckets[key].processes, process)
	end

	local function selectMainProcess(processList)
		local function hasChildren(candidate)
			for _, other in ipairs(processList) do
				if other.ppid == candidate.pid then
					return true
				end
			end
			return false
		end

		local function isBetter(candidate, current)
			if not current then
				return true
			end

			local candidateIsApp = self:isAppProcessEntry(candidate)
			local currentIsApp = self:isAppProcessEntry(current)
			if candidateIsApp ~= currentIsApp then
				return candidateIsApp
			end

			local candidateIsParent = hasChildren(candidate)
			local currentIsParent = hasChildren(current)
			if candidateIsParent ~= currentIsParent then
				return candidateIsParent
			end

			local candidateMem = candidate.mem or 0
			local currentMem = current.mem or 0
			if candidateMem ~= currentMem then
				return candidateMem > currentMem
			end

			return (candidate.pid or math.huge) < (current.pid or math.huge)
		end

		local selected = nil
		for _, proc in ipairs(processList) do
			if isBetter(proc, selected) then
				selected = proc
			end
		end
		return selected or processList[1]
	end

	local aggregatedProcesses = {}
	for _, bucket in pairs(nameBuckets) do
		local list = bucket.processes
		if #list == 1 then
			table.insert(aggregatedProcesses, list[1])
		else
			local main = selectMainProcess(list)
			local totalCpu = 0
			local totalMem = 0

			for _, proc in ipairs(list) do
				totalCpu = totalCpu + (proc.cpu or 0)
				totalMem = totalMem + (proc.mem or 0)
			end

			local totalMemDisplay = formatMemory(totalMem)
			local subText = string.format(
				"PID: %d | Total CPU: %.1f%% | Total Memory: %s | %s | %d processes",
				main.pid,
				totalCpu,
				totalMemDisplay,
				main.fullPath or "",
				#list
			)

			table.insert(aggregatedProcesses, {
				text = bucket.name,
				subText = subText,
				pid = main.pid,
				ppid = main.ppid,
				cpu = totalCpu,
				mem = totalMem,
				memDisplay = totalMemDisplay,
				name = bucket.name,
				fullPath = main.fullPath,
				aggregated = list,
			})
		end
	end

	processes = aggregatedProcesses

	-- Debug logging
	self.logger:d(
		string.format(
			"Processed %d lines, %d parsed, %d raw processes, returning %d aggregated processes",
			lineCount,
			processedCount,
			rawProcessCount,
			#processes
		)
	)

	-- Limit results to maxResults
	if #processes > self.maxResults then
		local limitedProcesses = {}
		for i = 1, self.maxResults do
			table.insert(limitedProcesses, processes[i])
		end
		processes = limitedProcesses
	end

	-- Sort by memory usage (descending)
	table.sort(processes, function(a, b)
		return a.mem > b.mem
	end)

	return processes
end

--- KillProcess:show()
--- Method
--- Show the process chooser
function obj:show()
	self:createChooser()
	self.currentQuery = ""
	self.chooser:show()

	if self.refreshTimer then
		self.refreshTimer:stop()
	end
	self.refreshTimer = hs.timer.doEvery(self.refreshIntervalSeconds, function()
		if self.chooser and self.chooser:isVisible() then
			self.chooser:refreshChoicesCallback()
		end
	end)
end

--- KillProcess:hide()
--- Method
--- Hide the process chooser
function obj:hide()
	if self.chooser then
		self.chooser:hide()
	end
end

--- KillProcess:toggle()
--- Method
--- Toggle the process chooser visibility
function obj:toggle()
	if self.chooser and self.chooser:isVisible() then
		self:hide()
	else
		self:show()
	end
end

--- KillProcess:bindHotkeys(mapping)
--- Method
--- Bind hotkeys for KillProcess
---
--- Parameters:
---  * mapping - A table containing hotkey mappings. Supported keys:
---    * show - Show the process chooser (default: no hotkey)
---    * toggle - Toggle the process chooser visibility (default: no hotkey)
function obj:bindHotkeys(mapping)
	local def = {
		show = hs.fnutils.partial(self.show, self),
		toggle = hs.fnutils.partial(self.toggle, self),
	}
	hs.spoons.bindHotkeysToSpec(def, mapping)
	return self
end

--- KillProcess:configure(options)
--- Method
--- Configure the spoon with custom options
---
--- Parameters:
---  * options - A table containing configuration options:
---    * maxResults - Maximum number of results to show (default: 1000)
---    * refreshIntervalSeconds - How often to refresh the process list (default: 1)
function obj:configure(options)
	if options.maxResults then
		self.maxResults = options.maxResults
	end
	if options.refreshIntervalSeconds then
		self.refreshIntervalSeconds = options.refreshIntervalSeconds
	end
	return self
end

--- KillProcess:isAppPath(path)
--- Method
--- Determine if a command path belongs to an app bundle
function obj:isAppPath(path)
	if not path or path == "" then
		return false
	end
	local lowered = path:lower()
	return lowered:find("%.app/") ~= nil or lowered:sub(-4) == ".app"
end

--- KillProcess:isAppProcessEntry(process)
--- Method
--- Determine if a process entry represents an app bundle
function obj:isAppProcessEntry(process)
	if not process then
		return false
	end
	return self:isAppPath(process.fullPath)
end

--- KillProcess:extractProcessName(command, baseAppName, appProcessList)
--- Method
--- Extract a clean process name from the command string, with helper suffix for auxiliary app processes
function obj:extractProcessName(command, baseAppName, appProcessList)
	if not command or command == "" then
		return "Unknown"
	end

	-- Handle IP address network processes that belong to an app (e.g., Spotify network processes)
	if command:match("^%d+%.%d+%.%d+%.%d+$") then
		-- If we have app context from the grouping, use it
		if baseAppName and baseAppName ~= "Unknown" and baseAppName ~= command then
			return baseAppName .. " - Network"
		else
			return "Network (" .. command .. ")"
		end
	end

	-- Get the base process name first
	local processName = self:getSimpleProcessName(command)

	-- If this app has multiple processes, determine which is main and which are helpers
	if appProcessList and #appProcessList > 1 then
		local isMainProcess = self:isMainAppProcess(command, baseAppName, appProcessList)

		-- If it's the main process, return early without any suffix
		if isMainProcess then
			return processName
		end

		-- This is a helper process - add appropriate suffix
		-- Don't add suffix if process name already contains Helper, Daemon, etc.
		if
				processName:match("[Hh]elper")
				or processName:match("[Dd]aemon")
				or processName:match("%(Helper%)")
				or processName:match("%(Daemon%)")
		then
			return processName
		end

		-- Determine if it's a helper or daemon based on process characteristics
		if
				processName:match("daemon")
				or processName:match("service")
				or processName:match("worker")
				or processName:match("monitor")
				or processName:match("mgr")
		then
			return processName .. " (Daemon)"
		else
			-- Mark as helper for auxiliary app processes
			return processName .. " (Helper)"
		end
	end

	return processName
end

--- KillProcess:getSimpleProcessName(command)
--- Method
--- Extract a simple process name from the command string
function obj:getSimpleProcessName(command)
	if not command or command == "" then
		return "Unknown"
	end

	-- Handle IP addresses (return the IP for grouping)
	if command:match("^%d+%.%d+%.%d+%.%d+$") then
		return command
	end

	-- Handle Electron apps (app.asar)
	if command:match("app%.asar") then
		local pathAppName = command:match("/([^/]+)%.app/") or command:match("([A-Z][%w%s]+)")
		if pathAppName then
			return pathAppName .. " - Electron"
		end
		return "Electron App"
	end

	-- Handle bracketed process names like [kernel_task]
	local bracketName = command:match("^%[(.+)%]$")
	if bracketName then
		return bracketName
	end

	-- Extract process name from full path
	local processName = command:match("([^/]+)$") or command:match("^(%S+)") or command

	-- Remove .app extension if present
	processName = processName:gsub("%.app$", "")

	-- Remove common executable suffixes
	processName = processName:gsub("%.bin$", "")

	-- Handle processes with arguments by taking only the first part
	processName = processName:match("^([^%s]+)") or processName

	-- XPC services
	if processName:match("%.xpc$") then
		processName = processName:gsub("%.xpc$", " (XPC)")
	end

	return processName
end

--- KillProcess:getBaseAppName(command)
--- Method
--- Extract base application name for grouping processes
function obj:getBaseAppName(command)
	if not command or command == "" then
		return "Unknown"
	end

	-- Handle IP address processes - look for app context
	if command:match("^%d+%.%d+%.%d+%.%d+$") then
		-- Look for app bundle in the path or environment
		local appName = command:match("([^/]+)%.app/")
		if appName then
			return appName
		end
		-- Check if the IP appears to be launched from an app directory
		local pathAppName = command:match("/([^/]+)%.app/") or command:match("/Applications/([^/]+)/")
		if pathAppName then
			return pathAppName
		end
		-- Return the IP as fallback for grouping
		return command
	end

	-- Extract app name from .app bundle path
	local appName = command:match("([^/]+)%.app/")
	if appName then
		return appName
	end

	-- For IP address processes, return as is for grouping
	if command:match("^%d+%.%d+%.%d+%.%d+$") then
		return command
	end

	-- For non-app processes, use the executable name
	local execName = command:match("([^/]+)$") or command:match("^(%S+)") or command

	-- Clean up the name
	execName = execName:gsub("%.app$", "")
	execName = execName:gsub("%.bin$", "")
	execName = execName:match("^([^%s]+)") or execName

	return execName
end

--- KillProcess:isMainAppProcess(command, baseAppName, appProcessList)
--- Method
--- Determine if this is the main process for an application
function obj:isMainAppProcess(command, baseAppName, appProcessList)
	if not command or not appProcessList or #appProcessList <= 1 then
		return true
	end

	-- Main process detection priority:
	-- 1. The one that's directly in the .app/Contents/MacOS/ path (highest priority)
	-- 2. The one without "Helper", "GPU", "Renderer", "Content", etc. in the name
	-- 3. The one that matches the base app name exactly

	-- Debug logging
	self.logger:d(string.format("Checking if main process for: %s (baseApp: %s)", command, tostring(baseAppName)))

	-- First check if this is the main executable path - this is the strongest indicator
	if command:match("%.app/Contents/MacOS/[^/]+$") then
		self.logger:d("Detected as main process: MacOS path match")
		return true
	end

	-- Check if this looks like a helper process based on command content
	if
			command:match("[Hh]elper")
			or command:match("GPU")
			or command:match("Renderer")
			or command:match("Content")
			or command:match("Utility")
			or command:match("Network")
			or command:match("--type=")
			or command:match("--variation")
	then
		self.logger:d("Detected as helper process: keyword match")
		return false
	end

	-- Check if the command is exactly the app name or contains the app directly
	local simpleName = self:getSimpleProcessName(command)
	if simpleName == baseAppName then
		return true
	end

	-- For single word app names, check if command contains just the app name
	if baseAppName and command:match("/" .. baseAppName .. "$") then
		return true
	end

	-- If we can't determine and it doesn't have helper indicators, assume it's main
	return true
end

return obj
