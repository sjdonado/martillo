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
- **`config/`**: Optional configuration modules (like `actions.lua` for ActionsLauncher)

### Key Design Patterns

1. **Declarative Configuration**: Users configure everything through a single `require("martillo").setup()` call with a table-based specification
2. **Spoon Specification Format**: Each spoon is configured with:
   - `[1]` (string): Spoon name (required)
   - `opts` (table/function): Configuration options
   - `keys` (table): Hotkey definitions in format `{ modifiers, key, action, desc }`
   - `config` (function): Post-setup configuration hook
   - `init` (function): Pre-configuration initialization hook

3. **Hotkey Processing**: The framework automatically processes hotkey specifications and binds them using `spoon:bindHotkeys()`

4. **Spoon Loading**: Spoons are loaded from the `spoons/` directory following Hammerspoon's `.spoon` structure

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
**Purpose**: Searchable command palette with live transformations and system controls

**Key Features**:
- Fuzzy search across all available actions
- Live transformations: paste content, select text, transform it in real-time
- Extensible action system with categories
- Custom icon support for visual identification

**Built-in Action Categories**:

1. **Window Management**:
   - Maximize, almost maximize (90% centered)
   - Reasonable size (60%×70% centered)
   - Quick window positioning

2. **System Controls**:
   - Toggle dark mode
   - Caffeinate (prevent sleep)
   - Screen lock
   - Volume control

3. **Developer Utilities**:
   - Copy public IP address
   - Generate UUID
   - Network status check
   - Process information

4. **Live Transformations** (work on clipboard or selection):
   - **Timestamp Converter**: Unix timestamp ↔ human-readable date
   - **Base64**: Encode/decode
   - **JWT Decoder**: View JWT payload without external tools
   - **Color Converter**: HEX ↔ RGB ↔ HSL
   - **URL Encoder/Decoder**: Handle special characters
   - **JSON Formatter**: Pretty print JSON
   - **Hash Generator**: MD5, SHA1, SHA256

**Use Cases**:
- Quick development tasks without switching to browser/tools
- Transform clipboard content without manual copying/pasting
- System controls without reaching for System Preferences
- Create custom shortcuts for repeated tasks

**Technical Details**:
- Uses Hammerspoon's `hs.chooser` for UI
- Actions are Lua functions with metadata (name, description, icon, handler)
- Supports async actions and error handling
- Live transformations work on pasteboard or selected text

**Configuration Example**:
```lua
{
  "ActionsLauncher",
  opts = function()
    return {
      actions = {
        {
          name = "Custom Action",
          description = "My custom action",
          icon = "⚡",
          handler = function()
            hs.alert.show("Action executed!")
          end
        }
      }
    }
  end
}
```

---

### WindowManager
**Purpose**: Keyboard-driven window positioning and layout management

**Key Features**:
- Snap windows to screen halves (left, right, top, bottom)
- Maximize window or almost maximize (90% centered for better ergonomics)
- Center window at current size or reasonable size
- Instant window manipulation without mouse dragging

**Available Actions**:
- `left_half` / `right_half`: Snap to left/right 50% of screen
- `top_half` / `bottom_half`: Snap to top/bottom 50% of screen
- `maximize`: Fill entire screen
- `almost_maximize`: 90% centered (more comfortable for large displays)
- `center`: Center window at current size
- `reasonable_size`: Resize to 60%×70% and center

**Use Cases**:
- Side-by-side code editor and browser
- Terminal on one half, documentation on the other
- Quick window organization during presentations
- Consistent window sizes across different displays

**Technical Details**:
- Uses Hammerspoon's `hs.window` API
- Works with any application window
- Respects screen safe areas (menu bar, dock)
- Smooth animations

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
The framework supports both simple spoon loading and complex configurations with custom hotkeys and options. See README.md for full examples.

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
