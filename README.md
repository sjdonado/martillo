# 🔨 Martillo

**Build anything you can imagine and launch it with a keystroke.** Martillo is a powerful actions launcher for macOS powered by [Hammerspoon](https://www.hammerspoon.org/). Create custom actions, automate repetitive tasks, and access everything through a command palette with fuzzy search.

**Your productivity hub, your way.** An open-source alternative to Raycast and Alfred with no vendor lock-in, zero dependencies, and full configuration through a single Lua file. Write your own actions, use ready-made bundles, customize every keybinding, add aliases for lightning-fast access, and share your creations freely. All configuration lives in a single file, inspired by [lazy.nvim](https://github.com/folke/lazy.nvim)'s declarative plugin system.

## Demo

https://github.com/user-attachments/assets/d5c803a9-7d83-479a-946b-80f29a2f09bf

## Core Capabilities
- **Fast & Lightweight**: Pure Lua, zero dependencies, no compilation needed
- **Command Palette**: Searchable actions with fuzzy search
- **App Launcher**: Quick app switching with single hotkeys
- **Browser Routing**: Smart URL routing to different browsers
- **My Schedule**: Lists today’s upcoming events in your menu bar, click any entry to jump into the meeting
- **Clipboard Manager**: History of your text, images, and files with fuzzy search
- **Store**: Install external actions from any Git repo via the built-in store loader, drop in community actions freely
- **Batteries Included**: `lib` helpers (icons, events, search, chooser, leader) make building your own actions easy and
dependency-free

## Bundled Actions

Every action below ships with Martillo and is available through `ActionsLauncher` (search, bind hotkeys, or set aliases).

| Category | Action ID | What it does | Enter / ⇧Enter | Search & notes |
| --- | --- | --- | --- | --- |
| Window | switch_window | Switch to any open window with fuzzy search | Enter: focus window<br>⇧Enter: same | Child chooser with fuzzy search<br>Shows app icons and titles |
| Window | window_maximize | Maximize window to full screen | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_almost_maximize | Resize to 90% of screen, centered | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_reasonable_size | Resize to ~70% of screen, centered | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_center | Center window without resizing | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_left | Left half | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_right | Right half | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_up | Top half | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_down | Bottom half | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_top_left | Top-left quarter | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_top_right | Top-right quarter | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_bottom_left | Bottom-left quarter | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_bottom_right | Bottom-right quarter | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_left_third | Left third | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_center_third | Center third | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_right_third | Right third | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_left_two_thirds | Left two thirds | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_right_two_thirds | Right two thirds | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_top_third | Top third | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_middle_third | Middle third | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_bottom_third | Bottom third | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_top_two_thirds | Top two thirds | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_bottom_two_thirds | Bottom two thirds | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_left_fourth | Left fourth | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_center_left_fourth | Center-left fourth | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_center_right_fourth | Center-right fourth | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_right_fourth | Right fourth | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_left_three_fourths | Left three-fourths | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_right_three_fourths | Right three-fourths | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_maximize_horizontal | Maximize width (keep height and position) | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Window | window_maximize_vertical | Maximize height (keep width and position) | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| System | toggle_caffeinate | Toggle system sleep prevention | Enter: toggle<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| System | toggle_system_appearance | Toggle Dark/Light Mode | Enter: toggle<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| System | system_information | Live CPU/memory/battery/network stats with auto-refresh | Enter: copy field<br>⇧Enter: same | Child chooser with fuzzy search on fields |
| Utilities | generate_uuid | Generate UUID v4 and copy | Enter: copy<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Utilities | word_count | Live counts for characters/words/sentences/paragraphs | Enter: copy metric<br>⇧Enter: same | Child chooser<br>Type/paste text to update results (no fuzzy search) |
| Converter | converter_time | Convert Unix/ISO/RFC2822/relative times | Enter: copy selected conversion<br>⇧Enter: same | Child chooser<br>Type any time value to populate results |
| Converter | converter_colors | HEX ↔ RGB with color preview | Enter: copy selected conversion<br>⇧Enter: same | Child chooser<br>Type/paste a color; results update live |
| Converter | converter_base64 | Base64 encode/decode | Enter: copy encoded/decoded value<br>⇧Enter: same | Child chooser<br>Type/paste text to see both directions |
| Converter | converter_jwt | Decode JWT header/payload | Enter: copy decoded part<br>⇧Enter: same | Child chooser<br>Paste JWT to inspect sections |
| Keyboard | keyboard_lock | Lock keyboard for cleaning (unlock with `<leader>+Enter`) | Enter/⇧Enter: instruction only<br>Unlock via leader+Enter | Child chooser shows unlock hint<br>Keyboard input blocked |
| Keyboard | keyboard_keep_alive | Toggle F15 keep-alive ping | Enter: toggle<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Clipboard | clipboard_history | Persistent clipboard with fuzzy search | Enter: paste (or copy-only in secure apps)<br>⇧Enter: copy | Child chooser with fuzzy search<br>Supports text/images/files |
| Processes | kill_process | Manage running processes with CPU/mem display | Enter: kill<br>⇧Enter: copy PID | Child chooser with fuzzy search<br>Auto-refreshes process list |
| Network | network_ip_geolocation | Show local/public IP, geolocation, ISP | Enter: copy selected value<br>⇧Enter: same | Child chooser with fuzzy search<br>Auto-fetches and refreshes |
| Network | network_connected_devices | Scan LAN (/24), show IP/MAC/vendor | Enter: copy IP<br>⇧Enter: copy MAC | Child chooser with fuzzy search<br>Vendor lookup + caching |
| Network | network_speed_test | Latency/download/upload test | Enter/⇧Enter: display only | Child chooser with fuzzy search<br>Live-updating results |
| Browser | safari_tabs | Switch Safari tabs across windows | Enter: focus tab<br>⇧Enter: copy URL | Child chooser with fuzzy search<br>Shows favicons |
| Screen | screen_confetti | Confetti celebration animation | Enter: run<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Screen | screen_ruler | On-screen ruler overlay | Enter: show ruler<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Martillo | martillo_reload | Reload Martillo/Hammerspoon config | Enter: reload<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Martillo | martillo_update | Pull latest Martillo changes from git | Enter: update then reload<br>⇧Enter: same | Global fuzzy search<br>Direct action |
| Store | f1_standings | View current F1 driver standings | Enter: copy driver/team summary<br>⇧Enter: same | Child chooser with fuzzy search (by name, team, nationality) |
| Store | idonthavespotify | Convert music links across platforms | Enter: open target link<br>⇧Enter: copy link | Child chooser (no fuzzy search)<br>Populates from clipboard link |


## Quick Start

```bash
# Install Hammerspoon
brew install --cask hammerspoon

# Clone Martillo
git clone https://github.com/sjdonado/martillo ~/.martillo

# Create configuration
cat > ~/.hammerspoon/init.lua << 'EOF'
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.martillo/?.lua"

return require("martillo").setup({
    leader_key = { "alt", "ctrl" },

    {
        "ActionsLauncher",
        actions = {
            { "toggle_system_appearance", alias = "ta" },
            { "toggle_caffeinate",        alias = "tc" },
            { "system_information",       alias = "si" },
            { "screen_ruler",             alias = "ru" },

            { "switch_window",            keys = { { "<leader>", "tab" } }, opts = { success_toast = false } },
            { "window_maximize",          alias = "wm" },
            { "window_almost_maximize",   keys = { { "<leader>", "up" } } },
            { "window_reasonable_size",   keys = { { "<leader>", "down" } } },
            { "window_center",            keys = { { "<leader>", "return" } } },
            { "window_left_two_thirds",   keys = { { "<leader>", "left" } } },
            { "window_right_two_thirds",  keys = { { "<leader>", "right" } } },

            { "clipboard_history",        keys = { { "<leader>", "-" } } },
            { "kill_process",             keys = { { "<leader>", "=" } } },
            { "safari_tabs",              keys = { { "alt", "tab" } } },

            { "generate_uuid",            alias = "gu" },
            { "word_count",               alias = "wc" },

            { "converter_time",           alias = "ct" },
            { "converter_colors",         alias = "cc" },
            { "converter_base64",         alias = "cb" },
            { "converter_jwt",            alias = "cj" },

            { "network_ip_geolocation",   alias = "ni" },
            { "network_speed_test",       alias = "ns" },

            { "keyboard_lock",            alias = "kl" },
            { "keyboard_keep_alive",      alias = "ka" },

            { "screen_confetti",          alias = "cf" },
            { "f1_standings",             alias = "f1" },

            { "martillo_reload",          alias = "mr" },
            { "martillo_update",          alias = "mu" },
        },
        keys = {
            { "<leader>", "space" },
        },
    },

    {
        "LaunchOrToggleFocus",
        keys = {
            { "<leader>", "c", app = "Calendar" },
            { "<leader>", "f", app = "Finder" },
            { "<leader>", ";", app = "Ghostty" },
            { "<leader>", "h", app = "Helium" },
            { "<leader>", "l", app = "Music" },
            { "<leader>", "e", app = "Mail" },
            { "<leader>", "m", app = "Messages" },
            { "<leader>", "n", app = "Notes" },
            { "<leader>", "p", app = "Passwords" },
            { "<leader>", "r", app = "Reminders" },
            { "<leader>", "b", app = "Safari" },
            { "<leader>", "s", app = "Slack" },
            { "<leader>", "t", app = "Kagi Translate" },
            { "<leader>", "y", app = "Yaak" },
        },
    },

    {
        "MySchedule",
        config = function(spoon)
            spoon:compile()
            spoon:start()
        end,
    },

    {
        "BrowserRedirect",
        opts = {
            default_app = "Safari",
            redirect = {
                { match = { "*localhost*", "*127.0.0.1*", "*0.0.0.0*" }, app = "Helium" },
                { match = { "*fly.dev*" },                               app = "Helium" },
                { match = { "*meet.google*" },                           app = "Helium" },
            },
        },
        config = function(spoon)
            spoon:start()
        end,
    },
})
EOF

# Reload Hammerspoon
```

## System Information Setup (Optional)

The System Information action works out of the box and displays:
- **Memory** (App Memory + Wired + Compressed)
- **Battery** status and percentage
- **Network** upload/download speeds
- **Uptime** with boot date

For **advanced metrics** (CPU cluster residency, GPU, Thermal, and Power), configure passwordless sudo for `powermetrics`:

```bash
echo "$(whoami) ALL=(ALL) NOPASSWD: /usr/bin/powermetrics" | sudo tee /private/etc/sudoers.d/powermetrics
sudo chmod 0440 /private/etc/sudoers.d/powermetrics
```

Then add the include directive to your sudoers file:
```bash
sudo visudo
```

Add this line at the end:
```
#includedir /private/etc/sudoers.d
```

**Note:** CPU, GPU, Thermal, and Power metrics all require sudo access to powermetrics. Without it, these metrics will show "Loading..." but Memory, Battery, Network, and Uptime will work normally.

## Custom Actions from Store

The `store/` directory is for custom actions that extend Martillo. All actions in `store/` are **automatically loaded** - just drop a new folder with an `init.lua` file and it's ready to use!

**Example Store Structure:**
```
store/
  f1_standings/
    init.lua        # F1 Drivers Championship standings (included example)
  my_action/
    init.lua        # Your custom action module
    icon.png        # Optional custom icon (overrides default icons)
```

Each action module should return an array of actions, just like bundles. Custom icons placed in store folders will override default icons with the same name.

See [store/README.md](store/README.md) for details on creating custom actions.

## Installing Actions from External Repositories

Martillo includes a built-in CLI for managing external store actions. The CLI uses Git sparse checkout to fetch only the specific action folder you need, without downloading entire repositories.

### Store CLI Commands

**Add an external action:**
```bash
./scripts/store-cli.sh add <github-url>

# Example: Install I Don't Have Spotify action
./scripts/store-cli.sh add https://github.com/sjdonado/idonthavespotify/tree/master/extra/martillo
```

**List installed actions:**
```bash
./scripts/store-cli.sh list
```

**Update an action:**
```bash
./scripts/store-cli.sh update idonthavespotify

# Update all actions
./scripts/store-cli.sh update
```

**Remove an action:**
```bash
./scripts/store-cli.sh remove idonthavespotify
```

### How It Works

- **Lock File**: All installations are tracked in `store.lock.json` with commit hashes for version control
- **Sparse Checkout**: Only downloads the specific folder you need (efficient!)
- **Automatic Loading**: Installed actions are automatically available in ActionsLauncher
- **Safe Updates**: Detects upstream changes by comparing commit hashes

After installation, add the action to your config:

```lua
{
  "ActionsLauncher",
  actions = {
    { "idonthavespotify", alias = "idhs" },  -- Automatically loaded!
  },
}
```

### Creating Actions for External Distribution

To make your action installable via the Store CLI, create a folder structure in your repository:

```
your-repo/
  extra/martillo/      # Or any path ending with /martillo
    init.lua           # Action definition (required)
    icon.png           # Optional icon
```

Users can then install it with:
```bash
./scripts/store-cli.sh add https://github.com/you/your-repo/tree/main/extra/martillo
```

**Available Community Actions:**
- [idonthavespotify](https://github.com/sjdonado/idonthavespotify) - Convert music links across streaming platforms

## Configuration

### Global Options

```lua
return require("martillo").setup({
  -- Global configuration
  leader_key = { "alt", "ctrl" },      -- Expand <leader> in keybindings
  alertDuration = 1,                    -- Alert duration in seconds

  -- Spoons go here...
})
```

### Leader Key

Use `<leader>` as a placeholder in any keybinding. It expands to your configured `leader_key`:

```lua
{ "<leader>", "space" }           -- Expands to { "alt", "ctrl", "space" }
{ { "<leader>", "cmd" }, "p" }    -- Expands to { "alt", "ctrl", "cmd", "p" }
```

### ActionsLauncher

The central command palette with all your actions. Martillo automatically loads all built-in bundles and store actions:

```lua
{
  "ActionsLauncher",
  actions = {
    -- Assign keybindings and aliases to specific actions
    { "window_center", keys = { { "<leader>", "return" } } },
    { "toggle_caffeinate", alias = "tc" },
    { "clipboard_history", keys = { { "<leader>", "v" } } },
    { "f1_standings", alias = "f1" },  -- From store/
  },
  keys = {
    { "<leader>", "space", desc = "Toggle Actions Launcher" }
  }
}
```

**Action Fields:**
- `keys` - Keybindings for direct access
- `alias` - Short name for faster fuzzy search
- `desc` - Optional description for the keybinding
- `opts` - Action-specific options (e.g., `{ success_toast = false }` to disable success toasts)

**Note:** All bundles from `bundle/` and custom actions from `store/` are automatically loaded. You don't need to manually import them!

### Available Action Bundles

- `bundle.window` - Window positioning (halves, quarters, thirds, maximize, center) - 26 actions total
- `bundle.switch_window` - Window switcher with fuzzy search
- `bundle.system` - System management (caffeinate, dark mode, system information)
- `bundle.utilities` - Text utilities (UUID generation, word count)
- `bundle.converter` - Converters (time, colors, base64, JWT)
- `bundle.keyboard` - Keyboard actions (lock, keep-alive)
- `bundle.clipboard_history` - Clipboard manager with history
- `bundle.kill_process` - Process killer with fuzzy search
- `bundle.network` - Network utilities (IP geolocation, speed test)
- `bundle.safari_tabs` - Safari tab switcher
- `bundle.screen` - Screen effects (confetti, ruler)
- `bundle.martillo` - Martillo management (reload, update)




### LaunchOrToggleFocus

Quick app switching with single hotkeys:

```lua
{
  "LaunchOrToggleFocus",
  keys = {
    { "<leader>", "b", app = "Safari" },
    { "<leader>", ";", app = "Ghostty" },
    { "<leader>", "c", app = "Calendar" },
    { "<leader>", "e", app = "Mail" },
  }
}
```

### MySchedule

Calendar integration in menu bar:

```lua
{
  "MySchedule",
  config = function(spoon)
    spoon:compile()
    spoon:start()
  end
}
```

### BrowserRedirect

Smart URL routing to different browsers:

```lua
{
  "BrowserRedirect",
  opts = {
    default_app = "Safari",
    redirect = {
      { match = { "*localhost*", "*127.0.0.1*" }, app = "Chromium" },
      { match = { "*meet.google*" }, app = "Google Meet" },
    },
    mapper = {
      {
        name = "googleToKagi",
        from = "*google.com*/search*",
        to = "https://kagi.com/search?q={query.q|encode}"
      }
    }
  },
  config = function(spoon)
    spoon:start()
  end
}
```


## Navigation

### Main Launcher (ActionsLauncher)
- **Search**: Type to fuzzy search actions and aliases
- **Enter**: Execute selected action
- **ESC**: Close launcher
- **Shift+ESC**: Force close (same as ESC for main launcher)

### Child Choosers (Clipboard, Converters, etc.)
- **Type**: Filter results in real-time
- **Enter**: Execute action (paste, convert, etc.)
- **Shift+Enter**: Alternate action (copy only, etc.)
- **ESC**: Navigate back to parent chooser
- **Shift+ESC**: Close all choosers and return to desktop
- **Click outside**: Close all choosers and return to desktop


## Creating Custom Actions

### Bundle Structure (Core Actions)

Create a new file in the `bundle/` directory for core actions:

```lua
-- bundle/my_custom_bundle.lua
-- My Custom Actions Bundle

local icons = require 'lib.icons'

return {
  {
    id = 'my_action',
    name = 'My Action',
    icon = icons.preset.star,
    description = 'Does something awesome',
    handler = function()
      hs.alert.show('Hello from my action!')
    end,
  },
}
```

### Store Structure (Custom/External Actions)

Create a new folder in `store/` with an `init.lua` file for custom actions:

```lua
-- store/my_action/init.lua
local icons = require 'lib.icons'

return {
  {
    id = 'my_store_action',
    name = 'My Store Action',
    icon = icons.preset.message,
    description = 'Custom action from store',
    handler = function()
      -- Your action logic here
    end,
  },
}
```

**That's it!** The store auto-loader will automatically discover and load your action. No need to manually import it - just drop a new folder in `store/` and use it in your config:

```lua
{
  "ActionsLauncher",
  actions = {
    { "my_store_action", alias = "ma" },  -- Automatically available!
  },
}
```


## Contributing

Contributions welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

## Acknowledgments

- [Raycast](https://www.raycast.com/) - Inspiration for the launcher UX and workflow philosophy
- [Hammerspoon](https://www.hammerspoon.org/) - The powerful macOS automation tool that makes this possible
- [lazy.nvim](https://github.com/folke/lazy.nvim) - Inspiration for declarative config style
- [3dicons.co](https://3dicons.co/) - Beautiful 3D icon collection
