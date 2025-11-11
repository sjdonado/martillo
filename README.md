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
			return require("actions")
		end,
		actions = {
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
			-- Dynamic actions (open child pickers)
			{ "timestamp", alias = "ts" },
			{ "colors", alias = "color" },
			{ "base64", alias = "b64" },
			{ "jwt", alias = "jwt" },
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
Searchable command palette with configurable actions and nested picker support. Features include:
- **Window management**: Maximize, almost maximize, reasonable size, thirds positioning
- **System controls**: Toggle dark mode, caffeinate (prevent sleep)
- **Utilities**: Copy public IP, generate UUID, network status check
- **Dynamic actions**: Opens child pickers for real-time transformations
  - Timestamp conversion (unix ↔ ISO format)
  - Color conversion (hex ↔ rgb with visual preview)
  - Base64 encoding/decoding
  - JWT token decoding
- **Navigation**: ESC or DELETE (on empty query) returns to parent picker

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

The ActionsLauncher uses a unified `actions` interface for both static and dynamic actions:

```lua
{
	"ActionsLauncher",
	opts = function()
		return require("actions")  -- Load all available actions
	end,
	actions = {
		-- Static actions with optional keybindings and aliases
		"maximize_window",                                            -- Enable without keybinding
		{ "center_window", keys = { { "<leader>", "return" } } },     -- With keybinding
		{ "window_left_third", keys = { { "<leader>", "left" } } },   -- Window to left third
		{ "window_right_third", keys = { { "<leader>", "right" } } }, -- Window to right third

		-- Dynamic actions (open child pickers) with aliases
		{ "timestamp", alias = "ts" },    -- Unix timestamp converter
		{ "colors", alias = "color" },    -- Color format converter
		{ "base64", alias = "b64" },      -- Base64 encoder/decoder
		{ "jwt", alias = "jwt" },         -- JWT token decoder
	},
	keys = {
		{ "<leader>", "\\", desc = "Toggle Actions Launcher" }
	},
}
```

**Actions Format:**
- Each action can be a string (action ID) or a table with `{ "action_id", keys = { ... }, alias = "..." }`
- All actions (both static and dynamic) can have aliases for faster search
- All actions can have optional keybindings using the `keys` field
- Static actions execute immediately when selected
- Dynamic actions open a child picker where user input is processed in real-time
- Keybindings use the same format as spoon keys and support `<leader>` expansion
- If no `actions` filter is provided, all actions from `opts` are loaded

**Child Picker Navigation:**
- Type to provide input for dynamic actions
- **ESC**: Close child picker and return to parent
- **DELETE** (when query is empty): Return to parent picker

**Action Examples:**

See the detailed examples below for how to implement static and dynamic actions. A full list of available actions is in [`actions.lua`](actions.lua).

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

#### Dynamic Actions (Child Picker Pattern)

Dynamic actions open a child picker where user input is processed in real-time. Here are examples of the built-in dynamic actions:

**Timestamp Converter:**

```lua
{
	id = "timestamp",
	name = "Timestamp Converter",
	description = "Convert unix timestamp to date",
	alias = "ts",
	isDynamic = true,
	handler = function()
		ActionsLauncher:openChildPicker({
			placeholder = "Enter unix timestamp...",
			parentAction = "timestamp",
			handler = function(query, launcher)
				if not query or query == "" then
					return {}
				end

				local timestamp = tonumber(query)
				if not timestamp then
					return {
						{
							text = "Invalid timestamp",
							subText = "Enter a valid unix timestamp",
							uuid = launcher:generateUUID()
						}
					}
				end

				local date = os.date("%Y-%m-%d %H:%M:%S", timestamp)
				local relativeTime = os.time() - timestamp
				local uuid = launcher:generateUUID()

				launcher.handlers[uuid] = function()
					hs.pasteboard.setContents(date)
					return "Copied: " .. date
				end

				return {
					{
						text = date,
						subText = string.format("%.0f seconds ago", relativeTime),
						uuid = uuid,
						copyToClipboard = true
					}
				}
			end
		})
		return "OPEN_CHILD_PICKER"
	end
}
```

**Color Converter (Hex ↔ RGB):**

```lua
{
	id = "colors",
	name = "Color Converter",
	description = "Convert between color formats (hex, rgb)",
	alias = "color",
	isDynamic = true,
	handler = function()
		ActionsLauncher:openChildPicker({
			placeholder = "Enter color (hex or rgb)...",
			parentAction = "colors",
			handler = function(query, launcher)
				if not query or query == "" then
					return {}
				end

				local results = {}

				-- Try to parse as hex color (#RRGGBB or RRGGBB)
				local hex = query:match("^#?([%x][%x][%x][%x][%x][%x])$")
				if hex then
					local r = tonumber(hex:sub(1, 2), 16)
					local g = tonumber(hex:sub(3, 4), 16)
					local b = tonumber(hex:sub(5, 6), 16)

					local rgbUuid = launcher:generateUUID()
					launcher.handlers[rgbUuid] = function()
						local rgb = string.format("rgb(%d, %d, %d)", r, g, b)
						hs.pasteboard.setContents(rgb)
						return "Copied: " .. rgb
					end

					table.insert(results, {
						text = string.format("rgb(%d, %d, %d)", r, g, b),
						subText = "RGB format",
						uuid = rgbUuid,
						image = launcher:createColorSwatch(r, g, b),
						copyToClipboard = true
					})
				end

				-- Try to parse as RGB (rgb(r, g, b))
				local r, g, b = query:match("rgb%s*%((%d+)%s*,%s*(%d+)%s*,%s*(%d+)%)")
				if r and g and b then
					r, g, b = tonumber(r), tonumber(g), tonumber(b)

					local hexUuid = launcher:generateUUID()
					launcher.handlers[hexUuid] = function()
						local hex = string.format("#%02X%02X%02X", r, g, b)
						hs.pasteboard.setContents(hex)
						return "Copied: " .. hex
					end

					table.insert(results, {
						text = string.format("#%02X%02X%02X", r, g, b),
						subText = "Hex format",
						uuid = hexUuid,
						image = launcher:createColorSwatch(r, g, b),
						copyToClipboard = true
					})
				end

				if #results == 0 then
					return {
						{
							text = "Invalid color format",
							subText = "Try: #FF5733 or rgb(255, 87, 51)",
							uuid = launcher:generateUUID()
						}
					}
				end

				return results
			end
		})
		return "OPEN_CHILD_PICKER"
	end
}
```

**Base64 Encoder/Decoder:**

```lua
{
	id = "base64",
	name = "Base64 Encoder/Decoder",
	description = "Encode or decode base64",
	alias = "b64",
	isDynamic = true,
	handler = function()
		ActionsLauncher:openChildPicker({
			placeholder = "Enter text to encode/decode...",
			parentAction = "base64",
			handler = function(query, launcher)
				if not query or query == "" then
					return {}
				end

				local results = {}

				-- Encode
				local encoded = hs.base64.encode(query)
				local encodeUuid = launcher:generateUUID()
				launcher.handlers[encodeUuid] = function()
					hs.pasteboard.setContents(encoded)
					return "Copied encoded"
				end

				table.insert(results, {
					text = encoded,
					subText = "Base64 Encoded",
					uuid = encodeUuid,
					copyToClipboard = true
				})

				-- Try to decode
				local success, decoded = pcall(function()
					return hs.base64.decode(query)
				end)

				if success and decoded then
					local decodeUuid = launcher:generateUUID()
					launcher.handlers[decodeUuid] = function()
						hs.pasteboard.setContents(decoded)
						return "Copied decoded"
					end

					table.insert(results, {
						text = decoded,
						subText = "Base64 Decoded",
						uuid = decodeUuid,
						copyToClipboard = true
					})
				end

				return results
			end
		})
		return "OPEN_CHILD_PICKER"
	end
}
```

**JWT Decoder:**

```lua
{
	id = "jwt",
	name = "JWT Decoder",
	description = "Decode JWT token",
	alias = "jwt",
	isDynamic = true,
	handler = function()
		ActionsLauncher:openChildPicker({
			placeholder = "Paste JWT token...",
			parentAction = "jwt",
			handler = function(query, launcher)
				if not query or query == "" then
					return {}
				end

				local parts = {}
				for part in query:gmatch("[^.]+") do
					table.insert(parts, part)
				end

				if #parts ~= 3 then
					return {
						{
							text = "Invalid JWT",
							subText = "JWT must have 3 parts separated by dots",
							uuid = launcher:generateUUID()
						}
					}
				end

				local results = {}

				-- Decode header
				local headerSuccess, header = pcall(function()
					return hs.base64.decode(parts[1])
				end)

				if headerSuccess and header then
					local headerUuid = launcher:generateUUID()
					launcher.handlers[headerUuid] = function()
						hs.pasteboard.setContents(header)
						return "Copied header"
					end

					table.insert(results, {
						text = header,
						subText = "JWT Header",
						uuid = headerUuid,
						copyToClipboard = true
					})
				end

				-- Decode payload
				local payloadSuccess, payload = pcall(function()
					return hs.base64.decode(parts[2])
				end)

				if payloadSuccess and payload then
					local payloadUuid = launcher:generateUUID()
					launcher.handlers[payloadUuid] = function()
						hs.pasteboard.setContents(payload)
						return "Copied payload"
					end

					table.insert(results, {
						text = payload,
						subText = "JWT Payload",
						uuid = payloadUuid,
						copyToClipboard = true
					})
				end

				if #results == 0 then
					return {
						{
							text = "Failed to decode JWT",
							subText = "Invalid base64 encoding",
							uuid = launcher:generateUUID()
						}
					}
				end

				return results
			end
		})
		return "OPEN_CHILD_PICKER"
	end
}
```

### Global Options

```lua
return require("martillo").setup({
	-- Global options (non-numeric keys)
	autoReload = true,               -- Auto-reload on file change (default: true)
	alertOnLoad = true,              -- Show alert when config loads (default: true)
	alertMessage = "Martillo Ready", -- Custom load message
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
- [x] **Precompiled Spoons** - All spoons loaded and compiled by default
- [x] **Simplified Configuration** - Single table configuration like lazy.nvim
- [x] **Spoon Aliases** - Set custom aliases for each spoon
- [x] **Enhanced Search** - Search by aliases in choosers
- [x] **Alias Display** - Show aliases in chooser items (right side)
- [x] **Nested Choosers** - Child choosers with parent context preservation
- [x] **Unified Actions Interface** - Single `actions` array for static and dynamic actions
- [x] **Nested Choosers** - Don't close on action if child process spawns

### Enhanced Chooser System
- [ ] **Fork Hammerspoon** - Custom build with enhanced chooser capabilities
- [ ] **Navigation Callbacks**:
  - `onScrollTop` - Trigger when scrolling to top
  - `onScrollBottom` - Trigger when scrolling to bottom
  - `onBack` - Navigation back button for nested choosers
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
