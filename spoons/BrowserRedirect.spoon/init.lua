--- Intelligent URL routing to different applications based on patterns
--- Includes customizable link mapping interface

local obj = {}
obj.__index = obj

obj.default_app = 'Safari'
obj.redirect = {}
obj.mapper = {}
obj.isActive = false
obj.originalDefaultBrowser = nil
obj.lastProcessedURL = nil
obj.lastProcessedTime = 0
obj.redirectLookup = {}
obj.mapperLookup = {}
obj.logger = hs.logger.new('BrowserRedirect', 'info')

--- BrowserRedirect:init()
--- Method
--- Initialize the spoon
function obj:init()
  return self
end

--- BrowserRedirect:setup(config)
--- Method
--- Setup the BrowserRedirect with configuration
---
--- Parameters:
---  * config - A table containing:
---    * default_app - Default application name (string)
---    * redirect - Array of redirect rules with 'match' patterns and 'app' name
---    * mapper - Array of URL transformation functions
function obj:setup(config)
  if not config then
    return self
  end

  self.default_app = config.default_app or 'Safari'
  self.redirect = config.redirect or {}
  self.mapper = config.mapper or {}

  -- Build optimized lookup tables
  self:_buildLookupTables()

  return self
end

--- BrowserRedirect:_buildLookupTables()
--- Method
--- Build optimized lookup tables for O(1) pattern matching
function obj:_buildLookupTables()
  self.redirectLookup = {}
  self.mapperLookup = {}

  -- Build redirect lookup table
  for _, rule in ipairs(self.redirect) do
    if rule and rule.match and rule.app then
      local patterns = type(rule.match) == 'table' and rule.match or { rule.match }
      for _, pattern in ipairs(patterns) do
        -- Store exact matches and wildcard patterns separately
        if pattern:find '*' then
          -- For wildcard patterns, we still need to check them sequentially
          self.redirectLookup['__wildcards'] = self.redirectLookup['__wildcards'] or {}
          table.insert(self.redirectLookup['__wildcards'], {
            pattern = pattern,
            app = rule.app,
          })
        else
          -- Exact matches for O(1) lookup
          self.redirectLookup[pattern] = rule.app
        end
      end
    end
  end

  -- Build mapper lookup table
  for _, mapper in ipairs(self.mapper) do
    if mapper.from then
      if mapper.from:find '*' then
        self.mapperLookup['__wildcards'] = self.mapperLookup['__wildcards'] or {}
        table.insert(self.mapperLookup['__wildcards'], mapper)
      else
        self.mapperLookup[mapper.from] = mapper
      end
    end
  end

  -- Count exact redirects
  local exactRedirects = 0
  for k, v in pairs(self.redirectLookup) do
    if k ~= '__wildcards' then
      exactRedirects = exactRedirects + 1
    end
  end

  -- Count exact mappers
  local exactMappers = 0
  for k, v in pairs(self.mapperLookup) do
    if k ~= '__wildcards' then
      exactMappers = exactMappers + 1
    end
  end

  self.logger:i(
    string.format(
      'Built lookup tables - %d exact redirects, %d wildcard redirects, %d exact mappers, %d wildcard mappers',
      exactRedirects,
      self.redirectLookup['__wildcards'] and #self.redirectLookup['__wildcards'] or 0,
      exactMappers,
      self.mapperLookup['__wildcards'] and #self.mapperLookup['__wildcards'] or 0
    )
  )
end

--- BrowserRedirect:start()
--- Method
--- Start URL interception system
function obj:start()
  if self.isActive then
    return self
  end

  self.logger:i 'Starting URL interception'

  -- Start URL scheme handler (for external URLs)
  self:_startURLSchemeHandler()

  self.isActive = true
  self.logger:i 'URL interception started'

  return self
end

--- BrowserRedirect:stop()
--- Method
--- Stop URL interception
function obj:stop()
  if not self.isActive then
    return self
  end

  self.isActive = false

  -- Restore original default browser if we had one
  if self.originalDefaultBrowser then
    hs.execute(
      string.format(
        "defaults write com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers -array-add '{LSHandlerContentType=public.html;LSHandlerRoleAll=%s;}'",
        self.originalDefaultBrowser
      )
    )
    hs.execute(
      string.format(
        "defaults write com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers -array-add '{LSHandlerURLScheme=http;LSHandlerRoleAll=%s;}'",
        self.originalDefaultBrowser
      )
    )
    hs.execute(
      string.format(
        "defaults write com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers -array-add '{LSHandlerURLScheme=https;LSHandlerRoleAll=%s;}'",
        self.originalDefaultBrowser
      )
    )
  end

  self.logger:i 'URL interception stopped'
  return self
end

--- BrowserRedirect:_startURLSchemeHandler()
--- Method
--- Start URL scheme handler for external URLs
function obj:_startURLSchemeHandler()
  -- Store original default browser
  local output =
    hs.execute "defaults read com.apple.LaunchServices/com.apple.launchservices.secure LSHandlers | grep -A3 LSHandlerURLScheme | grep http -A2 | grep LSHandlerRoleAll -A1 | tail -1 | cut -d'\"' -f2"
  if output and output ~= '' then
    self.originalDefaultBrowser = output:gsub('%s+', '')
  end

  -- Register URL scheme handlers with error handling
  local success, err = pcall(function()
    hs.urlevent.setDefaultHandler 'http'
    hs.urlevent.setDefaultHandler 'https'
  end)

  if not success then
    self.logger:w(
      'Could not set default URL handler (this is usually fine): ' .. tostring(err) .. '. URL redirection will still work for URLs opened through Hammerspoon.'
    )
  end

  -- Set up URL event callback
  hs.urlevent.httpCallback = function(scheme, host, params, fullURL)
    if fullURL then
      self:_handleURL(fullURL)
    end
  end

  self.logger:d 'URL scheme handler started'
end

--- BrowserRedirect:_handleURL(url)
--- Method
--- Handle intercepted URL and route to appropriate application
---
--- Parameters:
---  * url - The intercepted URL
function obj:_handleURL(url)
  if not url then
    return
  end

  -- Debounce rapid URL processing
  local currentTime = hs.timer.secondsSinceEpoch()
  if self.lastProcessedURL == url and (currentTime - self.lastProcessedTime) < 2 then
    return
  end

  self.lastProcessedURL = url
  self.lastProcessedTime = currentTime

  self.logger:d(string.format('Intercepted URL: %s', url))

  -- Transform the URL if it matches any mappers
  local transformedURL = self:_transformURL(url)
  local targetApp = self:_findTargetApp(transformedURL)

  self.logger:i(string.format('Routing to %s', targetApp))

  -- Open URL in target app
  local success = self:_openInApp(transformedURL, targetApp)
  if not success then
    self.logger:w 'Failed to open in target app, using system default'
    hs.urlevent.openURLWithBundle(transformedURL, self.default_app)
  end
end

--- BrowserRedirect:_openInApp(url, appName)
--- Method
--- Open URL in specific application
---
--- Parameters:
---  * url - The URL to open
---  * appName - Name of the application
---
--- Returns:
---  * Boolean - Success status
function obj:_openInApp(url, appName)
  local openCmd = string.format('open -a "%s" "%s"', appName, url)
  local output, success = hs.execute(openCmd)
  return success
end

--- BrowserRedirect:_transformURL(url)
--- Method
--- Transform URL based on configured mappers
---
--- Parameters:
---  * url - The original URL to transform
---
--- Returns:
---  * String - The transformed URL or original if no mapping found
function obj:_transformURL(url)
  -- First check exact matches for O(1) lookup
  local exactMapper = self.mapperLookup[url]
  if exactMapper then
    if exactMapper.to then
      self.logger:d(string.format('Exact transform: %s -> %s', url, exactMapper.to))
      return exactMapper.to
    elseif exactMapper.transform then
      return exactMapper.transform(exactMapper, url)
    end
  end

  -- Then check wildcard patterns
  if self.mapperLookup['__wildcards'] then
    for _, mapper in ipairs(self.mapperLookup['__wildcards']) do
      if mapper.from and mapper.to then
        -- Pattern-based transformation
        if self:_matchesURLPattern(url, mapper.from) then
          local transformedURL = self:_transformURLPattern(url, mapper.from, mapper.to)
          self.logger:d(string.format('Transforming URL: %s -> %s', url, transformedURL))
          return transformedURL
        end
      elseif mapper.matches and mapper.transform then
        -- Function-based transformation
        if mapper.matches(mapper, url) then
          return mapper.transform(mapper, url)
        end
      end
    end
  end

  return url
end

--- BrowserRedirect:_matchesURLPattern(url, pattern)
--- Method
--- Check if URL matches a wildcard pattern
---
--- Parameters:
---  * url - The URL to check
---  * pattern - The pattern to match (supports * wildcards and {param} extractions)
---
--- Returns:
---  * Boolean - True if URL matches the pattern
function obj:_matchesURLPattern(url, pattern)
  -- Convert pattern to Lua pattern
  local luaPattern = pattern:gsub('([%^%$%(%)%%%.%[%]%+%-%?])', '%%%1')
  luaPattern = luaPattern:gsub('%*', '.*')
  luaPattern = luaPattern:gsub('{[^}]+}', '(.-)')
  luaPattern = '^' .. luaPattern .. '$'

  return url:match(luaPattern) ~= nil
end

--- BrowserRedirect:_transformURLPattern(url, fromPattern, toPattern)
--- Method
--- Transform URL using pattern matching and substitution
---
--- Parameters:
---  * url - The original URL
---  * fromPattern - The pattern to match against (with {param} placeholders)
---  * toPattern - The target pattern (with {param} references)
---
--- Returns:
---  * String - The transformed URL
function obj:_transformURLPattern(url, fromPattern, toPattern)
  -- Extract parameter names from the from pattern
  local paramNames = {}
  for param in fromPattern:gmatch '{([^}]+)}' do
    table.insert(paramNames, param)
  end

  -- Create Lua pattern for matching and capturing
  local luaPattern = fromPattern:gsub('([%^%$%(%)%%%.%[%]%+%-%?])', '%%%1')
  luaPattern = luaPattern:gsub('%*', '.*')
  luaPattern = luaPattern:gsub('{[^}]+}', '(.-)')
  luaPattern = '^' .. luaPattern .. '$'

  -- Extract parameter values
  local params = {}
  local captures = { url:match(luaPattern) }
  for i, value in ipairs(captures) do
    if paramNames[i] then
      params[paramNames[i]] = value
    end
  end

  -- Parse URL for query parameters if needed
  local urlParts = hs.http.urlParts(url)
  if urlParts and urlParts.query then
    if type(urlParts.query) == 'table' then
      for key, value in pairs(urlParts.query) do
        params['query.' .. key] = value
      end
    elseif type(urlParts.query) == 'string' then
      -- Parse query string manually
      for pair in urlParts.query:gmatch '([^&]+)' do
        local key, value = pair:match '([^=]+)=?(.*)'
        if key then
          params['query.' .. key] = value or ''
        end
      end
    end
  end

  -- Transform the target pattern
  local result = toPattern
  for param, value in pairs(params) do
    local placeholder = '{' .. param .. '}'
    local encodePlaceholder = '{' .. param .. '|encode}'

    if result:find(encodePlaceholder, 1, true) then
      result = result:gsub(encodePlaceholder:gsub('([%^%$%(%)%%%.%[%]%+%-%?])', '%%%1'), hs.http.encodeForQuery(value or ''))
    else
      result = result:gsub(placeholder:gsub('([%^%$%(%)%%%.%[%]%+%-%?])', '%%%1'), value or '')
    end
  end

  return result
end

--- BrowserRedirect:_findTargetApp(url)
--- Method
--- Find the target application for a given URL based on redirect rules
---
--- Parameters:
---  * url - The URL to find an application for
---
--- Returns:
---  * String - The target application name
function obj:_findTargetApp(url)
  if not url then
    return self.default_app
  end

  -- First check exact matches for O(1) lookup
  local exactApp = self.redirectLookup[url]
  if exactApp then
    self.logger:d(string.format('Exact match found: %s -> %s', url, exactApp))
    return exactApp
  end

  -- Then check wildcard patterns
  if self.redirectLookup['__wildcards'] then
    for _, rule in ipairs(self.redirectLookup['__wildcards']) do
      self.logger:d(string.format("Checking wildcard pattern '%s' against URL '%s'", rule.pattern, url))
      if self:_matchesPattern(url, rule.pattern) then
        self.logger:d(string.format('Wildcard pattern matched! Returning app: %s', rule.app))
        return rule.app
      end
    end
  end

  return self.default_app
end

--- BrowserRedirect:_matchesPattern(url, pattern)
--- Method
--- Check if URL matches a given pattern (supports wildcards)
---
--- Parameters:
---  * url - The URL to check
---  * pattern - The pattern to match against
---
--- Returns:
---  * Boolean - True if URL matches the pattern
function obj:_matchesPattern(url, pattern)
  if not url or not pattern or type(url) ~= 'string' or type(pattern) ~= 'string' then
    self.logger:w(string.format('Invalid input - url: %s, pattern: %s', tostring(url), tostring(pattern)))
    return false
  end

  local luaPattern = pattern:gsub('([%^%$%(%)%%%.%[%]%+%-%?])', '%%%1')
  luaPattern = luaPattern:gsub('%*', '.*')
  luaPattern = '^' .. luaPattern .. '$'

  local matches = url:match(luaPattern) ~= nil
  self.logger:d(string.format("Pattern '%s' -> Lua pattern '%s' matches URL '%s': %s", pattern, luaPattern, url, tostring(matches)))

  return matches
end

--- BrowserRedirect:_isValidURL(str)
--- Method
--- Check if string is a valid HTTP/HTTPS URL
---
--- Parameters:
---  * str - String to check
---
--- Returns:
---  * Boolean - True if valid URL
function obj:_isValidURL(str)
  if not str or type(str) ~= 'string' then
    return false
  end

  return str:match '^https?://' ~= nil
end

--- BrowserRedirect:addRedirect(rule)
--- Method
--- Add a redirect rule
---
--- Parameters:
---  * rule - A table with 'match' pattern and 'app' name
function obj:addRedirect(rule)
  if not rule.match or not rule.app then
    self.logger:e "Redirect rule must have 'match' and 'app' fields"
    return self
  end

  table.insert(self.redirect, rule)
  self:_buildLookupTables()
  return self
end

--- BrowserRedirect:removeRedirect(pattern)
--- Method
--- Remove redirect rule by pattern
---
--- Parameters:
---  * pattern - The pattern to remove
function obj:removeRedirect(pattern)
  for i = #self.redirect, 1, -1 do
    if self.redirect[i].match == pattern then
      table.remove(self.redirect, i)
    end
  end
  self:_buildLookupTables()
  return self
end

--- BrowserRedirect:addMapper(mapper)
--- Method
--- Add a URL mapper
---
--- Parameters:
---  * mapper - A mapper configuration
function obj:addMapper(mapper)
  table.insert(self.mapper, mapper)
  self:_buildLookupTables()
  return self
end

--- BrowserRedirect:removeMapper(name)
--- Method
--- Remove mapper by name
---
--- Parameters:
---  * name - The name of the mapper to remove
function obj:removeMapper(name)
  for i = #self.mapper, 1, -1 do
    if self.mapper[i].name == name then
      table.remove(self.mapper, i)
    end
  end
  self:_buildLookupTables()
  return self
end

--- BrowserRedirect:getStats()
--- Method
--- Get statistics about redirect rules and mappers
---
--- Returns:
---  * Table - Statistics about the current configuration
function obj:getStats()
  return {
    redirectRules = #self.redirect,
    mappers = #self.mapper,
    isActive = self.isActive,
    originalDefaultBrowser = self.originalDefaultBrowser,
    lastProcessedURL = self.lastProcessedURL,
  }
end

return obj
