-- martillo.lua
-- Martillo: A declarative Hammerspoon configuration framework
-- Fast, ergonomic and reliable productivity tools for macOS

-- Add martillo to package path
local martilloPath = os.getenv("HOME") .. "/.martillo"
package.path = package.path .. ";" .. martilloPath .. "/?.lua"
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.martillo/?/init.lua"

leader = require("lib.leader")

local M = {}

-- Version
M.version = "1.0.0"
M.logger = hs.logger.new("Martillo", "debug")

-- State
M.spoons = {}
M.config = {}

-- Default configuration
M.defaults = {
  alertDuration = 1,
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

-- Append all elements from multiple arrays into dest
local function append_all(dest, ...)
  for _, t in ipairs({ ... }) do
    for i = 1, #t do
      dest[#dest + 1] = t[i]
    end
  end
end

-- Flatten actions array if it contains nested arrays
-- Supports both: { action1, action2 } and { {action1, action2}, {action3, action4} }
local function flattenActions(actions)
  if not actions or type(actions) ~= "table" or #actions == 0 then
    return actions
  end

  -- Check if first element is an array (nested structure)
  local firstElement = actions[1]
  if type(firstElement) == "table" and #firstElement > 0 and not firstElement.id then
    -- Nested arrays detected - flatten them
    local flattened = {}
    append_all(flattened, table.unpack(actions))
    return flattened
  end

  -- Already flat
  return actions
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
  M.logger:d("Compiling Martillo spoons with native binaries...")

  -- List of spoons that require compilation
  local compilableSpoons = { "MySchedule" }

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
          M.logger:d("✅ Compiled " .. spoonName)
        else
          M.logger:e("Failed to compile " .. spoonName)
          M.logger:e("Error: " .. tostring(compileErr))
          M.logger:e("Stack trace: " .. debug.traceback())
        end
      end
      -- Don't clean up - these will be used by the user's config
    else
      M.logger:w(" Skipping compilation for " .. spoonName .. " (not found or failed to load)")
    end
  end
end

-- Process action filters to enable only selected actions with custom overrides
local function processActionFilters(allActions, actionFilters)
  -- Detect if using new unified API (flat array) or old API (static/dynamic keys)
  local isNewAPI = actionFilters[1] ~= nil and not actionFilters.static and not actionFilters.dynamic

  if isNewAPI then
    -- New API: actionFilters is a flat array, allActions is also a flat array
    local allActionsPool = {}

    -- Check if allActions is a flat array or old format with static/dynamic
    if allActions[1] then
      -- New format: flat array
      for _, action in ipairs(allActions) do
        allActionsPool[action.id] = action
      end
    elseif allActions.actions then
      -- New format with actions key: { actions = [...] }
      for _, action in ipairs(allActions.actions) do
        allActionsPool[action.id] = action
      end
    else
      -- Old format: has static/dynamic keys
      if allActions.static then
        for _, action in ipairs(allActions.static) do
          allActionsPool[action.id] = action
        end
      end
      if allActions.dynamic then
        for _, action in ipairs(allActions.dynamic) do
          allActionsPool[action.id] = action
        end
      end
    end

    -- Filter and process based on actionFilters
    local filteredActions = {}
    for _, selector in ipairs(actionFilters) do
      local actionId, overrides

      if type(selector) == "string" then
        actionId = selector
        overrides = {}
      elseif type(selector) == "table" then
        actionId = selector[1] or selector.id
        overrides = selector
      end

      -- Find matching action
      local action = allActionsPool[actionId]
      if action then
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

        -- Apply opts override (merge with existing opts)
        if overrides.opts then
          if not filteredAction.opts then
            filteredAction.opts = {}
          end
          for k, v in pairs(overrides.opts) do
            filteredAction.opts[k] = v
          end
        end

        table.insert(filteredActions, filteredAction)
      end
    end

    return { actions = filteredActions }
  else
    -- Old API: actionFilters has static/dynamic keys
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

            -- Apply opts override (merge with existing opts)
            if overrides.opts then
              if not filteredAction.opts then
                filteredAction.opts = {}
              end
              for k, v in pairs(overrides.opts) do
                filteredAction.opts[k] = v
              end
            end

            table.insert(filtered.static, filteredAction)
            break
          end
        end
      end
    end

    -- Process Nested Actions
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

        -- Find matching action in allActions
        for _, action in ipairs(allActions.dynamic) do
          if action.id == actionId then
            -- Clone the action
            local filteredAction = {}
            for k, v in pairs(action) do
              filteredAction[k] = v
            end

            -- Apply alias override (Nested Actions can't have keys)
            if overrides.alias then
              filteredAction.alias = overrides.alias
            end

            -- Apply opts override (merge with existing opts)
            if overrides.opts then
              if not filteredAction.opts then
                filteredAction.opts = {}
              end
              for k, v in pairs(overrides.opts) do
                filteredAction.opts[k] = v
              end
            end

            table.insert(filtered.dynamic, filteredAction)
            break
          end
        end
      end
    end

    return filtered
  end
end

-- Load all action bundles from bundle directory
local function loadBundleActions()
  local bundleDir = martilloPath .. "/bundle"
  local actions = {}

  M.logger:d("Loading bundle actions from: " .. bundleDir)

  -- Check if bundle directory exists
  local attr = hs.fs.attributes(bundleDir)
  if not attr or attr.mode ~= "directory" then
    M.logger:w("Bundle directory not found: " .. bundleDir)
    return actions
  end

  -- Iterate through all .lua files in bundle directory
  for file in hs.fs.dir(bundleDir) do
    if file:match("%.lua$") and file ~= "." and file ~= ".." then
      local filePath = bundleDir .. "/" .. file
      M.logger:d("Loading bundle: " .. file)

      local success, result = pcall(function()
        return dofile(filePath)
      end)

      if success then
        if type(result) == "table" then
          -- Bundle returns an array of actions
          for _, action in ipairs(result) do
            table.insert(actions, action)
          end
          M.logger:d("✅ Loaded " .. #result .. " actions from " .. file)
        else
          M.logger:w("Bundle " .. file .. " did not return a table, skipping")
        end
      else
        M.logger:e("Failed to load bundle: " .. file)
        M.logger:e("Error: " .. tostring(result))
        -- Don't fail entire load, just skip this bundle
      end
    end
  end

  M.logger:d("Total bundle actions loaded: " .. #actions)
  return actions
end

-- Load all action stores from store directory subfolders
local function loadStoreActions()
  local storeDir = martilloPath .. "/store"
  local actions = {}

  M.logger:d("Loading store actions from: " .. storeDir)

  -- Check if store directory exists
  local attr = hs.fs.attributes(storeDir)
  if not attr or attr.mode ~= "directory" then
    M.logger:w("Store directory not found: " .. storeDir)
    return actions
  end

  -- Iterate through subdirectories in store
  for item in hs.fs.dir(storeDir) do
    if item ~= "." and item ~= ".." then
      local itemPath = storeDir .. "/" .. item
      local itemAttr = hs.fs.attributes(itemPath)

      -- Check if it's a directory
      if itemAttr and itemAttr.mode == "directory" then
        local initPath = itemPath .. "/init.lua"
        local initAttr = hs.fs.attributes(initPath)

        -- Check if init.lua exists
        if initAttr and initAttr.mode == "file" then
          M.logger:d("Loading store: " .. item)

          local success, result = pcall(function()
            return dofile(initPath)
          end)

          if success then
            if type(result) == "table" then
              -- Store returns an array of actions
              for _, action in ipairs(result) do
                table.insert(actions, action)
              end
              M.logger:d("✅ Loaded " .. #result .. " actions from " .. item)
            else
              M.logger:w("Store " .. item .. " did not return a table, skipping")
            end
          else
            M.logger:e("Failed to load store: " .. item)
            M.logger:e("Error: " .. tostring(result))
            -- Don't fail entire load, just skip this store
          end
        end
      end
    end
  end

  M.logger:d("Total store actions loaded: " .. #actions)
  return actions
end

-- Get all actions from bundles and stores
function M.getAllActions()
  local allActions = {}

  -- Load bundle actions
  local bundleActions = loadBundleActions()
  for _, action in ipairs(bundleActions) do
    table.insert(allActions, action)
  end

  -- Load store actions
  local storeActions = loadStoreActions()
  for _, action in ipairs(storeActions) do
    table.insert(allActions, action)
  end

  M.logger:d("Total actions loaded: " .. #allActions)
  return allActions
end

-- Ensure Martillo spoons directory is in the search path
local function ensureMartilloSpoonPath()
  local martilloSpoonsDir = os.getenv("HOME") .. "/.martillo/spoons"
  if hs.fs.attributes(martilloSpoonsDir) then
    -- Add main spoons directory to package.path if not already present
    local searchPattern = martilloSpoonsDir .. "/?.spoon/init.lua"
    if not package.path:find(searchPattern, 1, true) then
      package.path = searchPattern .. ";" .. package.path
      M.logger:d("Added Martillo spoons to package path")
    end

    -- lib directory is already accessible at root level, no need to add to path
  end
end

-- Load a single spoon
local function loadSpoon(spec)
  local name = type(spec) == "string" and spec or spec[1]

  if not name then
    hs.alert.show("Invalid spoon specification", _G.MARTILLO_ALERT_DURATION)
    return nil
  end

  -- Debug: Show what we're loading
  M.logger:d("Loading spoon: " .. name)

  -- Load the spoon
  hs.loadSpoon(name)

  local spoonInstance = spoon[name]

  if not spoonInstance then
    M.logger:e("Failed to load spoon: " .. name .. " (spoon[" .. name .. "] is nil)")
  end

  M.logger:d("✅ Loaded spoon: " .. name)

  -- Handle table specs with options
  if type(spec) == "table" then
    -- Process opts
    local opts = nil

    if spec.opts then
      opts = type(spec.opts) == "function" and spec.opts() or spec.opts
    end

    -- Auto-load actions for ActionsLauncher if not provided
    if name == "ActionsLauncher" then
      if not opts then
        opts = {}
      end
      if not opts.actions then
        M.logger:d("Auto-loading actions from bundle and store for ActionsLauncher")
        opts.actions = M.getAllActions()
      end
    end

    -- Process the opts if we have any
    if opts then
      -- Flatten actions array if it contains nested arrays
      -- This allows users to write: { actions = { window_mgmt, utilities, encoders } }
      -- instead of manually combining all arrays
      if opts.actions then
        opts.actions = flattenActions(opts.actions)
      end

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

  -- Make alert duration globally accessible
  _G.MARTILLO_ALERT_DURATION = opts.alertDuration or 2

  -- Sync Martillo spoons to Hammerspoon's standard location
  ensureMartilloSpoonPath()

  -- Compile spoons that need native binaries
  compileSpoons()

  -- Load all spoons
  for _, spoonSpec in ipairs(spoons) do
    local ok, err = pcall(loadSpoon, spoonSpec)
    if not ok then
      local spoonName = type(spoonSpec) == "string" and spoonSpec or spoonSpec[1]
      M.logger:e("Failed to load spoon: " .. tostring(spoonName))
      M.logger:e("Error: " .. hs.inspect(err))
      M.logger:e("Stack trace: " .. debug.traceback())
      hs.alert.show("Error loading " .. tostring(spoonName) .. ", check console", _G.MARTILLO_ALERT_DURATION)
      return
    end
  end

  -- Open ActionsLauncher on load
  -- Store timer reference to prevent garbage collection
  M.openTimer = hs.timer.doAfter(0.1, function()
    if spoon.ActionsLauncher then
      spoon.ActionsLauncher:show()
    else
      M.logger:e("ActionsLauncher spoon not found in global spoon table")
      M.logger:e("Available spoons: " .. hs.inspect(spoon))
    end
    -- Clear timer reference after execution
    M.openTimer = nil
  end)

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
