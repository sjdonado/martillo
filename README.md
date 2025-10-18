# 🔨 Martillo

> **⚠️ Pre-Alpha**: Features may be incomplete, unstable, or change significantly. Use at your own risk.

A powerful, declarative configuration framework for [Hammerspoon](https://www.hammerspoon.org/) that provides fast, ergonomic, and reliable productivity tools for macOS.

Martillo (Spanish for "hammer") offers a clean, maintainable way to configure Hammerspoon using a single-line setup inspired by [lazy.nvim](https://github.com/folke/lazy.nvim), with a collection of custom productivity spoons built-in.

## Full Example

```lua
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.martillo/?.lua"

return require("martillo").setup {
  -- LaunchOrToggleFocus: App switching hotkeys
  {
    "LaunchOrToggleFocus",
    keys = {
      { { "alt", "shift" }, "c", app = "Calendar" },
      { { "alt", "shift" }, "d", app = "Chromium" },
      { { "alt", "shift" }, "x", app = "Excalidraw" },
      { { "alt", "shift" }, "space", app = "Ghostty" },
      { { "alt", "shift" }, "e", app = "Mail" },
      { { "alt", "shift" }, "m", app = "Music" },
      { { "alt", "shift" }, "n", app = "Notes" },
      { { "alt", "shift" }, "r", app = "Reminders" },
      { { "alt", "shift" }, "b", app = "Safari" },
      { { "alt", "shift" }, "h", app = "Yaak" },
      { { "alt", "shift" }, "z", app = "Zed" },
    },
  },

  -- ActionsLauncher: Command palette with actions
  {
    "ActionsLauncher",
    opts = function()
      return require("config.actions")
    end,
    keys = {
      { { "alt", "shift" }, "\\", desc = "Toggle Actions Launcher" }
    },
  },

  -- KillProcess: Process killer
  {
    "KillProcess",
    keys = {
      { { "alt", "shift" }, "=", desc = "Toggle Kill Process" }
    },
  },

  -- WindowManager: Minimal window manipulation
  {
    "WindowManager",
    keys = {
      { { "cmd", "shift" }, "left",   "left_half",   desc = "Move window to left half" },
      { { "cmd", "shift" }, "right",  "right_half",  desc = "Move window to right half" },
      { { "cmd", "shift" }, "up",     "top_half",    desc = "Move window to top half" },
      { { "cmd", "shift" }, "down",   "bottom_half", desc = "Move window to bottom half" },
      { { "cmd", "shift" }, "return", "center",      desc = "Center window" },
    },
  },

  -- MySchedule: Calendar integration that displays today's events in the menu bar
  {
    "MySchedule",
    config = function(spoon)
      spoon:compile()
      spoon:start()
    end,
  },

  -- ClipboardHistory: Clipboard manager
  {
    "ClipboardHistory",
    config = function(spoon)
      spoon:start()
    end,
    keys = {
      { { "alt", "shift" }, "-", desc = "Toggle Clipboard History" }
    },
  },

  -- BrowserRedirect: Smart browser routing
  {
    "BrowserRedirect",
    opts = {
      defaultBrowser = "Safari",
      redirect = {
        { match = { "*localhost*", "*127.0.0.1*", "*0.0.0.0*" }, browser = "Chromium" },
        { match = { "*fly.dev*" },                               browser = "Chromium" },
        { match = { "*linear*" },                                browser = "Linear" },
      },
      mapper = {
        { name = "googleToKagiHomepage", from = "*google.com*",         to = "https://kagi.com/" },
        { name = "googleToKagiSearch",   from = "*google.com*/search*", to = "https://kagi.com/search?q={query.q|encode}" }
      },
    },
    config = function(spoon)
      spoon:start()
    end,
  },
}
```

## Built-in Spoons

Martillo comes with these productivity spoons:

### LaunchOrToggleFocus
Quick app switching with customizable hotkeys. Launch or focus apps instantly without lifting your hands from the keyboard.

### ActionsLauncher
Searchable command palette with configurable actions. Current built-in actions include:
- **Window management**: Maximize, almost maximize, reasonable size
- **System controls**: Toggle dark mode, caffeinate (prevent sleep)
- **Utilities**: Copy public IP, generate UUID, network status check
- **Live transformations**: Timestamp conversion, Base64 encoding/decoding, JWT decoding, color conversions

![50c706b1-01b8-474b-a019-2fd2ed997a8c](https://github.com/user-attachments/assets/0a35f718-3ea5-48bd-821f-2b3cdf276125)

![b3b8d12d-6628-4351-9c6e-8ecf58e3e0c4](https://github.com/user-attachments/assets/5ccf5360-1347-49e0-b542-20e0a39c59a5)

![95d40333-a141-4557-b653-6fefa89f56c0](https://github.com/user-attachments/assets/6e636afb-f462-4fef-9b20-48d05c508beb)

### WindowManager
Window positioning and resizing with keyboard shortcuts. Available actions:
- **Halves**: Snap to left, right, top, or bottom half of screen
- **Maximize**: Full screen or almost maximize (90% centered)
- **Center**: Center window at current size or reasonable size (60%×70% centered)

### KillProcess
Quick process killer with fuzzy search. Find and terminate unresponsive apps instantly.

![8726c321-6f4c-4ca2-9684-70700c58020d](https://github.com/user-attachments/assets/f95fc249-dbfd-4e51-b7e6-f6a894e963f6)

### ClipboardHistory
Lightweight clipboard manager with persistent plain text history. Features:
- Fast fuzzy search entirely in Lua
- Simple plain text storage (fish_history-like format)
- Support for text, images, and file paths
- Background clipboard monitoring
- No external dependencies required
- Human-readable history file

![ff32fe87-1306-4ee5-a4b8-b3a84b4767bb](https://github.com/user-attachments/assets/a0255fda-3114-4594-8ac3-be4093650cd7)

### BrowserRedirect
Intelligent URL routing to different browsers based on patterns. Perfect for developers who need specific browsers for different environments.

### MySchedule
Calendar integration that displays today's events in the menu bar with countdown timers. Uses macOS EventKit to access calendar data, showing upcoming meetings with real-time time remaining and clickable meeting URLs.

## Installation

**Prerequisites**
- macOS 10.12 or later
- [Homebrew](https://brew.sh/) (for installing dependencies)

### Dependencies

All spoons are now dependency-free! No external libraries or compilation required.

### Quick Install

```bash
# Install Hammerspoon if you don't have it
brew install --cask hammerspoon

# Clone Martillo
git clone https://github.com/sjdonado/martillo ~/.martillo

# Backup existing Hammerspoon config (if any)
[ -f ~/.hammerspoon/init.lua ] && mv ~/.hammerspoon/init.lua ~/.hammerspoon/init.lua.backup

# Create new init.lua
cat > ~/.hammerspoon/init.lua << 'EOF'
-- Load Martillo
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.martillo/?.lua"

-- Your configuration
return require("martillo").setup {
  -- Spoons configuration here
}
EOF

# Reload Hammerspoon
```

## Configuration

### Basic Setup

```lua
-- ~/.hammerspoon/init.lua
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.martillo/?.lua"

return require("martillo").setup {
  -- Simple spoon
  { "WindowManager" },

  -- Spoon with configuration
  { "ClipboardHistory",
    config = function(spoon)
      spoon:start()
    end
  },
}
```

## Default Keybindings

| Feature | Default Shortcut | Description |
|---------|-----------------|-------------|
| **Actions Launcher** | `⌥ ⇧ \` | Open command palette |
| **Kill Process** | `⌥ ⇧ =` | Process killer |
| **Clipboard History** | `⌥ ⇧ -` | Show clipboard history |
| **Window Left** | `⌘ ⇧ ←` | Snap window to left half |
| **Window Right** | `⌘ ⇧ →` | Snap window to right half |
| **Window Up** | `⌘ ⇧ ↑` | Snap window to top half |
| **Window Down** | `⌘ ⇧ ↓` | Snap window to bottom half |
| **Window Center** | `⌘ ⇧ ↵` | Center window |
| **App Hotkeys** | `⌥ ⇧ [key]` | Launch/focus specific apps |

## Configuration Options

### Spoon Specification

Each spoon can have these fields:

| Field | Type | Description |
|-------|------|-------------|
| `[1]` | `string` | The spoon name (required) |
| `opts` | `table\|function` | Configuration options |
| `keys` | `table` | Keybinding definitions |
| `config` | `function` | Post-setup configuration |
| `init` | `function` | Pre-configuration initialization |

### Keybinding Format

```lua
keys = {
  { modifiers, key, action, desc = "description" },
  -- Examples:
  { { "cmd", "shift" }, "left", "left_half", desc = "Move left" },
  { { "alt" }, "space", desc = "Toggle" }, -- No action = "toggle"
}
```

### Global Options

```lua
return require("martillo").setup({
  -- Spoons configuration
}, {
  -- Global options
  autoReload = true,              -- Auto-reload on file change (default: true)
  alertOnLoad = true,             -- Show alert when config loads (default: true)
  alertMessage = "Martillo Ready" -- Custom load message
})
```

## API Reference

### Core Functions

```lua
local martillo = require("martillo")

-- Setup with configuration
martillo.setup(config, options)

-- Get a loaded spoon
local spoon = martillo.get("SpoonName")

-- List all loaded spoons
local spoons = martillo.list()

-- Manually reload configuration
martillo.reload()
```

## Roadmap

**Vision**: Open source Raycast alternative built with Lua and Hammerspoon

### Core Features
- [x] Extensive action launcher with fuzzy search
- [x] Window management via launcher and keymaps
- [x] Launch/toggle macOS apps via keymaps
- [x] Process killer with fuzzy search
- [x] Clipboard history with search and paste
- [x] Upcoming meetings display in menu bar
- [x] Browser routing rules based on URL patterns
- [x] Link transformation rules before opening

### Framework Improvements
- [ ] **Fork Hammerspoon** - Custom build with enhanced chooser capabilities
- [x] **Precompiled Spoons** - All spoons loaded and compiled by default
- [x] **Simplified Configuration** - Single table configuration like lazy.nvim
- [ ] **Spoon Aliases** - Set custom aliases for each spoon
- [ ] **Enhanced Search** - Search by aliases in choosers
- [ ] **Alias Display** - Show aliases in chooser items (right side)

### Enhanced Chooser System
- [ ] **Navigation Callbacks**:
  - `onScrollTop` - Trigger when scrolling to top
  - `onScrollBottom` - Trigger when scrolling to bottom
  - `onBack` - Navigation back button for nested choosers
- [ ] **Nested Choosers** - Child choosers with parent context preservation
- [ ] **Persistent Choosers** - Don't close on action if child process spawns
- [ ] **Smart Refresh** - Refresh choices without losing scroll position
- [ ] **Main Launcher** - Central chooser listing all actions and sub-launchers

### Advanced Features
- [ ] Snippet expansion system
- [ ] Emoji picker and special characters

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Hammerspoon](https://www.hammerspoon.org/) - The powerful macOS automation tool
- [lazy.nvim](https://github.com/folke/lazy.nvim) - Inspiration for the declarative configuration style
