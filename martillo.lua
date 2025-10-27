-- martillo.lua
-- Martillo: A declarative Hammerspoon configuration framework
-- Fast, ergonomic and reliable productivity tools for macOS

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

local MODIFIER_ALIASES = {
    cmd = "cmd",
    command = "cmd",
    ["⌘"] = "cmd",
    alt = "alt",
    option = "alt",
    ["⌥"] = "alt",
    ctrl = "ctrl",
    control = "ctrl",
    ["⌃"] = "ctrl",
    shift = "shift",
    ["⇧"] = "shift",
    fn = "fn",
    hyper = "hyper",
    super = "super",
    meh = "meh",
}

local function trim(str)
    if type(str) ~= "string" then
        return ""
    end
    return (str:match("^%s*(.-)%s*$") or "")
end

local function canonicalModifier(mod)
    local cleaned = trim(mod)
    if cleaned == "" then
        return nil
    end
    local lower = cleaned:lower()
    return MODIFIER_ALIASES[lower] or MODIFIER_ALIASES[cleaned] or lower
end

local function collectModifiers(value)
    local result = {}
    local seen = {}

    local function collect(v)
        if type(v) == "string" then
            local canonical = canonicalModifier(v)
            if canonical and not seen[canonical] then
                table.insert(result, canonical)
                seen[canonical] = true
            end
        elseif type(v) == "table" then
            for _, item in ipairs(v) do
                collect(item)
            end
        end
    end

    collect(value)
    return result
end

local function copyArray(list)
    if type(list) ~= "table" then
        return nil
    end

    local copy = {}
    for i, value in ipairs(list) do
        copy[i] = value
    end
    for key, value in pairs(list) do
        if type(key) ~= "number" then
            copy[key] = value
        end
    end
    return copy
end

local function normalizeLeaderToken(token)
    local lower = trim(token):lower()
    if lower == "<leader>" or lower == "leader" then
        return "leader"
    end
    return nil
end

local function resolveLeaderMods(mods)
    local leader = M.config and M.config.leader_key
    local placeholderUsed = false
    local result = {}
    local seen = {}

    local function addModifier(mod)
        local canonical = canonicalModifier(mod)
        if canonical and not seen[canonical] then
            table.insert(result, canonical)
            seen[canonical] = true
        end
    end

    local function appendLeader()
        placeholderUsed = true
        if not leader then
            return
        end
        for _, mod in ipairs(leader) do
            addModifier(mod)
        end
    end

    local function process(value)
        if type(value) == "string" then
            if normalizeLeaderToken(value) then
                appendLeader()
            else
                addModifier(value)
            end
        elseif type(value) == "table" then
            for _, item in ipairs(value) do
                process(item)
            end
        end
    end

    process(mods)

    if #result == 0 then
        return nil, placeholderUsed
    end

    return result, placeholderUsed
end

local function expandLeaderEntry(entry)
    if type(entry) ~= "table" then
        return entry
    end

    local expanded = copyArray(entry) or {}
    local mods = expanded[1]
    local resolved, usedPlaceholder = resolveLeaderMods(mods)

    if usedPlaceholder and (not resolved or #resolved == 0) then
        error("Martillo: <leader> placeholder used in hotkey without leader_key configuration", 0)
    end

    if resolved then
        expanded[1] = resolved
    else
        local normalized = collectModifiers(mods)
        if #normalized > 0 then
            expanded[1] = normalized
        elseif type(mods) == "string" then
            expanded[1] = nil
        end
    end

    return expanded
end

local function normalizeLeaderKey(value)
    if not value then
        return nil
    end

    local normalized = collectModifiers(value)

    if #normalized == 0 then
        return nil
    end

    return normalized
end

-- Process hotkey specification
local function processHotkeys(spoon, keys)
    if not keys or not spoon.bindHotkeys then return end

    local hotkeyMap = {}
    for _, key in ipairs(keys) do
        if type(key) == "table" then
            local hotkeyEntry = expandLeaderEntry(key)
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

-- Ensure Martillo spoons directory is in the search path
local function ensureMartilloSpoonPath()
    local martilloSpoonsDir = os.getenv("HOME") .. "/.martillo/spoons"
    if hs.fs.attributes(martilloSpoonsDir) then
        -- Add to package.path if not already present
        local searchPattern = martilloSpoonsDir .. "/?.spoon/init.lua"
        if not package.path:find(searchPattern, 1, true) then
            package.path = searchPattern .. ";" .. package.path
            print("🔄 Added Martillo spoons to package path")
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
                    expandedKeys[index] = expandLeaderEntry(keyConfig)
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
function M.setup(config, options)
    -- Handle both array of spoons and full config table
    local spoons = config
    local opts = options or M.defaults

    -- If no separate options provided, check if config has options
    if not options then
        -- Check if config has non-numeric keys (mixed format)
        local hasOptions = false
        for k, v in pairs(config) do
            if type(k) ~= "number" then
                hasOptions = true
                break
            end
        end

        if hasOptions then
            -- Extract spoons (numeric keys) and options (non-numeric keys)
            spoons = {}
            local configOpts = {}
            for k, v in pairs(config) do
                if type(k) == "number" then
                    spoons[k] = v
                else
                    configOpts[k] = v
                end
            end
            opts = merge(M.defaults, configOpts)
        end
    else
        opts = merge(M.defaults, options)
    end

    opts.leader_key = normalizeLeaderKey(opts.leader_key)

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
            instance = entry.instance
        })
    end
    table.sort(list, function(a, b) return a.name < b.name end)
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
