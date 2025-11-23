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
    icon = icons.preset.chart,
    description = 'View real-time system information',
    handler = function()
      local actionsLauncher = spoon.ActionsLauncher
      local updateTimer = nil
      local isActive = true
      local results = {
        { text = 'CPU: Loading...',         subText = 'Processor usage and load',      value = '' },
        { text = 'Memory: Loading...',      subText = 'RAM usage and pressure',        value = '' },
        { text = 'GPU: Loading...',         subText = 'Graphics processor usage',      value = '' },
        { text = 'Thermal: Loading...',     subText = 'System thermal pressure',       value = '' },
        { text = 'Consumption: Loading...', subText = 'CPU/GPU power consumption',     value = '' },
        { text = 'Battery: Loading...',     subText = 'Battery status and percentage', value = '' },
        { text = 'Network: Loading...',     subText = 'Upload/Download speeds',        value = '' },
        { text = 'Uptime: Loading...',      subText = 'System uptime',                 value = '' },
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

      local prevNetStats = { rx = 0, tx = 0, time = os.time() }

      local function updateSystemInfo()
        -- Single powermetrics call for CPU, GPU, Thermal, and Power
        hs.task
            .new('/bin/bash', function(exitCode, stdout, stderr)
              if exitCode == 0 then
                local output = stdout

                -- Parse CPU cluster active residency (handle P0/P1 clusters)
                local eClusterActive = output:match 'E%-Cluster HW active residency:%s+([%d%.]+)%%'
                local p0ClusterActive = output:match 'P0%-Cluster HW active residency:%s+([%d%.]+)%%'
                local p1ClusterActive = output:match 'P1%-Cluster HW active residency:%s+([%d%.]+)%%'

                -- Fallback for single P-Cluster systems
                if not p0ClusterActive and not p1ClusterActive then
                  p0ClusterActive = output:match 'P%-Cluster HW active residency:%s+([%d%.]+)%%'
                end

                -- Calculate average CPU usage
                local cpuValues = {}
                if eClusterActive then
                  table.insert(cpuValues, tonumber(eClusterActive))
                end
                if p0ClusterActive then
                  table.insert(cpuValues, tonumber(p0ClusterActive))
                end
                if p1ClusterActive then
                  table.insert(cpuValues, tonumber(p1ClusterActive))
                end

                if #cpuValues > 0 then
                  local sum = 0
                  for _, v in ipairs(cpuValues) do
                    sum = sum + v
                  end
                  local avgCPU = sum / #cpuValues
                  results[1].text = string.format('CPU: %.0f%%', avgCPU)
                  results[1].value = string.format('%.0f%%', avgCPU)
                end

                -- Get load average
                local load = hs.execute "sysctl -n vm.loadavg | awk '{print $2, $3, $4}'"
                if load and load ~= '' then
                  results[1].subText = 'Load: ' .. trim(load)
                end

                -- Parse GPU
                local gpuActive = output:match 'GPU HW active residency:%s+([%d%.]+)%%'
                if gpuActive then
                  results[3].text = string.format('GPU: %.0f%%', tonumber(gpuActive))
                  results[3].value = string.format('%.0f%%', tonumber(gpuActive))
                  local gpuFreq = output:match 'GPU HW active frequency: (%d+) MHz'
                  if gpuFreq then
                    results[3].subText = 'Active @ ' .. gpuFreq .. ' MHz'
                  else
                    results[3].subText = 'Graphics processor usage'
                  end
                end

                -- Parse Thermal
                local thermalLevel = output:match 'Current pressure level: (%w+)'
                if thermalLevel then
                  results[4].text = 'Thermal: ' .. thermalLevel
                  results[4].value = thermalLevel
                  results[4].subText = 'System thermal pressure level'
                end

                -- Parse Power
                local cpuPower = output:match 'CPU Power: (%d+) mW'
                local gpuPower = output:match 'GPU Power: (%d+) mW'
                local anePower = output:match 'ANE Power: (%d+) mW'
                if cpuPower and gpuPower then
                  local totalPower = tonumber(cpuPower) + tonumber(gpuPower) + (tonumber(anePower) or 0)
                  local watts = totalPower / 1000
                  results[5].text = string.format('Consumption: %.1f W', watts)
                  results[5].value = string.format('%.1f W', watts)
                  results[5].subText = string.format('CPU: %.1fW | GPU: %.1fW', tonumber(cpuPower) / 1000,
                    tonumber(gpuPower) / 1000)
                end
              end

              if isActive then
                actionsLauncher:refresh()
              end
            end, {
              '-c',
              'sudo -n powermetrics --samplers cpu_power,gpu_power,thermal,tasks -i 1000 -n 1 2>/dev/null',
            })
            :start()

        -- Memory - calculate like Activity Monitor (App Memory + Wired + Compressed)
        hs.task
            .new('/bin/bash', function(exitCode, stdout, stderr)
              if exitCode == 0 then
                local output = trim(stdout)
                local totalMem = hs.execute 'sysctl -n hw.memsize'

                -- Extract page size from vm_stat first line
                local pageSizeStr = output:match 'page size of (%d+) bytes'
                local pageSize = tonumber(pageSizeStr) or 16384

                -- Parse vm_stat output
                local anonymous = output:match 'Anonymous pages:%s+(%d+)'
                local wired = output:match 'Pages wired down:%s+(%d+)'
                local compressed = output:match 'Pages occupied by compressor:%s+(%d+)'

                if anonymous and wired and compressed and totalMem then
                  -- Activity Monitor formula: App Memory + Wired + Compressed
                  local anonymousPages = tonumber(anonymous)
                  local wiredPages = tonumber(wired)
                  local compressedPages = tonumber(compressed)

                  local usedBytes = (anonymousPages + wiredPages + compressedPages) * pageSize
                  local usedGB = usedBytes / 1024 / 1024 / 1024
                  local totalGB = tonumber(totalMem) / 1024 / 1024 / 1024
                  local percent = (usedGB / totalGB) * 100

                  results[2].text = string.format('Memory: %.0f%%', percent)
                  results[2].value = string.format('%.0f%%', percent)
                  results[2].subText = string.format('%.1f GB / %.1f GB', usedGB, totalGB)
                end
              end

              if isActive then
                actionsLauncher:refresh()
              end
            end, { '-c', 'vm_stat' })
            :start()

        -- Battery Status
        hs.task
            .new('/bin/bash', function(exitCode, stdout, stderr)
              if exitCode == 0 then
                local output = trim(stdout)
                local percent = output:match '(%d+)%%'

                if not percent then
                  results[6].text = 'Battery: AC Power'
                  results[6].subText = 'Connected to power adapter'
                  results[6].value = 'AC Power'
                else
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

        -- Uptime
        hs.task
            .new('/bin/bash', function(exitCode, stdout, stderr)
              if exitCode == 0 then
                local boottime = trim(stdout)
                local bootSec = boottime:match 'sec = (%d+)'

                if bootSec then
                  local bootTimestamp = tonumber(bootSec)
                  local currentTime = os.time()
                  local uptimeSeconds = currentTime - bootTimestamp

                  local days = math.floor(uptimeSeconds / 86400)
                  local hours = math.floor((uptimeSeconds % 86400) / 3600)
                  local mins = math.floor((uptimeSeconds % 3600) / 60)

                  local uptimeStr = ''
                  if days > 0 then
                    uptimeStr = string.format('%dd %dh %dm', days, hours, mins)
                  elseif hours > 0 then
                    uptimeStr = string.format('%dh %dm', hours, mins)
                  else
                    uptimeStr = string.format('%dm', mins)
                  end

                  local bootDate = os.date('%B %d, %Y at %H:%M', bootTimestamp)
                  results[8].text = 'Uptime: ' .. uptimeStr
                  results[8].value = uptimeStr
                  results[8].subText = 'Running since ' .. bootDate
                end
              end

              if isActive then
                actionsLauncher:refresh()
              end
            end, { '-c', 'sysctl kern.boottime' })
            :start()
      end

      actionsLauncher:openChildChooser {
        placeholder = 'System Information (↩ copy metric)',
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
          isActive = false
          if updateTimer then
            updateTimer:stop()
            updateTimer = nil
          end
        end,
      }

      -- Initial update
      updateSystemInfo()

      -- Update every 2 seconds
      updateTimer = hs.timer.doEvery(2, function()
        if isActive then
          updateSystemInfo()
        end
      end)
    end,
  },
}
