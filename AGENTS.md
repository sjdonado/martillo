# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Martillo** (Spanish for "hammer") is a powerful, declarative configuration framework for [Hammerspoon](https://www.hammerspoon.org/) that provides fast, ergonomic, and reliable productivity tools for macOS. The project aims to be an open-source Raycast alternative built with Lua and Hammerspoon.

### Vision & Philosophy

- **Declarative Configuration**: Single-line setup inspired by [lazy.nvim](https://github.com/folke/lazy.nvim)
- **Zero Dependencies**: Pure Lua implementation with no external libraries or compilation required
- **Developer-First**: Built by developers, for developers who want powerful automation without leaving the keyboard
- **Extensible**: Easy to create custom spoons and actions
- **Performance**: Lightweight, fast, and runs entirely in the background

### Current Status
- **Pre-Alpha**: Features may be incomplete, unstable, or change significantly
- Core functionality is stable and ready for daily use
- Active development with regular improvements

## Commands

This is a Lua-based Hammerspoon configuration framework. Since this is a pure Lua project, there are no npm/bun commands. However, you can use these commands for development:

- **Test configuration**: Copy the project to `~/.martillo` and test in Hammerspoon directly
- **Reload Hammerspoon**: Use Hammerspoon's built-in reload functionality or `hs.reload()` in the console
- **Check logs**: Open Hammerspoon Console to see debug output and errors

## Architecture

Martillo is a declarative configuration framework for Hammerspoon that follows these key patterns:

### Core Structure
- **`martillo.lua`**: Main framework module that handles spoon loading, configuration, and hotkey binding
- **`spoons/`**: Collection of custom Hammerspoon spoons (productivity tools)
- **`spoons/_internal/`**: Shared internal modules (leader.lua, search.lua, window.lua)
- **`config/`**: Optional configuration modules (like `actions.lua` for ActionsLauncher)

### Key Design Patterns

1. **Declarative Configuration**: Users configure everything through a single `require("martillo").setup({ ... })` call where:
   - Global options (like `leader_key`) are non-numeric keys
   - Spoons are numeric array entries

2. **Spoon Specification Format**: Each spoon is configured with:
   - `[1]` (string): Spoon name (required)
   - `opts` (table/function): Configuration options
   - `actions` (table): Filter and customize actions (ActionsLauncher only)
   - `keys` (table): Hotkey definitions in format `{ modifiers, key, action, desc }`
   - `config` (function): Post-setup configuration hook
   - `init` (function): Pre-configuration initialization hook

3. **Leader Key Support**: `<leader>` placeholder in hotkeys expands to configured `leader_key` modifiers

4. **Hotkey Processing**: The framework automatically processes hotkey specifications and binds them using `spoon:bindHotkeys()` or per-action keybindings

5. **Shared Modules**: Internal utilities in `spoons/_internal/` for leader key handling, fuzzy search, and window management

## Built-in Spoons

### LaunchOrToggleFocus
**Purpose**: Ultra-fast application switching without touching the mouse

**Key Features**:
- Launch or focus applications with single hotkey press
- Smart toggle: if app is already focused, press again to switch to previous app
- Configurable hotkey mappings for each application
- Supports any installed macOS application

**Use Cases**:
- Quick switching between development tools (terminal, editor, browser)
- Instant access to communication apps (Mail, Messages)
- Keyboard-driven workflow without Alt+Tab

**Technical Details**:
- Uses Hammerspoon's `hs.application` API for app management
- Tracks previously focused app for toggle functionality
- Handles edge cases (app not installed, multiple windows, etc.)

---

### ActionsLauncher
**Purpose**: Searchable command palette with selective action loading, per-action keybindings, and live transformations

**Key Features**:
- Fuzzy search across all available actions with alias support
- Selective action loading - enable only the actions you need
- Per-action keybindings - bind hotkeys to specific actions
- Static actions (one-time executables) and dynamic actions (query-based transformations)
- Alias support for quick searching (e.g., "tc" for "Toggle Caffeinate")

**Action Categories**:

1. **Static Actions** (can have keybindings and aliases):
   - **Window Management**: Maximize, center, quarters, thirds positioning
   - **System Controls**: Toggle dark mode, caffeinate (prevent sleep)
   - **Developer Utilities**: Copy IP, generate UUID, network status

2. **Dynamic Actions** (query-based transformations):
   - **Timestamp Converter**: Unix timestamp ↔ ISO string (detects 10 or 13 digit numbers)
   - **Base64**: Auto-decode valid base64 strings
   - **JWT Decoder**: Auto-decode JWT tokens into header/payload
   - **Color Converter**: HEX ↔ RGB with visual color swatch

**Use Cases**:
- Quick window management without dedicated window manager spoon
- Transform clipboard content (paste timestamp, get ISO date)
- System controls with searchable aliases
- Custom action workflows with keybindings

**Technical Details**:
- Actions defined in `config/actions.lua` and filtered in spoon configuration
- Uses `spoons/_internal/search.lua` for fuzzy ranking with alias boosting
- Static actions support `keys` property for direct hotkey binding
- Dynamic actions use pattern matching on query input

**Configuration Example**:
```lua
{
  "ActionsLauncher",
  opts = function()
    return require("config.actions")  -- Load all available actions
  end,
  actions = {
    static = {
      -- Enable specific actions with optional keybindings and aliases
      { "window_center", keys = { { "<leader>", "return" } } },
      { "toggle_caffeinate", alias = "tc" },
      { "copy_ip", alias = "gi" },
    },
    dynamic = {
      "timestamp",    -- Auto-converts unix timestamps
      "colors",       -- Auto-converts color formats
      "base64",       -- Auto-decodes base64
      "jwt",          -- Auto-decodes JWT tokens
    }
  },
  keys = {
    { "<leader>", "space", desc = "Toggle Actions Launcher" }
  }
}
```

---

### Window Management (Internal Module)
**Purpose**: Shared library for keyboard-driven window positioning - used by ActionsLauncher, not a standalone spoon

**Location**: `spoons/_internal/window.lua`

**Available Positions**:
- **Halves**: left, right, up, down (50% of screen)
- **Quarters**: top_left, top_right, bottom_left, bottom_right (25% of screen)
- **Thirds (horizontal)**: left_third, center_third, right_third, left_two_thirds, right_two_thirds
- **Thirds (vertical)**: top_third, middle_third, bottom_third, top_two_thirds, bottom_two_thirds
- **Sizing**: max (fullscreen), almost_max (90% centered), reasonable (60%×70% centered), center

**Usage**:
Window management is accessed through ActionsLauncher actions with IDs like `window_center`, `window_left_third`, etc. These actions can have keybindings assigned in the ActionsLauncher configuration.

**Example**:
```lua
{
  "ActionsLauncher",
  actions = {
    static = {
      { "window_left_third", keys = { { "<leader>", "left" } } },
      { "window_center", keys = { { "<leader>", "return" } } },
    }
  }
}
```

**Technical Details**:
- Pure Lua module (not a spoon)
- Uses Hammerspoon's `hs.window` API
- Single `moveWindow(direction)` function
- No external dependencies

---

### KillProcess
**Purpose**: Fast process termination with fuzzy search

**Key Features**:
- Fuzzy search through running processes
- Shows process name, PID, and CPU/memory usage
- Force quit unresponsive applications
- Safe process filtering (prevents killing system processes)

**Use Cases**:
- Kill frozen applications without Activity Monitor
- Quick cleanup of development servers
- Emergency process termination
- Find and stop resource-heavy processes

**Technical Details**:
- Uses `ps aux` to get process list
- Filters out kernel processes and critical system processes
- Shows real-time CPU and memory usage
- Uses `kill -9` for force termination

**Safety Features**:
- Requires confirmation before killing processes
- Filters out system-critical processes
- Shows clear process information before termination

---

### ClipboardHistory
**Purpose**: Never lose copied content with searchable clipboard history

**Key Features**:
- Persistent plain text history (survives Hammerspoon restarts)
- Fast fuzzy search entirely in Lua (no external dependencies)
- Support for text, images, and file paths
- Smart preview with file type detection
- Copy or paste from history

**Storage Format**:
- Uses fish_history-like plain text format
- Human-readable and editable
- Stored in `~/.martillo/spoons/ClipboardHistory.spoon/clipboard_history`
- Images saved in `images/` subdirectory

**Search Features**:
- Exact match (highest priority)
- Prefix match (high priority)
- Contains match (medium priority)
- Fuzzy character-by-character matching (lower priority)

**Smart Behavior**:
- Auto-paste in most apps
- Copy-only mode for Finder and System Settings
- Duplicate detection (moves existing entry to top)
- Configurable maximum entries (default: 300)

**Use Cases**:
- Recover accidentally overwritten clipboard
- Access frequently copied snippets
- Search through past clipboard items
- Copy multiple items and paste in sequence

**Technical Details**:
- Pure Lua implementation (no C++ compilation)
- Background clipboard monitoring with `hs.pasteboard.watcher`
- File type detection for images, videos, documents, code
- Smart preview generation with icons

**File Format Example**:
```
- content: Hello World
  when: 1729262400
  type: text
- content: /path/to/image.png
  when: 1729262300
  type: image
```

---

### BrowserRedirect
**Purpose**: Intelligent URL routing to different browsers based on patterns

**Key Features**:
- Pattern-based URL matching
- Multiple browser targets
- URL transformation/mapping rules
- Development vs production environment routing

**Common Use Cases**:
- Route localhost URLs to development browser (Chromium)
- Open work apps (Linear, Jira) in specific browser
- Redirect Google searches to privacy-focused alternatives (Kagi)
- Keep personal browsing in Safari, work in Chrome

**Configuration Example**:
```lua
{
  "BrowserRedirect",
  opts = {
    defaultBrowser = "Safari",
    redirect = {
      { match = { "*localhost*", "*127.0.0.1*" }, browser = "Chromium" },
      { match = { "*linear.app*" },               browser = "Linear" },
    },
    mapper = {
      { 
        name = "googleToKagi", 
        from = "*google.com*/search*", 
        to = "https://kagi.com/search?q={query.q|encode}" 
      }
    }
  }
}
```

**Technical Details**:
- Intercepts URL open events
- Pattern matching with wildcards
- Query parameter extraction and transformation
- Fallback to default browser if no match

---

### MySchedule
**Purpose**: Display today's calendar events in the menu bar with countdown timers

**Key Features**:
- Shows upcoming meetings in menu bar
- Real-time countdown to next event
- Clickable meeting URLs (Zoom, Meet, Teams)
- Native macOS Calendar integration

**Display Format**:
- Menu bar shows next event with time remaining
- Dropdown shows full day schedule
- Meeting links are clickable for instant join

**Use Cases**:
- Always know what's next without checking calendar
- One-click meeting join
- Time awareness during work day
- Meeting preparation reminders

**Technical Details**:
- Uses macOS EventKit API via Objective-C bridge
- Requires calendar access permission
- Updates every minute
- Timezone-aware date handling
- Compiled Objective-C component for calendar access

**Setup**:
```lua
{
  "MySchedule",
  config = function(spoon)
    spoon:compile()  -- Compile Objective-C calendar bridge
    spoon:start()
  end
}
```

---

## Configuration Examples

The framework uses a single-table configuration where global options (non-numeric keys) are mixed with spoons (numeric keys):

```lua
return require("martillo").setup({
  -- Global options
  leader_key = { "alt", "ctrl" },

  -- Spoons
  {
    "LaunchOrToggleFocus",
    keys = {
      { "<leader>", "c", app = "Calendar" },
      { "<leader>", "b", app = "Safari" },
    }
  },

  {
    "ActionsLauncher",
    opts = function() return require("config.actions") end,
    actions = {
      static = {
        { "window_center", keys = { { "<leader>", "return" } } },
        { "toggle_caffeinate", alias = "tc" },
      },
      dynamic = { "timestamp", "colors", "base64", "jwt" }
    },
    keys = { { "<leader>", "space", desc = "Toggle Actions Launcher" } }
  },
})
```

See README.md for complete examples.

## Development Guidelines

### Adding New Spoons

1. Create directory: `spoons/YourSpoon.spoon/`
2. Create `init.lua` with standard spoon structure:
   ```lua
   local obj = {}
   obj.__index = obj
   
   obj.name = "YourSpoon"
   obj.version = "1.0"
   obj.author = "Your Name"
   obj.license = "MIT"
   
   function obj:init()
     return self
   end
   
   function obj:start()
     return self
   end
   
   function obj:stop()
     return self
   end
   
   function obj:bindHotkeys(mapping)
     -- Handle hotkey binding
     return self
   end
   
   return obj
   ```

3. Add to README.md documentation
4. Test with Hammerspoon reload

### Code Style

- Use 2-space indentation
- Follow Lua naming conventions (camelCase for functions, PascalCase for classes)
- Add documentation comments for public APIs
- Use `hs.logger` for debugging output
- Handle errors gracefully with `pcall` when appropriate

### Testing

- Test in actual Hammerspoon environment (no unit test framework)
- Use Hammerspoon Console for debugging
- Test edge cases (app not installed, no network, etc.)
- Verify hotkeys don't conflict with system shortcuts

## Important Notes

- This is a pure Lua project - no Node.js, package managers, or build tools
- All spoons follow Hammerspoon's standard spoon structure with `init.lua` files
- The framework handles automatic reloading when configuration files change
- Users configure everything in their `~/.hammerspoon/init.lua` file
- Testing requires actual Hammerspoon installation and macOS environment
- Some spoons (like MySchedule) may require compilation of Objective-C components

## Roadmap

See README.md for the full roadmap. Key upcoming features:

- Fork Hammerspoon with enhanced chooser capabilities
- Nested chooser system for complex workflows
- Main launcher integrating all spoons
- Snippet expansion system
- Emoji picker

## Resources

- [Hammerspoon Documentation](http://www.hammerspoon.org/docs/)
- [Lua 5.4 Reference](https://www.lua.org/manual/5.4/)
- [lazy.nvim](https://github.com/folke/lazy.nvim) - Configuration style inspiration
