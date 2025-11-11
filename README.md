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

	-- ActionsLauncher: Command palette with unified actions interface
	{
		"ActionsLauncher",
		opts = function()
			-- Import preset bundles
			local window_mgmt = require("presets.window_management")
			local utilities = require("presets.utilities")
			local encoders = require("presets.encoders")
			local clipboard = require("presets.clipboard_history")
			local kill_process = require("presets.kill_process")

			-- Martillo automatically flattens nested arrays
			return { actions = { window_mgmt, utilities, encoders, clipboard, kill_process } }
		end,
		actions = {
			-- Window management actions
			{ "window_left_two_thirds", keys = { { "<leader>", "left" } } },
			{ "window_right_two_thirds", keys = { { "<leader>", "right" } } },
			{ "window_almost_maximize", keys = { { "<leader>", "up" } } },
			{ "window_reasonable_size", keys = { { "<leader>", "down" } } },
			{ "window_center", keys = { { "<leader>", "return" } } },
			{ "window_maximize", alias = "wm" },
			{ "window_left_third", alias = "wlt" },
			{ "window_right_third", alias = "wrt" },
			{ "window_center_third", alias = "wct" },
			-- System actions
			{ "toggle_caffeinate", alias = "tc" },
			{ "toggle_system_appearance", alias = "ta" },
			{ "copy_ip", alias = "gi" },
			{ "generate_uuid", alias = "gu" },
			{ "network_status" },
			-- Nested Actions (open child pickers)
			{ "timestamp", alias = "ct" },
			{ "colors", alias = "cc" },
			{ "base64", alias = "cb" },
			{ "jwt", alias = "cj" },
			-- Clipboard history
			{ "clipboard_history", alias = "ch" },
			-- Kill process
			{ "kill_process", alias = "kp" },
		},
		keys = {
			{ "<leader>", "space", desc = "Toggle Actions Launcher" },
		},
	},

	-- LaunchOrToggleFocus: App switching hotkeys
	{
		"LaunchOrToggleFocus",
		keys = {
			{ "<leader>", "c", app = "Calendar" },
			{ "<leader>", "d", app = "Chromium" },
			{ "<leader>", "x", app = "Excalidraw" },
			{ "<leader>", ";", app = "Ghostty" },
			{ "<leader>", "l", app = "Linear" },
			{ "<leader>", "e", app = "Mail" },
			{ "<leader>", "m", app = "Music" },
			{ "<leader>", "n", app = "Notes" },
			{ "<leader>", "p", app = "Postico 2" },
			{ "<leader>", "r", app = "Reminders" },
			{ "<leader>", "b", app = "Safari" },
			{ "<leader>", "s", app = "Slack" },
			{ "<leader>", "t", app = "Kagi Translate" },
			{ "<leader>", "h", app = "Yaak" },
		},
	},

	-- Note: ClipboardHistory and KillProcess are now standalone presets
	-- All clipboard history functionality is in presets/clipboard_history.lua
	-- No separate spoon needed - monitoring starts automatically when preset loads

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
			default_app = "Safari",
			redirect = {
				{ match = { "*localhost*", "*127.0.0.1*", "*0.0.0.0*" }, app = "Chromium" },
				{ match = { "*meet.google*" }, app = "Google Meet" },
			},
			mapper = {
				{ name = "googleToKagiHomepage", from = "*google.com*", to = "https://kagi.com" },
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
Searchable command palette with configurable actions and nested actions support. Features include:
- **Window management**: Maximize, almost maximize, reasonable size, thirds positioning
- **System controls**: Toggle dark mode, caffeinate (prevent sleep)
- **Utilities**: Copy public IP, generate UUID, network status check
- **Nested Actions**: Opens child pickers for real-time transformations
  - Timestamp conversion (unix ↔ ISO format)
  - Color conversion (hex ↔ rgb with visual preview)
  - Base64 encoding/decoding
  - JWT token decoding
- **Navigation**: ESC or DELETE (on empty query) returns to parent picker

### WindowManager
Window positioning and resizing with keyboard shortcuts. Available actions:
- **Halves**: Snap to left, right, top, or bottom half of screen
- **Quarters**: Position in any corner (top-left, top-right, bottom-left, bottom-right)
- **Thirds (horizontal)**: Left, center, or right third; left or right two-thirds
- **Thirds (vertical)**: Top, middle, or bottom third; top or bottom two-thirds
- **Maximize**: Full screen or almost maximize (90% centered)
- **Center**: Center window at current size or reasonable size (60%×70% centered)

### Kill Process
Lightweight process killer implemented as a standalone preset. Features:
- **All-in-one solution**: No separate spoon required - all logic in the preset file
- Fast fuzzy search with process aggregation
- Real-time process list updates
- Process grouping (combines helper processes)
- Memory and CPU usage display
- **Smart selection**: Enter kills process, Shift+Enter copies PID to clipboard
- **Flexible usage**: Works standalone (via keymap) or as a child picker from ActionsLauncher
- **Smart navigation**:
  - When opened from ActionsLauncher: DELETE/ESC navigates back to parent, Enter kills process and closes both pickers
  - When opened from keymap: DELETE/ESC and Enter both close the picker after action
  - Shift+ESC always closes all pickers
- No external dependencies required

### Clipboard History
Lightweight clipboard manager implemented as a standalone preset. Features:
- **All-in-one solution**: No separate spoon required - all logic in the preset file
- Fast fuzzy search entirely in Lua
- Simple plain text storage (fish_history-like format)
- Support for text, images, and file paths
- **Auto-start monitoring**: Clipboard watcher starts automatically when preset loads
- **Smart selection**: Enter pastes to focused window, Shift+Enter copies to clipboard only
- **Flexible usage**: Works standalone (via keymap) or as a child picker from ActionsLauncher
- **Smart navigation**:
  - When opened from ActionsLauncher: DELETE/ESC navigates back to parent, Enter closes both pickers
  - When opened from keymap: DELETE/ESC and Enter both close the picker
  - Shift+ESC always closes all pickers
- **Image caching**: Images loaded once and cached for performance
- No external dependencies required
- Human-readable history file at `~/.martillo/presets/clipboard_history`
- Screenshots saved to `~/.martillo/presets/clipboard_images/`

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

Note: ClipboardHistory and KillProcess have been converted to lightweight presets and no longer require separate spoons.

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

The ActionsLauncher uses preset bundles that can be imported on demand. Available presets:
- **`presets.window_management`** - Window positioning and resizing actions
- **`presets.utilities`** - System utilities (caffeinate, dark mode, IP, UUID, network status)
- **`presets.encoders`** - Encoder/decoder actions (timestamp, base64, JWT, colors)
- **`presets.clipboard_history`** - Standalone clipboard history with auto-start monitoring
- **`presets.kill_process`** - Process killer with fuzzy search and real-time updates

#### Import All Presets

Martillo automatically flattens nested action arrays, so you can simply pass an array of preset bundles:

```lua
{
	"ActionsLauncher",
	opts = function()
		-- Import all preset bundles
		local window_mgmt = require("presets.window_management")
		local utilities = require("presets.utilities")
		local encoders = require("presets.encoders")
		local clipboard = require("presets.clipboard_history")
		local kill_process = require("presets.kill_process")

		-- Martillo automatically flattens nested arrays
		return { actions = { window_mgmt, utilities, encoders, clipboard, kill_process } }
	end,
	actions = {
		-- Filter and customize with keybindings and aliases
		{ "window_left_two_thirds", keys = { { "<leader>", "left" } } },
		{ "window_right_two_thirds", keys = { { "<leader>", "right" } } },
		{ "window_center", keys = { { "<leader>", "return" } } },
		{ "window_maximize", alias = "wm" },

		-- Nested Actions
		{ "timestamp", alias = "ct" },
		{ "colors", alias = "cc" },
		{ "base64", alias = "cb" },
		{ "jwt", alias = "cj" },

		-- Clipboard and process management
		{ "clipboard_history", alias = "ch" },
		{ "kill_process", alias = "kp" },
	},
	keys = {
		{ "<leader>", "space", desc = "Toggle Actions Launcher" }
	},
}
```

#### Import Specific Presets

You can also import only the presets you need:

```lua
{
	"ActionsLauncher",
	opts = function()
		-- Import only window management and utilities
		local window_mgmt = require("presets.window_management")
		local utilities = require("presets.utilities")

		return { actions = { window_mgmt, utilities } }
	end,
	actions = {
		{ "window_maximize", alias = "wm" },
		{ "toggle_caffeinate", alias = "tc" },
	},
	keys = {
		{ "<leader>", "space", desc = "Toggle Actions Launcher" }
	},
}
```

#### Custom Actions

You can also provide your own custom actions array:

```lua
{
	"ActionsLauncher",
	opts = {
		actions = {
			{
				id = "my_action",
				name = "My Custom Action",
				description = "Does something custom",
				handler = function()
					hs.alert.show("Custom action!")
				end,
			},
		},
	},
	keys = {
		{ "<leader>", "space", desc = "Toggle Actions Launcher" }
	},
}
```

**Actions Format:**
- Each action can be a string (action ID) or a table with `{ "action_id", keys = { ... }, alias = "..." }`
- All actions (both static and dynamic) can have aliases for faster search
- All actions can have optional keybindings using the `keys` field
- Static actions execute immediately when selected
- Nested Actions open a child picker where user input is processed in real-time
- Keybindings use the same format as spoon keys and support `<leader>` expansion
- If no `actions` filter is provided, all actions from `opts` are loaded

**Child Picker Navigation:**

The behavior depends on how the child picker was opened:

*With parent (opened from ActionsLauncher):*
- Type to provide input for Nested Actions
- **Enter**: Execute action and close both child and parent pickers
- **Shift+Enter**: Execute action with alternate behavior and close both pickers
- **DELETE/ESC** (when query is empty): Navigate back to parent picker
- **Shift+ESC**: Close all pickers immediately

*Without parent (opened directly from keymap):*
- Type to provide input
- **Enter**: Execute action and close the picker
- **Shift+Enter**: Execute action with alternate behavior and close the picker
- **DELETE/ESC** (when query is empty): Close the picker
- **Shift+ESC**: Close the picker

**Action Examples:**

See the detailed examples below for how to implement static and Nested Actions. All available preset actions can be found in the [`presets/`](presets/) directory:
- [`presets/window_management.lua`](presets/window_management.lua) - Window positioning actions
- [`presets/utilities.lua`](presets/utilities.lua) - System utilities
- [`presets/encoders.lua`](presets/encoders.lua) - Encoder/decoder actions
- [`presets/clipboard_history.lua`](presets/clipboard_history.lua) - Standalone clipboard history (no spoon needed)
- [`presets/kill_process.lua`](presets/kill_process.lua) - Standalone process killer (no spoon needed)

#### Static Actions

Static actions execute immediately when selected:

```lua
{
	id = "reload_config",
	name = "Reload Config",
	description = "Reload Hammerspoon configuration",
	alias = "rc",
	handler = function()
		hs.reload()
		return "Config reloaded"
	end
}
```

### Global Options

```lua
return require("martillo").setup({
	-- Global options (non-numeric keys)
	autoReload = true,               -- Auto-reload on file change (default: true)
	alertOnLoad = true,              -- Show alert when config loads (default: true)
	alertMessage = "Martillo is ready", -- Custom load message
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
- [x] Process killer with fuzzy search (as preset)
- [x] Clipboard history with search and paste (as preset)
- [x] Upcoming meetings display in menu bar
- [x] Browser routing rules based on URL patterns
- [x] Link transformation rules before opening

### Framework Improvements
- [x] **Precompiled Spoons** - All spoons loaded and compiled by default
- [x] **Simplified Configuration** - Single table configuration like lazy.nvim
- [x] **Spoon Aliases** - Set custom aliases for each spoon
- [x] **Enhanced Search** - Search by aliases in choosers
- [x] **Alias Display** - Show aliases in chooser items (right side)
- [x] **Nested Choosers** - Child choosers with parent context preservation
- [x] **Unified Actions Interface** - Single `actions` array for static and Nested Actions
- [x] **Nested Choosers** - Don't close on action if child process spawns
- [x] **Main Launcher** - Central chooser listing all actions and nested actions

### Enhanced Chooser System
- [ ] **Fork Hammerspoon** - Custom build with enhanced chooser capabilities
- [ ] **Scroll listeners**:
  - `onScrollTop` - Trigger when scrolling to top
  - `onScrollBottom` - Trigger when scrolling to bottom
  - `onBack` - Navigation back button for nested choosers
- [ ] **Smart Refresh** - Refresh picker choices without losing scroll position

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
