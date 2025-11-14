# 🔨 Martillo

**Build anything you can imagine and launch it with a keystroke.** Martillo is a powerful actions launcher for macOS powered by [Hammerspoon](https://www.hammerspoon.org/). Create custom actions, automate repetitive tasks, and access everything through a command palette with fuzzy search.

**Your productivity hub, your way.** An open-source alternative to Raycast and Alfred with no vendor lock-in, zero dependencies, and full configuration through a single Lua file. Write your own actions, use ready-made bundles, customize every keybinding, add aliases for lightning-fast access, and share your creations freely. All configuration lives in a single file, inspired by [lazy.nvim](https://github.com/folke/lazy.nvim)'s declarative plugin system.

https://github.com/user-attachments/assets/d5c803a9-7d83-479a-946b-80f29a2f09bf

## Features

**Core Capabilities:**
- ⚡ **Fast & Lightweight**: Pure Lua, zero dependencies, no compilation needed
- 🎯 **Command Palette**: Searchable actions with fuzzy search
- 🚀 **App Launcher**: Quick switching between apps with single hotkey
- 🌐 **Browser Routing**: Smart URL routing to different browsers based on patterns
- 🔄 **Auto-Open on Load**: ActionsLauncher opens automatically when Hammerspoon loads

**Window Management** - Complete keyboard-driven positioning:
- Maximize, Almost Maximize (90%), Reasonable Size (70%), Center
- Halves (left, right, top, bottom)
- Quarters (all four corners)
- Thirds (horizontal and vertical, including two-thirds combinations)

**Clipboard History** - Never lose copied content:
- Persistent clipboard with fuzzy search
- Support for text, images, and files with file size and line count display
- Enter to paste, Shift+Enter to copy only

**Process Killer** - Manage running processes:
- Fuzzy search through running processes with app icons
- Shows memory and CPU usage
- Enter to kill, Shift+Enter to copy PID

**Smart Converters** - Live transformation with visual previews:
- ⏰ Time Converter (Unix ↔ ISO ↔ Relative)
- 🎨 Color Converter (HEX ↔ RGB with color preview)
- 🔐 Base64 (Encode/decode)
- 🔑 JWT Decoder

**System Information** - Real-time system monitoring:
- CPU usage and load average
- Memory usage and pressure
- Battery/Power status
- Network upload/download speeds
- Auto-refreshing every 2 seconds

**Keyboard Actions:**
- 🔒 Lock Keyboard (for cleaning, unlock with `<leader>+Enter`)
- ⏰ Keep-Alive (simulate activity to keep screen active)

**Text Utilities:**
- 📊 Word Count (characters, words, sentences, paragraphs with real-time updates)
- 🔑 Generate UUID

**Network Utilities:**
- 🌐 IP Geolocation
- 📡 Network Speed Test

**Screen Effects:**
- 🎉 Confetti animation
- 📏 Screen ruler

**Utilities:**
- ☕ Toggle Caffeinate (prevent sleep)
- 🌓 Toggle Dark/Light Mode

**Browser Management:**
- 🔗 Safari tab switcher

**Calendar Integration:**
- 📅 Today's events in menu bar with countdown timers
- Clickable meeting URLs for quick joining


## Quick Start

```bash
# Install Hammerspoon
brew install --cask hammerspoon

# Clone Martillo
git clone https://github.com/sjdonado/martillo ~/.martillo

# Create configuration
cat > ~/.hammerspoon/init.lua << 'EOF'
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.martillo/?.lua"

return require("martillo").setup({
    leader_key = { "alt", "ctrl" },

    {
        "ActionsLauncher",
        actions = {
            { "toggle_system_appearance", alias = "ta" },
            { "toggle_caffeinate",        alias = "tc" },
            { "system_information",       alias = "si" },
            { "screen_ruler",             alias = "ru" },

            { "window_maximize",          alias = "wm" },
            { "window_almost_maximize",   keys = { { "<leader>", "up" } } },
            { "window_reasonable_size",   keys = { { "<leader>", "down" } } },
            { "window_center",            keys = { { "<leader>", "return" } } },
            { "window_left_two_thirds",   keys = { { "<leader>", "left" } } },
            { "window_right_two_thirds",  keys = { { "<leader>", "right" } } },

            { "clipboard_history",        keys = { { "<leader>", "-" } } },
            { "kill_process",             keys = { { "<leader>", "=" } } },
            { "safari_tabs",              keys = { { "alt", "tab" } } },

            { "generate_uuid",            alias = "gu" },
            { "word_count",               alias = "wc" },

            { "converter_time",           alias = "ct" },
            { "converter_colors",         alias = "cc" },
            { "converter_base64",         alias = "cb" },
            { "converter_jwt",            alias = "cj" },

            { "network_ip_geolocation",   alias = "ni" },
            { "network_speed_test",       alias = "ns" },

            { "keyboard_lock",            alias = "kl" },
            { "keyboard_keep_alive",      alias = "ka" },

            { "screen_confetti",          alias = "cf" },
            { "f1_standings",             alias = "f1" },

            { "martillo_reload",          alias = "mr" },
            { "martillo_update",          alias = "mu" },
        },
        keys = {
            { "<leader>", "space", desc = "Toggle Actions Launcher" },
        },
    },

    {
        "LaunchOrToggleFocus",
        keys = {
            { "<leader>", "c", app = "Calendar" },
            { "<leader>", "f", app = "Finder" },
            { "<leader>", ";", app = "Ghostty" },
            { "<leader>", "h", app = "Helium" },
            { "<leader>", "l", app = "Music" },
            { "<leader>", "e", app = "Mail" },
            { "<leader>", "m", app = "Messages" },
            { "<leader>", "n", app = "Notes" },
            { "<leader>", "p", app = "Passwords" },
            { "<leader>", "r", app = "Reminders" },
            { "<leader>", "b", app = "Safari" },
            { "<leader>", "s", app = "Slack" },
            { "<leader>", "t", app = "Kagi Translate" },
            { "<leader>", "y", app = "Yaak" },
        },
    },

    {
        "MySchedule",
        config = function(spoon)
            spoon:compile()
            spoon:start()
        end,
    },

    {
        "BrowserRedirect",
        opts = {
            default_app = "Safari",
            redirect = {
                { match = { "*localhost*", "*127.0.0.1*", "*0.0.0.0*" }, app = "Helium" },
                { match = { "*fly.dev*" },                               app = "Helium" },
                { match = { "*meet.google*" },                           app = "Helium" },
            },
        },
        config = function(spoon)
            spoon:start()
        end,
    },
})
EOF

# Reload Hammerspoon
```

## Configuration

### Global Options

```lua
return require("martillo").setup({
  -- Global configuration
  leader_key = { "alt", "ctrl" },      -- Expand <leader> in keybindings
  alertDuration = 1,                    -- Alert duration in seconds

  -- Spoons go here...
})
```

### Leader Key

Use `<leader>` as a placeholder in any keybinding. It expands to your configured `leader_key`:

```lua
{ "<leader>", "space" }           -- Expands to { "alt", "ctrl", "space" }
{ { "<leader>", "cmd" }, "p" }    -- Expands to { "alt", "ctrl", "cmd", "p" }
```

### ActionsLauncher

The central command palette with all your actions. Martillo automatically loads all built-in bundles and store actions:

```lua
{
  "ActionsLauncher",
  actions = {
    -- Assign keybindings and aliases to specific actions
    { "window_center", keys = { { "<leader>", "return" } } },
    { "toggle_caffeinate", alias = "tc" },
    { "clipboard_history", keys = { { "<leader>", "v" } } },
    { "f1_standings", alias = "f1" },  -- From store/
  },
  keys = {
    { "<leader>", "space", desc = "Toggle Actions Launcher" }
  }
}
```

**Action Fields:**
- `keys` - Keybindings for direct access
- `alias` - Short name for faster fuzzy search
- `desc` - Optional description for the keybinding

**Note:** All bundles from `bundle/` and custom actions from `store/` are automatically loaded. You don't need to manually import them!

### Available Action Bundles

- `bundle.window` - Window positioning (halves, quarters, thirds, maximize, center) - 25 actions total
- `bundle.system` - System management (caffeinate, dark mode, system information)
- `bundle.utilities` - Text utilities (UUID generation, word count)
- `bundle.converter` - Converters (time, colors, base64, JWT)
- `bundle.keyboard` - Keyboard actions (lock, keep-alive)
- `bundle.clipboard_history` - Clipboard manager with history
- `bundle.kill_process` - Process killer with fuzzy search
- `bundle.network` - Network utilities (IP geolocation, speed test)
- `bundle.safari_tabs` - Safari tab switcher
- `bundle.screen` - Screen effects (confetti, ruler)
- `bundle.martillo` - Martillo management (reload, update)

### Custom Actions from Store

The `store/` directory is for custom actions that extend Martillo. All actions in `store/` are **automatically loaded** - just drop a new folder with an `init.lua` file and it's ready to use!

**Example Store Structure:**
```
store/
  f1_standings/
    init.lua        # F1 Drivers Championship standings (included example)
  my_action/
    init.lua        # Your custom action module
    icon.png        # Optional custom icon (overrides default icons)
```

Each action module should return an array of actions, just like bundles. Custom icons placed in store folders will override default icons with the same name.

See [store/README.md](store/README.md) for details on creating custom actions.


### LaunchOrToggleFocus

Quick app switching with single hotkeys:

```lua
{
  "LaunchOrToggleFocus",
  keys = {
    { "<leader>", "b", app = "Safari" },
    { "<leader>", ";", app = "Ghostty" },
    { "<leader>", "c", app = "Calendar" },
    { "<leader>", "e", app = "Mail" },
  }
}
```

### MySchedule

Calendar integration in menu bar:

```lua
{
  "MySchedule",
  config = function(spoon)
    spoon:compile()
    spoon:start()
  end
}
```

### BrowserRedirect

Smart URL routing to different browsers:

```lua
{
  "BrowserRedirect",
  opts = {
    default_app = "Safari",
    redirect = {
      { match = { "*localhost*", "*127.0.0.1*" }, app = "Chromium" },
      { match = { "*meet.google*" }, app = "Google Meet" },
    },
    mapper = {
      {
        name = "googleToKagi",
        from = "*google.com*/search*",
        to = "https://kagi.com/search?q={query.q|encode}"
      }
    }
  },
  config = function(spoon)
    spoon:start()
  end
}
```


## Navigation

### Main Launcher (ActionsLauncher)
- **Search**: Type to fuzzy search actions and aliases
- **Enter**: Execute selected action
- **ESC**: Close launcher
- **Shift+ESC**: Close all pickers

### Child Pickers (Clipboard, Converters, etc.)
- **Type**: Filter results in real-time
- **Enter**: Execute action (paste, convert, etc.)
- **Shift+Enter**: Alternate action (copy only, etc.)
- **DELETE/ESC** (empty query): Navigate back to parent
- **Shift+ESC**: Close all pickers


## Creating Custom Actions

### Bundle Structure (Core Actions)

Create a new file in the `bundle/` directory for core actions:

```lua
-- bundle/my_custom_bundle.lua
-- My Custom Actions Bundle

local icons = require 'lib.icons'
local actions = require 'lib.actions'

return {
  {
    id = 'my_action',
    name = 'My Action',
    icon = icons.preset.star,
    description = 'Does something awesome',
    handler = function()
      hs.alert.show('Hello from my action!')
    end,
  },
}
```

### Store Structure (Custom/External Actions)

Create a new folder in `store/` with an `init.lua` file for custom actions:

```lua
-- store/my_action/init.lua
local icons = require 'lib.icons'
local actions = require 'lib.actions'

return {
  {
    id = 'my_store_action',
    name = 'My Store Action',
    icon = icons.preset.message,
    description = 'Custom action from store',
    handler = function()
      -- Your action logic here
    end,
  },
}
```

**That's it!** The store auto-loader will automatically discover and load your action. No need to manually import it - just drop a new folder in `store/` and use it in your config:

```lua
{
  "ActionsLauncher",
  actions = {
    { "my_store_action", alias = "ma" },  -- Automatically available!
  },
}
```


## Contributing

Contributions welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

## Acknowledgments

- [Raycast](https://www.raycast.com/) - Inspiration for the launcher UX and workflow philosophy
- [Hammerspoon](https://www.hammerspoon.org/) - The powerful macOS automation tool that makes this possible
- [lazy.nvim](https://github.com/folke/lazy.nvim) - Inspiration for declarative config style
- [3dicons.co](https://3dicons.co/) - Beautiful 3D icon collection

