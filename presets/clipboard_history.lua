-- Clipboard History Actions Bundle
-- Actions for accessing clipboard history from ActionsLauncher

-- Ensure ClipboardHistory spoon is loaded and started when this preset is required
if not spoon.ClipboardHistory then
	hs.loadSpoon("ClipboardHistory")
end

-- Start monitoring clipboard if not already started
if spoon.ClipboardHistory and not spoon.ClipboardHistory.watcher then
	spoon.ClipboardHistory:start()
end

return {
	{
		id = "clipboard_history",
		name = "Clipboard History",
		description = "Search and paste from clipboard history",
		handler = function()
			local navigation = require("lib.navigation")
			local clipboardSpoon = spoon.ClipboardHistory

			if not clipboardSpoon then
				hs.alert.show("ClipboardHistory spoon not loaded")
				return
			end

			-- Get ActionsLauncher instance to determine if we have a parent picker
			local actionsLauncher = spoon.ActionsLauncher
			local hasParent = actionsLauncher and actionsLauncher.pickerManager ~= nil

			-- Capture focus before showing picker
			clipboardSpoon:captureFocus()

			-- Define the callback for when user selects an item
			local onSelect = function(choice)
				if not choice then
					return
				end

				-- Check if Shift is held to determine behavior
				local shiftHeld = navigation.isShiftHeld()

				if shiftHeld then
					-- Shift+Enter: Copy only (no paste)
					clipboardSpoon:copyToClipboard(choice)
				else
					-- Regular Enter: Copy and paste (but respect copy-only apps)
					local shouldJustCopy = clipboardSpoon:shouldOnlyCopyForApp()
					if shouldJustCopy then
						clipboardSpoon:copyToClipboard(choice)
					else
						clipboardSpoon:pasteContent(choice)
					end
				end

				-- Close all pickers after action completes
				if hasParent and actionsLauncher.pickerManager then
					actionsLauncher.pickerManager:clear()
				end
				if clipboardSpoon.chooser then
					clipboardSpoon.chooser:hide()
				end
			end

			-- Hide parent picker if we have one
			if hasParent then
				-- Save parent state
				local parentState = {
					choices = actionsLauncher.originalChoices,
					placeholder = "Search actions...",
					handlers = hs.fnutils.copy(actionsLauncher.handlers),
					parentAction = "clipboard_history",
				}
				actionsLauncher.pickerManager:pushParent(parentState)

				if actionsLauncher.chooser then
					actionsLauncher.chooser:hide()
				end
			end

			-- Small delay before showing ClipboardHistory to ensure smooth transition
			hs.timer.doAfter(0.05, function()
				-- Flag to track if chooser was closed due to selection
				local closedBySelection = false

				-- Destroy existing chooser if it exists
				if clipboardSpoon.chooser then
					clipboardSpoon.chooser:delete()
					clipboardSpoon.chooser = nil
				end

				-- Wrap onSelect to set the flag
				local wrappedOnSelect = function(choice)
					if choice then
						closedBySelection = true
					end
					return onSelect(choice)
				end

				-- Create new chooser
				clipboardSpoon.chooser = hs.chooser.new(wrappedOnSelect)
				clipboardSpoon.chooser:rows(10)
				clipboardSpoon.chooser:width(40)
				clipboardSpoon.chooser:searchSubText(true)
				clipboardSpoon.chooser:queryChangedCallback(function(query)
					clipboardSpoon.currentQuery = query
					clipboardSpoon:updateChoices()
				end)

				-- Reset query and load history
				clipboardSpoon.currentQuery = ""
				clipboardSpoon:updateChoices()
				clipboardSpoon.chooser:selectedRow(1)

				-- Set up keyboard watchers
				local deleteKeyWatcher = nil
				local escapeKeyWatcher = nil

				-- Only set up DELETE key navigation if we have a parent
				if hasParent then
					deleteKeyWatcher = navigation.setupDeleteKeyWatcher(
						actionsLauncher.pickerManager,
						clipboardSpoon.chooser
					)
				end

				-- Always set up Shift+ESC to close all pickers
				if hasParent then
					escapeKeyWatcher = navigation.setupShiftEscapeWatcher(
						actionsLauncher.pickerManager,
						clipboardSpoon.chooser
					)
				else
					-- For keymap (no parent), Shift+ESC should just close the picker
					escapeKeyWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
						local keyCode = event:getKeyCode()
						local modifiers = event:getFlags()
						-- ESC key (keyCode 53) with Shift modifier
						if keyCode == 53 and modifiers.shift then
							if clipboardSpoon.chooser then
								clipboardSpoon.chooser:hide()
							end
							return true
						end
						return false
					end)
					escapeKeyWatcher:start()
				end

				-- Set up hide callback for cleanup and navigation
				clipboardSpoon.chooser:hideCallback(function()
					-- Stop keyboard watchers
					if deleteKeyWatcher then
						deleteKeyWatcher:stop()
						deleteKeyWatcher = nil
					end
					if escapeKeyWatcher then
						escapeKeyWatcher:stop()
						escapeKeyWatcher = nil
					end

					-- Only navigate back if NOT closed by selection and we have a parent
					if not closedBySelection and hasParent and actionsLauncher.pickerManager:hasParent() then
						local parent = actionsLauncher.pickerManager:popParent()

						-- Small delay before restoring parent
						hs.timer.doAfter(0.05, function()
							actionsLauncher:restoreParentPicker(parent)
						end)
					else
						-- Closed by selection or no parent, just cleanup
						if clipboardSpoon.chooser then
							clipboardSpoon.chooser:delete()
							clipboardSpoon.chooser = nil
						end
					end
				end)

				-- Show the chooser
				clipboardSpoon.chooser:show()
			end)

			-- Return special marker if opened as child picker
			if hasParent then
				return "OPEN_CHILD_PICKER"
			end
		end,
	},
}
