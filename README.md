# 🔨 Martillo

> **⚠️ Pre-Alpha**: Features may be incomplete, unstable, or change significantly. Use at your own risk.

A powerful, declarative configuration framework for [Hammerspoon](https://www.hammerspoon.org/) that provides fast, ergonomic, and reliable productivity tools for macOS.

Martillo (Spanish for "hammer") offers a clean, maintainable way to configure Hammerspoon using a single-line setup inspired by [lazy.nvim](https://github.com/folke/lazy.nvim), with a collection of custom productivity spoons built-in.

## Full Example

```lua
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.martillo/?.lua"

return require("martillo").setup({
  -- Global configuration
  leader_key = { "alt", "ctrl" },

  -- LaunchOrToggleFocus: App switching hotkeys
  {
    "LaunchOrToggleFocus",
    keys = {
      { "<leader>", "c",  app = "Calendar" },
      { "<leader>", "d",  app = "Chromium" },
      { "<leader>", "x",  app = "Excalidraw" },
      { "<leader>", ";",  app = "Ghostty" },
      { "<leader>", "l",  app = "Linear" },
      { "<leader>", "e",  app = "Mail" },
      { "<leader>", "m",  app = "Music" },
      { "<leader>", "n",  app = "Notes" },
      { "<leader>", "p",  app = "Postico 2" },
      { "<leader>", "r",  app = "Reminders" },
      { "<leader>", "b",  app = "Safari" },
      { "<leader>", "s",  app = "Slack" },
      { "<leader>", "t",  app = "Kagi Translate" },
      { "<leader>", "h",  app = "Yaak" },
    },
  },

  -- ActionsLauncher: Command palette with window management actions
  {
    "ActionsLauncher",
    opts = function()
      return require("config.actions")
    end,
    actions = {
      static = {
        -- Window management actions
        { "window_left_third", keys = { { "<leader>", "left" } } },
        { "window_right_third", keys = { { "<leader>", "right" } } },
        { "window_almost_maximize", keys = { { "<leader>", "up" } } },
        { "window_reasonable_size", keys = { { "<leader>", "down" } } },
        { "window_center", keys = { { "<leader>", "return" } } },
        { "window_maximize", alias = "wm" },
        -- System actions
        { "toggle_caffeinate", alias = "tc" },
        { "toggle_system_appearance", alias = "ta" },
        { "copy_ip", alias = "gi" },
        { "generate_uuid", alias = "gu" },
        { "network_status" },
      },
      dynamic = {
        "timestamp",
        "colors",
        "base64",
        "jwt",
      }
    },
    keys = {
      { "<leader>", "space", desc = "Toggle Actions Launcher" },
    },
  },

  -- KillProcess: Process killer
  {
    "KillProcess",
    keys = {
      { "<leader>", "=", desc = "Toggle Kill Process" },
    },
  },

  -- ClipboardHistory: Clipboard manager
  {
    "ClipboardHistory",
    config = function(spoon)
      spoon:start()
    end,
    keys = {
      { "<leader>", "-", desc = "Toggle Clipboard History" },
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

  -- BrowserRedirect: Smart browser routing
  {
    "BrowserRedirect",
    opts = {
      defaultBrowser = "Safari",
      redirect = {
        { match = { "*localhost*", "*127.0.0.1*", "*0.0.0.0*" }, browser = "Chromium" },
      },
      mapper = {
        { name = "googleToKagiHomepage", from = "*google.com*", to = "https://kagi.com/" },
        {
          name = "googleToKagiSearch",
          from = "*google.com*/search*",
          to = "https://kagi.com/search?q={query.q|encode}",
        },
      },
    },
    config = function(spoon)
      spoon:start()
    end,
  },
})
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
- **Dynamic transformations**: Timestamp conversion, Base64 encoding/decoding, JWT decoding, color conversions

<img width="866" height="667" alt="Screenshot 2025-11-02 at 13 26 01" src="https://github.com/user-attachments/assets/8f86b67b-49c6-4c2c-a8bc-89f322e6a8e6" />
<img width="866" height="667" alt="Screenshot 2025-11-02 at 13 26 18" src="https://github.com/user-attachments/assets/bffef712-c496-4dd1-8921-3803b49e7018" />
<img width="866" height="667" alt="Screenshot 2025-11-02 at 13 26 40" src="https://github.com/user-attachments/assets/afc92d3e-8a01-47cf-9785-15ac65ef540b" />

### WindowManager
Window positioning and resizing with keyboard shortcuts. Available actions:
- **Halves**: Snap to left, right, top, or bottom half of screen
- **Quarters**: Position in any corner (top-left, top-right, bottom-left, bottom-right)
- **Thirds (horizontal)**: Left, center, or right third; left or right two-thirds
- **Thirds (vertical)**: Top, middle, or bottom third; top or bottom two-thirds
- **Maximize**: Full screen or almost maximize (90% centered)
- **Center**: Center window at current size or reasonable size (60%×70% centered)

### KillProcess
Quick process killer with fuzzy search. Find and terminate unresponsive apps instantly.

<img width="866" height="667" alt="Screenshot 2025-11-02 at 13 27 45" src="https://github.com/user-attachments/assets/7b99609d-3db3-4869-9a47-8838406982df" />

### ClipboardHistory
Lightweight clipboard manager with persistent plain text history. Features:
- Fast fuzzy search entirely in Lua
- Simple plain text storage (fish_history-like format)
- Support for text, images, and file paths
- Background clipboard monitoring
- No external dependencies required
- Human-readable history file

<img width="866" height="667" alt="Screenshot 2025-11-02 at 13 27 09" src="https://github.com/user-attachments/assets/141e1891-b1dc-42a6-b472-3a4f68e16d3b" />

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

### Spoon Specification

Each spoon can have these fields:

| Field | Type | Description |
|-------|------|-------------|
| `[1]` | `string` | The spoon name (required) |
| `opts` | `table\|function` | Configuration options |
| `actions` | `table` | Filter and customize actions (ActionsLauncher only) |
| `keys` | `table` | Keybinding definitions |
| `config` | `function` | Post-setup configuration |
| `init` | `function` | Pre-configuration initialization |

### Keybinding Format

```lua
keys = {
  { modifiers, key, action, desc = "description" },
  -- Examples:
  { "<leader>", "\\", desc = "Toggle palette" },
  { { "<leader>", "cmd" }, "p", desc = "Leader + cmd + p" },
  { { "cmd", "shift" }, "left", "left_half", desc = "Move left" },
  { { "alt" }, "space", desc = "Toggle" }, -- No action = "toggle"
}
```

Use the `<leader>` placeholder anywhere inside the modifiers list to expand to your configured leader chord. Mixing `<leader>` with additional modifiers (e.g., `{ "<leader>", "cmd" }`) is supported, and an explicit error is raised if you reference `<leader>` without defining `leader_key`.

### ActionsLauncher Configuration

The ActionsLauncher can selectively enable actions and bind keybindings to them:

```lua
{
  "ActionsLauncher",
  opts = function()
    return require("config.actions")  -- Load all available actions
  end,
  actions = {
    -- Enable specific static actions with optional keybindings
    static = {
      "maximize_window",                                              -- Enable without keybinding
      { "center_window", keys = { { "<leader>", "return" } } },       -- With single keybinding
      { "window_left_third", keys = { { "<leader>", "left" } } },     -- Window to left third
      { "window_right_third", keys = { { "<leader>", "right" } } },   -- Window to right third
    },
    -- Enable specific dynamic actions (cannot have keybindings)
    dynamic = {
      "timestamp",      -- Unix timestamp to ISO converter
      "colors",         -- RGB/HEX color converter
      "base64",         -- Base64 decoder
      "jwt",            -- JWT decoder
    }
  },
  keys = {
    { "<leader>", "\\", desc = "Toggle Actions Launcher" }
  },
}
```

**Actions Format:**
- Each action can be a string (action ID) or a table with `{ "action_id", keys = { ... } }`
- The `actions` table has two categories:
  - `static`: One-time executable actions (window management, system controls, utilities) - can have keybindings
  - `dynamic`: Query-based transformations (timestamps, colors, base64, JWT) - cannot have keybindings
- Keybindings use the same format as spoon keys and support `<leader>` expansion
- If no `actions` filter is provided, all actions from `opts` are loaded

### Global Options

```lua
return require("martillo").setup({
  -- Global options (non-numeric keys)
  autoReload = true,              -- Auto-reload on file change (default: true)
  alertOnLoad = true,             -- Show alert when config loads (default: true)
  alertMessage = "Martillo Ready",-- Custom load message
  leader_key = { "alt", "shift" }, -- Expand <leader> modifiers (optional)

  -- Spoons configuration (numeric keys)
  { "SpoonName", ... },
  { "AnotherSpoon", ... },
})
```
Modifier names are case-insensitive and support common aliases such as `command`, `⌘`, `option`, or `⌥`; Martillo canonicalises them automatically for Hammerspoon.


## API Reference

### Core Functions

```lua
local martillo = require("martillo")

-- Setup with configuration (single table with spoons and options)
martillo.setup({
  leader_key = { "alt", "ctrl" },
  { "SpoonName", ... },
  { "AnotherSpoon", ... },
})

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
- [x] **Spoon Aliases** - Set custom aliases for each spoon
- [x] **Enhanced Search** - Search by aliases in choosers
- [x] **Alias Display** - Show aliases in chooser items (right side)

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

## Acknowledgments

- [Hammerspoon](https://www.hammerspoon.org/) - The powerful macOS automation tool
- [lazy.nvim](https://github.com/folke/lazy.nvim) - Inspiration for the declarative configuration style
