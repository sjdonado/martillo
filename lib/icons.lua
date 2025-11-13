-- Icons Helper
-- Provides access to 3D icons and file type icon mappings

local M = {
  cache = {},
  iconsPath = nil,
  logger = hs.logger.new('IconsHelper', 'info'),
}

-- Global icon size (matches Hammerspoon's default icon size)
M.ICON_SIZE = { w = 32, h = 32 }

-- Expand tilde in path
local function expandPath(path)
  if path:sub(1, 1) == '~' then
    local home = os.getenv 'HOME'
    return home .. path:sub(2)
  end
  return path
end

-- Initialize icons path
local function initIconsPath()
  if M.iconsPath then
    return
  end

  -- Get the directory where this module is located
  local info = debug.getinfo(1, 'S')
  local scriptPath = info.source:match '^@(.+)$'
  local scriptDir = scriptPath:match '(.+)/[^/]+$'
  local projectRoot = scriptDir:match '(.+)/lib$'

  M.iconsPath = projectRoot .. '/assets/icons'
  M.logger:d('Icons path initialized: ' .. M.iconsPath)
end

-- Get icon from cache or load it
local function loadIcon(iconName)
  if M.cache[iconName] then
    return M.cache[iconName]
  end

  local iconPath = M.iconsPath .. '/' .. iconName .. '.png'
  local image = hs.image.imageFromPath(iconPath)

  if not image then
    M.logger:w('Failed to load icon: ' .. iconPath)
    return nil
  end

  -- Resize to standard icon size
  local resized = image:setSize(M.ICON_SIZE)
  M.cache[iconName] = resized

  return resized
end

-- Get icon by name
-- Returns: hs.image object or nil
function M.getIcon(iconName)
  if not iconName then
    return nil
  end

  initIconsPath()

  return loadIcon(iconName)
end

-- Get all available icon names
function M.getAvailableIcons()
  initIconsPath()

  local icons = {}
  local handle = io.popen('ls "' .. M.iconsPath .. '"')
  if handle then
    for file in handle:lines() do
      if file:match '%.png$' then
        local name = file:match '(.+)%.png$'
        table.insert(icons, name)
      end
    end
    handle:close()
  end

  table.sort(icons)
  return icons
end

-- Clear icon cache
function M.clearCache()
  M.cache = {}
  M.logger:d 'Icon cache cleared'
end

return M
