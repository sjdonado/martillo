# 🔨 Martillo

**Build anything you can imagine and launch it with a keystroke.** Martillo is a powerful, declarative actions launcher for macOS powered by [Hammerspoon](https://www.hammerspoon.org/). Create custom workflows, automate repetitive tasks, and access everything through a beautiful command palette with fuzzy search.

**Your productivity hub, your way.** Think Raycast, but completely open-source with no vendor lock-in. Write your own actions in Lua, use ready-made bundles, customize every keybinding, add aliases for lightning-fast access, and share your creations freely. All configuration lives in a single file, inspired by [lazy.nvim](https://github.com/folke/lazy.nvim)'s elegant plugin system.

## Features

**Core Capabilities:**
- ⚡ **Fast & Lightweight**: Pure Lua, zero dependencies, no compilation needed
- 🎯 **Command Palette**: Searchable actions with fuzzy search and beautiful 3D icons
- 🚀 **App Launcher**: Quick switching between apps with single hotkey
- 🌐 **Browser Routing**: Smart URL routing to different browsers based on patterns

**Window Management** - Keyboard-driven positioning with 💻 icon:
- Maximize, Center, Reasonable Size
- Halves (left, right, top, bottom), Quarters (corners), Thirds (horizontal and vertical)

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

**Utilities:**
- ☕ Toggle Caffeinate (prevent sleep)
- 🌓 Toggle Dark/Light Mode
- 🌐 Copy Public IP
- 🔑 Generate UUID
- 📡 Network Speed Test

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
    opts = function()
      local window = require("bundle.window")
      local utilities = require("bundle.utilities")
      local converters = require("bundle.converter")
      local clipboard = require("bundle.clipboard_history")
      local kill_process = require("bundle.kill_process")
      local martillo = require("bundle.martillo")

      return { actions = { window_mgmt, utilities, converters, clipboard, kill_process, martillo } }
    end,
    actions = {
      { "window_center", keys = { { "<leader>", "return" } } },
      { "window_maximize", alias = "wm" },
      { "clipboard_history", alias = "ch", keys = { { "<leader>", "v" } } },
      { "kill_process", alias = "kp" },
      { "toggle_caffeinate", alias = "tc" },
      { "generate_uuid", alias = "gu" },
      { "converter_time", alias = "ct" },
      { "converter_colors", alias = "cc" },
    },
    keys = {
      { "<leader>", "space" }
    }
  },

  {
    "LaunchOrToggleFocus",
    keys = {
      { "<leader>", "b", app = "Safari" },
      { "<leader>", ";", app = "Ghostty" },
    }
  }
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
  alertOnLoad = true,                   -- Show alert when loaded
  alertMessage = "Martillo is ready",   -- Custom load message

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
    local window_mgmt = require("bundle.window_management")
    local utilities = require("bundle.utilities")

    return { actions = { window_mgmt, utilities } }
  end,
  actions = {
    -- Assign keybindings and aliases to specific actions
    { "window_center", keys = { { "<leader>", "return" } } },
    { "toggle_caffeinate", alias = "tc" },
    { "clipboard_history", keys = { { "<leader>", "v" } } },
  },
  keys = {
    { "<leader>", "space", desc = "Toggle Actions Launcher" }
  }
}
```

**Action Fields:**
- `icon` - Icon name from 3D icons collection (auto-inherited by child pickers)
- `keys` - Keybindings for direct access
- `alias` - Short name for faster fuzzy search

### Available Action Bundles

- `bundle.window_management` - Window positioning (halves, quarters, thirds, maximize, center)
- `bundle.utilities` - System utilities (caffeinate, dark mode, generate UUID)
- `bundle.converter` - Converters (time, colors, base64, JWT)
- `bundle.clipboard_history` - Clipboard manager with history
- `bundle.kill_process` - Process killer with fuzzy search
- `bundle.martillo` - Martillo management (reload, update)
- `bundle.safari_tabs` - Safari tab switcher
- `bundle.screen` - Screen effects (confetti, ruler)
- `bundle.network` - Network utilities


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
