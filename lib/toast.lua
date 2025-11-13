-- Toast helpers

local M = {}

--- Show info toast
--- @param message string message to display
--- @param duration number | nil toast duration
function M.info(message, duration)
  if not final_duration then
    final_duration = _G.MARTILLO_ALERT_DURATION
  end
  hs.alert.show('ℹ️ ' .. message, final_duration)
end

--- Show success toast
--- @param message string message to display
--- @param duration number | nil toast duration
function M.success(message, duration)
  if not final_duration then
    final_duration = _G.MARTILLO_ALERT_DURATION
  end
  hs.alert.show('✅ ' .. message, final_duration)
end

--- Show error toast
--- @param message string message to display
--- @param duration number | nil toast duration
function M.error(message)
  if not final_duration then
    final_duration = _G.MARTILLO_ALERT_DURATION
  end
  hs.alert.show('❌ ' .. message, final_duration)
end

--- Show copied toast
--- @param message string | nil message to display
--- @param duration number | nil toast duration
function M.copied(message)
  local final_message = message
  if not message then
    final_message = 'to clipboard'
  end
  if not final_duration then
    final_duration = _G.MARTILLO_ALERT_DURATION
  end
  hs.alert.show('📋 Copied ' .. final_message, final_duration)
end

return M
