-- Martillo Actions Bundle
-- Core system management actions for Martillo

return {
	{
		id = "martillo_reload",
		name = "Reload Martillo",
		handler = function()
			hs.reload()
		end,
		description = "Reload Hammerspoon and Martillo configuration",
	},
	{
		id = "martillo_update",
		name = "Update Martillo",
		handler = function()
			spoon.ActionsLauncher.executeShell(
				"cd ~/.martillo && git pull",
				"Update Martillo"
			)
		end,
		description = "Pull latest changes",
	},
}
