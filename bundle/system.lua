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
      local isActive = true -- Flag to track if picker is still active
      local results = {
        { text = 'CPU: Loading...',     subText = 'Processor usage and load', value = '', details = '' },
        { text = 'Memory: Loading...',  subText = 'RAM usage and pressure',   value = '', details = '' },
        { text = 'Power: Loading...',   subText = 'Battery and power status', value = '', details = '' },
        { text = 'Network: Loading...', subText = 'Upload/Download speeds',   value = '', details = '' },
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
        -- CPU Usage
        hs.task
            .new('/bin/bash', function(exitCode, stdout, stderr)
              if exitCode == 0 then
                local cpu = trim(stdout)
                if cpu ~= '' then
                  results[1].text = 'CPU: ' .. cpu .. '%'
                  results[1].value = cpu .. '%'
                end
              end
              if isActive then
                actionsLauncher:refresh()
              end
            end, {
              '-c',
              "top -l 2 -n 0 -F -s 0 | grep 'CPU usage' | tail -1 | awk '{print 100-$7}' | cut -d. -f1",
            })
            :start()

        -- CPU Load Average (additional detail)
        hs.task
            .new('/bin/bash', function(exitCode, stdout, stderr)
              if exitCode == 0 then
                local load = trim(stdout)
                if load ~= '' then
                  results[1].details = 'Load avg: ' .. load
                  results[1].subText = 'Load avg: ' .. load
                end
              end
              if isActive then
                actionsLauncher:refresh()
              end
            end, { '-c', "sysctl -n vm.loadavg | awk '{print $2, $3, $4}'" })
            :start()

        -- Memory Usage
        hs.task
            .new('/bin/bash', function(exitCode, stdout, stderr)
              if exitCode == 0 then
                local output = trim(stdout)
                local used, total, percent = output:match '([^|]+)|([^|]+)|([^|]+)'
                if used and total and percent then
                  results[2].text = 'Memory: ' .. trim(percent) .. '%'
                  results[2].value = trim(percent) .. '%'
                  results[2].details = trim(used) .. ' / ' .. trim(total)
                  results[2].subText = trim(used) .. ' / ' .. trim(total) .. ' remaining'
                end
              end
              if isActive then
                actionsLauncher:refresh()
              end
            end, {
              '-c',
              [[
                vm_stat | awk '
                  /Pages active/ {active=$3}
                  /Pages wired down/ {wired=$4}
                  /Pages occupied by compressor/ {compressed=$5}
                  END {
                    page_size=4096
                    used=(active+wired+compressed)*page_size/1024/1024/1024
                    total_bytes='$(sysctl -n hw.memsize)'
                    total=total_bytes/1024/1024/1024
                    percent=(used/total)*100
                    printf "%.1f GB|%.1f GB|%.0f", used, total, percent
                  }'
              ]],
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
                  results[3].text = 'Power: AC Power'
                  results[3].subText = 'Connected to power adapter'
                  results[3].value = 'AC Power'
                else
                  -- Has battery
                  local charging = output:match 'charging'
                  local charged = output:match 'charged'
                  local discharging = output:match 'discharging'

                  local status = ''
                  local statusText = ''

                  if charged then
                    status = '⚡'
                    statusText = 'Fully charged'
                  elseif charging then
                    status = '⚡'
                    statusText = 'Charging'
                  elseif discharging then
                    status = '🔋'
                    statusText = 'On battery'
                  end

                  results[3].text = 'Power: ' .. status .. ' ' .. percent .. '%'
                  results[3].value = percent .. '%'

                  -- Extract time remaining
                  local time = output:match '(%d+:%d+)'
                  if time then
                    results[3].subText = statusText .. ' - ' .. time .. ' remaining'
                  else
                    results[3].subText = statusText
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

                      results[4].text = string.format('Network: ↓ %s ↑ %s', formatBytes(rxSpeed), formatBytes(txSpeed))
                      results[4].value = string.format('↓ %s ↑ %s', formatBytes(rxSpeed), formatBytes(txSpeed))
                      results[4].subText = string.format('Download: %s, Upload: %s', formatBytes(rxSpeed),
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
      end

      actionsLauncher:openChildPicker {
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
          -- Stop the update timer when picker closes
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

      return 'OPEN_CHILD_PICKER'
    end,
  },
}
