-- Utilities Actions Bundle
-- System utilities and helper tools

return {
  -- System Actions
  {
    id = 'toggle_caffeinate',
    name = 'Toggle Caffeinate',
    handler = function()
      spoon.ActionsLauncher.executeShell(
        "if pgrep caffeinate > /dev/null; then pkill caffeinate && echo 'Caffeinate disabled'; else nohup caffeinate -disu > /dev/null 2>&1 & echo 'Caffeinate enabled'; fi",
        'Toggle Caffeinate'
      )
    end,
    description = 'Toggle system sleep prevention',
  },
  {
    id = 'toggle_system_appearance',
    name = 'Toggle System Appearance',
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
    description = 'Toggle between light and dark mode',
  },
  -- Utility Actions
  {
    id = 'generate_uuid',
    name = 'Generate UUID',
    handler = function()
      spoon.ActionsLauncher.executeShell("uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '\\n' | pbcopy && pbpaste", 'Generate UUID')
    end,
    description = 'Generate UUID v4 and copy to clipboard',
  },
}
