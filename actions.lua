package.path = package.path .. ";" .. os.getenv("HOME") .. "/.martillo/?.lua"

local window = require("lib.window")

return {
	-- Window Management Actions - Sizing
	{
		id = "window_maximize",
		name = "Maximize Window",
		handler = function()
			window.moveWindow("max")
		end,
		description = "Maximize window to full screen",
	},
	{
		id = "window_almost_maximize",
		name = "Almost Maximize",
		handler = function()
			window.moveWindow("almost_max")
		end,
		description = "Resize window to 90% of screen, centered",
	},
	{
		id = "window_reasonable_size",
		name = "Reasonable Size",
		handler = function()
			window.moveWindow("reasonable")
		end,
		description = "Resize window to reasonable size 70% of screen, centered",
	},
	{
		id = "window_center",
		name = "Center Window",
		handler = function()
			window.moveWindow("center")
		end,
		description = "Center window without resizing",
	},

	-- Window Management Actions - Quarters
	{
		id = "window_top_left",
		name = "Window Top Left",
		handler = function()
			window.moveWindow("top_left")
		end,
		description = "Position window in top left quarter",
	},
	{
		id = "window_top_right",
		name = "Window Top Right",
		handler = function()
			window.moveWindow("top_right")
		end,
		description = "Position window in top right quarter",
	},
	{
		id = "window_bottom_left",
		name = "Window Bottom Left",
		handler = function()
			window.moveWindow("bottom_left")
		end,
		description = "Position window in bottom left quarter",
	},
	{
		id = "window_bottom_right",
		name = "Window Bottom Right",
		handler = function()
			window.moveWindow("bottom_right")
		end,
		description = "Position window in bottom right quarter",
	},

	-- Window Management Actions - Thirds (Horizontal)
	{
		id = "window_left_third",
		name = "Window Left Third",
		handler = function()
			window.moveWindow("left_third")
		end,
		description = "Position window in left third",
	},
	{
		id = "window_center_third",
		name = "Window Center Third",
		handler = function()
			window.moveWindow("center_third")
		end,
		description = "Position window in center third",
	},
	{
		id = "window_right_third",
		name = "Window Right Third",
		handler = function()
			window.moveWindow("right_third")
		end,
		description = "Position window in right third",
	},
	{
		id = "window_left_two_thirds",
		name = "Window Left Two Thirds",
		handler = function()
			window.moveWindow("left_two_thirds")
		end,
		description = "Position window in left two thirds",
	},
	{
		id = "window_right_two_thirds",
		name = "Window Right Two Thirds",
		handler = function()
			window.moveWindow("right_two_thirds")
		end,
		description = "Position window in right two thirds",
	},

	-- Window Management Actions - Thirds (Vertical)
	{
		id = "window_top_third",
		name = "Window Top Third",
		handler = function()
			window.moveWindow("top_third")
		end,
		description = "Position window in top third",
	},
	{
		id = "window_middle_third",
		name = "Window Middle Third",
		handler = function()
			window.moveWindow("middle_third")
		end,
		description = "Position window in middle third",
	},
	{
		id = "window_bottom_third",
		name = "Window Bottom Third",
		handler = function()
			window.moveWindow("bottom_third")
		end,
		description = "Position window in bottom third",
	},
	{
		id = "window_top_two_thirds",
		name = "Window Top Two Thirds",
		handler = function()
			window.moveWindow("top_two_thirds")
		end,
		description = "Position window in top two thirds",
	},
	{
		id = "window_bottom_two_thirds",
		name = "Window Bottom Two Thirds",
		handler = function()
			window.moveWindow("bottom_two_thirds")
		end,
		description = "Position window in bottom two thirds",
	},

	-- System Actions
	{
		id = "toggle_caffeinate",
		name = "Toggle Caffeinate",
		handler = function()
			spoon.ActionsLauncher.executeShell(
				"if pgrep caffeinate > /dev/null; then pkill caffeinate && echo 'Caffeinate disabled'; else nohup caffeinate -disu > /dev/null 2>&1 & echo 'Caffeinate enabled'; fi",
				"Toggle Caffeinate"
			)
		end,
		description = "Toggle system sleep prevention",
	},
	{
		id = "toggle_system_appearance",
		name = "Toggle System Appearance",
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
				"Toggle System Appearance"
			)
		end,
		description = "Toggle between light and dark mode",
	},

	-- Utility Actions
	{
		id = "copy_ip",
		name = "Copy IP",
		handler = function()
			spoon.ActionsLauncher.executeShell("curl -s ifconfig.me | pbcopy && curl -s ifconfig.me", "Copy IP")
		end,
		description = "Copy public IP address to clipboard",
	},
	{
		id = "generate_uuid",
		name = "Generate UUID",
		handler = function()
			spoon.ActionsLauncher.executeShell(
				"uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '\\n' | pbcopy && pbpaste",
				"Generate UUID"
			)
		end,
		description = "Generate UUID v4 and copy to clipboard",
	},
	{
		id = "network_status",
		name = "Network Status",
		description = "Check network connectivity and status",
		handler = function()
			-- Simple alert for now - network testing with child picker needs more work
			hs.alert.show("Running network test...")

			-- Run network test
			local task = hs.task.new("/bin/sh", function(exitCode, stdOut, stdErr)
				if exitCode == 0 then
					local pingLine = stdOut:match("round%-trip min/avg/max/stddev = [%d%.]+/([%d%.]+)/[%d%.]+/[%d%.]+ ms")
					if pingLine then
						local latency = string.format("%.1f ms", tonumber(pingLine))
						hs.alert.show("✅ Connected - Latency: " .. latency)
					else
						hs.alert.show("✅ Connected")
					end
				else
					hs.alert.show("❌ Network test failed")
				end
			end, { "-c", "ping -c 3 -W 2000 1.1.1.1" })

			task:start()
		end,
	},
	{
		id = "timestamp",
		name = "Timestamp Converter",
		description = "Convert unix timestamp to date",
		isDynamic = true,
		handler = function()
			spoon.ActionsLauncher:openChildPicker({
				placeholder = "Enter unix timestamp...",
				parentAction = "timestamp",
				handler = function(query, launcher)
					if not query or query == "" then
						return {}
					end

					local timestamp = tonumber(query)
					if not timestamp then
						return {
							{
								text = "Invalid timestamp",
								subText = "Enter a valid unix timestamp (10 or 13 digits)",
								uuid = launcher:generateUUID(),
							},
						}
					end

					-- Convert to seconds if it's milliseconds
					if string.len(query) == 13 then
						timestamp = timestamp / 1000
					end

					local date = os.date("%Y-%m-%d %H:%M:%S", timestamp)
					local relativeTime = os.time() - timestamp
					local uuid = launcher:generateUUID()

					launcher.handlers[uuid] = function()
						return date;
					end

					return {
						{
							text = date,
							subText = string.format("%.0f seconds ago", relativeTime),
							uuid = uuid,
							copyToClipboard = true,
						},
					}
				end,
			})
			return "OPEN_CHILD_PICKER"
		end,
	},

	{
		id = "base64",
		name = "Base64 Encoder/Decoder",
		description = "Encode or decode base64",
		isDynamic = true,
		handler = function()
			spoon.ActionsLauncher:openChildPicker({
				placeholder = "Enter text to encode/decode...",
				parentAction = "base64",
				handler = function(query, launcher)
					if not query or query == "" then
						return {}
					end

					local results = {}

					-- Try to encode
					local encoded = hs.base64.encode(query)
					local encodeUuid = launcher:generateUUID()
					launcher.handlers[encodeUuid] = function()
						return encoded
					end

					table.insert(results, {
						text = encoded,
						subText = "Base64 Encoded",
						uuid = encodeUuid,
						copyToClipboard = true,
					})

					-- Try to decode
					local success, decoded = pcall(function()
						return hs.base64.decode(query)
					end)

					if success and decoded then
						local decodeUuid = launcher:generateUUID()
						launcher.handlers[decodeUuid] = function()
							return decoded
						end

						table.insert(results, {
							text = decoded,
							subText = "Base64 Decoded",
							uuid = decodeUuid,
							copyToClipboard = true,
						})
					end

					return results
				end,
			})
			return "OPEN_CHILD_PICKER"
		end,
	},

	{
		id = "jwt",
		name = "JWT Decoder",
		description = "Decode JWT token",
		isDynamic = true,
		handler = function()
			spoon.ActionsLauncher:openChildPicker({
				placeholder = "Paste JWT token...",
				parentAction = "jwt",
				handler = function(query, launcher)
					if not query or query == "" then
						return {}
					end

					local parts = {}
					for part in query:gmatch("[^.]+") do
						table.insert(parts, part)
					end

					if #parts ~= 3 then
						return {
							{
								text = "Invalid JWT",
								subText = "JWT must have 3 parts separated by dots",
								uuid = launcher:generateUUID(),
							},
						}
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

					local results = {}

					-- Decode header
					local headerSuccess, header = pcall(decodeJWTPart, parts[1])
					if headerSuccess and header then
						local headerUuid = launcher:generateUUID()
						launcher.handlers[headerUuid] = function()
							return header
						end

						table.insert(results, {
							text = header,
							subText = "JWT Header",
							uuid = headerUuid,
							copyToClipboard = true,
						})
					end

					-- Decode payload
					local payloadSuccess, payload = pcall(decodeJWTPart, parts[2])
					if payloadSuccess and payload then
						local payloadUuid = launcher:generateUUID()
						launcher.handlers[payloadUuid] = function()
							return payoad
						end

						table.insert(results, {
							text = payload,
							subText = "JWT Payload",
							uuid = payloadUuid,
							copyToClipboard = true,
						})
					end

					if #results == 0 then
						return {
							{
								text = "Failed to decode JWT",
								subText = "Invalid base64 encoding",
								uuid = launcher:generateUUID(),
							},
						}
					end

					return results
				end,
			})
			return "OPEN_CHILD_PICKER"
		end,
	},

	{
		id = "colors",
		name = "Color Converter",
		description = "Convert between color formats (hex, rgb)",
		isDynamic = true,
		handler = function()
			spoon.ActionsLauncher:openChildPicker({
				placeholder = "Enter color (hex or rgb)...",
				parentAction = "colors",
				handler = function(query, launcher)
					if not query or query == "" then
						return {}
					end

					local results = {}

					-- Try to parse as hex color (#RRGGBB or RRGGBB)
					local hex = query:match("^#?([%x][%x][%x][%x][%x][%x])$")
					if hex then
						local r = tonumber(hex:sub(1, 2), 16)
						local g = tonumber(hex:sub(3, 4), 16)
						local b = tonumber(hex:sub(5, 6), 16)

						-- RGB result
						local rgbUuid = launcher:generateUUID()
						launcher.handlers[rgbUuid] = function()
							return string.format("rgb(%d, %d, %d)", r, g, b)
						end

						table.insert(results, {
							text = string.format("rgb(%d, %d, %d)", r, g, b),
							subText = "RGB format",
							uuid = rgbUuid,
							image = launcher:createColorSwatch(r, g, b),
							copyToClipboard = true,
						})
					end

					-- Try to parse as RGB (rgb(r, g, b))
					local r, g, b = query:match("rgb%s*%((%d+)%s*,%s*(%d+)%s*,%s*(%d+)%)")
					if r and g and b then
						r, g, b = tonumber(r), tonumber(g), tonumber(b)

						-- Hex result
						local hexUuid = launcher:generateUUID()
						launcher.handlers[hexUuid] = function()
							return string.format("#%02X%02X%02X", r, g, b)
						end

						table.insert(results, {
							text = string.format("#%02X%02X%02X", r, g, b),
							subText = "Hex format",
							uuid = hexUuid,
							image = launcher:createColorSwatch(r, g, b),
							copyToClipboard = true,
						})
					end

					if #results == 0 then
						return {
							{
								text = "Invalid color format",
								subText = "Try: #FF5733 or rgb(255, 87, 51)",
								uuid = launcher:generateUUID(),
							},
						}
					end

					return results
				end,
			})
			return "OPEN_CHILD_PICKER"
		end,
	},
}
