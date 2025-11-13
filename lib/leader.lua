-- leader.lua
-- Leader key handling for Martillo hotkey configuration

local M = {}

-- Modifier aliases mapping
local MODIFIER_ALIASES = {
  cmd = 'cmd',
  command = 'cmd',
  ['⌘'] = 'cmd',
  alt = 'alt',
  option = 'alt',
  ['⌥'] = 'alt',
  ctrl = 'ctrl',
  control = 'ctrl',
  ['⌃'] = 'ctrl',
  shift = 'shift',
  ['⇧'] = 'shift',
  fn = 'fn',
  hyper = 'hyper',
  super = 'super',
  meh = 'meh',
}

-- Current leader key configuration
M.leaderKey = nil

-- Trim whitespace from string
local function trim(str)
  if type(str) ~= 'string' then
    return ''
  end
  return (str:match '^%s*(.-)%s*$' or '')
end

-- Convert modifier to canonical form
local function canonicalModifier(mod)
  local cleaned = trim(mod)
  if cleaned == '' then
    return nil
  end
  local lower = cleaned:lower()
  return MODIFIER_ALIASES[lower] or MODIFIER_ALIASES[cleaned] or lower
end

-- Collect and normalize modifiers from a value
local function collectModifiers(value)
  local result = {}
  local seen = {}

  local function collect(v)
    if type(v) == 'string' then
      local canonical = canonicalModifier(v)
      if canonical and not seen[canonical] then
        table.insert(result, canonical)
        seen[canonical] = true
      end
    elseif type(v) == 'table' then
      for _, item in ipairs(v) do
        collect(item)
      end
    end
  end

  collect(value)
  return result
end

-- Copy an array with both numeric and non-numeric keys
local function copyArray(list)
  if type(list) ~= 'table' then
    return nil
  end

  local copy = {}
  for i, value in ipairs(list) do
    copy[i] = value
  end
  for key, value in pairs(list) do
    if type(key) ~= 'number' then
      copy[key] = value
    end
  end
  return copy
end

-- Check if a token is a leader placeholder
local function normalizeLeaderToken(token)
  local lower = trim(token):lower()
  if lower == '<leader>' or lower == 'leader' then
    return 'leader'
  end
  return nil
end

-- Resolve leader placeholders in modifier list
local function resolveLeaderMods(mods)
  local leader = M.leaderKey
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
    if type(value) == 'string' then
      if normalizeLeaderToken(value) then
        appendLeader()
      else
        addModifier(value)
      end
    elseif type(value) == 'table' then
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

--- Set the leader key configuration
--- @param value table|nil The leader key modifiers
function M.setLeaderKey(value)
  if not value then
    M.leaderKey = nil
    return
  end

  local normalized = collectModifiers(value)

  if #normalized == 0 then
    M.leaderKey = nil
    return
  end

  M.leaderKey = normalized
end

--- Expand leader placeholders in a hotkey entry
--- @param entry table The hotkey entry to expand
--- @return table The expanded entry
function M.expandLeaderEntry(entry)
  if type(entry) ~= 'table' then
    return entry
  end

  local expanded = copyArray(entry) or {}
  local mods = expanded[1]
  local resolved, usedPlaceholder = resolveLeaderMods(mods)

  if usedPlaceholder and (not resolved or #resolved == 0) then
    error('Martillo: <leader> placeholder used in hotkey without leader_key configuration', 0)
  end

  if resolved then
    expanded[1] = resolved
  else
    local normalized = collectModifiers(mods)
    if #normalized > 0 then
      expanded[1] = normalized
    elseif type(mods) == 'string' then
      expanded[1] = nil
    end
  end

  return expanded
end

return M
