-- Window Management Actions Bundle
-- Actions for positioning and resizing windows

package.path = package.path .. ";" .. os.getenv("HOME") .. "/.martillo/?.lua"

local window = require("lib.window")

return {
	-- Window Management Actions - Sizing
	{
		id = "window_maximize",
		name = "Maximize Window",
		handler = function()
			window.moveWindow("max")
		end,
		description = "Maximize window to full screen",
	},
	{
		id = "window_almost_maximize",
		name = "Almost Maximize",
		handler = function()
			window.moveWindow("almost_max")
		end,
		description = "Resize window to 90% of screen, centered",
	},
	{
		id = "window_reasonable_size",
		name = "Reasonable Size",
		handler = function()
			window.moveWindow("reasonable")
		end,
		description = "Resize window to reasonable size 70% of screen, centered",
	},
	{
		id = "window_center",
		name = "Center Window",
		handler = function()
			window.moveWindow("center")
		end,
		description = "Center window without resizing",
	},

	-- Window Management Actions - Quarters
	{
		id = "window_top_left",
		name = "Window Top Left",
		handler = function()
			window.moveWindow("top_left")
		end,
		description = "Position window in top left quarter",
	},
	{
		id = "window_top_right",
		name = "Window Top Right",
		handler = function()
			window.moveWindow("top_right")
		end,
		description = "Position window in top right quarter",
	},
	{
		id = "window_bottom_left",
		name = "Window Bottom Left",
		handler = function()
			window.moveWindow("bottom_left")
		end,
		description = "Position window in bottom left quarter",
	},
	{
		id = "window_bottom_right",
		name = "Window Bottom Right",
		handler = function()
			window.moveWindow("bottom_right")
		end,
		description = "Position window in bottom right quarter",
	},

	-- Window Management Actions - Thirds (Horizontal)
	{
		id = "window_left_third",
		name = "Window Left Third",
		handler = function()
			window.moveWindow("left_third")
		end,
		description = "Position window in left third",
	},
	{
		id = "window_center_third",
		name = "Window Center Third",
		handler = function()
			window.moveWindow("center_third")
		end,
		description = "Position window in center third",
	},
	{
		id = "window_right_third",
		name = "Window Right Third",
		handler = function()
			window.moveWindow("right_third")
		end,
		description = "Position window in right third",
	},
	{
		id = "window_left_two_thirds",
		name = "Window Left Two Thirds",
		handler = function()
			window.moveWindow("left_two_thirds")
		end,
		description = "Position window in left two thirds",
	},
	{
		id = "window_right_two_thirds",
		name = "Window Right Two Thirds",
		handler = function()
			window.moveWindow("right_two_thirds")
		end,
		description = "Position window in right two thirds",
	},

	-- Window Management Actions - Thirds (Vertical)
	{
		id = "window_top_third",
		name = "Window Top Third",
		handler = function()
			window.moveWindow("top_third")
		end,
		description = "Position window in top third",
	},
	{
		id = "window_middle_third",
		name = "Window Middle Third",
		handler = function()
			window.moveWindow("middle_third")
		end,
		description = "Position window in middle third",
	},
	{
		id = "window_bottom_third",
		name = "Window Bottom Third",
		handler = function()
			window.moveWindow("bottom_third")
		end,
		description = "Position window in bottom third",
	},
	{
		id = "window_top_two_thirds",
		name = "Window Top Two Thirds",
		handler = function()
			window.moveWindow("top_two_thirds")
		end,
		description = "Position window in top two thirds",
	},
	{
		id = "window_bottom_two_thirds",
		name = "Window Bottom Two Thirds",
		handler = function()
			window.moveWindow("bottom_two_thirds")
		end,
		description = "Position window in bottom two thirds",
	},
}
