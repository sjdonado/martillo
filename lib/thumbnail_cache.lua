-- Thumbnail Cache Library
-- Manages thumbnail generation and caching to disk to reduce memory usage
--
local icons = require 'lib.icons'
local temp = require 'lib.tmp'

local M = {
  cacheDir = temp.getDir('thumbnails'),
  defaultSize = icons.ICON_SIZE,
  logger = hs.logger.new('ThumbnailCache', 'info'),
  -- Memory limit tracking (per subdirectory)
  loadedCounts = {},       -- Track how many thumbnails loaded per subdir in this session
  maxLoadedPerSubdir = {}, -- Configurable limits per subdir
  fallbackIcons = {},      -- Cached fallback icons
}

local function cacheDirFor(subdir)
  if subdir then
    return temp.getDir('thumbnails/' .. subdir)
  end
  return M.cacheDir
end

-- Sanitize a string to be safe for use as a filename
local function sanitizeFilename(str)
  if not str then
    return 'unknown'
  end
  -- Replace invalid filename characters with underscores
  local sanitized = str:gsub('[/\\:*?"<>|]', '_')
  -- Limit length to avoid filesystem issues
  if #sanitized > 200 then
    sanitized = sanitized:sub(1, 200)
  end
  return sanitized
end

-- Get the path for a cached thumbnail
local function getThumbnailPath(cacheKey, subdir)
  local dir = cacheDirFor(subdir)
  local safeName = sanitizeFilename(cacheKey)
  return dir .. '/' .. safeName .. '.png'
end

-- Check if a thumbnail exists and is valid
local function thumbnailExists(path)
  local file = io.open(path, 'r')
  if file then
    file:close()
    return true
  end
  return false
end

-- Generate and save a thumbnail from an image
-- @param image: hs.image object or path to image file
-- @param outputPath: where to save the thumbnail
-- @return: true if successful, false otherwise
function M.generateThumbnail(image, outputPath)
  -- Load image if it's a path
  local imageObj = image
  if type(image) == 'string' then
    imageObj = hs.image.imageFromPath(image)
    if not imageObj then
      M.logger:e('Failed to load image from path: ' .. image)
      return false
    end
  end

  if not imageObj then
    M.logger:e('Invalid image object')
    return false
  end

  local thumbnail = imageObj:setSize(M.defaultSize)
  if not thumbnail then
    M.logger:e('Failed to resize image')
    return false
  end

  -- Save thumbnail
  local success = thumbnail:saveToFile(outputPath)
  if not success then
    M.logger:e('Failed to save thumbnail: ' .. outputPath)
    return false
  end

  M.logger:d('Generated thumbnail: ' .. outputPath)
  return true
end

-- Set the maximum number of thumbnails to load for a subdirectory
-- After this limit, fallback icons should be used instead
function M.setMaxLoaded(subdir, maxCount)
  subdir = subdir or 'default'
  M.maxLoadedPerSubdir[subdir] = maxCount
  M.logger:d(string.format('Set max loaded for %s: %d', subdir, maxCount))
end

-- Check if we've reached the limit for a subdirectory
local function hasReachedLimit(subdir)
  subdir = subdir or 'default'
  local maxCount = M.maxLoadedPerSubdir[subdir]
  if not maxCount then
    return false -- No limit set
  end

  local currentCount = M.loadedCounts[subdir] or 0
  return currentCount >= maxCount
end

-- Increment the loaded count for a subdirectory
local function incrementLoadedCount(subdir)
  subdir = subdir or 'default'
  M.loadedCounts[subdir] = (M.loadedCounts[subdir] or 0) + 1
end

-- Reset the loaded count for a subdirectory
function M.resetLoadedCount(subdir)
  if subdir then
    M.loadedCounts[subdir] = 0
  else
    M.loadedCounts = {}
  end
end

-- Get or create a cached fallback icon
-- @param fallbackKey: unique key for this fallback icon
-- @param iconLoader: function that returns an hs.image object
-- @return: hs.image object or nil
function M.getFallbackIcon(fallbackKey, iconLoader)
  if not fallbackKey or not iconLoader then
    return nil
  end

  -- Check if fallback is already cached
  if M.fallbackIcons[fallbackKey] then
    return M.fallbackIcons[fallbackKey]
  end

  -- Load and cache the fallback icon
  local icon = iconLoader()
  if icon then
    icon = icon:setSize(M.defaultSize)
  end

  M.fallbackIcons[fallbackKey] = icon
  return icon
end

-- Get or generate a cached thumbnail for an image
-- @param cacheKey: unique identifier for this thumbnail
-- @param imageLoader: function that returns an hs.image object when called
-- @param subdir: optional subdirectory within cache
-- @return: hs.image object or nil (nil if limit reached)
function M.getCachedThumbnail(cacheKey, imageLoader, subdir)
  if not cacheKey or not imageLoader then
    M.logger:e('Invalid parameters for getCachedThumbnail')
    return nil
  end

  -- Check if we've reached the memory limit for this subdirectory
  if hasReachedLimit(subdir) then
    M.logger:d(string.format('Memory limit reached for subdir: %s', subdir or 'default'))
    return nil -- Caller should use fallback icon
  end

  local thumbnailPath = getThumbnailPath(cacheKey, subdir)

  -- Check if thumbnail exists
  if thumbnailExists(thumbnailPath) then
    M.logger:d('Loading cached thumbnail: ' .. thumbnailPath)
    local image = hs.image.imageFromPath(thumbnailPath)
    if image then
      incrementLoadedCount(subdir)
    end
    return image
  end

  -- Generate thumbnail
  M.logger:d('Generating new thumbnail for: ' .. cacheKey)
  local sourceImage = imageLoader()
  if not sourceImage then
    M.logger:e('Image loader returned nil for: ' .. cacheKey)
    return nil
  end

  local success = M.generateThumbnail(sourceImage, thumbnailPath)
  if not success then
    return nil
  end

  -- Load and return the generated thumbnail
  local image = hs.image.imageFromPath(thumbnailPath)
  if image then
    incrementLoadedCount(subdir)
  end
  return image
end

-- Get or generate a cached thumbnail for an app icon
-- @param bundleID: app bundle identifier
-- @return: hs.image object or nil
function M.getCachedAppIcon(bundleID)
  if not bundleID then
    return nil
  end

  return M.getCachedThumbnail(
    bundleID,
    function()
      return hs.image.imageFromAppBundle(bundleID)
    end,
    'app_icons'
  )
end

-- Get or generate a cached thumbnail for a file type icon
-- @param fileType: file type identifier (e.g., 'public.unix-executable')
-- @return: hs.image object or nil
function M.getCachedFileTypeIcon(fileType)
  if not fileType then
    return nil
  end

  return M.getCachedThumbnail(
    fileType,
    function()
      return hs.image.iconForFileType(fileType)
    end,
    'file_icons'
  )
end

-- Get or generate a cached thumbnail for an image file
-- @param imagePath: path to the image file
-- @return: hs.image object or nil
function M.getCachedImageThumbnail(imagePath)
  if not imagePath then
    return nil
  end

  -- Use filename as cache key to avoid regenerating for the same file
  local filename = imagePath:match '([^/]+)$'
  if not filename then
    filename = imagePath
  end

  return M.getCachedThumbnail(
    filename,
    function()
      return hs.image.imageFromPath(imagePath)
    end,
    'images'
  )
end

-- Clear all cached thumbnails
function M.clearCache()
  M.logger:i('Clearing thumbnail cache: ' .. M.cacheDir)
  os.execute("rm -rf '" .. M.cacheDir .. "'")
  hs.fs.mkdir(M.cacheDir)
end

-- Clear a specific subdirectory in the cache
function M.clearCacheSubdir(subdir)
  if not subdir then
    return
  end
  local dir = M.cacheDir .. '/' .. subdir
  M.logger:i('Clearing cache subdirectory: ' .. dir)
  os.execute("rm -rf '" .. dir .. "'")
  hs.fs.mkdir(dir)
end

-- Initialize the cache
function M.init(cacheDir)
  if cacheDir then
    M.cacheDir = cacheDir
  else
    M.cacheDir = temp.getDir('thumbnails')
  end
  hs.fs.mkdir(M.cacheDir)
  M.logger:i('Thumbnail cache initialized: ' .. M.cacheDir)
end

-- Initialize on load
M.init()

return M
