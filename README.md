# 🔨 Martillo

A powerful, declarative configuration framework for [Hammerspoon](https://www.hammerspoon.org/) that provides fast, ergonomic, and reliable productivity tools for macOS.

Martillo (Spanish for "hammer") offers a clean, maintainable way to configure Hammerspoon using a single-line setup inspired by [lazy.nvim](https://github.com/folke/lazy.nvim), with a collection of custom productivity spoons built-in.

## ✨ Features

- 🎯 **Single-line setup** - Your entire configuration in one `return` statement
- 📦 **Custom Spoons Collection** - Curated productivity tools included
- ⚡ **Fast & Native** - Pure Lua performance, no overhead
- 🔧 **Fully Customizable** - Every aspect can be tweaked to your workflow
- 🔄 **Auto-reload** - Automatically reload configuration on file changes
- 🎨 **Clean API** - Consistent, predictable configuration structure

## 🛠️ Built-in Spoons

Martillo comes with these productivity spoons:

### 🚀 **LaunchOrToggleFocus**
Quick app switching with customizable hotkeys. Launch or focus apps instantly without lifting your hands from the keyboard.

### 📋 **ActionsLauncher**
Command palette for system actions, utilities, and custom commands. Includes:
- Window management actions
- System controls (dark mode, caffeinate)
- Network utilities
- Color converter
- Base64/JWT decoder
- UUID generator
- Live transformations (timestamps, colors, encoding)

### 🪟 **WindowManager**
Powerful window manipulation with keyboard shortcuts:
- Snap to halves/quarters
- Center windows
- Move between screens
- Custom layouts

### 💀 **KillProcess**
Quick process killer with fuzzy search. Find and terminate unresponsive apps instantly.

### 📋 **ClipboardHistory**
Clipboard manager with history and search capabilities. Never lose copied content again.

### 🌐 **BrowserRedirect**
Intelligent URL routing to different browsers based on patterns. Perfect for developers who need specific browsers for different environments.

### 📅 **MySchedule**
Personal scheduling and reminder system integrated with macOS.

## 📋 Prerequisites

- macOS 10.12 or later
- [Hammerspoon](https://www.hammerspoon.org/)

## 🚀 Installation

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

## 📖 Configuration

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
      spoon:compile()
      spoon:start()
    end
  },
}
```

### Full Example

```lua
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.martillo/?.lua"

return require("martillo").setup {
  -- LaunchOrToggleFocus: App switching hotkeys
  {
    "LaunchOrToggleFocus",
    opts = {
      calendar   = { hotkey = { { "alt", "shift" }, "c" }, app = "Calendar" },
      chromium   = { hotkey = { { "alt", "shift" }, "d" }, app = "Chromium" },
      excalidraw = { hotkey = { { "alt", "shift" }, "x" }, app = "Excalidraw" },
      ghostty    = { hotkey = { { "alt", "shift" }, ";" }, app = "Ghostty" },
      mail       = { hotkey = { { "alt", "shift" }, "e" }, app = "Mail" },
      music      = { hotkey = { { "alt", "shift" }, "m" }, app = "Music" },
      notes      = { hotkey = { { "alt", "shift" }, "n" }, app = "Notes" },
      reminders  = { hotkey = { { "alt", "shift" }, "r" }, app = "Reminders" },
      safari     = { hotkey = { { "alt", "shift" }, "b" }, app = "Safari" },
      yaak       = { hotkey = { { "alt", "shift" }, "h" }, app = "Yaak" },
      zed        = { hotkey = { { "alt", "shift" }, "space" }, app = "Zed" },
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

  -- WindowManager: Window manipulation
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

  -- MySchedule: Personal scheduling
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
      spoon:compile()
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

## ⌨️ Default Keybindings

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

## 🎨 ActionsLauncher Features

The ActionsLauncher provides live transformations for:

- **Timestamps**: Convert Unix timestamps to ISO format
- **Base64**: Decode Base64 strings
- **JWT**: Decode JWT tokens (header and payload)
- **Colors**: Convert between HEX and RGB formats
- **UUID**: Generate UUIDs
- **Network**: Check connectivity and latency
- **System**: Toggle dark mode, caffeinate

## 🔧 Configuration Options

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

## 📚 API Reference

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

## 🗂️ Project Structure

```
~/.martillo/
├── martillo.lua           # Core module
├── spoons/               # Built-in spoons
│   ├── LaunchOrToggleFocus.spoon/
│   ├── ActionsLauncher.spoon/
│   ├── WindowManager.spoon/
│   ├── KillProcess.spoon/
│   ├── ClipboardHistory.spoon/
│   ├── BrowserRedirect.spoon/
│   └── MySchedule.spoon/
└── README.md

~/.hammerspoon/
├── init.lua              # Your configuration
└── config/               # Optional config modules
    └── actions.lua       # ActionsLauncher config
```

## 🎯 Roadmap

- [ ] Unified launcher (Raycast-style command palette)
- [ ] Enhanced clipboard manager with images
- [ ] Snippet expansion system
- [ ] Calculator with natural language
- [ ] Emoji picker

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Hammerspoon](https://www.hammerspoon.org/) - The powerful macOS automation tool
- [lazy.nvim](https://github.com/folke/lazy.nvim) - Inspiration for the declarative configuration style

## 📮 Support

- [Report Issues](https://github.com/sjdonado/martillo/issues)
- [Discussions](https://github.com/sjdonado/martillo/discussions)
