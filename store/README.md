# Store - Custom Actions

This directory contains custom actions that extend Martillo. All actions in `store/` are **automatically loaded** - just drop a new folder with an `init.lua` file and it's ready to use!

## How It Works

The store auto-loader automatically discovers and loads all action modules in subdirectories. No manual imports needed!

## Structure

Each action should be in its own folder with an `init.lua` file:

```
store/
  f1_standings/     # F1 Drivers Championship (included example)
    init.lua
  my_action/        # Your custom action
    init.lua
    icon.png        # Optional custom icon
```

## Creating a Custom Action

1. Create a new folder with your action name
2. Add an `init.lua` file that returns an action array
3. **That's it!** Use it in your config immediately

### Example: store/f1_standings/init.lua

```lua
-- F1 Drivers Championship Standings
-- Displays current F1 season driver standings from F1 Connect API

local toast = require 'lib.toast'
local events = require 'lib.events'
local icons = require 'lib.icons'

return {
  {
    id = 'f1_standings',
    name = 'F1 Drivers Standings',
    icon = icons.preset.trophy,
    description = 'View current F1 drivers championship standings',
    handler = function()
      local actionsLauncher = spoon.ActionsLauncher
      local standings = {}
      local loading = true

      actionsLauncher:openChildChooser {
        placeholder = 'F1 Drivers Championship (↩ copy driver, ⇧↩ copy team)',
        parentAction = 'f1_standings',
        handler = function(query, launcher)
          local choices = {}

          if loading then
            table.insert(choices, {
              text = 'Loading F1 standings...',
              subText = 'Fetching from F1 Connect API',
              uuid = launcher:generateUUID(),
            })
          else
            for _, entry in ipairs(standings) do
              local uuid = launcher:generateUUID()
              local text = string.format('P%d. %s %s (%s) - %d pts',
                entry.position, entry.driver.name, entry.driver.surname,
                entry.driver.shortName, entry.points)

              table.insert(choices, { text = text, subText = '...', uuid = uuid })

              launcher.handlers[uuid] = events.copyToClipboard(function(choice)
                return string.format('%s %s - P%d - %d points',
                  entry.driver.name, entry.driver.surname,
                  entry.position, entry.points)
              end)
            end
          end

          return choices
        end,
      }

      -- Fetch standings from API
      hs.http.asyncGet('https://f1connectapi.vercel.app/api/current/drivers-championship',
        nil, function(status, body, headers)
          loading = false
          if status == 200 then
            local success, data = pcall(function() return hs.json.decode(body) end)
            if success and data and data.drivers_championship then
              standings = data.drivers_championship
              actionsLauncher:refresh()
            end
          end
        end)
    end,
  },
}
```

Then use it in your config:

```lua
{
  "ActionsLauncher",
  actions = {
    { "f1_standings", alias = "f1" },  -- Automatically available!
  },
}
```

## Action Format

Each action must have:

- `id` - Unique identifier (string)
- `name` - Display name (string)
- `icon` - Absolute path to icon (use `icons.preset.iconName` for built-in icons)
- `description` - What the action does (string)
- `handler` - Function that executes the action (function)

## Available Icons

Use the `icons.preset` API to access built-in 3D icons from [3dicons.co](https://3dicons.co/):

```lua
local icons = require 'lib.icons'

icon = icons.preset.star       -- ✓ Correct
icon = icons.preset.trophy     -- ✓ Correct
icon = icons.preset.message    -- ✓ Correct
```

**Custom Icons:** Place a `.png` file in your action folder. It will automatically override the default icon with the same name.

## Action Events

Use composable helpers from `lib.events.lua` for common patterns:

```lua
local events = require 'lib.events'

-- Copy to clipboard
launcher.handlers[uuid] = events.copyToClipboard(function(choice)
  return "text to copy"
end)

-- Copy + paste with Shift modifier support
launcher.handlers[uuid] = events.copyAndPaste(function(choice)
  return "text to paste"
end)

-- Display-only (no action on Enter)
launcher.handlers[uuid] = events.noAction()

-- Custom logic
launcher.handlers[uuid] = events.custom(function(choice)
  -- Your custom logic here
end)
```

## Tips

- Use `local toast = require 'lib.toast'` for notifications
- Use `local icons = require 'lib.icons'` for icon paths
- Use `local events = require 'lib.events'` for action helpers
- Handle errors gracefully with `pcall`
- For child choosers, see examples in `bundle/` directory
- Child choosers: Simply call `spoon.ActionsLauncher:openChildChooser({...})`
