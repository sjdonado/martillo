-- Martillo Actions Bundle
-- Core system management actions for Martillo

local icons = require 'lib.icons'

return {
	{
		id = 'martillo_reload',
		name = 'Reload Martillo',
		icon = icons.preset.axe,
		handler = function()
			hs.reload()
		end,
		description = 'Reload Hammerspoon and Martillo configuration',
	},
	{
		id = 'martillo_update',
		name = 'Update Martillo',
		icon = icons.preset.axe,
		handler = function()
			local task = hs.task.new('/bin/sh', function(exitCode, stdOut, stdErr)
				if exitCode == 0 then
					local output = stdOut and stdOut:gsub('%s+$', '') or ''
					if output ~= '' then
						hs.alert.show('✅ ' .. output .. ' - Reloading...', _G.MARTILLO_ALERT_DURATION)
					else
						hs.alert.show('✅ Update Martillo completed - Reloading...', _G.MARTILLO_ALERT_DURATION)
					end
					-- Reload Martillo after successful update
					hs.timer.doAfter(0.5, function()
						hs.reload()
					end)
				else
					hs.alert.show('Update Martillo failed: ' .. (stdErr or 'Unknown error'), _G.MARTILLO_ALERT_DURATION)
				end
			end, { '-c', 'cd ~/.martillo && git pull' })
			task:start()
		end,
		description = 'Pull latest changes and reload',
	},
}
