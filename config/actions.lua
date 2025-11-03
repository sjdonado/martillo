-- Load window management module
local internalPath = os.getenv("HOME") .. "/.martillo/spoons/_internal/?.lua"
if not package.path:find(internalPath, 1, true) then
    package.path = internalPath .. ";" .. package.path
end
local window = require("window")

return {
    static = {
        -- Window Management Actions - Sizing
        {
            id = "window_maximize",
            name = "Maximize Window",
            handler = function() window.moveWindow("max") end,
            description = "Maximize window to full screen",
        },
        {
            id = "window_almost_maximize",
            name = "Almost Maximize",
            handler = function() window.moveWindow("almost_max") end,
            description = "Resize window to 90% of screen, centered",
        },
        {
            id = "window_reasonable_size",
            name = "Reasonable Size",
            handler = function() window.moveWindow("reasonable") end,
            description = "Resize window to reasonable size 70% of screen, centered",
        },
        {
            id = "window_center",
            name = "Center Window",
            handler = function() window.moveWindow("center") end,
            description = "Center window without resizing",
        },

        -- Window Management Actions - Quarters
        {
            id = "window_top_left",
            name = "Window Top Left",
            handler = function() window.moveWindow("top_left") end,
            description = "Position window in top left quarter",
        },
        {
            id = "window_top_right",
            name = "Window Top Right",
            handler = function() window.moveWindow("top_right") end,
            description = "Position window in top right quarter",
        },
        {
            id = "window_bottom_left",
            name = "Window Bottom Left",
            handler = function() window.moveWindow("bottom_left") end,
            description = "Position window in bottom left quarter",
        },
        {
            id = "window_bottom_right",
            name = "Window Bottom Right",
            handler = function() window.moveWindow("bottom_right") end,
            description = "Position window in bottom right quarter",
        },

        -- Window Management Actions - Thirds (Horizontal)
        {
            id = "window_left_third",
            name = "Window Left Third",
            handler = function() window.moveWindow("left_third") end,
            description = "Position window in left third",
        },
        {
            id = "window_center_third",
            name = "Window Center Third",
            handler = function() window.moveWindow("center_third") end,
            description = "Position window in center third",
        },
        {
            id = "window_right_third",
            name = "Window Right Third",
            handler = function() window.moveWindow("right_third") end,
            description = "Position window in right third",
        },
        {
            id = "window_left_two_thirds",
            name = "Window Left Two Thirds",
            handler = function() window.moveWindow("left_two_thirds") end,
            description = "Position window in left two thirds",
        },
        {
            id = "window_right_two_thirds",
            name = "Window Right Two Thirds",
            handler = function() window.moveWindow("right_two_thirds") end,
            description = "Position window in right two thirds",
        },

        -- Window Management Actions - Thirds (Vertical)
        {
            id = "window_top_third",
            name = "Window Top Third",
            handler = function() window.moveWindow("top_third") end,
            description = "Position window in top third",
        },
        {
            id = "window_middle_third",
            name = "Window Middle Third",
            handler = function() window.moveWindow("middle_third") end,
            description = "Position window in middle third",
        },
        {
            id = "window_bottom_third",
            name = "Window Bottom Third",
            handler = function() window.moveWindow("bottom_third") end,
            description = "Position window in bottom third",
        },
        {
            id = "window_top_two_thirds",
            name = "Window Top Two Thirds",
            handler = function() window.moveWindow("top_two_thirds") end,
            description = "Position window in top two thirds",
        },
        {
            id = "window_bottom_two_thirds",
            name = "Window Bottom Two Thirds",
            handler = function() window.moveWindow("bottom_two_thirds") end,
            description = "Position window in bottom two thirds",
        },

        -- System Actions
        {
            id = "toggle_caffeinate",
            name = "Toggle Caffeinate",
            handler = function()
                spoon.ActionsLauncher.executeShell(
                    "if pgrep caffeinate > /dev/null; then pkill caffeinate && echo 'Caffeinate disabled'; else nohup caffeinate -disu > /dev/null 2>&1 & echo 'Caffeinate enabled'; fi",
                    "Toggle Caffeinate")
            end,
            description = "Toggle system sleep prevention",
        },
        {
            id = "toggle_system_appearance",
            name = "Toggle System Appearance",
            handler = function()
                spoon.ActionsLauncher.executeAppleScript([[
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
        ]], "Toggle System Appearance")
            end,
            description = "Toggle between light and dark mode",
        },

        -- Utility Actions
        {
            id = "copy_ip",
            name = "Copy IP",
            handler = function()
                spoon.ActionsLauncher.executeShell(
                    "curl -s ifconfig.me | pbcopy && curl -s ifconfig.me",
                    "Copy IP")
            end,
            description = "Copy public IP address to clipboard",
        },
        {
            id = "generate_uuid",
            name = "Generate UUID",
            handler = function()
                spoon.ActionsLauncher.executeShell(
                    "uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '\\n' | pbcopy && pbpaste",
                    "Generate UUID")
            end,
            description = "Generate UUID v4 and copy to clipboard",
        },
        {
            id = "network_status",
            name = "Network Status",
            handler = function()
                -- Check if we have cached results (fresh for 30 seconds)
                if _G.networkTestCache and _G.networkTestCache.timestamp and
                    (os.time() - _G.networkTestCache.timestamp) < 30 then
                    return false -- Use cached results, expand immediately
                end

                -- Check if test is already running
                if _G.networkTestRunning then
                    return false -- Show loading state
                end

                -- Start new test
                _G.networkTestRunning = true
                _G.networkTestCache = nil -- Clear old cache

                -- Start the actual network test
                local networkTestTask = hs.task.new("/bin/sh", function(exitCode, stdOut, stdErr)
                    _G.networkTestRunning = false

                    local networkTestChoices = {}

                    if exitCode ~= 0 then
                        table.insert(networkTestChoices, {
                            text = "❌ Network Test Failed",
                            subText = "Unable to reach network",
                            uuid = "network_error",
                            handler = function() return "Network test failed" end
                        })
                        table.insert(networkTestChoices, {
                            text = "🔄 Try Again",
                            subText = "Retry the network test",
                            uuid = "network_retry",
                            handler = function()
                                _G.networkTestCache = nil
                                _G.networkTestRunning = false
                                return false
                            end,
                            expandHandler = function()
                                for _, action in ipairs(spoon.ActionsLauncher.singleActions) do
                                    if action.id == "network_status" then
                                        action.handler()
                                        return action.expandHandler()
                                    end
                                end
                                return {}
                            end
                        })
                    else
                        -- Parse ping result
                        local pingLatency = "Unable to measure"
                        local pingLine = stdOut:match(
                            "round%-trip min/avg/max/stddev = [%d%.]+/([%d%.]+)/[%d%.]+/[%d%.]+ ms")
                        if pingLine then
                            pingLatency = string.format("%.1f ms", tonumber(pingLine))
                        end

                        -- Get connection status
                        local status = pingLatency ~= "Unable to measure" and "✅ Connected" or "❌ Disconnected"

                        -- Create result items
                        table.insert(networkTestChoices, {
                            text = "Network Status",
                            subText = status,
                            uuid = "network_status_result",
                            handler = function() return status end
                        })

                        table.insert(networkTestChoices, {
                            text = "Latency",
                            subText = pingLatency,
                            uuid = "network_ping_result",
                            handler = function() return "Latency: " .. pingLatency end
                        })

                        table.insert(networkTestChoices, {
                            text = "Run Again",
                            subText = "Check network status again",
                            uuid = "network_rerun",
                            handler = function()
                                _G.networkTestCache = nil
                                _G.networkTestRunning = false
                                return false
                            end,
                            expandHandler = function()
                                for _, action in ipairs(spoon.ActionsLauncher.singleActions) do
                                    if action.id == "network_status" then
                                        action.handler()
                                        return action.expandHandler()
                                    end
                                end
                                return {}
                            end
                        })
                    end

                    -- Cache results
                    _G.networkTestCache = {
                        results = networkTestChoices,
                        timestamp = os.time()
                    }

                    -- Refresh the chooser if it's expanded and visible
                    spoon.ActionsLauncher:refreshExpandedChoices()
                end, { "-c", "ping -c 3 -W 2000 1.1.1.1" })

                networkTestTask:start()
                return false -- Expand to show loading state
            end,
            expandHandler = function()
                -- Check if we have cached results
                if _G.networkTestCache and _G.networkTestCache.timestamp and
                    (os.time() - _G.networkTestCache.timestamp) < 30 then
                    return spoon.ActionsLauncher:addBackOption(_G.networkTestCache.results)
                end

                -- Show loading state
                local loadingChoices = {
                    {
                        text = "⏳ Loading...",
                        subText = "Checking network status, please wait...",
                        uuid = "network_loading",
                        handler = function() return "" end
                    }
                }

                return spoon.ActionsLauncher:addBackOption(loadingChoices)
            end,
            description = "Check network connectivity and status",
        },
    },

    dynamic = {
        {
            id = "timestamp",
            enabled = true,
            pattern = function(query)
                return string.match(query, "^%d+$") and
                    (string.len(query) == 10 or string.len(query) == 13)
            end,
            handler = function(query, context)
                local timestamp = tonumber(query)
                if timestamp then
                    -- Convert to seconds if it's milliseconds
                    if string.len(query) == 13 then
                        timestamp = timestamp / 1000
                    end

                    local isoString = os.date("!%Y-%m-%dT%H:%M:%SZ", timestamp)
                    local uuid = context.generateUUID()

                    table.insert(context.dynamicChoices, {
                        text = "Unix Timestamp → ISO String",
                        subText = isoString,
                        uuid = uuid,
                        copyToClipboard = true
                    })

                    context.callbacks[uuid] = function()
                        return isoString
                    end
                end
            end
        },

        {
            id = "base64",
            enabled = true,
            pattern = function(query)
                return string.match(query, "^[A-Za-z0-9+/]*={0,2}$") and string.len(query) >= 4 and
                    string.len(query) % 4 == 0
            end,
            handler = function(query, context)
                local success, decoded = pcall(function()
                    return hs.base64.decode(query)
                end)

                if success and decoded and decoded ~= "" then
                    local uuid = context.generateUUID()
                    table.insert(context.dynamicChoices, {
                        text = "Base64 → Plain Text",
                        subText = decoded,
                        uuid = uuid,
                        copyToClipboard = true
                    })

                    context.callbacks[uuid] = function()
                        return decoded
                    end
                end
            end
        },

        {
            id = "jwt",
            enabled = true,
            pattern = function(query)
                local jwtParts = {}
                for part in string.gmatch(query, "[^%.]+") do
                    table.insert(jwtParts, part)
                end
                return #jwtParts == 3
            end,
            handler = function(query, context)
                local jwtParts = {}
                for part in string.gmatch(query, "[^%.]+") do
                    table.insert(jwtParts, part)
                end

                -- Helper function to decode JWT part
                local function decodeJWTPart(part)
                    local paddedPart = part:gsub("-", "+"):gsub("_", "/")
                    local padding = 4 - (string.len(paddedPart) % 4)
                    if padding < 4 then
                        paddedPart = paddedPart .. string.rep("=", padding)
                    end
                    return hs.base64.decode(paddedPart)
                end

                -- Decode header and payload
                local headerSuccess, header = pcall(decodeJWTPart, jwtParts[1])
                local payloadSuccess, payload = pcall(decodeJWTPart, jwtParts[2])

                -- Add header option if successful
                if headerSuccess and header and header ~= "" then
                    local headerUuid = context.generateUUID()
                    table.insert(context.dynamicChoices, {
                        text = "JWT → Decoded Header",
                        subText = header,
                        uuid = headerUuid,
                        copyToClipboard = true
                    })

                    context.callbacks[headerUuid] = function()
                        return header
                    end
                end

                -- Add payload option if successful
                if payloadSuccess and payload and payload ~= "" then
                    local payloadUuid = context.generateUUID()
                    table.insert(context.dynamicChoices, {
                        text = "JWT → Decoded Payload",
                        subText = payload,
                        uuid = payloadUuid,
                        copyToClipboard = true
                    })

                    context.callbacks[payloadUuid] = function()
                        return payload
                    end
                end
            end
        },

        {
            id = "colors",
            enabled = true,
            pattern = function(query)
                -- Check for RGB format: rgb(255,128,64) or 255,128,64
                local r, g, b = string.match(query, "rgb%s*%((%d+)%s*,%s*(%d+)%s*,%s*(%d+)%)")
                if r and g and b then return true end

                r, g, b = string.match(query, "^(%d+)%s*,%s*(%d+)%s*,%s*(%d+)$")
                if r and g and b then return true end

                -- Check for HEX format: #ff8040 or ff8040
                local hex = string.match(query,
                    "^#?([a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9])$")
                return hex ~= nil
            end,
            handler = function(query, context)
                -- Handle RGB to HEX conversion
                local r, g, b = string.match(query, "rgb%s*%((%d+)%s*,%s*(%d+)%s*,%s*(%d+)%)")
                if not r then
                    r, g, b = string.match(query, "^(%d+)%s*,%s*(%d+)%s*,%s*(%d+)$")
                end

                if r and g and b then
                    r, g, b = tonumber(r), tonumber(g), tonumber(b)
                    if r and g and b and r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255 then
                        local hex = string.format("#%02x%02x%02x", r, g, b)
                        local uuid = context.generateUUID()

                        table.insert(context.dynamicChoices, {
                            text = "RGB → HEX",
                            subText = hex,
                            uuid = uuid,
                            copyToClipboard = true,
                            image = context.createColorSwatch(r, g, b)
                        })

                        context.callbacks[uuid] = function()
                            return hex
                        end
                    end
                    return
                end

                -- Handle HEX to RGB conversion
                local hex = string.match(query,
                    "^#?([a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9])$")
                if hex then
                    local rHex = string.sub(hex, 1, 2)
                    local gHex = string.sub(hex, 3, 4)
                    local bHex = string.sub(hex, 5, 6)

                    local r = tonumber(rHex, 16)
                    local g = tonumber(gHex, 16)
                    local b = tonumber(bHex, 16)

                    if r and g and b then
                        local rgb = string.format("rgb(%d, %d, %d)", r, g, b)
                        local uuid = context.generateUUID()

                        table.insert(context.dynamicChoices, {
                            text = "HEX → RGB",
                            subText = rgb,
                            uuid = uuid,
                            copyToClipboard = true,
                            image = context.createColorSwatch(r, g, b)
                        })

                        context.callbacks[uuid] = function()
                            return rgb
                        end
                    end
                end
            end
        }
    }
}
