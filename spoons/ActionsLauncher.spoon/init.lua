--- === ActionsLauncher ===
---
--- A customizable action palette for Hammerspoon that allows you to define and execute various actions
--- through a searchable interface using callback functions.
--- Supports child pickers for Nested Actions.

local searchUtils = require("lib.search")
local navigation = require("lib.navigation")
local icons = require("lib.icons")

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "ActionsLauncher"
obj.version = "2.0"
obj.author = "sjdonado"
obj.homepage = "https://github.com/sjdonado/martillo/spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.hotkeys = {}
obj.actionHotkeys = {}
obj.chooser = nil
obj.actions = {}
obj.handlers = {}
obj.originalChoices = {}
obj.uuidCounter = 0
obj.pickerManager = nil
obj.deleteKeyWatcher = nil
obj.escapeKeyWatcher = nil
obj.currentChildHandler = nil
obj.logger = hs.logger.new("ActionsLauncher", "info")

--- ActionsLauncher:init()
--- Method
--- Initialize the spoon
function obj:init()
	self.pickerManager = navigation.new()
	return self
end

--- ActionsLauncher:executeActionWithModifiers(choice)
--- Method
--- Execute an action with modifier key detection
---
--- Parameters:
---  * choice - The chosen item
function obj:executeActionWithModifiers(choice)
	if not choice or not choice.uuid then
		return
	end

	local handler = self.handlers[choice.uuid]
	if not handler then
		return
	end

	local result = handler()

	-- Handle Nested Action (opens child picker)
	if result == "OPEN_CHILD_PICKER" then
		return "OPEN_CHILD_PICKER"
	end

	-- Handle string results with copy/paste logic
	if result and type(result) == "string" and result ~= "" then
		local shiftHeld = navigation.isShiftHeld()

		if shiftHeld then
			-- Shift+Enter: Copy only (no paste)
			hs.pasteboard.setContents(result)
			hs.alert.show("📋 " .. result)
		else
			-- Regular Enter: Copy and paste
			hs.pasteboard.setContents(result)
			hs.alert.show("✓ " .. result)
			-- Paste using keyStrokes
			hs.eventtap.keyStrokes(result)
		end
	end

	-- Close all pickers after executing action
	self.pickerManager:clear()
	if self.chooser then
		self.chooser:hide()
	end
end

--- ActionsLauncher:createChooser()
--- Method
--- Create a new chooser instance
function obj:createChooser()
	if self.chooser then
		self.chooser:delete()
	end

	self.chooser = hs.chooser.new(function(choice)
		self:executeActionWithModifiers(choice)
	end)

	self.chooser:rows(10)
	self.chooser:width(40)
	self.chooser:searchSubText(true)
	self.chooser:placeholderText("Search actions...")

	-- Set up query change callback for Nested Actions
	self.chooser:queryChangedCallback(function(query)
		self:handleQueryChange(query)
	end)

	-- Set choices
	self.chooser:choices(self.originalChoices)

	-- Store reference in picker manager
	self.pickerManager:setChooser(self.chooser)

	-- Set up Shift+ESC to close all pickers using navigation helper
	if self.escapeKeyWatcher then
		self.escapeKeyWatcher:stop()
		self.escapeKeyWatcher = nil
	end
	self.escapeKeyWatcher = navigation.setupShiftEscapeWatcher(self.pickerManager, self.chooser)

	-- Automatically cleanup when chooser is hidden
	self.chooser:hideCallback(function()
		-- Stop escape key watcher
		if self.escapeKeyWatcher then
			self.escapeKeyWatcher:stop()
			self.escapeKeyWatcher = nil
		end

		if self.chooser then
			self.chooser:delete()
			self.chooser = nil
		end
		-- Clear picker stack when completely closed
		if not self.pickerManager:hasParent() then
			self.pickerManager:clear()
		end
	end)
end

--- ActionsLauncher:setup(config)
--- Method
--- Setup the ActionsLauncher with actions
---
--- Parameters:
---  * config - A table containing:
---    * actions - A table of action definitions
---    * actionKeys - A table mapping action IDs to their keybindings (optional)
function obj:setup(config)
	config = config or {}

	-- Unbind any existing action hotkeys
	for _, hotkey in ipairs(self.actionHotkeys) do
		hotkey:delete()
	end
	self.actionHotkeys = {}

	-- Setup actions
	self.actions = config.actions or {}
	self.handlers = {}

	-- Convert actions to chooser format and store handlers
	self.originalChoices = {}
	for i, action in ipairs(self.actions) do
		local uuid = action.id or tostring(i)
		self.handlers[uuid] = action.handler

		local subTextParts = {}
		if action.description and action.description ~= "" then
			table.insert(subTextParts, action.description)
		end
		if action.alias and action.alias ~= "" then
			table.insert(subTextParts, "alias: " .. action.alias)
		end

		local choice = {
			text = action.name,
			subText = table.concat(subTextParts, " • "),
			uuid = uuid,
			copyToClipboard = false,
			alias = action.alias,
			isDynamic = action.isDynamic or false,
		}

		-- Add icon if specified
		if action.icon then
			local icon = icons.getIcon(action.icon)
			if icon then
				choice.image = icon
			end
		end

		self.originalChoices[i] = choice

		-- Bind action keys if provided
		if action.keys then
			for _, keySpec in ipairs(action.keys) do
				local mods = keySpec[1]
				local key = keySpec[2]
				local handler = action.handler

				local hotkey = hs.hotkey.bind(mods, key, function()
					local result = handler()
					-- Don't show alert for child picker actions or empty results
					if result and type(result) == "string" and result ~= "" and result ~= "OPEN_CHILD_PICKER" then
						hs.alert.show(result)
					end
				end)
				table.insert(self.actionHotkeys, hotkey)
			end
		end
	end

	return self
end

--- ActionsLauncher:show()
--- Method
--- Show the actions chooser
function obj:show()
	self:createChooser()
	self.chooser:show()
end

--- ActionsLauncher:hide()
--- Method
--- Hide the actions chooser
function obj:hide()
	if self.chooser then
		self.chooser:hide()
	end
end

--- ActionsLauncher:toggle()
--- Method
--- Toggle the actions chooser visibility
function obj:toggle()
	if self.chooser and self.chooser:isVisible() then
		self:hide()
	else
		self:show()
	end
end

--- ActionsLauncher:refresh()
--- Method
--- Refresh the current child picker by calling its handler again
--- This is useful when data changes and the picker needs to be updated
function obj:refresh()
	if not self.chooser or not self.chooser:isVisible() then
		self.logger:w("Cannot refresh: no visible chooser")
		return
	end

	if not self.currentChildHandler then
		self.logger:w("Cannot refresh: no child handler stored")
		return
	end

	-- Get current query
	local query = self.chooser:query() or ""

	-- Call handler to get updated choices
	local choices = self.currentChildHandler(query, self)

	-- Update chooser with new choices
	if choices then
		self.chooser:choices(choices)
		self.logger:d("Refreshed picker with " .. #choices .. " choices")
	end
end

--- ActionsLauncher:openChildPicker(config)
--- Method
--- Open a child picker for Nested Actions
---
--- Parameters:
---  * config - A table containing:
---    * placeholder - Placeholder text for the child picker
---    * handler - Function that takes query and returns choices
---    * parentAction - The parent action that opened this picker
---
--- Navigation behavior depends on whether the picker has a parent:
---  * With parent (opened from ActionsLauncher):
---    - DELETE/ESC on empty query: Navigate back to parent
---    - Enter: Execute action and close both child and parent
---  * Without parent (opened from keymap):
---    - DELETE/ESC on empty query: Close the picker
---    - Enter: Execute action and close the picker
function obj:openChildPicker(config)
	-- Store handler for refresh functionality
	self.currentChildHandler = config.handler

	-- Only save parent state if ActionsLauncher's chooser is visible
	-- This determines if we're opening from ActionsLauncher (has parent) or from keymap (standalone)
	local hasParent = self.chooser and self.chooser:isVisible()

	if hasParent then
		local parentState = {
			choices = self.originalChoices,
			placeholder = "Search actions...",
			handlers = hs.fnutils.copy(self.handlers),
			parentAction = config.parentAction,
		}
		self.pickerManager:pushParent(parentState)
		self.logger:d("Opened child picker with parent, stack depth: " .. self.pickerManager:depth())

		-- Close current picker
		self.chooser:hide()
	else
		self.logger:d("Opened standalone child picker (no parent)")
	end

	-- Small delay to ensure smooth transition
	hs.timer.doAfter(0.05, function()
		-- Capture whether we have a parent before any operations
		-- This is used by hideCallback to determine behavior
		local hadParentAtStart = self.pickerManager:hasParent()

		-- Flag to track if chooser was closed due to selection
		local closedBySelection = false

		-- Create new chooser for child picker
		if self.chooser then
			self.chooser:delete()
		end

		self.chooser = hs.chooser.new(function(choice)
			if choice then
				closedBySelection = true
			end
			self:executeActionWithModifiers(choice)
		end)

		self.chooser:rows(10)
		self.chooser:width(40)
		self.chooser:searchSubText(true)
		self.chooser:placeholderText(config.placeholder or "Type input...")

		-- Set up query change callback for child picker
		self.chooser:queryChangedCallback(function(query)
			if not query or query == "" then
				-- Empty query - show results from handler
				local choices = config.handler("", self)
				self.chooser:choices(choices)
				return
			end

			-- Generate choices based on query
			local choices = config.handler(query, self)
			self.chooser:choices(choices)
		end)

		-- Set initial choices by calling handler with empty query
		local initialChoices = config.handler("", self)
		self.chooser:choices(initialChoices)

		-- Set up DELETE key watcher for going back when query is empty using navigation helper
		if self.deleteKeyWatcher then
			self.deleteKeyWatcher:stop()
			self.deleteKeyWatcher = nil
		end
		self.deleteKeyWatcher = navigation.setupDeleteKeyWatcher(self.pickerManager, self.chooser, {})

		-- Store reference in picker manager
		self.pickerManager:setChooser(self.chooser)

		-- Automatically cleanup when chooser is hidden
		self.chooser:hideCallback(function()
			-- Stop DELETE key watcher
			if self.deleteKeyWatcher then
				self.deleteKeyWatcher:stop()
				self.deleteKeyWatcher = nil
			end

			-- Clear child handler
			self.currentChildHandler = nil

			-- Use captured parent state, not current state
			-- (current state may have been cleared by executeActionWithModifiers)
			if hadParentAtStart then
				-- Case 1: Child picker with parent (opened from ActionsLauncher)
				if closedBySelection then
					-- Enter pressed: Close both child and parent
					if self.chooser then
						self.chooser:delete()
						self.chooser = nil
					end
					-- Picker manager already cleared by executeActionWithModifiers
				else
					-- ESC/DELETE pressed: Navigate back to parent
					local parent = self.pickerManager:popParent()
					hs.timer.doAfter(0.05, function()
						self:restoreParentPicker(parent)
					end)
				end
			else
				-- Case 2: Child picker without parent (opened from keymap)
				-- Always just close the picker
				if self.chooser then
					self.chooser:delete()
					self.chooser = nil
				end
			end
		end)

		self.chooser:show()
	end)
end

--- ActionsLauncher:restoreParentPicker(parentState)
--- Method
--- Restore the parent picker with its original state
---
--- Parameters:
---  * parentState - The saved parent state
function obj:restoreParentPicker(parentState)
	if self.chooser then
		self.chooser:delete()
	end

	-- Restore handlers
	self.handlers = parentState.handlers

	self.chooser = hs.chooser.new(function(choice)
		self:executeActionWithModifiers(choice)
	end)

	self.chooser:rows(10)
	self.chooser:width(40)
	self.chooser:searchSubText(true)
	self.chooser:placeholderText(parentState.placeholder)

	-- Set up query change callback
	self.chooser:queryChangedCallback(function(query)
		self:handleQueryChange(query)
	end)

	-- Restore choices
	self.chooser:choices(parentState.choices)

	-- Store reference in picker manager
	self.pickerManager:setChooser(self.chooser)

	-- Set up Shift+ESC to close all pickers using navigation helper
	if self.escapeKeyWatcher then
		self.escapeKeyWatcher:stop()
		self.escapeKeyWatcher = nil
	end
	self.escapeKeyWatcher = navigation.setupShiftEscapeWatcher(self.pickerManager, self.chooser)

	-- Automatically cleanup when chooser is hidden
	self.chooser:hideCallback(function()
		-- Stop escape key watcher
		if self.escapeKeyWatcher then
			self.escapeKeyWatcher:stop()
			self.escapeKeyWatcher = nil
		end

		if self.chooser then
			self.chooser:delete()
			self.chooser = nil
		end
		if not self.pickerManager:hasParent() then
			self.pickerManager:clear()
		end
	end)

	self.chooser:show()
	self.logger:d("Restored parent picker")
end

--- ActionsLauncher:handleQueryChange(query)
--- Method
--- Handle query changes for search filtering
---
--- Parameters:
---  * query - The current search query
function obj:handleQueryChange(query)
	if not query or query == "" then
		if self.chooser then
			self.chooser:choices(self.originalChoices)
		end
		return
	end

	local rankedChoices = searchUtils.rank(query, self.originalChoices, {
		getFields = function(choice)
			return {
				{ value = choice.text or "",    weight = 1.0, key = "text" },
				{ value = choice.subText or "", weight = 0.6, key = "subText" },
				{ value = choice.alias or "",   weight = 1.2, key = "alias" },
			}
		end,
		fuzzyMinQueryLength = 4,
		tieBreaker = function(a, b)
			local aText = a.text or ""
			local bText = b.text or ""
			if aText ~= bText then
				return aText < bText
			end
			return (a.uuid or "") < (b.uuid or "")
		end,
	})

	self.chooser:choices(rankedChoices)
end

--- ActionsLauncher:generateUUID()
--- Method
--- Generate a unique identifier for actions
---
--- Returns:
---  * A unique string identifier
function obj:generateUUID()
	self.uuidCounter = self.uuidCounter + 1
	return "action_" .. tostring(self.uuidCounter) .. "_" .. tostring(os.time())
end

--- ActionsLauncher:createColorSwatch(r, g, b)
--- Method
--- Create a small color swatch image for color previews
---
--- Parameters:
---  * r - Red component (0-255)
---  * g - Green component (0-255)
---  * b - Blue component (0-255)
---
--- Returns:
---  * An hs.image object representing the color swatch
function obj:createColorSwatch(r, g, b)
	local size = { w = 20, h = 20 }
	local canvas = hs.canvas.new(size)

	canvas[1] = {
		type = "rectangle",
		frame = { x = 0, y = 0, w = size.w, h = size.h },
		fillColor = { red = r / 255, green = g / 255, blue = b / 255, alpha = 1.0 },
		strokeColor = { red = 0.5, green = 0.5, blue = 0.5, alpha = 1.0 },
		strokeWidth = 1,
	}

	local image = canvas:imageFromCanvas()
	canvas:delete()
	return image
end

--- ActionsLauncher.executeShell(command, actionName)
--- Function
--- Execute a shell command with error handling and user feedback
---
--- Parameters:
---  * command - The shell command to execute
---  * actionName - The name of the action (for user feedback)
function obj.executeShell(command, actionName)
	local task = hs.task.new("/bin/sh", function(exitCode, stdOut, stdErr)
		if exitCode == 0 then
			local output = stdOut and stdOut:gsub("%s+$", "") or ""
			if output ~= "" then
				hs.alert.show(output)
			else
				hs.alert.show(actionName .. " completed")
			end
		else
			hs.alert.show(actionName .. " failed: " .. (stdErr or "Unknown error"))
		end
	end, { "-c", command })
	task:start()
end

--- ActionsLauncher.executeAppleScript(script, actionName)
--- Function
--- Execute an AppleScript with error handling and user feedback
---
--- Parameters:
---  * script - The AppleScript to execute
---  * actionName - The name of the action (for user feedback)
function obj.executeAppleScript(script, actionName)
	local success, result = hs.applescript.applescript(script)
	if success then
		if result ~= "" then
			hs.alert.show(result)
		else
			hs.alert.show(actionName .. " completed")
		end
	else
		hs.alert.show(actionName .. " failed: " .. (result or "Unknown error"))
	end
	return result
end

--- ActionsLauncher:bindHotkeys(mapping)
--- Method
--- Bind hotkeys for ActionsLauncher
---
--- Parameters:
---  * mapping - A table containing hotkey mappings. Supported keys:
---    * show - Show the actions chooser
---    * toggle - Toggle the actions chooser
function obj:bindHotkeys(mapping)
	local def = {
		show = function()
			self:show()
		end,
		toggle = function()
			self:toggle()
		end,
	}
	hs.spoons.bindHotkeysToSpec(def, mapping)
	return self
end

return obj
