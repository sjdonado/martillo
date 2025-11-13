-- Window Management Actions Bundle
-- Actions for positioning and resizing windows

package.path = package.path .. ';' .. os.getenv 'HOME' .. '/.martillo/?.lua'

local window = require 'lib.window'

return {
	-- Window Management Actions - Sizing
	{
		id = 'window_maximize',
		name = 'Maximize Window',
		icon = 'computer',
		description = 'Maximize window to full screen',
		handler = function()
			window.moveWindow 'max'
		end,
	},
	{
		id = 'window_almost_maximize',
		name = 'Almost Maximize',
		icon = 'computer',
		description = 'Resize window to 90% of screen, centered',
		handler = function()
			window.moveWindow 'almost_max'
		end,
	},
	{
		id = 'window_reasonable_size',
		name = 'Reasonable Size',
		icon = 'computer',
		description = 'Resize window to reasonable size 70% of screen, centered',
		handler = function()
			window.moveWindow 'reasonable'
		end,
	},
	{
		id = 'window_center',
		name = 'Center Window',
		icon = 'computer',
		description = 'Center window without resizing',
		handler = function()
			window.moveWindow 'center'
		end,
	},

	-- Window Management Actions - Quarters
	{
		id = 'window_top_left',
		name = 'Window Top Left',
		icon = 'computer',
		description = 'Position window in top left quarter',
		handler = function()
			window.moveWindow 'top_left'
		end,
	},
	{
		id = 'window_top_right',
		name = 'Window Top Right',
		icon = 'computer',
		description = 'Position window in top right quarter',
		handler = function()
			window.moveWindow 'top_right'
		end,
	},
	{
		id = 'window_bottom_left',
		name = 'Window Bottom Left',
		icon = 'computer',
		description = 'Position window in bottom left quarter',
		handler = function()
			window.moveWindow 'bottom_left'
		end,
	},
	{
		id = 'window_bottom_right',
		name = 'Window Bottom Right',
		icon = 'computer',
		description = 'Position window in bottom right quarter',
		handler = function()
			window.moveWindow 'bottom_right'
		end,
	},

	-- Window Management Actions - Thirds (Horizontal)
	{
		id = 'window_left_third',
		name = 'Window Left Third',
		icon = 'computer',
		description = 'Position window in left third',
		handler = function()
			window.moveWindow 'left_third'
		end,
	},
	{
		id = 'window_center_third',
		name = 'Window Center Third',
		icon = 'computer',
		description = 'Position window in center third',
		handler = function()
			window.moveWindow 'center_third'
		end,
	},
	{
		id = 'window_right_third',
		name = 'Window Right Third',
		icon = 'computer',
		description = 'Position window in right third',
		handler = function()
			window.moveWindow 'right_third'
		end,
	},
	{
		id = 'window_left_two_thirds',
		name = 'Window Left Two Thirds',
		icon = 'computer',
		description = 'Position window in left two thirds',
		handler = function()
			window.moveWindow 'left_two_thirds'
		end,
	},
	{
		id = 'window_right_two_thirds',
		name = 'Window Right Two Thirds',
		icon = 'computer',
		description = 'Position window in right two thirds',
		handler = function()
			window.moveWindow 'right_two_thirds'
		end,
	},

	-- Window Management Actions - Thirds (Vertical)
	{
		id = 'window_top_third',
		name = 'Window Top Third',
		icon = 'computer',
		description = 'Position window in top third',
		handler = function()
			window.moveWindow 'top_third'
		end,
	},
	{
		id = 'window_middle_third',
		name = 'Window Middle Third',
		icon = 'computer',
		description = 'Position window in middle third',
		handler = function()
			window.moveWindow 'middle_third'
		end,
	},
	{
		id = 'window_bottom_third',
		name = 'Window Bottom Third',
		icon = 'computer',
		description = 'Position window in bottom third',
		handler = function()
			window.moveWindow 'bottom_third'
		end,
	},
	{
		id = 'window_top_two_thirds',
		name = 'Window Top Two Thirds',
		icon = 'computer',
		description = 'Position window in top two thirds',
		handler = function()
			window.moveWindow 'top_two_thirds'
		end,
	},
	{
		id = 'window_bottom_two_thirds',
		icon = 'computer',
		name = 'Window Bottom Two Thirds',
		description = 'Position window in bottom two thirds',
		handler = function()
			window.moveWindow 'bottom_two_thirds'
		end,
	},
}
