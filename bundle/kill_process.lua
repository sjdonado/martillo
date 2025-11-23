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
  refreshIntervalSeconds = 1,
  currentQuery = '',
  maxResults = 200,
  logger = hs.logger.new('KillProcess', 'info'),
  cachedProcessList = nil, -- Cache process list to avoid re-running ps on every keystroke
  cacheRefreshTimer = nil, -- Timer to refresh the cache periodically
  iconCache = {},          -- Cache icon objects in memory for the session
}

-- Format memory for display
local function formatMemory(memKB)
  if memKB >= 1024 * 1024 then -- >= 1GB
    return string.format('%.1f GB', memKB / (1024 * 1024))
  elseif memKB >= 1024 then    -- >= 1MB
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
      return pathAppName .. ' - Electron'
    end
    return 'Electron App'
  end

  -- Handle bracketed process names like [kernel_task]
  local bracketName = command:match '^%[(.+)%]$'
  if bracketName then
    return bracketName
  end

  -- Extract process name from full path
  local processName = command:match '([^/]+)$' or command:match '^(%S+)' or command

  -- Remove .app extension if present
  processName = processName:gsub('%.app$', '')

  -- Remove common executable suffixes
  processName = processName:gsub('%.bin$', '')

  -- Handle processes with arguments by taking only the first part
  processName = processName:match '^([^%s]+)' or processName

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
local function extractProcessName(command, baseAppName, appProcessList)
  if not command or command == '' then
    return 'Unknown'
  end

  -- Handle IP address network processes that belong to an app (e.g., Spotify network processes)
  if command:match '^%d+%.%d+%.%d+%.%d+$' then
    -- If we have app context from the grouping, use it
    if baseAppName and baseAppName ~= 'Unknown' and baseAppName ~= command then
      return baseAppName .. ' - Network'
    else
      return 'Network (' .. command .. ')'
    end
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

  -- If this app has multiple processes, determine which is main and which are helpers
  if appProcessList and #appProcessList > 1 then
    local isMainProc = isMainAppProcess(command, baseAppName, appProcessList)

    -- If it's the main process, return early without any suffix
    if isMainProc then
      return processName
    end

    -- This is a helper process - add appropriate suffix
    -- Don't add suffix if process name already contains Helper, Daemon, etc.
    if processName:match '[Hh]elper' or processName:match '[Dd]aemon' or processName:match '%(Helper%)' or processName:match '%(Daemon%)' then
      return processName
    end

    -- Determine if it's a helper or daemon based on process characteristics
    if processName:match 'daemon' or processName:match 'service' or processName:match 'worker' or processName:match 'monitor' or processName:match 'mgr' then
      return processName .. ' (Daemon)'
    else
      -- Mark as helper for auxiliary app processes
      return processName .. ' (Helper)'
    end
  end

  return processName
end

-- Get list of running processes
local function getProcessList()
  -- Get ALL processes including kernel tasks and parent info
  local success, output = pcall(hs.execute, 'ps -axo pid,ppid,pcpu,rss,command')
  if not success or not output then
    M.logger:e('Failed to execute ps command: ' .. tostring(output))
    return {}
  end

  local processes = {}
  local appProcesses = {} -- Map app names to their processes
  local lineCount = 0
  local processedCount = 0

  for line in output:gmatch '[^\r\n]+' do
    lineCount = lineCount + 1

    -- Skip header line
    if not line:match '^%s*PID' then
      -- Parse: PID PPID %CPU RSS COMMAND
      -- Handle both normal RSS values and edge cases
      local pid, ppid, cpu, rss, command = line:match '^%s*(%d+)%s+(%d+)%s+([%d%.]+)%s+(%d+)%s+(.*)'

      -- Fallback: try to capture processes with missing or non-numeric RSS
      if not pid then
        pid, ppid, cpu, rss, command = line:match '^%s*(%d+)%s+(%d+)%s+([%d%.]+)%s+(%S+)%s+(.*)'
      end

      -- Last resort: handle lines with unusual spacing or formatting
      if not pid then
        pid, ppid, cpu, command = line:match '^%s*(%d+)%s+(%d+)%s+([%d%.]+)%s+(.*)'
        rss = '0'
      end

      if pid and cpu and tonumber(pid) and tonumber(pid) >= 0 then
        processedCount = processedCount + 1

        local pidNum = tonumber(pid)
        local ppidNum = tonumber(ppid) or 0

        -- Ensure RSS is numeric
        if rss and not tonumber(rss) then
          rss = '0'
        end

        -- Get base app name for grouping
        local baseAppName = getBaseAppName(command)

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
        local processName = extractProcessName(command, baseAppName, appProcesses[baseAppName])

        -- Ensure we have a valid process name
        if processName and processName ~= '' then
          -- Get memory usage (allow 0 memory processes)
          local memKB = tonumber(rss) or 0

          -- Convert RSS (KB) to MB or GB for display
          local memDisplay = formatMemory(memKB)

          -- Create process entry with safe values
          local pidNum = tonumber(pid)
          local cpuNum = tonumber(cpu)

          if pidNum and cpuNum then
            table.insert(processes, {
              text = processName or 'Unknown',
              subText = string.format('PID: %s | CPU: %s%% | Memory: %s | %s', pid, cpu, memDisplay, command or ''),
              pid = pidNum,
              ppid = ppidNum,
              cpu = tonumber(cpu),
              mem = memKB, -- Store raw KB for sorting
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

  local rawProcessCount = #processes

  -- Aggregate processes with the same display name
  local nameBuckets = {}
  for _, process in ipairs(processes) do
    local key = process.name or process.text or 'Unknown'
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

      local candidateIsApp = isAppProcessEntry(candidate)
      local currentIsApp = isAppProcessEntry(current)
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
      local subText =
          string.format('PID: %d | Total CPU: %.1f%% | Total Memory: %s | %s | %d processes', main.pid, totalCpu,
            totalMemDisplay, main.fullPath or '', #list)

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
        -- Don't load icon here - will be loaded lazily when displayed
      })
    end
  end

  processes = aggregatedProcesses

  -- Sort by memory usage (descending) FIRST
  table.sort(processes, function(a, b)
    return a.mem > b.mem
  end)

  -- Debug logging
  M.logger:d(
    string.format('Processed %d lines, %d parsed, %d raw processes, %d aggregated (before limit)', lineCount,
      processedCount, rawProcessCount, #processes)
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

  -- No search query - return all processes
  if not M.currentQuery or M.currentQuery == '' then
    local appProcesses = {}
    local otherProcesses = {}

    for _, process in ipairs(allProcesses) do
      if process then
        if isAppProcessEntry(process) then
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
    handler = function()
      -- Get ActionsLauncher instance
      local actionsLauncher = spoon.ActionsLauncher
      local currentLauncher = nil -- Will be set by handler

      -- Reset icon count at the start of each search session
      thumbnailCache.resetLoadedCount 'app_icons'

      -- Set thumbnail memory limit for app icons
      thumbnailCache.setMaxLoaded('app_icons', 100)

      -- Clear icon cache from previous session
      M.iconCache = {}

      -- Initialize process cache and start refresh timer
      refreshProcessCache() -- Initial load

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

          -- Check if icon is already cached in memory for this PID
          local icon = M.iconCache[process.pid]

          if not icon then
            -- Load icon for this process
            if isAppProcessEntry(process) then
              -- App processes: try to get app icon
              if process.pid then
                local success, appbundle = pcall(hs.application.applicationForPID, process.pid)
                if success and appbundle then
                  local bundleID = appbundle:bundleID()
                  if bundleID then
                    icon = thumbnailCache.getCachedAppIcon(bundleID)
                  end
                end
              end
            end

            -- Fallback icon for non-app processes or if app icon failed
            if not icon then
              icon = thumbnailCache.getFallbackIcon('kill_process_fallback', function()
                return icons.getIcon(icons.preset.puzzle)
              end)
            end

            -- Cache the icon in memory for this session
            M.iconCache[process.pid] = icon
          end

          -- Create choice entry
          local choiceEntry = {
            text = process.text,
            subText = process.subText,
            uuid = uuid,
            image = icon,
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
                toast.success('Killed: ' .. process.name)
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
          M.iconCache = {}
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
