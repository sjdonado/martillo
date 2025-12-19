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

4. **Icon System** (`lib/icons.lua`):
   - 120+ beautiful icons from 3dicons.co in `assets/icons/`
   - `icons.preset.iconName` - Get absolute path to preset icon
   - `icons.getIcon(path)` - Load icon from absolute path
   - `icons.ICON_SIZE` - Standard icon size ({ w = 32, h = 32 })
   - Automatic discovery from `assets/icons/` and `store/*/` directories
   - Store icons can override default icons
   - Automatic caching for performance

5. **Leader Key Support**: `<leader>` placeholder in hotkeys expands to configured `leader_key` modifiers

6. **Child Chooser Pattern**: Actions that open child choosers call `spoon.ActionsLauncher:openChildChooser({...})` without needing to return any value. The framework automatically detects when a child chooser is opened and manages the navigation stack internally.

7. **Action Events** (`lib/events.lua`):
   - `events.copyToClipboard(getText?)` - Copy to clipboard with toast
   - `events.copyAndPaste(getText?)` - Copy + paste with Shift modifier support
   - `events.showToast(getMessage?)` - Show toast message
   - `events.noAction()` - Display-only (no action on Enter)
   - `events.custom(fn)` - Custom handler function

8. **Action Options System**:
   - Actions can define default options via `opts` field
   - Users can override options in their config: `{ "action_id", opts = { option_name = value } }`
   - Options are merged by `martillo.lua` during action processing
   - Access options via `events.getActionOpt(actionId, optionName, defaultValue)`
   - Common option: `success_toast` (default: true) - disable success toast notifications

9. **Shared Modules**:
   - `lib/icons.lua` - Icon management with automatic discovery and caching
   - `lib/events.lua` - Composable action helpers for common patterns + action options helper
   - `lib/search.lua` - Fuzzy search with ranking
   - `lib/chooser.lua` - Chooser state management (stack-based navigation with Tab support)
   - `lib/leader.lua` - Leader key expansion
   - `lib/thumbnail_cache.lua` - Disk-based thumbnail caching with memory limits
   - `lib/toast.lua` - Toast notification helpers

## Built-in Spoons

### ActionsLauncher
**Purpose**: Searchable command palette with selective action loading, per-action keybindings, and 3D icons

**Key Features**:
- Fuzzy search with alias support
- Beautiful 3D icons for all actions
- Icon inheritance for child choosers
- Per-action keybindings
- Child choosers (query-based transformations)
- Auto-opens on Hammerspoon load/reload

**Configuration**:
```lua
{
  "ActionsLauncher",
  actions = {
    { "window_center", keys = { { "<leader>", "return" } } },
    { "clipboard_history", alias = "ch" },
    { "f1_standings", alias = "f1" },  -- From store/
  },
  keys = { { "<leader>", "space", desc = "Toggle Actions Launcher" } }
}
```

**Note:** All bundles from `bundle/` and custom actions from `store/` are automatically loaded. You don't need to manually import them!

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
**Description**: Window positioning (halves, quarters, thirds, maximize, center) - 26 actions total
**Self-contained**: All window management logic embedded (no external dependencies)

**Actions**:
- `window_maximize` - Maximize window to full screen
- `window_almost_maximize` - Resize to 90% of screen, centered
- `window_reasonable_size` - Resize to 70% of screen, centered
- `window_center` - Center window without resizing
- `window_maximize_horizontal` - Maximize width (keep height and Y position)
- `window_maximize_vertical` - Maximize height (keep width and X position)
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
  - Opens childChooser immediately with unlock instructions
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
- Automatic clipboard monitoring
- Enter to paste, Shift+Enter to copy only
- Stores up to 150 entries (configurable via `M.maxEntries`)
- File extension mapping for icons
- Thumbnail caching for images (limit: 30 per session for performance)
- History file: `~/.martillo_clipboard_history`
- Image assets folder: `~/.martillo_clipboard_history_assets`

### bundle/kill_process.lua
**Description**: Process manager with accurate memory display (matches Activity Monitor)

**Features**:
- Real-time process list sorted by memory usage (descending)
- Accurate memory values using `top` command (matches Activity Monitor)
- Full command paths from `ps` command (for process identification)
- Enter to kill process, Shift+Enter to copy PID
- Fuzzy search through process names
- Limit: 150 processes (configurable via `M.maxResults`)
- Refresh interval: 2 seconds while picker is open
- Icons disabled for performance (uses single default icon)

**Process Naming**:
- **Interpreters** (node, python, ruby): Shows script name in parentheses
  - `node (tsserver.js)`, `python (script.py)`, `ruby (server.rb)`
- **Safari WebKit processes**: Shows domain from open tabs via AppleScript
  - `Safari (github.com)`, `Safari (autarc-grafana.fly.dev)`
  - Falls back to `Safari (WebContent)` if no domains available
- **Electron apps**: Detected via `app.asar` pattern
  - `AppName (Electron)`

**Technical Details**:
- Uses `top -l 1 -stats pid,ppid,cpu,mem` for memory (shows real memory including compressed)
- Uses `ps -axo pid,command` for full command paths (needed for process identification)
- Safari domains extracted via AppleScript: `osascript -e 'tell application "Safari" to get URL of every tab of every window'`
- No process aggregation - each process shown separately like Activity Monitor

**Why `top` instead of `ps` for memory**:
- `ps` RSS (Resident Set Size) only counts physical memory pages in RAM
- `top` MEM includes compressed memory, proportional shared memory
- Example: Postico shows 58MB with `ps` but 104MB with `top` (matching Activity Monitor)

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

### Example: store/f1_standings/init.lua
```lua
-- F1 Drivers Championship Standings
local toast = require 'lib.toast'
local events = require 'lib.events'
local icons = require 'lib.icons'

return {
  {
    id = 'f1_standings',
    name = 'F1 Drivers Standings',
    icon = icons.preset.trophy,
    description = 'View current F1 drivers championship standings',
    handler = function()
      local actionsLauncher = spoon.ActionsLauncher
      local standings = {}

      actionsLauncher:openChildChooser {
        placeholder = 'F1 Drivers Championship 2024',
        handler = function(query, launcher)
          local choices = {}
          for _, entry in ipairs(standings) do
            local uuid = launcher:generateUUID()
            table.insert(choices, {
              text = string.format('P%d. %s %s - %d pts',
                entry.position, entry.driver.name,
                entry.driver.surname, entry.points),
              subText = string.format('%s • %d wins',
                entry.team.teamName, entry.wins),
              uuid = uuid,
            })
            launcher.handlers[uuid] = events.copyToClipboard(function()
              return string.format('%s %s - P%d',
                entry.driver.name, entry.driver.surname, entry.position)
            end)
          end
          return choices
        end,
      }

      hs.http.asyncGet('https://f1connectapi.vercel.app/api/current/drivers-championship',
        nil, function(status, body)
          if status == 200 then
            standings = hs.json.decode(body).drivers_championship
            actionsLauncher:refresh()
          end
        end)
    end,
  },
}
```

### Store Actions (Custom Actions)

All actions in `store/` are **automatically loaded** by Martillo. Just drop a new folder with an `init.lua` file and it's ready to use:

**Store Structure**:
```
store/
  f1_standings/     # F1 Drivers Championship (included example)
    init.lua
  my_action/        # Your custom action
    init.lua
    icon.png        # Optional custom icon
```

**Usage in Config**:
```lua
{
  "ActionsLauncher",
  actions = {
    { "f1_standings", alias = "f1" },  -- Automatically available!
    { "my_action", keys = { { "<leader>", "a" } } },
  },
}
```

**How It Works**: The `store/init.lua` auto-loader uses lazy loading with Lua metatables. At `require` time, it returns a proxy table. When actions are accessed (during ActionsLauncher setup), the metatable triggers directory scanning and module loading. This solves timing issues with `hs.fs` initialization and caches results for performance.

## Technical Details

### Icon System

**Location**: `lib/icons.lua`

**Key Features**:
- Automatic discovery from `assets/icons/` and `store/*/` directories
- Store icons can override default icons with the same name
- All icon fields expect absolute paths
- Preset icons accessible via `icons.preset.iconName`

**Usage**:
```lua
local icons = require 'lib.icons'

-- Get preset icon path
local iconPath = icons.preset.wifi

-- Load icon from path
local icon = icons.getIcon(iconPath)

-- Use in actions
return {
  {
    icon = icons.preset.star,  -- Preset icon
    -- OR
    icon = '/custom/path/icon.png',  -- Custom absolute path
  }
}

-- Standard size constant
icons.ICON_SIZE  -- { w = 32, h = 32 }

-- Clear cache and rebuild presets
icons.clearCache()
```

**Custom Icons in Store**:
- Place `.png` files in store action directories
- Accessible via `icons.preset.filename` (without extension)
- Override default icons automatically

### Action Events System

**Location**: `lib/events.lua`

**Purpose**: Composable helpers for common child chooser action patterns and action option management

**Action Handlers**:
```lua
local events = require 'lib.events'

-- Copy to clipboard
launcher.handlers[uuid] = events.copyToClipboard()

-- Copy to clipboard (custom text extraction)
launcher.handlers[uuid] = events.copyToClipboard(function(choice)
  return myData.value
end)

-- Copy and paste (Shift modifier support)
launcher.handlers[uuid] = events.copyAndPaste()

-- Display only (no action)
launcher.handlers[uuid] = events.noAction()

-- Custom handler
launcher.handlers[uuid] = events.custom(function(choice)
  -- Custom logic here
end)
```

**Action Options Helper**:
```lua
-- Get action option with default fallback
local showToast = events.getActionOpt('action_id', 'success_toast', true)

-- Looks up the action in ActionsLauncher.actions array
-- Returns the option value or defaultValue if not found
-- Handles nil checks and iteration internally
```

**Common Action Options**:
- `success_toast` (boolean, default: true) - Show success toast notifications
  - Supported by: `switch_window`, `safari_tabs`, `kill_process`, `keyboard_lock`, `keyboard_keep_alive`
  - Usage: `{ "switch_window", opts = { success_toast = false } }`

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

**Location**: `lib/chooser.lua`

**Features**:
- Stack-based navigation (single source of truth)
- Parent-child chooser state management
- ESC navigation: pop from stack and restore parent
- Shift+ESC: close all choosers and clear stack
- Click-outside: close all choosers and clear stack
- Tab navigation: navigate to next item, Shift+Tab to previous
- Modifier key detection (Shift for alternate actions in child choosers)

**Implementation**: ESC Interception with `hs.eventtap`

The navigation system uses a global keyboard event tap to intercept ESC before it reaches the chooser, allowing us to distinguish between three close scenarios:

**How it works**:

1. **eventtap intercepts ESC keypress** (keycode 53)
   ```lua
   hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
     if event:getKeyCode() == 53 then
       if event:getFlags().shift then
         return false  -- Let Shift+ESC through
       else
         return true   -- Consume plain ESC
       end
     end
   end)
   ```

2. **Three distinct behaviors**:
   - **ESC alone**: Event consumed → chooser stays open → navigation callback fires → manually pop stack and restore parent
   - **Shift+ESC**: Event propagates → chooser closes → hideCallback fires → clears stack
   - **Click outside**: No keyboard event → chooser closes → hideCallback fires → clears stack

3. **Stack state determines hideCallback behavior**:
   ```lua
   function M:shouldKeepStack()
     return #self.stack > 0
   end
   ```

   When `hideCallback` fires, it checks stack depth:
   - **Stack depth > 0**: ESC navigation in progress (popped current, parent still in stack) → keep stack
   - **Stack depth = 0**: Normal close (Shift+ESC, click-outside, or last chooser) → clear stack and stop eventtap

**Why this approach works**:

✅ **No external flags needed** - Stack depth IS the state
✅ **No race conditions** - Decision is synchronous based on keyboard event
✅ **Clear separation** - ESC intercepted vs Shift+ESC/click-outside handled by chooser
✅ **Self-documenting** - `shouldKeepStack()` clearly expresses intent
✅ **Centralized state** - All navigation logic contained in `lib/chooser.lua`

**Navigation flow**:

```
ESC Navigation (depth 2 → 1):
  User presses ESC
  → eventtap consumes event (returns true)
  → navigation callback: pop stack (depth becomes 1)
  → navigation callback: hide current chooser
  → hideCallback fires: shouldKeepStack() = true (depth = 1)
  → hideCallback: skips clear() call
  → timer restores parent chooser

Shift+ESC (depth 2 → 0):
  User presses Shift+ESC
  → eventtap lets event through (returns false)
  → chooser closes normally
  → hideCallback fires: shouldKeepStack() = false (depth = 2)
  → hideCallback: calls clear(), stops eventtap

Click Outside (depth 2 → 0):
  User clicks outside
  → chooser closes (no keyboard event)
  → hideCallback fires: shouldKeepStack() = false (depth = 2)
  → hideCallback: calls clear(), stops eventtap
```

**Stack pollution prevention**:

When the main launcher opens, it always clears any dirty stack:
```lua
if self.chooserManager:depth() > 0 then
  self.chooserManager:clear()
end
```

This handles cases where click-outside leaves stack items (because `shouldKeepStack()` returns true when depth > 0, even from click-outside of a child chooser).

**Key methods**:

- `startEscInterception(onNavigate)` - Starts eventtap, stores navigation callback
- `stopEscInterception()` - Stops and cleans up eventtap
- `startTabInterception()` - Starts Tab key interception for navigation
- `stopTabInterception()` - Stops Tab key interception
- `stopAllInterceptions()` - Stops both ESC and Tab interception
- `shouldKeepStack()` - Returns true if stack depth > 0 (ESC navigation in progress)

**Tab Navigation Implementation**:

Tab key navigation is implemented using `hs.eventtap` to intercept Tab and Shift+Tab key presses before they reach the chooser:

1. **Tab (keycode 48)**: Moves to next item by directly calling `chooser:selectedRow(currentRow + 1)`
2. **Shift+Tab**: Moves to previous item by calling `chooser:selectedRow(currentRow - 1)`

**Why direct row manipulation**:
- ❌ **Keystroke simulation failed**: Simulating Down/Up arrows with `hs.eventtap.keyStroke()` from within the event tap callback didn't reach the chooser properly
- ❌ **Querying choices failed**: Calling `chooser:choices()` from within event tap caused "incorrect number of arguments" error
- ✅ **Direct row setting works**: `chooser:selectedRow()` getter/setter works reliably from event tap callbacks
- ✅ **No wrapping needed**: The chooser handles out-of-bounds row numbers gracefully

**Implementation**:
```lua
-- Get current row
local currentRow = self.currentChooser:selectedRow()

-- Set new row (increment for Tab, decrement for Shift+Tab)
self.currentChooser:selectedRow(currentRow + 1)
```

**Secure input limitation**: Tab and ESC interception won't work in password fields or when macOS secure input is enabled (Hammerspoon API limitation)

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

### Adding Action Options

Actions can define configurable options that users can override in their config:

**Define default options in action**:
```lua
return {
  {
    id = 'my_action',
    name = 'My Action',
    icon = icons.preset.star,
    opts = {
      success_toast = true,  -- Default value
      custom_option = 'default',
    },
    handler = function()
      local events = require 'lib.events'

      -- Get option with fallback to default
      local showToast = events.getActionOpt('my_action', 'success_toast', true)
      local customValue = events.getActionOpt('my_action', 'custom_option', 'default')

      -- Use options in your logic
      if showToast then
        toast.success('Action completed!')
      end
    end,
  },
}
```

**User override in config**:
```lua
{
  "ActionsLauncher",
  actions = {
    { "my_action", opts = { success_toast = false, custom_option = 'custom' } },
  },
}
```

**How it works**:
1. Action defines default `opts` in bundle file
2. User provides overrides in config
3. `martillo.lua` merges user opts with action opts during `processActionFilters()`
4. Action handler calls `events.getActionOpt()` to retrieve merged value
5. Returns user value if set, otherwise default value

### Adding Icons to Actions

```lua
local icons = require 'lib.icons'

return {
  {
    id = "my_action",
    name = "My Action",
    icon = icons.preset.star,  -- Use preset icon
    description = "Does something cool",
    handler = function()
      -- Action code
    end
  }
}
```

### Using Icons in Code

```lua
local icons = require 'lib.icons'

-- Get preset icon path
local iconPath = icons.preset.rocket

-- Load icon from path
local myIcon = icons.getIcon(iconPath)

-- Use custom absolute path
local customIcon = icons.getIcon('/path/to/custom/icon.png')

-- Use standard size
local size = icons.ICON_SIZE

-- Set on chooser entry
choiceEntry.image = icons.getIcon(icons.preset.copy)
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
spoon.ActionsLauncher:openChildChooser{
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

## Performance Considerations

### Icon Loading
- **Problem**: Loading icons via `hs.application.applicationForPID()` and `thumbnailCache.getCachedAppIcon()` is slow
- **Solution**: For performance-critical pickers (like kill_process), use a single default icon for all entries
- **Trade-off**: Faster picker opening vs visual richness

### Thumbnail Caching (`lib/thumbnail_cache.lua`)
- Disk-based caching in `/tmp/martillo/{user}/thumbnails/`
- Memory limits configurable per subdirectory: `thumbnailCache.setMaxLoaded('images', 30)`
- Reset counts between sessions: `thumbnailCache.resetLoadedCount('images')`
- Fallback icons when limit reached: `thumbnailCache.getFallbackIcon(key, loaderFn)`

### Process Memory Values
- **`ps` RSS**: Only physical memory pages in RAM (inaccurate)
- **`top` MEM**: Real memory including compressed and proportional shared (accurate)
- Always use `top` when memory values need to match Activity Monitor

### Chooser Refresh Intervals
- Too frequent refreshes (e.g., 1 second) cause noticeable lag
- Recommended: 2+ seconds for auto-refreshing pickers
- Use cached data and only refresh on explicit user action when possible

### Entry Limits
- Large lists (200+ entries) slow down chooser rendering
- Recommended limits: 150 entries for process lists, 150 for clipboard history
- Apply limits AFTER sorting to show most relevant entries

## Resources

- [Hammerspoon Documentation](http://www.hammerspoon.org/docs/)
- [Lua 5.4 Reference](https://www.lua.org/manual/5.4/)
- [lazy.nvim](https://github.com/folke/lazy.nvim) - Configuration style inspiration
- [3dicons.co](https://3dicons.co/) - Icon source
