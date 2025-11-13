-- window.lua
-- Window management utilities for Martillo

local M = {}

--- Get the focused window with retry logic
--- @return hs.window|nil The focused window object or nil if no window is available
local function getFocusedWindow()
  local win = hs.window.focusedWindow()
  if win then
    return win
  end

  -- Retry logic - sometimes the focused window isn't immediately available
  local maxRetries = 3
  local retryDelay = 0.05 -- 50ms

  for i = 1, maxRetries do
    hs.timer.usleep(retryDelay * 1000000) -- Convert to microseconds
    win = hs.window.focusedWindow()
    if win then
      return win
    end
  end

  return nil
end

--- Move and resize the focused window
--- @param direction string The direction/action:
---   Halves: "left", "right", "up", "down"
---   Sizing: "max", "center", "almost_max", "reasonable"
---   Quarters: "top_left", "top_right", "bottom_left", "bottom_right"
---   Thirds (horizontal): "left_third", "center_third", "right_third", "left_two_thirds", "right_two_thirds"
---   Thirds (vertical): "top_third", "middle_third", "bottom_third", "top_two_thirds", "bottom_two_thirds"
function M.moveWindow(direction)
  local win = getFocusedWindow()
  if not win then
    return
  end

  local screen = win:screen()
  local frame = screen:frame()
  local winFrame = win:frame()

  -- Halves
  if direction == 'left' then
    winFrame.x = frame.x
    winFrame.y = frame.y
    winFrame.w = frame.w / 2
    winFrame.h = frame.h
  elseif direction == 'right' then
    winFrame.x = frame.x + frame.w / 2
    winFrame.y = frame.y
    winFrame.w = frame.w / 2
    winFrame.h = frame.h
  elseif direction == 'up' then
    winFrame.x = frame.x
    winFrame.y = frame.y
    winFrame.w = frame.w
    winFrame.h = frame.h / 2
  elseif direction == 'down' then
    winFrame.x = frame.x
    winFrame.y = frame.y + frame.h / 2
    winFrame.w = frame.w
    winFrame.h = frame.h / 2

    -- Sizing
  elseif direction == 'max' then
    winFrame = frame
  elseif direction == 'center' then
    winFrame.x = frame.x + (frame.w - winFrame.w) / 2
    winFrame.y = frame.y + (frame.h - winFrame.h) / 2
  elseif direction == 'almost_max' then
    -- Almost Maximize: 90% of screen, centered
    winFrame.w = frame.w * 0.9
    winFrame.h = frame.h * 0.9
    winFrame.x = frame.x + (frame.w - winFrame.w) / 2
    winFrame.y = frame.y + (frame.h - winFrame.h) / 2
  elseif direction == 'reasonable' then
    -- Reasonable Size: 70% of screen, centered
    winFrame.w = frame.w * 0.6
    winFrame.h = frame.h * 0.7
    winFrame.x = frame.x + (frame.w - winFrame.w) / 2
    winFrame.y = frame.y + (frame.h - winFrame.h) / 2

    -- Quarters
  elseif direction == 'top_left' then
    winFrame.x = frame.x
    winFrame.y = frame.y
    winFrame.w = frame.w / 2
    winFrame.h = frame.h / 2
  elseif direction == 'top_right' then
    winFrame.x = frame.x + frame.w / 2
    winFrame.y = frame.y
    winFrame.w = frame.w / 2
    winFrame.h = frame.h / 2
  elseif direction == 'bottom_left' then
    winFrame.x = frame.x
    winFrame.y = frame.y + frame.h / 2
    winFrame.w = frame.w / 2
    winFrame.h = frame.h / 2
  elseif direction == 'bottom_right' then
    winFrame.x = frame.x + frame.w / 2
    winFrame.y = frame.y + frame.h / 2
    winFrame.w = frame.w / 2
    winFrame.h = frame.h / 2

    -- Thirds (horizontal)
  elseif direction == 'left_third' then
    winFrame.x = frame.x
    winFrame.y = frame.y
    winFrame.w = frame.w / 3
    winFrame.h = frame.h
  elseif direction == 'center_third' then
    winFrame.x = frame.x + frame.w / 3
    winFrame.y = frame.y
    winFrame.w = frame.w / 3
    winFrame.h = frame.h
  elseif direction == 'right_third' then
    winFrame.x = frame.x + (frame.w * 2 / 3)
    winFrame.y = frame.y
    winFrame.w = frame.w / 3
    winFrame.h = frame.h
  elseif direction == 'left_two_thirds' then
    winFrame.x = frame.x
    winFrame.y = frame.y
    winFrame.w = frame.w * 2 / 3
    winFrame.h = frame.h
  elseif direction == 'right_two_thirds' then
    winFrame.x = frame.x + frame.w / 3
    winFrame.y = frame.y
    winFrame.w = frame.w * 2 / 3
    winFrame.h = frame.h

    -- Thirds (vertical)
  elseif direction == 'top_third' then
    winFrame.x = frame.x
    winFrame.y = frame.y
    winFrame.w = frame.w
    winFrame.h = frame.h / 3
  elseif direction == 'middle_third' then
    winFrame.x = frame.x
    winFrame.y = frame.y + frame.h / 3
    winFrame.w = frame.w
    winFrame.h = frame.h / 3
  elseif direction == 'bottom_third' then
    winFrame.x = frame.x
    winFrame.y = frame.y + (frame.h * 2 / 3)
    winFrame.w = frame.w
    winFrame.h = frame.h / 3
  elseif direction == 'top_two_thirds' then
    winFrame.x = frame.x
    winFrame.y = frame.y
    winFrame.w = frame.w
    winFrame.h = frame.h * 2 / 3
  elseif direction == 'bottom_two_thirds' then
    winFrame.x = frame.x
    winFrame.y = frame.y + frame.h / 3
    winFrame.w = frame.w
    winFrame.h = frame.h * 2 / 3
  end

  win:setFrame(winFrame, 0)
end

return M
