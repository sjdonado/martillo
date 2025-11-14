-- Action Helpers
-- Composable helper functions for common picker action patterns

local toast = require 'lib.toast'
local pickerManager = require 'lib.picker'

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

return M
