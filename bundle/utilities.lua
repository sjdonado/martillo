-- Utilities Actions Bundle
-- System utilities and helper tools

return {
  -- System Actions
  {
    id = 'toggle_caffeinate',
    name = 'Toggle Caffeinate',
    icon = 'tea-cup',
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
    icon = 'sun',
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
  -- Utility Actions
  {
    id = 'generate_uuid',
    name = 'Generate UUID',
    icon = 'key',
    description = 'Generate UUID v4 and copy to clipboard',
    handler = function()
      spoon.ActionsLauncher.executeShell("uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '\\n' | pbcopy && pbpaste",
        'Generate UUID', true)
    end,
  },
}
