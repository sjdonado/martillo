-- martillo.lua
-- Martillo: A declarative Hammerspoon configuration framework
-- Fast, ergonomic and reliable productivity tools for macOS

-- Load leader module
local leader = require("lib.leader")

local M = {}

-- Version
M.version = "1.0.0"

-- State
M.spoons = {}
M.config = {}

-- Default configuration
M.defaults = {
	autoReload = true,
	alertOnLoad = true,
	alertMessage = "Martillo Ready",
	leader_key = nil,
}

-- Merge tables helper
local function merge(...)
	local result = {}
	for _, t in ipairs({ ... }) do
		if type(t) == "table" then
			for k, v in pairs(t) do
				if type(v) == "table" and type(result[k]) == "table" then
					result[k] = merge(result[k], v)
				else
					result[k] = v
				end
			end
		end
	end
	return result
end

-- Process hotkey specification
local function processHotkeys(spoon, keys)
	if not keys or not spoon.bindHotkeys then
		return
	end

	local hotkeyMap = {}
	for _, key in ipairs(keys) do
		if type(key) == "table" then
			local hotkeyEntry = leader.expandLeaderEntry(key)
			local mods = hotkeyEntry[1]
			local keychar = hotkeyEntry[2]
			local action = hotkeyEntry[3]

			if type(action) == "string" then
				-- Named action
				hotkeyMap[action] = { mods, keychar }
			else
				-- Default toggle action
				hotkeyMap.toggle = { mods, keychar }
			end
		end
	end

	if next(hotkeyMap) then
		spoon:bindHotkeys(hotkeyMap)
	end
end

-- Pre-compile spoons that have native binaries without loading them into memory
-- Compile spoons that have native binaries (after sync)
local function compileSpoons()
	print("🔨 Compiling Martillo spoons with native binaries...")

	-- List of spoons that require compilation
	local compilableSpoons = { "MySchedule", "ClipboardHistory" }

	for _, spoonName in ipairs(compilableSpoons) do
		-- Load the synced spoon from Hammerspoon's standard location
		local loadSuccess, loadErr = pcall(function()
			hs.loadSpoon(spoonName)
		end)

		if loadSuccess and spoon[spoonName] then
			local spoonInstance = spoon[spoonName]
			if type(spoonInstance.compile) == "function" then
				local compileSuccess, compileErr = pcall(function()
					spoonInstance:compile()
				end)
				if compileSuccess then
					print("✅ Compiled " .. spoonName)
				else
					print("❌ Failed to compile " .. spoonName)
					print("Error: " .. tostring(compileErr))
					print("Stack trace:")
					print(debug.traceback())
				end
			end
			-- Don't clean up - these will be used by the user's config
		else
			print("⚠️  Skipping compilation for " .. spoonName .. " (not found or failed to load)")
		end
	end
end

-- Process action filters to enable only selected actions with custom overrides
local function processActionFilters(allActions, actionFilters)
	local filtered = {}

	-- Process static actions
	if actionFilters.static and allActions.static then
		filtered.static = {}
		for _, selector in ipairs(actionFilters.static) do
			local actionId, overrides

			if type(selector) == "string" then
				actionId = selector
				overrides = {}
			elseif type(selector) == "table" then
				actionId = selector[1] or selector.id
				overrides = selector
			end

			-- Find matching action in allActions
			for _, action in ipairs(allActions.static) do
				if action.id == actionId then
					-- Clone the action
					local filteredAction = {}
					for k, v in pairs(action) do
						filteredAction[k] = v
					end

					-- Apply keybinding overrides with leader expansion
					if overrides.keys then
						local expandedKeys = {}
						for _, keyEntry in ipairs(overrides.keys) do
							local expandedEntry = leader.expandLeaderEntry(keyEntry)
							table.insert(expandedKeys, expandedEntry)
						end
						filteredAction.keys = expandedKeys
					end

					-- Apply alias override
					if overrides.alias then
						filteredAction.alias = overrides.alias
					end

					table.insert(filtered.static, filteredAction)
					break
				end
			end
		end
	end

	-- Process dynamic actions
	if actionFilters.dynamic and allActions.dynamic then
		filtered.dynamic = {}
		for _, selector in ipairs(actionFilters.dynamic) do
			local actionId, overrides

			if type(selector) == "string" then
				actionId = selector
				overrides = {}
			elseif type(selector) == "table" then
				actionId = selector[1] or selector.id
				overrides = selector
			end

			-- Validate that dynamic actions don't have keys
			if overrides.keys then
				error("Martillo: Cannot add keybindings to dynamic actions. Action ID: " .. actionId, 0)
			end

			-- Find matching action in allActions
			for _, action in ipairs(allActions.dynamic) do
				if action.id == actionId then
					-- Clone the action
					local filteredAction = {}
					for k, v in pairs(action) do
						filteredAction[k] = v
					end

					table.insert(filtered.dynamic, filteredAction)
					break
				end
			end
		end
	end

	return filtered
end

-- Ensure Martillo spoons directory is in the search path
local function ensureMartilloSpoonPath()
	local martilloSpoonsDir = os.getenv("HOME") .. "/.martillo/spoons"
	if hs.fs.attributes(martilloSpoonsDir) then
		-- Add main spoons directory to package.path if not already present
		local searchPattern = martilloSpoonsDir .. "/?.spoon/init.lua"
		if not package.path:find(searchPattern, 1, true) then
			package.path = searchPattern .. ";" .. package.path
			print("🔄 Added Martillo spoons to package path")
		end

		-- Add _internal directory to package.path
		local internalPattern = martilloSpoonsDir .. "/_internal/?.spoon/init.lua"
		if not package.path:find(internalPattern, 1, true) then
			package.path = internalPattern .. ";" .. package.path
			print("🔄 Added Martillo internal spoons to package path")
		end
	end
end

-- Load a single spoon
local function loadSpoon(spec)
	local name = type(spec) == "string" and spec or spec[1]

	if not name then
		hs.alert.show("Invalid spoon specification")
		return nil
	end

	-- Load the spoon
	hs.loadSpoon(name)
	local spoonInstance = spoon[name]

	if not spoonInstance then
		hs.alert.show("Failed to load spoon: " .. name)
		return nil
	end

	-- Handle table specs with options
	if type(spec) == "table" then
		-- Process opts
		if spec.opts then
			local opts = type(spec.opts) == "function" and spec.opts() or spec.opts

			-- If actions filter is provided, filter and customize the opts
			if spec.actions then
				opts = processActionFilters(opts, spec.actions)
			end

			if spoonInstance.setup then
				spoonInstance:setup(opts)
			end
		end

		-- Process init
		if spec.init and type(spec.init) == "function" then
			spec.init(spoonInstance)
		end

		-- Process keys
		if spec.keys then
			-- Check if this is an app-based keys format (for LaunchOrToggleFocus)
			if spec.keys[1] and spec.keys[1].app and spoonInstance.setup then
				local expandedKeys = {}
				for index, keyConfig in ipairs(spec.keys) do
					expandedKeys[index] = leader.expandLeaderEntry(keyConfig)
				end
				for key, value in pairs(spec.keys) do
					if type(key) ~= "number" then
						expandedKeys[key] = value
					end
				end
				spoonInstance:setup(expandedKeys)
			else
				processHotkeys(spoonInstance, spec.keys)
			end
		end

		-- Process config (runs after setup and keys)
		if spec.config and type(spec.config) == "function" then
			spec.config(spoonInstance)
		end

		-- Process lazy loading
		if spec.lazy then
			-- Store for lazy loading but don't initialize yet
			M.spoons[name] = { instance = spoonInstance, spec = spec, loaded = false }
			return spoonInstance
		end
	end

	M.spoons[name] = { instance = spoonInstance, spec = spec, loaded = true }
	return spoonInstance
end

-- Setup auto-reload
local function setupAutoReload()
	local function reloadConfig(files)
		local doReload = false
		for _, file in pairs(files) do
			if file:sub(-4) == ".lua" then
				doReload = true
				break
			end
		end
		if doReload then
			hs.reload()
		end
	end

	-- Watch both Hammerspoon and Martillo directories
	hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig):start()
	local martilloPath = os.getenv("HOME") .. "/.martillo/"
	if hs.fs.attributes(martilloPath) then
		hs.pathwatcher.new(martilloPath, reloadConfig):start()
	end
end

-- Main setup function
function M.setup(config)
	-- Extract spoons (numeric keys) and options (non-numeric keys)
	local spoons = {}
	local configOpts = {}

	for k, v in pairs(config) do
		if type(k) == "number" then
			spoons[k] = v
		else
			configOpts[k] = v
		end
	end

	-- Merge with defaults
	local opts = merge(M.defaults, configOpts)

	-- Set leader key in the leader module
	leader.setLeaderKey(opts.leader_key)

	-- Store config
	M.config = opts

	-- Sync Martillo spoons to Hammerspoon's standard location
	ensureMartilloSpoonPath()

	-- Compile spoons that need native binaries
	compileSpoons()

	-- Load all spoons
	for _, spoonSpec in ipairs(spoons) do
		local ok, err = pcall(loadSpoon, spoonSpec)
		if not ok then
			hs.alert.show("Error: " .. tostring(err))
		end
	end

	-- Setup auto-reload
	if opts.autoReload then
		setupAutoReload()
	end

	-- Show load notification
	if opts.alertOnLoad then
		hs.alert.show(opts.alertMessage)
	end

	return M
end

-- Get a loaded spoon
function M.get(name)
	local entry = M.spoons[name]
	return entry and entry.instance
end

-- Manually load a lazy spoon
function M.load(name)
	local entry = M.spoons[name]
	if entry and not entry.loaded then
		if entry.spec.config then
			entry.spec.config(entry.instance)
		end
		entry.loaded = true
	end
	return entry and entry.instance
end

-- List all loaded spoons
function M.list()
	local list = {}
	for name, entry in pairs(M.spoons) do
		table.insert(list, {
			name = name,
			loaded = entry.loaded,
			instance = entry.instance,
		})
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	return list
end

-- Reload configuration
function M.reload()
	hs.reload()
end

-- Helper to get ActionsLauncher if loaded
function M.getActionsLauncher()
	return M.get("ActionsLauncher")
end

-- Helper to get ClipboardHistory if loaded
function M.getClipboard()
	return M.get("ClipboardHistory")
end

-- Helper to get WindowManager if loaded
function M.getWindowManager()
	return M.get("WindowManager")
end

-- Version check
function M.checkVersion()
	return M.version
end

return M
