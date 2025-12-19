-- Kill Process Preset
-- Process killer with fuzzy search

local searchUtils = require 'lib.search'
local chooserManager = require 'lib.chooser'
local toast = require 'lib.toast'
local icons = require 'lib.icons'
local events = require 'lib.events'
local thumbnailCache = require 'lib.thumbnail_cache'

local M = {
  refreshTimer = nil,
  refreshIntervalSeconds = 2,
  currentQuery = '',
  maxResults = 150,
  logger = hs.logger.new('KillProcess', 'info'),
  cachedProcessList = nil,   -- Cache process list to avoid re-running ps on every keystroke
  cacheRefreshTimer = nil,   -- Timer to refresh the cache periodically
}

-- Format memory for display
local function formatMemory(memKB)
  if memKB >= 1024 * 1024 then   -- >= 1GB
    return string.format('%.1f GB', memKB / (1024 * 1024))
  elseif memKB >= 1024 then      -- >= 1MB
    return string.format('%.0f MB', memKB / 1024)
  else
    return string.format('%.0f KB', memKB)
  end
end

-- Determine if a command path belongs to an app bundle
local function isAppPath(path)
  if not path or path == '' then
    return false
  end
  local lowered = path:lower()
  return lowered:find '%.app/' ~= nil or lowered:sub(-4) == '.app'
end

-- Determine if a process entry represents an app bundle
local function isAppProcessEntry(process)
  if not process then
    return false
  end
  return isAppPath(process.fullPath)
end

-- Extract a simple process name from the command string
local function getSimpleProcessName(command)
  if not command or command == '' then
    return 'Unknown'
  end

  -- Handle IP addresses (return the IP for grouping)
  if command:match '^%d+%.%d+%.%d+%.%d+$' then
    return command
  end

  -- Handle Electron apps (app.asar)
  if command:match 'app%.asar' then
    local pathAppName = command:match '/([^/]+)%.app/' or command:match '([A-Z][%w%s]+)'
    if pathAppName then
      return pathAppName .. ' (Electron)'
    end
    return 'Electron App'
  end

  -- Handle bracketed process names like [kernel_task]
  local bracketName = command:match '^%[(.+)%]$'
  if bracketName then
    return bracketName
  end

  -- First, extract just the executable path (before any arguments)
  local executablePath = command:match '^(%S+)' or command

  -- Then extract the basename from that executable path
  local processName = executablePath:match '([^/]+)$' or executablePath

  -- Remove .app extension if present
  processName = processName:gsub('%.app$', '')

  -- Remove common executable suffixes
  processName = processName:gsub('%.bin$', '')

  -- XPC services
  if processName:match '%.xpc$' then
    processName = processName:gsub('%.xpc$', ' (XPC)')
  end

  return processName
end

-- Extract base application name for grouping processes
local function getBaseAppName(command)
  if not command or command == '' then
    return 'Unknown'
  end

  -- Handle IP address processes - look for app context
  if command:match '^%d+%.%d+%.%d+%.%d+$' then
    -- Look for app bundle in the path or environment
    local appName = command:match '([^/]+)%.app/'
    if appName then
      return appName
    end
    -- Check if the IP appears to be launched from an app directory
    local pathAppName = command:match '/([^/]+)%.app/' or command:match '/Applications/([^/]+)/'
    if pathAppName then
      return pathAppName
    end
    -- Return the IP as fallback for grouping
    return command
  end

  -- Extract app name from .app bundle path
  local appName = command:match '([^/]+)%.app/'
  if appName then
    return appName
  end

  -- For IP address processes, return as is for grouping
  if command:match '^%d+%.%d+%.%d+%.%d+$' then
    return command
  end

  -- For non-app processes, use the executable name
  local execName = command:match '([^/]+)$' or command:match '^(%S+)' or command

  -- Clean up the name
  execName = execName:gsub('%.app$', '')
  execName = execName:gsub('%.bin$', '')
  execName = execName:match '^([^%s]+)' or execName

  return execName
end

-- Determine if this is the main process for an application
local function isMainAppProcess(command, baseAppName, appProcessList)
  if not command or not appProcessList or #appProcessList <= 1 then
    return true
  end

  -- First check if this is the main executable path - this is the strongest indicator
  if command:match '%.app/Contents/MacOS/[^/]+$' then
    return true
  end

  -- Check if this looks like a helper process based on command content
  if
      command:match '[Hh]elper'
      or command:match 'GPU'
      or command:match 'Renderer'
      or command:match 'Content'
      or command:match 'Utility'
      or command:match 'Network'
      or command:match '--type='
      or command:match '--variation'
  then
    return false
  end

  -- Check if the command is exactly the app name or contains the app directly
  local simpleName = getSimpleProcessName(command)
  if simpleName == baseAppName then
    return true
  end

  -- For single word app names, check if command contains just the app name
  if baseAppName and command:match('/' .. baseAppName .. '$') then
    return true
  end

  -- If we can't determine and it doesn't have helper indicators, assume it's main
  return true
end

-- Extract a clean process name from the command string, with helper suffix for auxiliary app processes
local function extractProcessName(command, safariDomains, webkitIndex)
  if not command or command == '' then
    return 'Unknown'
  end

  -- Handle IP address network processes that belong to an app (e.g., Spotify network processes)
  if command:match '^%d+%.%d+%.%d+%.%d+$' then
    return 'Network (' .. command .. ')'
  end

  -- Handle WebKit WebContent processes (Safari tabs) - show domain if available
  if command:match 'com%.apple%.WebKit%.WebContent' then
    if safariDomains and #safariDomains > 0 and webkitIndex then
      -- Use modulo to cycle through available domains
      local domainIndex = ((webkitIndex - 1) % #safariDomains) + 1
      local domain = safariDomains[domainIndex]
      -- Truncate long domains
      if #domain > 50 then
        domain = domain:sub(1, 47) .. '...'
      end
      return 'Safari (' .. domain .. ')'
    end
    return 'Safari (WebContent)'
  end

  -- Handle WebKit Networking processes
  if command:match 'com%.apple%.WebKit%.Networking' then
    return 'Safari (Networking)'
  end

  -- Handle WebKit GPU processes
  if command:match 'com%.apple%.WebKit%.GPU' then
    return 'Safari (GPU)'
  end

  -- Check if this is an app bundle process
  local isAppBundle = command:match '%.app/'

  -- For app bundle processes, prefer the base app name over the executable name
  local processName
  if isAppBundle and baseAppName and baseAppName ~= 'Unknown' then
    processName = baseAppName
  else
    processName = getSimpleProcessName(command)
  end

  -- Special handling for interpreter processes (node, python, ruby, etc.)
  -- Include the script/first argument to differentiate multiple instances
  if processName == 'node' or processName == 'nodejs' then
    -- For node, look for .js, .cjs, .mjs files in the command
    local scriptPath = command:match '%s([^%s]*%.m?[c]?js)' or command:match '%s([^%s]*tsserver[^%s]*)'
    if scriptPath then
      local scriptName = scriptPath:match '([^/]+)$' or scriptPath
      -- Truncate very long script names
      if #scriptName > 40 then
        scriptName = scriptName:sub(1, 37) .. '...'
      end
      return 'node (' .. scriptName .. ')'
    end
  elseif processName == 'python' or processName == 'python2' or processName == 'python3' then
    -- For python, look for .py files
    local scriptPath = command:match '%s([^%s]*%.py)'
    if scriptPath then
      local scriptName = scriptPath:match '([^/]+)$' or scriptPath
      if #scriptName > 40 then
        scriptName = scriptName:sub(1, 37) .. '...'
      end
      return processName .. ' (' .. scriptName .. ')'
    end
  elseif processName == 'ruby' then
    -- For ruby, look for .rb files
    local scriptPath = command:match '%s([^%s]*%.rb)'
    if scriptPath then
      local scriptName = scriptPath:match '([^/]+)$' or scriptPath
      if #scriptName > 40 then
        scriptName = scriptName:sub(1, 37) .. '...'
      end
      return processName .. ' (' .. scriptName .. ')'
    end
  end

  return processName
end

-- Parse memory value with unit suffix (e.g., "104M", "8017K", "2082M+")
local function parseMemoryValue(memStr)
  if not memStr or memStr == '' then
    return 0
  end

  -- Remove any trailing '+' or '-' characters
  memStr = memStr:gsub('[%+%-]$', '')

  -- Extract number and unit
  local num, unit = memStr:match '^([%d%.]+)([KMG]?)$'
  if not num then
    return 0
  end

  num = tonumber(num) or 0

  -- Convert to KB for consistency
  if unit == 'G' then
    return num * 1024 * 1024
  elseif unit == 'M' then
    return num * 1024
  elseif unit == 'K' then
    return num
  else
    -- No unit means bytes, convert to KB
    return num / 1024
  end
end

-- Get Safari tab URLs and extract domains
local function getSafariDomains()
  local success, output = pcall(hs.execute,
    [[osascript -e 'tell application "Safari" to get URL of every tab of every window' 2>/dev/null]])
  if not success or not output then
    return {}
  end

  local domains = {}
  -- Parse comma-separated URLs
  for url in output:gmatch('[^,]+') do
    url = url:gsub('^%s+', ''):gsub('%s+$', '')     -- trim whitespace
    -- Extract domain from URL
    local domain = url:match('https?://([^/]+)')
    if domain then
      table.insert(domains, domain)
    end
  end

  return domains
end

-- Get list of running processes
local function getProcessList()
  -- Use top for accurate memory values (matches Activity Monitor)
  -- top shows real memory including compressed memory and proportional shared memory
  local topSuccess, topOutput = pcall(hs.execute, 'top -l 1 -stats pid,ppid,cpu,mem')
  if not topSuccess or not topOutput then
    M.logger:e('Failed to execute top command: ' .. tostring(topOutput))
    return {}
  end

  -- Use ps to get full command paths (needed for icon detection)
  local psSuccess, psOutput = pcall(hs.execute, 'ps -axo pid,command')
  if not psSuccess or not psOutput then
    M.logger:e('Failed to execute ps command: ' .. tostring(psOutput))
    return {}
  end

  -- Get Safari domains for WebKit process labeling
  local safariDomains = getSafariDomains()
  local webkitProcessCount = 0

  -- Build a map of PID -> full command path from ps
  local pidToCommand = {}
  for line in psOutput:gmatch '[^\r\n]+' do
    local pid, command = line:match '^%s*(%d+)%s+(.*)'
    if pid and command and not command:match '^PID%s+COMMAND' then
      pidToCommand[pid] = command
    end
  end

  local processes = {}
  local lineCount = 0
  local processedCount = 0
  local inProcessList = false

  for line in topOutput:gmatch '[^\r\n]+' do
    lineCount = lineCount + 1

    -- Skip header lines until we find the column headers
    if line:match '^PID%s+PPID' then
      inProcessList = true
    elseif inProcessList then
      -- Parse: PID PPID %CPU MEM
      local pid, ppid, cpu, mem = line:match '^%s*(%d+)%s+(%d+)%s+([%d%.]+)%s+(%S+)'

      if pid and cpu and mem then
        processedCount = processedCount + 1

        local pidNum = tonumber(pid)
        local ppidNum = tonumber(ppid) or 0

        -- Get full command from ps output
        local command = pidToCommand[pid] or ''

        -- Parse memory value with unit
        local memKB = parseMemoryValue(mem)

        -- Track WebKit processes for domain assignment
        local isWebKit = command:match('com%.apple%.WebKit%.WebContent') ~= nil
        if isWebKit then
          webkitProcessCount = webkitProcessCount + 1
        end

        -- Extract process name (pass Safari domains for WebKit processes)
        local processName = extractProcessName(command, safariDomains, isWebKit and webkitProcessCount or nil)

        -- Ensure we have a valid process name
        if processName and processName ~= '' then
          -- Format memory for display
          local memDisplay = formatMemory(memKB)

          -- Create process entry with safe values
          local cpuNum = tonumber(cpu)

          if pidNum and cpuNum then
            table.insert(processes, {
              text = processName or 'Unknown',
              subText = string.format('PID: %s | CPU: %s%% | Memory: %s | %s', pid, cpu, memDisplay,
                command or ''),
              pid = pidNum,
              ppid = ppidNum,
              cpu = cpuNum,
              mem = memKB,               -- Store raw KB for sorting
              memDisplay = memDisplay,
              name = processName,
              fullPath = command,
              -- Don't load icon here - too slow for all processes
            })
          end
        end
      end
    end
  end

  -- Sort by memory usage (descending)
  table.sort(processes, function(a, b)
    return a.mem > b.mem
  end)

  -- Debug logging
  M.logger:d(
    string.format('Processed %d lines, %d parsed processes (before limit)', lineCount, processedCount)
  )

  -- Limit results to maxResults AFTER sorting
  if #processes > M.maxResults then
    local limitedProcesses = {}
    for i = 1, M.maxResults do
      table.insert(limitedProcesses, processes[i])
    end
    processes = limitedProcesses
    M.logger:d(string.format('Limited to %d processes', #processes))
  end

  return processes
end

-- Refresh the cached process list
local function refreshProcessCache()
  M.cachedProcessList = getProcessList()
  M.logger:d('Refreshed process cache: ' .. #M.cachedProcessList .. ' processes')
end

-- Get filtered choices based on current query with priority-based search
local function getFilteredChoices()
  -- Use cached process list if available, otherwise fetch fresh
  local allProcesses = M.cachedProcessList or getProcessList()
  local choices = {}

  -- Safety check
  if not allProcesses or #allProcesses == 0 then
    return {}
  end

  -- No search query - return all processes (already sorted by memory from getProcessList)
  if not M.currentQuery or M.currentQuery == '' then
    return allProcesses
  end

  -- Search filtering
  local rankedProcesses = searchUtils.rank(M.currentQuery, allProcesses, {
    getFields = function(process)
      return {
        { value = process.name or process.text or '', weight = 1.0, key = 'name' },
        { value = process.fullPath or '',             weight = 0.6, key = 'path' },
        { value = process.subText or '',              weight = 0.3, key = 'details' },
      }
    end,
    adjustScore = function(process, context)
      local score = context.score
      local matchType = context.match and context.match.matchType or nil

      if matchType == 'prefix' then
        score = score * 1.1
      elseif matchType == 'word_prefix' then
        score = score * 1.05
      end

      if isAppProcessEntry(process) then
        score = score * 1.1
      end

      if process.mem and process.mem > 0 then
        score = score + (process.mem / (1024 * 50))
      end

      return score
    end,
    tieBreaker = function(procA, procB)
      local aIsApp = isAppProcessEntry(procA)
      local bIsApp = isAppProcessEntry(procB)
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
    maxResults = M.maxResults,
  })

  return rankedProcesses
end

-- Return action definition
return {
  {
    id = 'kill_process',
    name = 'Kill Process',
    icon = icons.preset.trash_can,
    description = 'Kill processes with fuzzy search',
    opts = {
      success_toast = true,       -- Show success toast notification when killing processes
    },
    handler = function()
      -- Get ActionsLauncher instance
      local actionsLauncher = spoon.ActionsLauncher
      local currentLauncher = nil       -- Will be set by handler

      -- Get action configuration (user can override opts in their config)
      local showToast = events.getActionOpt('kill_process', 'success_toast', true)

      -- Use a single default icon for all processes (icons disabled for performance)
      local defaultIcon = icons.getIcon(icons.preset.puzzle)

      -- Initialize process cache and start refresh timer
      refreshProcessCache()       -- Initial load

      -- Function to build choices from filtered processes
      local function buildChoices(launcher)
        if not launcher then
          return {}
        end

        -- Get filtered processes (uses cached list)
        local filteredProcesses = getFilteredChoices()

        -- Build choices with handlers
        local choices = {}
        for _, process in ipairs(filteredProcesses) do
          -- Generate UUID for this choice
          local uuid = launcher:generateUUID()

          -- Create choice entry (using default icon for all processes)
          local choiceEntry = {
            text = process.text,
            subText = process.subText,
            uuid = uuid,
            image = defaultIcon,
          }

          -- Register handler for this choice
          launcher.handlers[uuid] = events.custom(function(choice)
            local shiftHeld = chooserManager.isShiftHeld()

            if shiftHeld then
              -- Shift+Enter: Copy PID to clipboard
              local pidStr = tostring(process.pid)
              hs.pasteboard.setContents(pidStr)
              toast.copied(pidStr)
            else
              -- Enter: Kill the process
              local success = hs.execute(string.format('kill %d', process.pid))
              if success then
                if showToast then
                  toast.success('Killed: ' .. process.name)
                end
              else
                toast.error('Failed to kill: ' .. process.name)
              end
            end
          end)

          table.insert(choices, choiceEntry)
        end

        return choices
      end

      -- Function to refresh chooser display
      local function refreshChooserDisplay()
        if currentLauncher and actionsLauncher.chooser then
          local newChoices = buildChoices(currentLauncher)
          actionsLauncher.chooser:choices(newChoices)
        end
      end

      -- Stop any existing timer
      if M.cacheRefreshTimer then
        M.cacheRefreshTimer:stop()
      end

      -- Start timer to refresh cache every second while chooser is open
      M.cacheRefreshTimer = hs.timer.new(M.refreshIntervalSeconds, function()
        refreshProcessCache()
        -- Update chooser display with new data
        refreshChooserDisplay()
      end)
      M.cacheRefreshTimer:start()

      actionsLauncher:openChildChooser {
        placeholder = 'Kill Process (↩ kill, ⇧↩ copy PID)',
        parentAction = 'kill_process',
        onClose = function()
          -- Stop cache refresh timer when chooser closes
          if M.cacheRefreshTimer then
            M.cacheRefreshTimer:stop()
            M.cacheRefreshTimer = nil
          end
          -- Clear cached process list and icon cache to free memory
          M.cachedProcessList = nil
          currentLauncher = nil
          M.logger:d 'Stopped process cache refresh timer and cleared caches'
        end,
        handler = function(query, launcher)
          -- Store launcher reference for refresh function
          currentLauncher = launcher

          -- Update current query for filtering (cached list will be used)
          M.currentQuery = query or ''

          -- Build and return choices
          return buildChoices(launcher)
        end,
      }
    end,
  },
}
