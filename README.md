# 🔨 Martillo

**Build anything you can imagine and launch it with a keystroke.** Martillo is a powerful, declarative actions launcher for macOS powered by [Hammerspoon](https://www.hammerspoon.org/). Create custom workflows, automate repetitive tasks, and access everything through a beautiful command palette with fuzzy search.

**Your productivity hub, your way.** Think Raycast, but completely open-source with no vendor lock-in. Write your own actions in Lua, use ready-made bundles, customize every keybinding, add aliases for lightning-fast access, and share your creations freely. All configuration lives in a single file, inspired by [lazy.nvim](https://github.com/folke/lazy.nvim)'s elegant plugin system.

## Features

**Core Capabilities:**
- ⚡ **Fast & Lightweight**: Pure Lua, zero dependencies, no compilation needed
- 🎯 **Command Palette**: Searchable actions with fuzzy search and beautiful 3D icons
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
- Beautiful 3D icons for different file types
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
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.martillo/?/init.lua"

return require("martillo").setup({
    leader_key = { "alt", "ctrl" },

    {
        "ActionsLauncher",
        opts = function()
            local window = require("bundle.window")
            local system = require("bundle.system")
            local utilities = require("bundle.utilities")
            local converter = require("bundle.converter")
            local screen = require("bundle.screen")
            local keyboard = require("bundle.keyboard")
            local network = require("bundle.network")
            local clipboard = require("bundle.clipboard_history")
            local kill_process = require("bundle.kill_process")
            local safari_tabs = require("bundle.safari_tabs")
            local martillo = require("bundle.martillo")

            return {
                actions = {
                    window,
                    system,
                    utilities,
                    converter,
                    screen,
                    keyboard,
                    network,
                    clipboard,
                    kill_process,
                    safari_tabs,
                    martillo,
                },
            }
        end,
        actions = {
            { "toggle_system_appearance", alias = "ta" },
            { "toggle_caffeinate", alias = "tc" },
            { "system_information", alias = "si" },
            { "screen_ruler", alias = "ru" },

            { "window_maximize", alias = "wm" },
            { "window_almost_maximize", keys = { { "<leader>", "up" } } },
            { "window_reasonable_size", keys = { { "<leader>", "down" } } },
            { "window_center", keys = { { "<leader>", "return" } } },
            { "window_left_two_thirds", keys = { { "<leader>", "left" } } },
            { "window_right_two_thirds", keys = { { "<leader>", "right" } } },

            { "clipboard_history", keys = { { "<leader>", "-" } } },
            { "kill_process", keys = { { "<leader>", "=" } } },
            { "safari_tabs", keys = { { "alt", "tab" } } },

            { "generate_uuid", alias = "gu" },
            { "word_count", alias = "wc" },

            { "converter_time", alias = "ct" },
            { "converter_colors", alias = "cc" },
            { "converter_base64", alias = "cb" },
            { "converter_jwt", alias = "cj" },

            { "network_ip_geolocation", alias = "ni" },
            { "network_speed_test", alias = "ns" },

            { "keyboard_lock", alias = "kl" },
            { "keyboard_keep_alive", alias = "ka" },

            { "screen_confetti", alias = "cf" },

            { "martillo_reload", alias = "mr" },
            { "martillo_update", alias = "mu" },
        },
        keys = {
            { "<leader>", "space" },
        },
    },

    {
        "LaunchOrToggleFocus",
        keys = {
            { "<leader>", "c", app = "Calendar" },
            { "<leader>", "f", app = "Finder" },
            { "<leader>", ";", app = "Ghostty" },
            { "<leader>", "e", app = "Mail" },
            { "<leader>", "m", app = "Messages" },
            { "<leader>", "b", app = "Safari" },
            { "<leader>", "s", app = "Slack" },
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
                { match = { "*meet.google*" }, app = "Google Meet" },
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

The central command palette with all your actions:

```lua
{
  "ActionsLauncher",
  opts = function()
    -- Import action bundles
    local window = require("bundle.window")
    local utilities = require("bundle.utilities")

    return { actions = { window, utilities } }
  end,
  actions = {
    -- Assign keybindings and aliases to specific actions
    { "window_center", keys = { { "<leader>", "return" } } },
    { "toggle_caffeinate", alias = "tc" },
    { "clipboard_history", keys = { { "<leader>", "v" } } },
  },
  keys = {
    { "<leader>", "space" }
  }
}
```

**Action Fields:**
- `icon` - Icon name from 3D icons collection (auto-inherited by child pickers)
- `keys` - Keybindings for direct access
- `alias` - Short name for faster fuzzy search

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

You can also load custom actions from the `store` directory. The store auto-loader will automatically discover and load all action modules:

```lua
{
  "ActionsLauncher",
  opts = function()
    local window = require("bundle.window")
    local store = require("store")  -- Auto-loads all store actions (lazy loading)

    return { actions = { window, store } }
  end,
  -- ... rest of config
}
```

**Example Store Structure:**
```
store/
  init.lua          # Auto-loader with lazy loading (automatically loads all modules)
  random_quote/
    init.lua        # Action module (included example)
  my_action/
    init.lua        # Your custom action module
```

Each action module should return an array of actions, just like bundles. The auto-loader uses lazy loading to defer directory scanning until the actions are actually needed.


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

### Bundle Structure

Create a new file in the `bundle/` directory:

```lua
-- my_custom_bundle.lua
-- My Custom Actions Bundle

return {
  {
    id = 'my_action',
    name = 'My Action',
    icon = 'star',
    description = 'Does something awesome',
    handler = function()
      hs.alert.show('Hello from my action!')
    end,
  },
}
```

### Store Structure (External Actions)

Create a new folder in `store/` with an `init.lua` file:

```lua
-- store/my_action/init.lua
return {
  {
    id = 'my_store_action',
    name = 'My Store Action',
    icon = 'message',
    description = 'Custom action from store',
    handler = function()
      -- Your action logic here
    end,
  },
}
```

Then load all store actions in your config:

```lua
local store = require("store")  -- Auto-loads all actions in store/ (lazy loading)
return { actions = { store, ... } }
```

The store auto-loader will automatically discover and load all action modules in subdirectories. Just drop a new action folder in `store/` and it will be loaded automatically!


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
