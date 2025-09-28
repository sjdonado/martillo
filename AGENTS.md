# AGENTS.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

This is a Lua-based Hammerspoon configuration framework. Since this is a pure Lua project, there are no npm/bun commands. However, you can use these commands for development:

- **Test configuration**: Copy the project to `~/.martillo` and test in Hammerspoon directly
- **Reload Hammerspoon**: Use Hammerspoon's built-in reload functionality or `hs.reload()` in the console

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

### Built-in Spoons
- **LaunchOrToggleFocus**: App switching with hotkeys
- **ActionsLauncher**: Command palette with live transformations and system actions
- **WindowManager**: Window manipulation and layout management
- **KillProcess**: Process killer with fuzzy search
- **ClipboardHistory**: Clipboard manager with history
- **BrowserRedirect**: Intelligent URL routing between browsers
- **MySchedule**: Personal scheduling system

### Configuration Examples
The framework supports both simple spoon loading and complex configurations with custom hotkeys and options. See README.md for full examples.

## Important Notes

- This is a pure Lua project - no Node.js, package managers, or build tools
- All spoons follow Hammerspoon's standard spoon structure with `init.lua` files
- The framework handles automatic reloading when configuration files change
- Users configure everything in their `~/.hammerspoon/init.lua` file
- Testing requires actual Hammerspoon installation and macOS environment
