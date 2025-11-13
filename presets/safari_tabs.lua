-- Safari Tabs Preset
-- Quick tab switcher with fuzzy search for Safari
-- Lists tabs by recency (current tab first, then other tabs in active window, then other windows)

local searchUtils = require("lib.search")
local navigation = require("lib.navigation")

local M = {
	logger = hs.logger.new("SafariTabs", "info"),
	iconSize = { w = 32, h = 32 }, -- Smaller icons for better performance
	safariIcon = nil, -- Fallback Safari icon
}

local function getSafariIcon()
	if not M.safariIcon then
		local icon = hs.image.imageFromAppBundle("com.apple.Safari")
		if icon then
			M.safariIcon = icon:setSize(M.iconSize)
		end
	end
	return M.safariIcon
end

local function getSafariTabs()
	local script = [[
		tell application "Safari"
			if not running then
				return "SAFARI_NOT_RUNNING"
			end

			set tabList to {}
			set currentWinIndex to -1
			set currentTabIndex to -1

			-- Get current window and tab
			try
				set currentWinIndex to index of front window
				set currentTabIndex to index of current tab of front window
			end try

			-- Iterate through all windows and tabs
			repeat with w from 1 to count of windows
				repeat with t from 1 to count of tabs of window w
					set tabTitle to name of tab t of window w
					set tabURL to URL of tab t of window w

					-- Determine sort priority
					-- 0 = current tab in current window (highest priority)
					-- 1 = other tabs in current window
					-- 2 = tabs in other windows
					set sortPriority to 2
					if w = currentWinIndex then
						if t = currentTabIndex then
							set sortPriority to 0
						else
							set sortPriority to 1
						end if
					end if

					set end of tabList to {tabTitle, tabURL, w, t, sortPriority}
				end repeat
			end repeat

			return tabList
		end tell
	]]

	local success, result, rawOutput = hs.osascript.applescript(script)

	if not success then
		M.logger:e("AppleScript failed: " .. tostring(rawOutput))
		return nil, "Failed to get Safari tabs"
	end

	-- Check if Safari is not running
	if type(result) == "string" and result == "SAFARI_NOT_RUNNING" then
		return nil, "Safari is not running"
	end

	if type(result) ~= "table" then
		M.logger:e("Unexpected result type: " .. type(result))
		return nil, "Unexpected response from Safari"
	end

	-- Parse results into tab objects
	local tabs = {}
	for _, tabData in ipairs(result) do
		if type(tabData) == "table" and #tabData >= 5 then
			table.insert(tabs, {
				title = tabData[1] or "Untitled",
				url = tabData[2] or "",
				windowIndex = tabData[3],
				tabIndex = tabData[4],
				sortPriority = tabData[5],
			})
		end
	end

	-- Sort by priority (current tab first, then tabs in current window, then other windows)
	table.sort(tabs, function(a, b)
		if a.sortPriority ~= b.sortPriority then
			return a.sortPriority < b.sortPriority
		end
		-- Within same priority, sort by window then tab index
		if a.windowIndex ~= b.windowIndex then
			return a.windowIndex < b.windowIndex
		end
		return a.tabIndex < b.tabIndex
	end)

	M.logger:d(string.format("Found %d Safari tabs", #tabs))
	return tabs, nil
end

-- Switch to a specific Safari tab
local function switchToTab(windowIndex, tabIndex)
	local script = string.format(
		[[
		tell application "Safari"
			activate
			set index of window %d to 1
			set current tab of window 1 to tab %d of window 1
		end tell
	]],
		windowIndex,
		tabIndex
	)

	local success, result, rawOutput = hs.osascript.applescript(script)

	if not success then
		M.logger:e("Failed to switch tab: " .. tostring(rawOutput))
		return false
	end

	return true
end

-- Format URL for display (truncate if too long)
local function formatURL(url, maxLength)
	maxLength = maxLength or 80
	if not url or url == "" then
		return ""
	end

	-- Remove protocol for cleaner display
	local displayURL = url:gsub("^https?://", "")

	if #displayURL <= maxLength then
		return displayURL
	end

	return displayURL:sub(1, maxLength - 3) .. "..."
end

-- Build choices for the picker
local function buildChoices(tabs, query, launcher)
	if not tabs or #tabs == 0 then
		return {}
	end

	-- Apply fuzzy search if query is provided
	local filteredTabs = tabs
	if query and query ~= "" then
		filteredTabs = searchUtils.rank(query, tabs, {
			getFields = function(tab)
				return {
					{ value = tab.title or "", weight = 1.0, key = "title" },
					{ value = tab.url or "", weight = 0.7, key = "url" },
				}
			end,
			fuzzyMinQueryLength = 3,
			maxResults = 100,
		})
	end

	-- Build choice entries
	local choices = {}
	for _, tab in ipairs(filteredTabs) do
		local uuid = launcher:generateUUID()

		local subText = formatURL(tab.url)
		if tab.sortPriority == 0 then
			subText = "★ " .. subText .. " (current)"
		end

		-- Get favicon for this tab (lazy loaded, cached by domain)
		local favicon = getSafariIcon()

		local choice = {
			text = tab.title,
			subText = subText,
			uuid = uuid,
			image = favicon, -- Add favicon
		}

		-- Register handler for this choice
		launcher.handlers[uuid] = function()
			local shiftHeld = navigation.isShiftHeld()

			if shiftHeld then
				-- Shift+Enter: Copy URL to clipboard
				hs.pasteboard.setContents(tab.url)
				hs.alert.show("📋 Copied URL", 0.5)
			else
				-- Enter: Switch to tab
				local success = switchToTab(tab.windowIndex, tab.tabIndex)
				if success then
					hs.alert.show("✓ Switched to tab", 0.5)
				else
					hs.alert.show("❌ Failed to switch to tab", 1)
				end
			end

			-- Return nil to prevent default copy/paste behavior
			return nil
		end

		table.insert(choices, choice)
	end

	return choices
end

return {
	{
		id = "safari_tabs",
		name = "Safari Tabs",
		description = "Switch to Safari tabs with fuzzy search",
		handler = function()
			-- Get Safari tabs
			local tabs, error = getSafariTabs()

			if error then
				hs.alert.show(error, 1.5)
				return
			end

			if not tabs or #tabs == 0 then
				hs.alert.show("No Safari tabs found", 1)
				return
			end

			-- Get ActionsLauncher instance
			local actionsLauncher = spoon.ActionsLauncher

			-- Open child picker
			actionsLauncher:openChildPicker({
				placeholder = "Search Safari tabs...",
				parentAction = "safari_tabs",
				handler = function(query, launcher)
					return buildChoices(tabs, query, launcher)
				end,
			})

			return "OPEN_CHILD_PICKER"
		end,
	},
}
