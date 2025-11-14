-- Icon utilities
-- Provides access to icon paths and loading functionality

local M = {
  cache = {},
  preset = {},
  logger = hs.logger.new('Icons', 'info'),
  ICON_SIZE = { w = 32, h = 32 },
}

-- Get the project root directory
local function getProjectRoot()
  local info = debug.getinfo(1, 'S')
  local scriptPath = info.source:match '^@(.+)$'
  local scriptDir = scriptPath:match '(.+)/[^/]+$'
  return scriptDir:match '(.+)/lib$'
end

-- Build preset icons table (icon name -> absolute path)
-- Scans assets/icons directory only
local function buildPresets()
  if next(M.preset) ~= nil then
    return -- Already built
  end

  local projectRoot = getProjectRoot()

  -- Scan assets/icons directory
  local assetsIconsPath = projectRoot .. '/assets/icons'
  local handle = io.popen('find "' .. assetsIconsPath .. '" -maxdepth 1 -name "*.png" 2>/dev/null')
  if handle then
    for file in handle:lines() do
      local iconName = file:match '([^/]+)%.png$'
      if iconName then
        M.preset[iconName] = file
      end
    end
    handle:close()
  end

  -- Count icons
  local count = 0
  for _ in pairs(M.preset) do
    count = count + 1
  end

  M.logger:d('Built preset icons table with ' .. count .. ' icons')
end

-- Initialize presets on module load
buildPresets()

-- Load icon from path or preset name
-- @param iconPathOrName string Absolute path to icon file, relative path, or preset name
-- @return hs.image object or nil
function M.getIcon(iconPathOrName)
  if not iconPathOrName then
    return nil
  end

  -- If it's already an hs.image, return it
  if type(iconPathOrName) == 'userdata' then
    return iconPathOrName
  end

  local iconPath = iconPathOrName

  -- Check if it's a preset name and resolve to path
  if M.preset[iconPathOrName] then
    iconPath = M.preset[iconPathOrName]
  end

  -- Resolve relative paths using project root
  if not iconPath:match('^/') then
    local projectRoot = getProjectRoot()
    iconPath = projectRoot .. '/store/' .. iconPath
  end

  -- Check cache
  if M.cache[iconPath] then
    return M.cache[iconPath]
  end

  local image = hs.image.imageFromPath(iconPath)

  if not image then
    M.logger:w('Failed to load icon: ' .. iconPath)
    return nil
  end

  -- Resize to standard icon size
  local resized = image:setSize(M.ICON_SIZE)
  M.cache[iconPath] = resized

  return resized
end

-- Clear icon cache and rebuild presets
function M.clearCache()
  M.cache = {}
  M.preset = {}
  buildPresets()
  M.logger:d 'Icon cache cleared'
end

return M
