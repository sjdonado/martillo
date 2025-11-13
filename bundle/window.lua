-- Window Management Actions Bundle
-- Actions for positioning and resizing windows
-- Self-contained with all window management functions included

-- Get the focused window with retry logic
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

-- Move and resize the focused window
local function moveWindow(direction)
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

-- Return action definitions
return {
	-- Window Management Actions - Sizing
	{
		id = 'window_maximize',
		name = 'Maximize Window',
		icon = 'computer',
		description = 'Maximize window to full screen',
		handler = function()
			moveWindow('max')
		end,
	},
	{
		id = 'window_almost_maximize',
		name = 'Almost Maximize',
		icon = 'computer',
		description = 'Resize window to 90% of screen, centered',
		handler = function()
			moveWindow('almost_max')
		end,
	},
	{
		id = 'window_reasonable_size',
		name = 'Reasonable Size',
		icon = 'computer',
		description = 'Resize window to reasonable size 70% of screen, centered',
		handler = function()
			moveWindow('reasonable')
		end,
	},
	{
		id = 'window_center',
		name = 'Center Window',
		icon = 'computer',
		description = 'Center window without resizing',
		handler = function()
			moveWindow('center')
		end,
	},

	-- Window Management Actions - Halves
	{
		id = 'window_left',
		name = 'Window Left Half',
		icon = 'computer',
		description = 'Position window in left half',
		handler = function()
			moveWindow('left')
		end,
	},
	{
		id = 'window_right',
		name = 'Window Right Half',
		icon = 'computer',
		description = 'Position window in right half',
		handler = function()
			moveWindow('right')
		end,
	},
	{
		id = 'window_up',
		name = 'Window Top Half',
		icon = 'computer',
		description = 'Position window in top half',
		handler = function()
			moveWindow('up')
		end,
	},
	{
		id = 'window_down',
		name = 'Window Bottom Half',
		icon = 'computer',
		description = 'Position window in bottom half',
		handler = function()
			moveWindow('down')
		end,
	},

	-- Window Management Actions - Quarters
	{
		id = 'window_top_left',
		name = 'Window Top Left',
		icon = 'computer',
		description = 'Position window in top left quarter',
		handler = function()
			moveWindow('top_left')
		end,
	},
	{
		id = 'window_top_right',
		name = 'Window Top Right',
		icon = 'computer',
		description = 'Position window in top right quarter',
		handler = function()
			moveWindow('top_right')
		end,
	},
	{
		id = 'window_bottom_left',
		name = 'Window Bottom Left',
		icon = 'computer',
		description = 'Position window in bottom left quarter',
		handler = function()
			moveWindow('bottom_left')
		end,
	},
	{
		id = 'window_bottom_right',
		name = 'Window Bottom Right',
		icon = 'computer',
		description = 'Position window in bottom right quarter',
		handler = function()
			moveWindow('bottom_right')
		end,
	},

	-- Window Management Actions - Thirds (Horizontal)
	{
		id = 'window_left_third',
		name = 'Window Left Third',
		icon = 'computer',
		description = 'Position window in left third',
		handler = function()
			moveWindow('left_third')
		end,
	},
	{
		id = 'window_center_third',
		name = 'Window Center Third',
		icon = 'computer',
		description = 'Position window in center third',
		handler = function()
			moveWindow('center_third')
		end,
	},
	{
		id = 'window_right_third',
		name = 'Window Right Third',
		icon = 'computer',
		description = 'Position window in right third',
		handler = function()
			moveWindow('right_third')
		end,
	},
	{
		id = 'window_left_two_thirds',
		name = 'Window Left Two Thirds',
		icon = 'computer',
		description = 'Position window in left two thirds',
		handler = function()
			moveWindow('left_two_thirds')
		end,
	},
	{
		id = 'window_right_two_thirds',
		name = 'Window Right Two Thirds',
		icon = 'computer',
		description = 'Position window in right two thirds',
		handler = function()
			moveWindow('right_two_thirds')
		end,
	},

	-- Window Management Actions - Thirds (Vertical)
	{
		id = 'window_top_third',
		name = 'Window Top Third',
		icon = 'computer',
		description = 'Position window in top third',
		handler = function()
			moveWindow('top_third')
		end,
	},
	{
		id = 'window_middle_third',
		name = 'Window Middle Third',
		icon = 'computer',
		description = 'Position window in middle third',
		handler = function()
			moveWindow('middle_third')
		end,
	},
	{
		id = 'window_bottom_third',
		name = 'Window Bottom Third',
		icon = 'computer',
		description = 'Position window in bottom third',
		handler = function()
			moveWindow('bottom_third')
		end,
	},
	{
		id = 'window_top_two_thirds',
		name = 'Window Top Two Thirds',
		icon = 'computer',
		description = 'Position window in top two thirds',
		handler = function()
			moveWindow('top_two_thirds')
		end,
	},
	{
		id = 'window_bottom_two_thirds',
		icon = 'computer',
		name = 'Window Bottom Two Thirds',
		description = 'Position window in bottom two thirds',
		handler = function()
			moveWindow('bottom_two_thirds')
		end,
	},
}
