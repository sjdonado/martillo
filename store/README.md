# Store - Custom Actions

This directory contains external custom actions that can be easily shared and distributed independently of the core Martillo bundles.

## Structure

Each action should be in its own folder with an `init.lua` file:

```
store/
  random_quote/     # Example action (included)
    init.lua
  my_action/        # Your custom actions
    init.lua
```

## Creating a Custom Action

1. Create a new folder with your action name
2. Add an `init.lua` file that returns an action array
3. Load it in your Hammerspoon config

### Example: store/random_quote/init.lua

```lua
-- Random Quote Action
-- Fetches a random inspirational quote from an API

return {
  {
    id = 'random_quote',
    name = 'Random Quote',
    icon = 'message',
    description = 'Get a random inspirational quote',
    handler = function()
      hs.http.asyncGet('https://quotes.domiadi.com/api', nil, function(status, body, headers)
        if status == 200 then
          local success, quote_data = pcall(function()
            return hs.json.decode(body)
          end)

          if success and quote_data then
            local quote_text = quote_data.quote or 'No quote available'
            local author = quote_data.author or 'Unknown'

            hs.dialog.blockAlert(
              'Quote of the Moment',
              string.format('"%s"\n\n— %s', quote_text, author),
              'OK'
            )
          else
            hs.alert.show('❌ Failed to parse quote', _G.MARTILLO_ALERT_DURATION)
          end
        else
          hs.alert.show('❌ Failed to fetch quote', _G.MARTILLO_ALERT_DURATION)
        end
      end)

      hs.alert.show('📡 Fetching quote...', _G.MARTILLO_ALERT_DURATION)
    end,
  },
}
```

## Action Format

Each action must have:

- `id` - Unique identifier (string)
- `name` - Display name (string)
- `icon` - Icon name from `assets/icons/` (string)
- `description` - What the action does (string)
- `handler` - Function that executes the action (function)

Optional fields:

- `isDynamic` - Set to true for actions that open child pickers (boolean)

## Available Icons

See `assets/icons/` directory for available 3D icons from [3dicons.co](https://3dicons.co/).

Common icons: `star`, `rocket`, `message`, `heart`, `clock`, `key`, `lock`, `magic-trick`, `text`, etc.

## Tips

- Use `_G.MARTILLO_ALERT_DURATION` for consistent alert timing
- Handle errors gracefully with `pcall`
- Use `hs.alert.show()` for quick feedback
- Use `hs.dialog.blockAlert()` for longer messages
- For child pickers, see examples in `bundle/` directory
