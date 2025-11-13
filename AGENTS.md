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
- **Auto-Launch**: ActionsLauncher opens automatically on Hammerspoon load/reload

### Current Status
- **Beta**: Core functionality is stable and ready for daily use
- Comprehensive set of productivity actions
- Active development with regular improvements
- 11 built-in action bundles with 60+ actions

## Architecture

### Core Structure
- **`martillo.lua`**: Main framework module that handles spoon loading, configuration, and hotkey binding
- **`spoons/`**: Collection of custom Hammerspoon spoons (productivity tools)
- **`bundle/`**: Action bundles (window, system, utilities, converter, keyboard, clipboard_history, etc.)
- **`store/`**: External custom actions directory (folder-based with init.lua)
- **`lib/`**: Shared library modules (icons, search, navigation, leader)
- **`assets/`**: Static resources (120+ 3D icons from 3dicons.co)

### Key Design Patterns

1. **Declarative Configuration**: Users configure everything through a single `require("martillo").setup({ ... })` call

2. **Action Bundles**: Modular action collections in `bundle/` directory that can be selectively imported

3. **Store Structure**: External actions in `store/` as folders with `init.lua` for easy distribution

4. **3D Icon System** (`lib/icons.lua`):
   - 120+ beautiful icons from 3dicons.co in `assets/icons/`
   - `icons.getIcon(name)` - Get icon by name
   - `icons.ICON_SIZE` - Standard icon size ({ w = 32, h = 32 })
   - Automatic caching for performance
   - Parent icon inheritance for child pickers

5. **Leader Key Support**: `<leader>` placeholder in hotkeys expands to configured `leader_key` modifiers

6. **Shared Modules**:
   - `lib/icons.lua` - Icon management with caching
   - `lib/search.lua` - Fuzzy search with ranking
   - `lib/picker.lua` - Picker state management
   - `lib/leader.lua` - Leader key expansion

## Built-in Spoons

### ActionsLauncher
**Purpose**: Searchable command palette with selective action loading, per-action keybindings, and 3D icons

**Key Features**:
- Fuzzy search with alias support
- Beautiful 3D icons for all actions
- Icon inheritance for child pickers
- Per-action keybindings
- Child pickers (query-based transformations)
- Auto-opens on Hammerspoon load/reload

**Configuration**:
```lua
{
  "ActionsLauncher",
  opts = function()
    local window = require("bundle.window")
    local utilities = require("bundle.utilities")
    return { actions = { window, utilities } }
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

### bundle/window.lua
**Description**: Window positioning (halves, quarters, thirds, maximize, center) - 25 actions total
**Self-contained**: All window management logic embedded (no external dependencies)

**Actions**:
- `window_maximize` - Maximize window to full screen
- `window_almost_maximize` - Resize to 90% of screen, centered
- `window_reasonable_size` - Resize to 70% of screen, centered
- `window_center` - Center window without resizing
- `window_left` - Position in left half
- `window_right` - Position in right half
- `window_up` - Position in top half
- `window_down` - Position in bottom half
- `window_top_left` - Position in top left quarter
- `window_top_right` - Position in top right quarter
- `window_bottom_left` - Position in bottom left quarter
- `window_bottom_right` - Position in bottom right quarter
- `window_left_third` - Position in left third
- `window_center_third` - Position in center third
- `window_right_third` - Position in right third
- `window_left_two_thirds` - Position in left two thirds
- `window_right_two_thirds` - Position in right two thirds
- `window_top_third` - Position in top third
- `window_middle_third` - Position in middle third
- `window_bottom_third` - Position in bottom third
- `window_top_two_thirds` - Position in top two thirds
- `window_bottom_two_thirds` - Position in bottom two thirds

### bundle/system.lua
**Description**: System management and monitoring actions

**Actions**:
- `toggle_caffeinate` - Toggle system sleep prevention (tea-cup icon)
- `toggle_system_appearance` - Toggle between light and dark mode (sun icon)
- `system_information` - View real-time system information (desktop-computer icon)
  - CPU usage and load average
  - Memory usage and pressure
  - Battery/Power status
  - Network upload/download speeds
  - Auto-refreshing every 2 seconds

### bundle/utilities.lua
**Description**: Text processing and generation utilities

**Actions**:
- `generate_uuid` - Generate UUID v4 and copy to clipboard (key icon)
- `word_count` - Count characters, words, sentences, and paragraphs (text icon)
  - Auto-pastes clipboard text
  - Real-time updates as you type
  - Shows: characters (with/without spaces), words, sentences, paragraphs, avg words per sentence
  - Formatted numbers with thousands separator

### bundle/converter.lua
**Description**: Live transformation actions with visual previews

**Actions**:
- `converter_time` - Time converter (clock icon)
  - Unix timestamps (seconds/milliseconds)
  - ISO 8601 format
  - RFC 2822 format
  - Human-readable dates (UTC/Local)
  - Relative time
- `converter_colors` - Color converter (color-palette icon)
  - HEX ↔ RGB with color preview swatch
- `converter_base64` - Base64 encoder/decoder (calculator icon)
- `converter_jwt` - JWT decoder (calculator icon)
  - Decodes header and payload

### bundle/keyboard.lua
**Description**: Keyboard management and automation actions

**Actions**:
- `keyboard_lock` - Lock keyboard for cleaning (lock icon)
  - Opens childPicker immediately with unlock instructions
  - Blocks ALL keyboard input except unlock combination
  - Unlock with `<leader>+Enter`
  - Visual feedback with modifier symbols
- `keyboard_keep_alive` - Toggle keep-alive activity simulation (magic-trick icon)
  - Presses F15 every 4 minutes
  - Keeps screen active and apps thinking you're present

### bundle/clipboard_history.lua
**Description**: Clipboard manager with automatic monitoring

**Features**:
- Persistent history with fuzzy search (copy icon)
- Support for text, images, and files
- File size and line count display
- Beautiful 3D icons for different file types
- Automatic clipboard monitoring
- Enter to paste, Shift+Enter to copy only
- Stores up to 300 entries
- File extension mapping for icons

### bundle/kill_process.lua
**Description**: Process killer with fuzzy search

**Features**:
- Real-time process list
- Memory and CPU usage display
- App icons for processes
- Enter to kill, Shift+Enter to copy PID
- Fuzzy search through process names

### bundle/network.lua
**Description**: Network utilities

**Actions**:
- `network_ip_geolocation` - IP geolocation lookup (location icon)
- `network_speed_test` - Network speed test (flash icon)

### bundle/safari_tabs.lua
**Description**: Safari tab management

**Actions**:
- `safari_tabs` - Fuzzy search and switch between Safari tabs
  - Shows all open tabs across windows
  - Quick switch with Enter

### bundle/screen.lua
**Description**: Screen effects and utilities

**Actions**:
- `screen_confetti` - Confetti celebration animation
- `screen_ruler` - On-screen ruler for measurements

### bundle/martillo.lua
**Description**: Martillo framework management

**Actions**:
- `martillo_reload` - Reload Hammerspoon configuration (axe icon)
- `martillo_update` - Pull latest changes from git (axe icon)

## Store Structure (External Actions)

### Purpose
The `store/` directory allows users to create and share custom actions independently of the core bundles.

### Structure
```
store/
  init.lua          # Auto-loader (discovers and loads all modules)
  action_name/
    init.lua        # Returns action array like bundles
  another_action/
    init.lua        # Returns action array like bundles
```

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
          local quote_data = hs.json.decode(body)
          hs.dialog.blockAlert(
            'Quote of the Moment',
            string.format('"%s"\n\n— %s', quote_data.quote, quote_data.author),
            'OK'
          )
        end
      end)
    end,
  },
}
```

### Loading Store Actions
```lua
{
  "ActionsLauncher",
  opts = function()
    local window = require("bundle.window")
    local store = require("store")  -- Auto-loads ALL store actions (lazy loading)

    return { actions = { window, store } }
  end,
}
```

The `store/init.lua` auto-loader uses lazy loading with Lua metatables. At `require` time, it returns a proxy table. When the actions are actually accessed (during ActionsLauncher setup), the metatable triggers directory scanning and module loading. This solves timing issues with `hs.fs` initialization and caches the results for performance.

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

**Location**: `lib/picker.lua`

**Features**:
- Parent-child picker state management
- DELETE/ESC navigation back to parent
- Shift+ESC closes all pickers
- Modifier key detection (Shift, etc.)

### Auto-Launch System

**Location**: `martillo.lua` (setup function)

**Implementation**:
- Timer reference stored in module to prevent garbage collection
- 0.5 second delay ensures all components are loaded
- Automatically opens ActionsLauncher on Hammerspoon load/reload
- No configuration required (default behavior)

### Store Lazy Loading System

**Location**: `store/init.lua`

**Implementation**:
- Returns a proxy table with a metatable at `require` time
- Metatable intercepts table access (`__index`, `__len`, `__ipairs`, `__pairs`)
- Directory scanning and module loading deferred until first access
- Results cached in `loadedActions` for subsequent accesses
- Solves timing issues with `hs.fs` initialization
- Supports all standard Lua table iteration patterns

**Metatable Methods**:
```lua
__index   -- Individual item access: store[1]
__len     -- Length operator: #store
__ipairs  -- Numeric iteration: for i, v in ipairs(store)
__pairs   -- General iteration: for k, v in pairs(store)
```

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

### Creating Store Actions

1. Create a folder in `store/` with your action name
2. Add `init.lua` that returns an action array
3. Use `require("store")` in ActionsLauncher opts (auto-loads all store modules)
4. Actions work exactly like bundle actions
5. The store auto-loader will automatically discover and load your action

### Code Style

- Use tabs for indentation (consistent with existing codebase)
- Follow Lua naming conventions (camelCase for functions, PascalCase for classes)
- Add header comments to bundle files (title + description)
- Use `hs.logger` for debugging output
- Handle errors gracefully with `pcall` when appropriate
- Use `_G.MARTILLO_ALERT_DURATION` for consistent alert timing

### Testing

- Test in actual Hammerspoon environment
- Use Hammerspoon Console for debugging
- Test edge cases (app not installed, no network, etc.)
- Verify hotkeys don't conflict
- Test auto-launch behavior after reload

## Important Notes

- This is a pure Lua project - no Node.js, package managers, or build tools
- All spoons follow Hammerspoon's standard spoon structure
- Icon files are in PNG format (50-100KB each)
- Icons are cached automatically by `lib/icons.lua`
- Bundle files are self-contained when possible (e.g., window.lua)
- Extension mapping uses dictionary lookups, not if/elseif chains
- Parent icon inheritance allows consistent fallback behavior
- ActionsLauncher auto-opens on load - no configuration needed
- Timer references must be stored in module to prevent garbage collection
- Store actions use folder structure: `store/name/init.lua`
- Store auto-loader uses lazy loading with metatables to defer directory scanning
- Lazy loading solves timing issues with `hs.fs` initialization

## Resources

- [Hammerspoon Documentation](http://www.hammerspoon.org/docs/)
- [Lua 5.4 Reference](https://www.lua.org/manual/5.4/)
- [lazy.nvim](https://github.com/folke/lazy.nvim) - Configuration style inspiration
- [3dicons.co](https://3dicons.co/) - Icon source
