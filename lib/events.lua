-- Composable helper functions for common action events

local toast = require 'lib.toast'
local pickerManager = require 'lib.picker'
local searchUtils = require 'lib.search'

local M = {}

--- Create a handler that copies the choice text to clipboard
--- @param getText function(choice) Function to extract text from choice (optional, defaults to choice.text)
--- @return function Handler function
function M.copyToClipboard(getText)
  getText = getText or function(choice)
    return choice.text
  end

  return function(choice)
    local text = getText(choice)
    if text and text ~= '' then
      hs.pasteboard.setContents(text)
      toast.copied(text)
    end
  end
end

--- Create a handler that opens a URL or copies it to clipboard
--- Supports Shift modifier:
--- - Regular Enter: Open URL in browser
--- - Shift+Enter: Copy URL to clipboard
--- @param getUrl function(choice) Function to extract URL from choice (required)
--- @return function Handler function
function M.openUrl(getUrl)
  return function(choice)
    local url = getUrl(choice)
    if not url or url == '' then
      return
    end

    local shiftHeld = pickerManager.isShiftHeld()

    if shiftHeld then
      -- Shift+Enter: Copy to clipboard
      hs.pasteboard.setContents(url)
      toast.success 'Link copied to clipboard'
    else
      -- Regular Enter: Open URL
      hs.urlevent.openURL(url)
      toast.success 'Opening link'
    end
  end
end

--- Create a handler that copies to clipboard AND pastes
--- Supports Shift modifier:
--- - Regular Enter: Copy to clipboard AND paste/insert
--- - Shift+Enter: Copy to clipboard only (no paste)
--- @param getText function(choice) Function to extract text from choice (optional, defaults to choice.text)
--- @return function Handler function
function M.copyAndPaste(getText)
  getText = getText or function(choice)
    return choice.text
  end

  return function(choice)
    local text = getText(choice)
    if not text or text == '' then
      return
    end

    local shiftHeld = pickerManager.isShiftHeld()

    if shiftHeld then
      -- Shift+Enter: Copy only (no paste)
      hs.pasteboard.setContents(text)
      hs.alert.show('📋 ' .. text, _G.MARTILLO_ALERT_DURATION)
    else
      -- Regular Enter: Copy and paste
      hs.pasteboard.setContents(text)
      toast.success(text)

      -- Paste content using keyStrokes
      hs.eventtap.keyStrokes(text)
    end
  end
end

--- Create a handler that shows a toast message
--- @param getMessage function(choice) Function to extract message from choice (optional, defaults to choice.text)
--- @return function Handler function
function M.showToast(getMessage)
  getMessage = getMessage or function(choice)
    return choice.text
  end

  return function(choice)
    local message = getMessage(choice)
    if message and message ~= '' then
      toast.success(message)
    end
  end
end

--- Create a handler that does nothing (display-only picker)
--- @return function Handler function
function M.noAction()
  return function(choice)
    -- Do nothing
  end
end

--- Create a custom handler with a custom function
--- @param fn function(choice) Custom function to execute
--- @return function Handler function
function M.custom(fn)
  return fn
end

--- Build choices from a results array without search
--- @param results table Array of result objects with text/subText/value/image fields
--- @param launcher table Launcher instance for UUID generation
--- @param opts table Options: { handler = function, image = hs.image }
--- @return table Array of choices ready for picker
function M.buildChoices(results, launcher, opts)
  opts = opts or {}
  local handler = opts.handler or M.noAction()
  local defaultImage = opts.image -- Optional default image for all choices

  -- Build choices with handlers
  local choices = {}
  for _, result in ipairs(results) do
    local uuid = launcher:generateUUID()
    local choice = {
      text = result.text,
      subText = result.subText,
      uuid = uuid,
    }

    -- Set image: prefer result.image, fallback to opts.image
    if result.image then
      choice.image = result.image
    elseif defaultImage then
      choice.image = defaultImage
    end

    table.insert(choices, choice)

    -- Resolve handler: can be a function that takes result, or a static handler
    if type(handler) == 'function' then
      local resolvedHandler = handler(result)
      launcher.handlers[uuid] = resolvedHandler
    else
      launcher.handlers[uuid] = handler
    end
  end

  return choices
end

--- Build choices with fuzzy search from a results array
--- Common pattern for display-only or copyable pickers with search support
--- @param query string Search query from user
--- @param results table Array of result objects with text/subText/value/image fields
--- @param launcher table Launcher instance for UUID generation
--- @param opts table Options: { handler = function, searchFields = table, fuzzyMinQueryLength = number, maxResults = number, image = hs.image }
--- @return table Array of choices ready for picker
function M.buildSearchableChoices(query, results, launcher, opts)
  opts = opts or {}
  local handler = opts.handler or M.noAction()
  local searchFields = opts.searchFields
    or function(result)
      return {
        { value = result.text or '', weight = 1.0, key = 'text' },
        { value = result.subText or '', weight = 0.7, key = 'subText' },
      }
    end
  local fuzzyMinQueryLength = opts.fuzzyMinQueryLength or 2
  local maxResults = opts.maxResults or 50
  local defaultImage = opts.image -- Optional default image for all choices

  -- Apply fuzzy search if query is provided
  local filteredResults = results
  if query and query ~= '' then
    filteredResults = searchUtils.rank(query, results, {
      getFields = searchFields,
      fuzzyMinQueryLength = fuzzyMinQueryLength,
      maxResults = maxResults,
    })
  end

  -- Build choices with handlers
  local choices = {}
  for _, result in ipairs(filteredResults) do
    local uuid = launcher:generateUUID()
    local choice = {
      text = result.text,
      subText = result.subText,
      uuid = uuid,
    }

    -- Set image: prefer result.image, fallback to opts.image
    if result.image then
      choice.image = result.image
    elseif defaultImage then
      choice.image = defaultImage
    end

    table.insert(choices, choice)

    -- Resolve handler: can be a function that takes result, or a static handler
    if type(handler) == 'function' then
      local resolvedHandler = handler(result)
      launcher.handlers[uuid] = resolvedHandler
    else
      launcher.handlers[uuid] = handler
    end
  end

  return choices
end

return M
