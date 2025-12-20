-- Network Actions Bundle
-- Network utilities for IP information and connectivity testing

local toast = require 'lib.toast'
local events = require 'lib.events'
local icons = require 'lib.icons'
local chooserManager = require 'lib.chooser'
local temp = require 'lib.tmp'

return {
  {
    id = 'network_ip_geolocation',
    name = 'IP Geolocation',
    icon = icons.preset.wifi,
    description = 'View detailed IP and geolocation information',
    handler = function()
      local actionsLauncher = spoon.ActionsLauncher
      local results = {
        { text = 'Local IPv4: Loading...',     subText = 'Enter to copy',             value = '' },
        { text = 'Public IPv4: Loading...',    subText = 'Enter to copy',             value = '' },
        { text = 'Location: Loading...',       subText = 'Country, State, City, ZIP', value = '' },
        { text = 'GeoCoordinates: Loading...', subText = 'Latitude, Longitude',       value = '' },
        { text = 'Timezone: Loading...',       subText = 'Enter to copy',             value = '' },
        { text = 'AS: Loading...',             subText = 'Autonomous System',         value = '' },
        { text = 'ISP: Loading...',            subText = 'Internet Service Provider', value = '' },
        { text = 'Organization: Loading...',   subText = 'Enter to copy',             value = '' },
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

      actionsLauncher:openChildChooser {
        placeholder = 'IP Geolocation Information (Enter to copy)',
        parentAction = 'network_copy_ip',
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
      }

      -- Start fetching data after chooser is shown
      hs.timer.doAfter(0.1, fetchData)
    end,
  },

  {
    id = 'network_connected_devices',
    name = 'Connected Devices',
    icon = icons.preset.wifi,
    description = 'List all devices connected to the current WiFi network',
    handler = function()
      local actionsLauncher = spoon.ActionsLauncher
      local deviceIcon = icons.getIcon(icons.preset.cube)
      local results = {
        { text = 'Scanning network...', subText = 'Please wait', ip = '', mac = '' },
      }

      local function trim(s)
        if not s then
          return ''
        end
        return s:match '^%s*(.-)%s*$'
      end

      local vendorCache = {}
      local cacheFile = temp.getDir() .. '/mac_vendor_cache.txt'

      local function loadVendorCache()
        -- Load from file
        local file = io.open(cacheFile, 'r')
        if file then
          for line in file:lines() do
            local oui, vendor = line:match '^([^|]+)|(.+)$'
            if oui and vendor then
              vendorCache[oui] = vendor
            end
          end
          file:close()
        end
      end

      local function saveVendorToCache(oui, vendor)
        vendorCache[oui] = vendor
        local file = io.open(cacheFile, 'a')
        if file then
          file:write(string.format('%s|%s\n', oui, vendor))
          file:close()
        end
      end

      local function isLocallyAdministeredMAC(mac)
        -- Check if MAC address is locally administered (bit 1 of first octet is 1)
        -- Locally administered MACs are randomized/private addresses
        local firstOctet = mac:match '^([^:]+)'
        if not firstOctet then
          return false
        end

        local value = tonumber(firstOctet, 16)
        if not value then
          return false
        end

        -- Check if bit 1 (second least significant bit) is set
        return (value % 4) >= 2
      end

      local function getOUI(mac)
        -- Extract first 3 octets (OUI) from MAC address
        local parts = {}
        for part in mac:gmatch '[^:]+' do
          table.insert(parts, part)
        end
        if #parts >= 3 then
          return string.format('%s:%s:%s', parts[1], parts[2], parts[3]):upper()
        end
        return nil
      end

      local function detectVendorFromHostname(hostname)
        if not hostname or hostname == 'Unknown' or hostname == '?' then
          return nil
        end

        local lowerHost = hostname:lower()

        -- Apple devices
        if
            lowerHost:match 'iphone'
            or lowerHost:match 'ipad'
            or lowerHost:match 'macbook'
            or lowerHost:match 'mac%-mini'
            or lowerHost:match 'imac'
            or lowerHost:match '^mac%.fritz'
            or lowerHost:match '%-mac%.'
        then
          return 'Apple, Inc.'
        elseif lowerHost:match 'raspberrypi' or lowerHost:match 'pizero' or lowerHost:match 'pi%d' or lowerHost:match '^pi%.' then
          return 'Raspberry Pi Foundation'
        elseif lowerHost:match 'samsung' then
          return 'Samsung'
        elseif lowerHost:match 'echo' or lowerHost:match 'kindle' or lowerHost:match 'fire%-' then
          return 'Amazon Technologies Inc.'
        end

        return nil
      end

      local function updateResultWithVendor(index, vendor)
        local hostname = results[index].hostname or 'Unknown'
        if hostname == 'Unknown' then
          results[index].subText = string.format('%s • %s', vendor, results[index].mac)
        else
          results[index].subText = string.format('%s • %s • %s', hostname, vendor, results[index].mac)
        end
        results[index].vendor = vendor
        actionsLauncher:refresh()
      end

      local function lookupVendor(mac, index)
        local oui = getOUI(mac)
        if not oui then
          return
        end

        -- Check if locally administered (randomized/private MAC)
        if isLocallyAdministeredMAC(mac) then
          -- Don't lookup - it's a randomized MAC address
          return
        end

        -- Check cache first
        if vendorCache[oui] then
          updateResultWithVendor(index, vendorCache[oui])
          return
        end

        -- Use macvendors.com API to lookup vendor
        hs.task
            .new('/usr/bin/curl', function(exitCode, stdout, stderr)
              if exitCode == 0 and stdout and stdout ~= '' then
                local vendor = trim(stdout)
                -- API returns error messages for unknown vendors or rate limiting
                local lowerVendor = vendor:lower()
                if
                    vendor ~= ''
                    and not vendor:match '^<!DOCTYPE'
                    and not lowerVendor:match 'error'
                    and not lowerVendor:match 'not found'
                    and not lowerVendor:match 'too many'
                then
                  -- Save to cache
                  saveVendorToCache(oui, vendor)
                  -- Update the result with vendor info
                  updateResultWithVendor(index, vendor)
                end
              end
            end, { '-s', '-m', '2', 'https://api.macvendors.com/' .. mac })
            :start()
      end

      local function parseArpTable()
        hs.task
            .new('/bin/bash', function(exitCode, stdout, stderr)
              if exitCode == 0 then
                results = {}
                local lines = {}
                for line in stdout:gmatch '[^\r\n]+' do
                  table.insert(lines, line)
                end

                -- Parse arp output
                -- Format: hostname (ip) at mac on interface [ethernet]
                for _, line in ipairs(lines) do
                  local hostname = line:match '^([^%(]+)%s*%('
                  local ip = line:match '%(([%d%.]+)%)'
                  local mac = line:match 'at%s+([%x:]+)%s+'

                  if ip and mac then
                    hostname = hostname and trim(hostname) or 'Unknown'
                    if hostname == '?' then
                      hostname = 'Unknown'
                    end

                    -- Filter out incomplete entries
                    -- Allow MAC addresses with 1 or 2 hex digits per octet (e.g., b8:27:eb:5:5f:26 or b8:27:eb:05:5f:26)
                    if mac ~= '(incomplete)' and mac:match '%x+:%x+:%x+:%x+:%x+:%x+' then
                      -- Normalize MAC address to always have 2 digits per octet
                      local normalizedMac = mac:gsub('(%x+)', function(octet)
                        if #octet == 1 then
                          return '0' .. octet
                        end
                        return octet
                      end)

                      table.insert(results, {
                        text = ip,
                        subText = string.format('%s • %s', hostname, normalizedMac:upper()),
                        ip = ip,
                        mac = normalizedMac:upper(),
                        hostname = hostname,
                        vendor = nil,
                      })
                    end
                  end
                end

                if #results == 0 then
                  results = {
                    { text = 'No devices found', subText = 'Try again or check network connection', ip = '', mac = '' },
                  }
                else
                  -- Sort by IP address
                  table.sort(results, function(a, b)
                    local function ipToNum(ip)
                      local parts = {}
                      for part in ip:gmatch '%d+' do
                        table.insert(parts, tonumber(part))
                      end
                      if #parts == 4 then
                        return parts[1] * 16777216 + parts[2] * 65536 + parts[3] * 256 + parts[4]
                      end
                      return 0
                    end
                    return ipToNum(a.ip) < ipToNum(b.ip)
                  end)

                  -- Lookup vendor for each MAC address
                  local apiCallDelay = 0
                  for i, result in ipairs(results) do
                    if result.mac and result.mac ~= '' then
                      -- First, try to detect vendor from hostname
                      local hostnameVendor = detectVendorFromHostname(result.hostname)
                      if hostnameVendor then
                        updateResultWithVendor(i, hostnameVendor)
                      else
                        -- Try MAC vendor lookup
                        local oui = getOUI(result.mac)
                        if oui and vendorCache[oui] then
                          -- Cached - show immediately
                          updateResultWithVendor(i, vendorCache[oui])
                        else
                          -- Not cached - rate limit API calls
                          hs.timer.doAfter(apiCallDelay * 0.5, function()
                            lookupVendor(result.mac, i)
                          end)
                          apiCallDelay = apiCallDelay + 1
                        end
                      end
                    end
                  end
                end
              else
                results = {
                  { text = 'Scan failed', subText = 'Unable to retrieve network devices', ip = '', mac = '' },
                }
              end
              actionsLauncher:refresh()
            end, { '-c', 'arp -a' })
            :start()
      end

      local function scanDevices()
        -- Load vendor cache at the start
        loadVendorCache()

        results[1].text = 'Scanning network...'
        results[1].subText = 'Discovering devices on local network'
        actionsLauncher:refresh()

        -- First, get the local IP and network range, then scan all IPs
        hs.task
            .new('/bin/bash', function(exitCode, stdout, stderr)
              if exitCode == 0 then
                local networkPrefix = trim(stdout)
                if networkPrefix ~= '' then
                  -- Scan the network by pinging all IPs in the range
                  -- This will populate the ARP table
                  results[1].text = 'Scanning ' .. networkPrefix .. '.0/24...'
                  results[1].subText = 'This may take a few seconds'
                  actionsLauncher:refresh()

                  hs.task
                      .new('/bin/bash', function(exitCode2, stdout2, stderr2)
                        -- After ping sweep, read the ARP table
                        parseArpTable()
                      end, {
                        '-c',
                        'for i in {1..254}; do ping -c 1 -W 1 ' .. networkPrefix .. '.$i >/dev/null 2>&1 & done; wait',
                      })
                      :start()
                else
                  results = {
                    { text = 'Network detection failed', subText = 'Unable to determine network range', ip = '', mac = '' },
                  }
                  actionsLauncher:refresh()
                end
              else
                results = {
                  { text = 'Network detection failed', subText = 'Unable to determine network range', ip = '', mac = '' },
                }
                actionsLauncher:refresh()
              end
            end, {
              '-c',
              'ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null | awk -F. \'{print $1"."$2"."$3}\'',
            })
            :start()
      end

      actionsLauncher:openChildChooser {
        placeholder = 'Network Devices (↩ copy IP, ⇧↩ copy MAC)',
        parentAction = 'network_connected_devices',
        handler = function(query, launcher)
          return events.buildSearchableChoices(query, results, launcher, {
            handler = function(result)
              return function()
                local shiftHeld = chooserManager.isShiftHeld()
                local copyValue

                if shiftHeld then
                  copyValue = result.mac
                else
                  copyValue = result.ip
                end

                if copyValue and copyValue ~= '' then
                  hs.pasteboard.setContents(copyValue)
                  toast.copied(copyValue)
                end
              end
            end,
            maxResults = 50,
            image = deviceIcon,
          })
        end,
      }

      -- Start scanning after chooser is shown
      hs.timer.doAfter(0.1, scanDevices)
    end,
  },

  {
    id = 'network_speed_test',
    name = 'Speed Test',
    icon = icons.preset.flash,
    description = 'Open speed test in webview',
    handler = function()
      -- Get screen dimensions for sizing the webview
      local screen = hs.screen.mainScreen()
      local screenFrame = screen:frame()

      -- Match ActionsLauncher chooser size (40% width, similar proportions)
      local width = screenFrame.w * 0.4
      local height = screenFrame.h * 0.6
      local x = screenFrame.x + (screenFrame.w - width) / 2
      local y = screenFrame.y + (screenFrame.h - height) / 2

      -- Create user content controller to inject dark mode
      local usercontent = hs.webview.usercontent.new('speedtest')
      usercontent:injectScript({
        source = [[
          (function() {
            var style = document.createElement('style');
            style.textContent = `
              html {
                background-color: #1a1a1a !important;
                filter: invert(1) hue-rotate(180deg);
                overscroll-behavior: none;
              }
              img, video, svg, [style*="background-image"] {
                filter: invert(1) hue-rotate(180deg);
              }
              /* Keep map inverted (dark) by not double-inverting its canvas */
              .maplibregl-map canvas,
              .mapboxgl-map canvas,
              [class*="protomaps"] canvas,
              [class*="map"] canvas {
                filter: none !important;
              }
            `;
            document.documentElement.appendChild(style);
          })();
        ]],
        mainFrame = true,
        injectionTime = 'documentStart',
      })

      local webview = hs.webview
          .new({ x = x, y = y, w = width, h = height }, {}, usercontent)
          :windowStyle({ 'titled', 'closable', 'resizable', 'miniaturizable' })
          :windowTitle('Speed Test')
          :url('https://speed.cloudflare.com/')
          :closeOnEscape(true)
          :allowTextEntry(true)
          :deleteOnClose(true)
          :show()
          :bringToFront(true)
    end,
  },
}
