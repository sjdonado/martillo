-- Network Actions Bundle
-- Network utilities for IP information and connectivity testing

local toast = require 'lib.toast'
local actions = require 'lib.actions'
local icons = require 'lib.icons'

return {
  {
    id = 'network_ip_geolocation',
    name = 'IP Geolocation',
    icon = icons.preset.wifi,
    description = 'View detailed IP and geolocation information',
    handler = function()
      local actionsLauncher = spoon.ActionsLauncher
      local results = {
        { text = 'Local IPv4: Loading...', subText = 'Enter to copy', value = '' },
        { text = 'Public IPv4: Loading...', subText = 'Enter to copy', value = '' },
        { text = 'Location: Loading...', subText = 'Country, State, City, ZIP', value = '' },
        { text = 'GeoCoordinates: Loading...', subText = 'Latitude, Longitude', value = '' },
        { text = 'Timezone: Loading...', subText = 'Enter to copy', value = '' },
        { text = 'AS: Loading...', subText = 'Autonomous System', value = '' },
        { text = 'ISP: Loading...', subText = 'Internet Service Provider', value = '' },
        { text = 'Organization: Loading...', subText = 'Enter to copy', value = '' },
      }

      local function trim(s)
        if not s then
          return ''
        end
        return s:match '^%s*(.-)%s*$'
      end

      local function fetchData()
        -- Get Local IP
        hs.task
          .new('/bin/bash', function(exitCode, stdout, stderr)
            local localIP = trim(stdout)
            if exitCode == 0 and localIP ~= '' then
              results[1].text = 'Local IPv4: ' .. localIP
              results[1].value = localIP
            else
              results[1].text = 'Local IPv4: Not found'
            end
            actionsLauncher:refresh()
          end, {
            '-c',
            "ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || ifconfig | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}'",
          })
          :start()

        -- Get Public IP and Geolocation
        hs.task
          .new('/bin/bash', function(exitCode, stdout, stderr)
            local publicIP = trim(stdout)
            if exitCode == 0 and publicIP ~= '' then
              results[2].text = 'Public IPv4: ' .. publicIP
              results[2].value = publicIP
              actionsLauncher:refresh()

              -- Fetch geolocation data
              hs.task
                .new('/usr/bin/curl', function(exitCode2, stdout2, stderr2)
                  if exitCode2 == 0 then
                    -- Parse JSON manually (simple approach)
                    local json = trim(stdout2)

                    -- Extract fields using pattern matching
                    local country = json:match '"country"%s*:%s*"([^"]*)"' or ''
                    local regionName = json:match '"regionName"%s*:%s*"([^"]*)"' or ''
                    local city = json:match '"city"%s*:%s*"([^"]*)"' or ''
                    local zip = json:match '"zip"%s*:%s*"([^"]*)"' or ''
                    local lat = json:match '"lat"%s*:%s*([%d%.%-]+)' or ''
                    local lon = json:match '"lon"%s*:%s*([%d%.%-]+)' or ''
                    local timezone = json:match '"timezone"%s*:%s*"([^"]*)"' or ''
                    local isp = json:match '"isp"%s*:%s*"([^"]*)"' or ''
                    local org = json:match '"org"%s*:%s*"([^"]*)"' or ''
                    local as = json:match '"as"%s*:%s*"([^"]*)"' or ''

                    -- Update results
                    if country ~= '' then
                      local location = country
                      if regionName ~= '' then
                        location = location .. ', ' .. regionName
                      end
                      if city ~= '' then
                        location = location .. ', ' .. city
                      end
                      if zip ~= '' then
                        location = location .. ', ZIP: ' .. zip
                      end
                      results[3].text = 'Location: ' .. location
                      results[3].value = location
                    end

                    if lat ~= '' and lon ~= '' then
                      results[4].text = 'GeoCoordinates: ' .. lat .. ', ' .. lon
                      results[4].value = lat .. ', ' .. lon
                    end

                    if timezone ~= '' then
                      results[5].text = 'Timezone: ' .. timezone
                      results[5].value = timezone
                    end

                    if as ~= '' then
                      results[6].text = 'AS: ' .. as
                      results[6].value = as
                    end

                    if isp ~= '' then
                      results[7].text = 'ISP: ' .. isp
                      results[7].value = isp
                    end

                    if org ~= '' then
                      results[8].text = 'Organization: ' .. org
                      results[8].value = org
                    end

                    actionsLauncher:refresh()
                  else
                    results[3].text = 'Location: Failed to fetch'
                    actionsLauncher:refresh()
                  end
                end, { '-s', 'http://ip-api.com/json/' .. publicIP })
                :start()
            else
              results[2].text = 'Public IPv4: Failed to fetch'
              actionsLauncher:refresh()
            end
          end, { '-c', 'curl -s ifconfig.me' })
          :start()
      end

      actionsLauncher:openChildPicker {
        placeholder = 'IP Geolocation Information (Enter to copy)',
        parentAction = 'network_copy_ip',
        handler = function(query, launcher)
          local choices = {}
          for _, result in ipairs(results) do
            local uuid = launcher:generateUUID()
            table.insert(choices, {
              text = result.text,
              subText = result.subText,
              uuid = uuid,
            })
            launcher.handlers[uuid] = actions.copyToClipboard(function(choice)
              return result.value
            end)
          end
          return choices
        end,
      }

      -- Start fetching data after picker is shown
      hs.timer.doAfter(0.1, fetchData)

      return 'OPEN_CHILD_PICKER'
    end,
  },

  {
    id = 'network_speed_test',
    name = 'Speed Test',
    icon = icons.preset.flash,
    description = 'Check network connectivity, latency, and speed',
    handler = function()
      local results = {
        { text = 'Latency: Loading...', subText = 'curl to 1.1.1.1' },
        { text = 'Download: Loading...', subText = '10MB from speed.cloudflare.com' },
        { text = 'Upload: Loading...', subText = '1MB to speed.cloudflare.com' },
      }

      -- Get ActionsLauncher instance
      local actionsLauncher = spoon.ActionsLauncher

      -- Helper to trim whitespace and newlines
      local function trim(s)
        if not s then
          return ''
        end
        return s:match '^%s*(.-)%s*$'
      end

      local function runTests()
        -- Test 1: Latency
        results[1].text = 'Latency: Loading...'
        actionsLauncher:refresh()

        hs.task
          .new('/bin/bash', function(exitCode, stdout, stderr)
            local latency = trim(stdout)
            if exitCode == 0 and latency ~= '' then
              results[1].text = string.format('Latency: %s ms', latency)
            else
              results[1].text = 'Latency: Failed'
            end
            actionsLauncher:refresh()

            -- Test 2: Download
            results[2].text = 'Download: Loading...'
            actionsLauncher:refresh()

            hs.task
              .new('/bin/bash', function(exitCode2, stdout2, stderr2)
                local download = trim(stdout2)
                if exitCode2 == 0 and download ~= '' then
                  results[2].text = string.format('Download: %s MB/s', download)
                else
                  results[2].text = 'Download: Failed'
                end
                actionsLauncher:refresh()

                -- Test 3: Upload
                results[3].text = 'Upload: Loading...'
                actionsLauncher:refresh()

                hs.task
                  .new('/bin/bash', function(exitCode3, stdout3, stderr3)
                    local upload = trim(stdout3)
                    if exitCode3 == 0 and upload ~= '' then
                      results[3].text = string.format('Upload: %s MB/s', upload)
                    else
                      results[3].text = 'Upload: Failed'
                    end
                    actionsLauncher:refresh()
                  end, {
                    '-c',
                    "dd if=/dev/zero bs=1024 count=1024 2>/dev/null | curl -o /dev/null -s -w '%{speed_upload}' --data-binary @- https://speed.cloudflare.com/__up 2>&1 | awk '{printf \"%.2f\", $1 / 1024 / 1024}'",
                  })
                  :start()
              end, {
                '-c',
                "curl -o /dev/null -s -w '%{speed_download}' https://speed.cloudflare.com/__down?bytes=10000000 2>&1 | awk '{printf \"%.2f\", $1 / 1024 / 1024}'",
              })
              :start()
          end, {
            '-c',
            "curl -o /dev/null -s -w '%{time_total}' https://1.1.1.1 2>&1 | awk '{printf \"%.0f\", $1 * 1000}'",
          })
          :start()
      end

      -- Use ActionsLauncher's openChildPicker
      actionsLauncher:openChildPicker {
        placeholder = 'Speed test results...',
        parentAction = 'network_status',
        handler = function(query, launcher)
          local choices = {}
          for _, result in ipairs(results) do
            local uuid = launcher:generateUUID()
            table.insert(choices, {
              text = result.text,
              subText = result.subText,
              uuid = uuid,
            })

            -- Display-only: no action on Enter
            launcher.handlers[uuid] = actions.noAction()
          end
          return choices
        end,
      }

      -- Start tests after picker is shown
      hs.timer.doAfter(0.1, runTests)

      return 'OPEN_CHILD_PICKER'
    end,
  },
}
