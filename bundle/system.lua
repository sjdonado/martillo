-- System Actions Bundle
-- System management and monitoring actions

local toast = require 'lib.toast'
local icons = require 'lib.icons'
local events = require 'lib.events'

return {
  {
    id = 'toggle_caffeinate',
    name = 'Toggle Caffeinate',
    icon = icons.preset.tea_cup,
    description = 'Toggle system sleep prevention',
    handler = function()
      spoon.ActionsLauncher.executeShell(
        "if pgrep caffeinate > /dev/null; then pkill caffeinate && echo 'Caffeinate disabled'; else nohup caffeinate -disu > /dev/null 2>&1 & echo 'Caffeinate enabled'; fi",
        'Toggle Caffeinate'
      )
    end,
  },
  {
    id = 'toggle_system_appearance',
    name = 'Toggle System Appearance',
    icon = icons.preset.sun,
    description = 'Toggle between light and dark mode',
    handler = function()
      spoon.ActionsLauncher.executeAppleScript(
        [[
          tell application "System Events"
            tell appearance preferences
              set dark mode to not dark mode
              if dark mode then
                return "Dark mode enabled"
              else
                return "Light mode enabled"
              end if
            end tell
          end tell
        ]],
        'Toggle System Appearance'
      )
    end,
  },
  {
    id = 'system_information',
    name = 'System Information',
    icon = icons.preset.tool,
    description = 'View real-time system information',
    handler = function()
      local actionsLauncher = spoon.ActionsLauncher
      local updateTimer = nil
      local isActive = true -- Flag to track if chooser is still active
      local results = {
        { text = 'CPU: Loading...',         subText = 'Processor usage and load',          value = '', details = '' },
        { text = 'Memory: Loading...',      subText = 'RAM usage and pressure',            value = '', details = '' },
        { text = 'GPU: Loading...',         subText = 'Graphics processor usage',          value = '', details = '' },
        { text = 'Thermal: Loading...',     subText = 'System thermal pressure',           value = '', details = '' },
        { text = 'Consumption: Loading...', subText = 'CPU/GPU power consumption',         value = '', details = '' },
        { text = 'Battery: Loading...',     subText = 'Battery status and percentage',     value = '', details = '' },
        { text = 'Network: Loading...',     subText = 'Upload/Download speeds',            value = '', details = '' },
        { text = 'Uptime: Loading...',      subText = 'System uptime',                     value = '', details = '' },
      }

      local function trim(s)
        if not s then
          return ''
        end
        return s:match '^%s*(.-)%s*$'
      end

      local function formatBytes(bytes)
        if bytes < 1024 then
          return string.format('%.0f B/s', bytes)
        elseif bytes < 1024 * 1024 then
          return string.format('%.2f KB/s', bytes / 1024)
        else
          return string.format('%.2f MB/s', bytes / (1024 * 1024))
        end
      end

      -- Store previous network stats for calculating speed
      local prevNetStats = { rx = 0, tx = 0, time = os.time() }

      local function updateSystemInfo()
        -- Use single powermetrics call for CPU, GPU, temps, and memory
        -- This is much more efficient than multiple separate commands
        hs.task
            .new('/bin/bash', function(exitCode, stdout, stderr)
              if exitCode == 0 then
                local output = stdout

                -- Parse CPU cluster active residency for overall CPU usage
                -- Look for both E-Cluster and P-Cluster
                local eClusterActive = output:match 'E%-Cluster HW active residency:%s+([%d%.]+)%%'
                local pClusterActive = output:match 'P%-Cluster HW active residency:%s+([%d%.]+)%%'

                if eClusterActive and pClusterActive then
                  -- Average of both clusters
                  local avgCPU = (tonumber(eClusterActive) + tonumber(pClusterActive)) / 2
                  results[1].text = string.format('CPU: %.0f%%', avgCPU)
                  results[1].value = string.format('%.0f%%', avgCPU)
                elseif pClusterActive then
                  results[1].text = string.format('CPU: %.0f%%', tonumber(pClusterActive))
                  results[1].value = string.format('%.0f%%', tonumber(pClusterActive))
                end

                -- Get load average from sysctl (more reliable)
                local load = hs.execute("sysctl -n vm.loadavg | awk '{print $2, $3, $4}'")
                if load and load ~= '' then
                  results[1].subText = 'Load: ' .. trim(load)
                end

                -- Parse Memory - use vm_stat for more accurate data
                local vmstat = hs.execute([[
                  vm_stat | awk '
                    /Pages active/ {active=$3}
                    /Pages wired down/ {wired=$4}
                    /Pages occupied by compressor/ {compressed=$5}
                    END {
                      page_size=4096
                      used=(active+wired+compressed)*page_size/1024/1024/1024
                      printf "%.1f", used
                    }'
                ]])
                local totalMem = hs.execute('sysctl -n hw.memsize')
                if vmstat and totalMem then
                  local usedGB = tonumber(trim(vmstat))
                  local totalGB = tonumber(totalMem) / 1024 / 1024 / 1024
                  local percent = (usedGB / totalGB) * 100
                  results[2].text = string.format('Memory: %.0f%%', percent)
                  results[2].value = string.format('%.0f%%', percent)
                  results[2].subText = string.format('%.1f GB / %.1f GB', usedGB, totalGB)
                end

                -- Parse GPU active residency
                local gpuActive = output:match 'GPU HW active residency:%s+([%d%.]+)%%'
                if gpuActive then
                  results[3].text = string.format('GPU: %.0f%%', tonumber(gpuActive))
                  results[3].value = string.format('%.0f%%', tonumber(gpuActive))

                  -- Get GPU frequency for additional context
                  local gpuFreq = output:match 'GPU HW active frequency: (%d+) MHz'
                  if gpuFreq then
                    results[3].subText = 'Active @ ' .. gpuFreq .. ' MHz'
                  else
                    results[3].subText = 'Graphics processor active residency'
                  end
                else
                  results[3].text = 'GPU: Setup Required'
                  results[3].value = 'Setup Required'
                  results[3].subText = 'Configure passwordless sudo for powermetrics'
                end

                -- Parse Thermal Pressure
                local thermalLevel = output:match 'Current pressure level: (%w+)'
                if thermalLevel then
                  results[4].text = 'Thermal: ' .. thermalLevel
                  results[4].value = thermalLevel
                  results[4].subText = 'System thermal pressure level'
                else
                  results[4].text = 'Thermal: Setup Required'
                  results[4].value = 'Setup Required'
                  results[4].subText = 'Configure passwordless sudo for powermetrics'
                end

                -- Parse Power Consumption
                local cpuPower = output:match 'CPU Power: (%d+) mW'
                local gpuPower = output:match 'GPU Power: (%d+) mW'
                local anePower = output:match 'ANE Power: (%d+) mW'

                if cpuPower and gpuPower then
                  local totalPower = tonumber(cpuPower) + tonumber(gpuPower) + (tonumber(anePower) or 0)
                  local watts = totalPower / 1000
                  results[5].text = string.format('Consumption: %.1f W', watts)
                  results[5].value = string.format('%.1f W', watts)
                  results[5].subText = string.format('CPU: %.1fW | GPU: %.1fW', tonumber(cpuPower)/1000, tonumber(gpuPower)/1000)
                else
                  results[5].text = 'Consumption: Setup Required'
                  results[5].value = 'Setup Required'
                  results[5].subText = 'Configure passwordless sudo for powermetrics'
                end
              else
                -- Powermetrics failed, likely no sudo access
                results[1].text = 'CPU: Setup Required'
                results[1].subText = 'Configure passwordless sudo for powermetrics'
                results[2].text = 'Memory: Setup Required'
                results[2].subText = 'Configure passwordless sudo for powermetrics'
                results[3].text = 'GPU: Setup Required'
                results[3].subText = 'Configure passwordless sudo for powermetrics'
                results[4].text = 'Thermal: Setup Required'
                results[4].subText = 'Configure passwordless sudo for powermetrics'
                results[5].text = 'Power: Setup Required'
                results[5].subText = 'Configure passwordless sudo for powermetrics'
              end

              if isActive then
                actionsLauncher:refresh()
              end
            end, {
              '-c',
              'sudo -n powermetrics --samplers cpu_power,gpu_power,thermal,tasks -i 1000 -n 1 2>/dev/null',
            })
            :start()

        -- Power/Battery Status
        hs.task
            .new('/bin/bash', function(exitCode, stdout, stderr)
              if exitCode == 0 then
                local output = trim(stdout)

                -- Check if on AC or Battery Power
                local onBattery = output:match 'Battery Power'
                local onAC = output:match 'AC Power'

                -- Extract battery percentage
                local percent = output:match '(%d+)%%'

                if not percent then
                  -- No battery (desktop Mac)
                  results[6].text = 'Battery: AC Power'
                  results[6].subText = 'Connected to power adapter'
                  results[6].value = 'AC Power'
                else
                  -- Has battery - check status (order matters: check "discharging" before "charging")
                  local discharging = output:match 'discharging'
                  local charging = output:match 'charging' and not discharging
                  local charged = output:match 'charged'

                  local status = ''
                  local statusText = ''

                  if charged then
                    status = '⚡'
                    statusText = 'Fully charged'
                  elseif discharging then
                    status = '🔋'
                    statusText = 'On battery'
                  elseif charging then
                    status = '⚡'
                    statusText = 'Charging'
                  else
                    status = '❓'
                    statusText = 'Unknown'
                  end

                  results[6].text = 'Battery: ' .. status .. ' ' .. percent .. '%'
                  results[6].value = percent .. '%'

                  -- Extract time remaining
                  local time = output:match '(%d+:%d+)'
                  if time then
                    results[6].subText = statusText .. ' - ' .. time .. ' remaining'
                  else
                    results[6].subText = statusText
                  end
                end
              end
              if isActive then
                actionsLauncher:refresh()
              end
            end, { '-c', 'pmset -g batt' })
            :start()

        -- Network Usage
        hs.task
            .new('/bin/bash', function(exitCode, stdout, stderr)
              if exitCode == 0 then
                local output = trim(stdout)
                local rx, tx = output:match '([^|]+)|([^|]+)'

                if rx and tx then
                  local rxBytes = tonumber(rx)
                  local txBytes = tonumber(tx)
                  local currentTime = os.time()

                  if prevNetStats.rx > 0 then
                    local timeDiff = currentTime - prevNetStats.time
                    if timeDiff > 0 then
                      local rxSpeed = (rxBytes - prevNetStats.rx) / timeDiff
                      local txSpeed = (txBytes - prevNetStats.tx) / timeDiff

                      results[7].text = string.format('Network: ↓ %s ↑ %s', formatBytes(rxSpeed), formatBytes(txSpeed))
                      results[7].value = string.format('↓ %s ↑ %s', formatBytes(rxSpeed), formatBytes(txSpeed))
                      results[7].subText = string.format('Download: %s, Upload: %s', formatBytes(rxSpeed),
                        formatBytes(txSpeed))
                    end
                  end

                  prevNetStats = { rx = rxBytes, tx = txBytes, time = currentTime }
                end
              end
              if isActive then
                actionsLauncher:refresh()
              end
            end, {
              '-c',
              'netstat -ib | awk \'/en[0-9]/ && $7>0 {rx+=$7; tx+=$10} END {print rx "|" tx}\'',
            })
            :start()

        -- System Uptime with boot date
        hs.task
            .new('/bin/bash', function(exitCode, stdout, stderr)
              if exitCode == 0 then
                local boottime = trim(stdout)
                -- Parse sysctl kern.boottime output: { sec = 1234567890, usec = 0 }
                local bootSec = boottime:match 'sec = (%d+)'

                if bootSec then
                  local bootTimestamp = tonumber(bootSec)
                  local currentTime = os.time()
                  local uptimeSeconds = currentTime - bootTimestamp

                  -- Calculate uptime components
                  local days = math.floor(uptimeSeconds / 86400)
                  local hours = math.floor((uptimeSeconds % 86400) / 3600)
                  local mins = math.floor((uptimeSeconds % 3600) / 60)

                  -- Format uptime string
                  local uptimeStr = ''
                  if days > 0 then
                    uptimeStr = string.format('%dd %dh %dm', days, hours, mins)
                  elseif hours > 0 then
                    uptimeStr = string.format('%dh %dm', hours, mins)
                  else
                    uptimeStr = string.format('%dm', mins)
                  end

                  -- Format boot date
                  local bootDate = os.date('%B %d, %Y at %H:%M', bootTimestamp)

                  results[8].text = 'Uptime: ' .. uptimeStr
                  results[8].value = uptimeStr
                  results[8].subText = 'Running since ' .. bootDate
                else
                  results[8].text = 'Uptime: Unknown'
                  results[8].value = 'Unknown'
                  results[8].subText = 'Unable to determine boot time'
                end
              end
              if isActive then
                actionsLauncher:refresh()
              end
            end, { '-c', 'sysctl kern.boottime' })
            :start()
      end

      actionsLauncher:openChildChooser {
        placeholder = 'System Information (real-time updates)',
        parentAction = 'system_information',
        handler = function(query, launcher)
          return events.buildSearchableChoices(query, results, launcher, {
            handler = function(result)
              return events.copyToClipboard(function(choice)
                return result.value
              end)
            end,
            maxResults = 10,
          })
        end,
        onClose = function()
          -- Set flag to prevent further refresh attempts
          isActive = false
          -- Stop the update timer when chooser closes
          if updateTimer then
            updateTimer:stop()
            updateTimer = nil
          end
        end,
      }

      -- Initial update
      updateSystemInfo()

      -- Set up timer for real-time updates (every 2 seconds)
      updateTimer = hs.timer.doEvery(2, function()
        updateSystemInfo()
      end)
    end,
  },
}
