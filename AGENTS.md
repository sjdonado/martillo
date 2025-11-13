# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Martillo** (Spanish for "hammer") is a powerful, declarative configuration framework for [Hammerspoon](https://www.hammerspoon.org/) that provides fast, ergonomic, and reliable productivity tools for macOS. The project aims to be an open-source Raycast alternative built with Lua and Hammerspoon.

### Vision & Philosophy

- **Declarative Configuration**: Single-line setup inspired by [lazy.nvim](https://github.com/folke/lazy.nvim)
- **Zero Dependencies**: Pure Lua implementation with no external libraries or compilation required
- **Developer-First**: Built by developers, for developers who want powerful automation without leaving the keyboard
- **Extensible**: Easy to create custom bundles and actions with beautiful 3D icons
- **Performance**: Lightweight, fast, and runs entirely in the background

### Current Status
- **Pre-Alpha**: Features may be incomplete, unstable, or change significantly
- Core functionality is stable and ready for daily use
- Active development with regular improvements

## Architecture

### Core Structure
- **`martillo.lua`**: Main framework module that handles spoon loading, configuration, and hotkey binding
- **`spoons/`**: Collection of custom Hammerspoon spoons (productivity tools)
- **`bundle/`**: Action bundles (window_management, clipboard_history, converter, utilities, etc.)
- **`lib/`**: Shared library modules (icons, search, navigation, window, leader)
- **`assets/`**: Static resources (120 3D icons from 3dicons.co)

### Key Design Patterns

1. **Declarative Configuration**: Users configure everything through a single `require("martillo").setup({ ... })` call

2. **Action Bundles**: Modular action collections in `bundle/` directory that can be selectively imported

3. **3D Icon System** (`lib/icons.lua`):
   - 120 beautiful icons from 3dicons.co in `assets/icons/`
   - `icons.getIcon(name)` - Get icon by name
   - `icons.ICON_SIZE` - Standard icon size ({ w = 32, h = 32 })
   - Automatic caching for performance
   - Parent icon inheritance for child pickers

4. **Leader Key Support**: `<leader>` placeholder in hotkeys expands to configured `leader_key` modifiers

5. **Shared Modules**:
   - `lib/icons.lua` - Icon management with caching
   - `lib/search.lua` - Fuzzy search with ranking
   - `lib/navigation.lua` - Picker state management
   - `lib/window.lua` - Window positioning
   - `lib/leader.lua` - Leader key expansion

## Built-in Spoons

### ActionsLauncher
**Purpose**: Searchable command palette with selective action loading, per-action keybindings, and 3D icons

**Key Features**:
- Fuzzy search with alias support
- Beautiful 3D icons for all actions
- Icon inheritance for child pickers
- Per-action keybindings
- Nested actions (query-based transformations)

**Configuration**:
```lua
{
  "ActionsLauncher",
  opts = function()
    -- Import action bundles
    return { actions = { require("bundle.window_management"), require("bundle.utilities") } }
  end,
  actions = {
    { "window_center", keys = { { "<leader>", "return" } } },
    { "clipboard_history", alias = "ch" },
  },
  keys = { { "<leader>", "space" } }
}
```

### LaunchOrToggleFocus
**Purpose**: Ultra-fast application switching

**Key Features**:
- Single hotkey per app
- Smart toggle (if focused, switch to previous app)
- Works with any macOS application

### MySchedule
**Purpose**: Calendar integration in menu bar

**Key Features**:
- Today's events with countdown timers
- Clickable meeting URLs
- Native macOS EventKit integration
- Requires compilation (`spoon:compile()`)

### BrowserRedirect
**Purpose**: Intelligent URL routing to different browsers

**Key Features**:
- Pattern-based URL matching
- URL transformation/mapping rules
- Development vs production routing

## Action Bundles

### bundle/window_management.lua
Window positioning actions with computer icon:
- Maximize, center, reasonable size
- Halves, quarters, thirds

### bundle/clipboard_history.lua
Clipboard manager with automatic monitoring:
- Persistent history with fuzzy search
- Support for text, images, files
- File size and line count display
- 3D icons for different file types
- Inherits parent icon as fallback

### bundle/converter.lua
Live transformation actions:
- Time converter (clock icon)
- Color converter (color-palette icon)
- Base64 encoder/decoder (text icon)
- JWT decoder (key icon)

### bundle/utilities.lua
System utilities:
- Toggle caffeinate (cup icon)
- Toggle dark mode (sun icon)
- Generate UUID (key icon)
- Copy IP (wifi icon)
- Network speed test (flash icon)

### bundle/kill_process.lua
Process killer with fuzzy search:
- Real-time process list
- Memory and CPU usage display
- App icons for processes
- Fallback icon for system processes

### bundle/martillo.lua
Martillo management:
- Reload configuration (rocket icon)
- Update Martillo (forward icon)

## Technical Details

### Icon System

**Location**: `lib/icons.lua`

**Key Functions**:
```lua
-- Get icon by name
local icon = icons.getIcon("star")

-- Standard size constant
icons.ICON_SIZE  -- { w = 32, h = 32 }

-- Get all available icons
icons.getAvailableIcons()

-- Clear cache
icons.clearCache()
```

**Icon Inheritance**:
- Parent actions pass their icon to child pickers via `parentIcon` config
- Child items inherit parent icon as fallback
- Specific icons override inherited icons

**File Extension Mapping** (in clipboard_history):
- Uses dictionary `extensionToIcon` for O(1) lookups
- Maps extensions to icon names: pdf→file-text, mp3→music, mp4→video-camera, etc.

### Search System

**Location**: `lib/search.lua`

**Features**:
- Exact match (highest priority)
- Prefix match
- Contains match
- Fuzzy character-by-character matching
- Alias boosting
- Custom scoring adjustments

### Navigation System

**Location**: `lib/navigation.lua`

**Features**:
- Parent-child picker state management
- DELETE/ESC navigation back to parent
- Shift+ESC closes all pickers
- Modifier key detection (Shift, etc.)

## Development Guidelines

### Adding Icons to Actions

```lua
return {
  {
    id = "my_action",
    name = "My Action",
    icon = "star",  -- Icon name from assets/icons/
    description = "Does something cool",
    handler = function()
      -- Action code
    end
  }
}
```

### Using Icons in Code

```lua
local icons = require("lib.icons")

-- Get icon
local myIcon = icons.getIcon("rocket")

-- Use standard size
local size = icons.ICON_SIZE

-- Set on chooser entry
choiceEntry.image = icons.getIcon("copy")
```

### File Extension to Icon Mapping

In `bundle/clipboard_history.lua`, use the dictionary pattern:

```lua
local extensionToIcon = {
  pdf = 'file-text',
  mp3 = 'music',
  mp4 = 'video-camera',
  psd = 'paint-brush',
  -- ... more mappings
}

local iconName = extensionToIcon[extension] or 'file'
local icon = icons.getIcon(iconName)
```

### Parent Icon Inheritance

```lua
-- In parent action
spoon.ActionsLauncher:openChildPicker{
  parentIcon = icons.getIcon('copy'),
  handler = function(query, launcher)
    local parentIcon = launcher:getParentIcon()

    for _, item in ipairs(items) do
      local choice = buildChoice(item)

      -- Fallback to parent icon
      if not choice.image and parentIcon then
        choice.image = parentIcon
      end
    end
  end
}
```

### Code Style

- Use 2-space indentation (with tabs in some files)
- Follow Lua naming conventions (camelCase for functions, PascalCase for classes)
- Add documentation comments for public APIs
- Use `hs.logger` for debugging output
- Handle errors gracefully with `pcall` when appropriate

### Testing

- Test in actual Hammerspoon environment
- Use Hammerspoon Console for debugging
- Test edge cases (app not installed, no network, etc.)
- Verify hotkeys don't conflict

## Important Notes

- This is a pure Lua project - no Node.js, package managers, or build tools
- All spoons follow Hammerspoon's standard spoon structure
- Icon files are in PNG format (50-100KB each)
- Icons are cached automatically by `lib/icons.lua`
- Bundle files use `bundle/` not `presets/` (updated from earlier versions)
- Extension mapping uses dictionary lookups, not if/elseif chains
- Parent icon inheritance allows consistent fallback behavior

## Resources

- [Hammerspoon Documentation](http://www.hammerspoon.org/docs/)
- [Lua 5.4 Reference](https://www.lua.org/manual/5.4/)
- [lazy.nvim](https://github.com/folke/lazy.nvim) - Configuration style inspiration
- [3dicons.co](https://3dicons.co/) - Icon source
