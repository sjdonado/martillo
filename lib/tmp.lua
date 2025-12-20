-- Temp directory helpers

local M = {}

local logger = hs.logger.new('TempDir', 'info')

local function ensureDir(path)
  local attributes = hs.fs.attributes(path)
  if attributes then
    if attributes.mode ~= "directory" then
      logger:e('Temp path exists but is not a directory: ' .. path)
      return false
    end
    return true
  end

  local ok = hs.fs.mkdir(path)
  if ok then
    logger:i('Temp dir created: ' .. path)
  else
    logger:e('Failed to create temp dir: ' .. path)
  end
  return ok
end

local function resolveBaseDir(user)
  local privateRoot = "/tmp/martillo-" .. user
  if ensureDir(privateRoot) then
    logger:i('Using private temp base: ' .. privateRoot)
    return privateRoot
  end

  logger:e('Falling back to /tmp for temp base')
  return "/tmp"
end

function M.getDir(subdir)
  local user = os.getenv("USER")
  local base = resolveBaseDir(user)

  if subdir and subdir ~= "" then
    base = base .. "/" .. subdir
    ensureDir(base)
  end

  return base
end

return M
