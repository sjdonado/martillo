-- Utilities Actions Bundle
-- System utilities and helper actions

return {
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
}
