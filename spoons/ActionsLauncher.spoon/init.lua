--- === ActionsLauncher ===
---
--- A customizable action palette for Hammerspoon that allows you to define and execute various actions
--- through a searchable interface using callback functions.
--- Supports nested pickers for dynamic actions.

local searchUtils = require("lib.search")
local pickerManager = require("lib.picker")

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
obj.logger = hs.logger.new("ActionsLauncher", "info")

--- ActionsLauncher:init()
--- Method
--- Initialize the spoon
function obj:init()
	self.pickerManager = pickerManager.new()
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

	-- Handle dynamic action (opens child picker)
	if result == "OPEN_CHILD_PICKER" then
		return "OPEN_CHILD_PICKER"
	end

	-- Handle action result with clipboard/paste logic
	pickerManager.handleActionResult(result)

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

	-- Set up query change callback for dynamic actions
	self.chooser:queryChangedCallback(function(query)
		self:handleQueryChange(query)
	end)

	-- Set choices
	self.chooser:choices(self.originalChoices)

	-- Store reference in picker manager
	self.pickerManager:setChooser(self.chooser)

	-- Set up Shift+ESC to close all pickers
	if self.escapeKeyWatcher then
		self.escapeKeyWatcher:stop()
		self.escapeKeyWatcher = nil
	end

	self.escapeKeyWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
		local keyCode = event:getKeyCode()
		local modifiers = event:getFlags()

		-- ESC key (keyCode 53) with Shift modifier
		if keyCode == 53 and modifiers.shift then
			-- Close all pickers
			self.pickerManager:clear()
			if self.chooser then
				self.chooser:hide()
			end
			return true -- Consume the event
		end

		return false -- Don't consume other events
	end)
	self.escapeKeyWatcher:start()

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

		self.originalChoices[i] = {
			text = action.name,
			subText = table.concat(subTextParts, " • "),
			uuid = uuid,
			copyToClipboard = false,
			alias = action.alias,
			isDynamic = action.isDynamic or false,
		}

		-- Bind action keys if provided
		if action.keys then
			for _, keySpec in ipairs(action.keys) do
				local mods = keySpec[1]
				local key = keySpec[2]
				local handler = action.handler

				local hotkey = hs.hotkey.bind(mods, key, function()
					local result = handler()
					if result and type(result) == "string" and result ~= "" then
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

--- ActionsLauncher:openChildPicker(config)
--- Method
--- Open a child picker for dynamic actions
---
--- Parameters:
---  * config - A table containing:
---    * placeholder - Placeholder text for the child picker
---    * handler - Function that takes query and returns choices
---    * parentAction - The parent action that opened this picker
function obj:openChildPicker(config)
	-- Save current state as parent
	local parentState = {
		choices = self.originalChoices,
		placeholder = "Search actions...",
		handlers = hs.fnutils.copy(self.handlers),
		parentAction = config.parentAction,
	}

	self.pickerManager:pushParent(parentState)
	self.logger:d("Opened child picker, stack depth: " .. self.pickerManager:depth())

	-- Close current picker
	if self.chooser then
		self.chooser:hide()
	end

	-- Small delay to ensure smooth transition
	hs.timer.doAfter(0.05, function()
		-- Create new chooser for child picker
		if self.chooser then
			self.chooser:delete()
		end

		self.chooser = hs.chooser.new(function(choice)
			self:executeActionWithModifiers(choice)
		end)

		self.chooser:rows(10)
		self.chooser:width(40)
		self.chooser:searchSubText(true)
		self.chooser:placeholderText(config.placeholder or "Type input...")

		-- Set up query change callback for child picker
		self.chooser:queryChangedCallback(function(query)
			if not query or query == "" then
				-- Empty query - show empty results
				local choices = config.handler("", self)
				self.chooser:choices(choices)
				return
			end

			-- Generate choices based on query
			local choices = config.handler(query, self)
			self.chooser:choices(choices)
		end)

		-- Set initial empty choices
		self.chooser:choices({})

		-- Set up DELETE key watcher for going back when query is empty
		if self.deleteKeyWatcher then
			self.deleteKeyWatcher:stop()
			self.deleteKeyWatcher = nil
		end

		self.deleteKeyWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
			local keyCode = event:getKeyCode()
			local modifiers = event:getFlags()
			local query = self.chooser and self.chooser:query() or ""

			-- Shift+ESC: Close all pickers
			if keyCode == 53 and modifiers.shift then
				self.pickerManager:clear()
				if self.chooser then
					self.chooser:hide()
				end
				return true -- Consume the event
			end

			-- DELETE key (keyCode 51) pressed when query is empty
			if keyCode == 51 and (not query or query == "") and self.pickerManager:hasParent() then
				-- Navigate back to parent
				self.chooser:hide()
				return true -- Consume the event
			end

			return false -- Don't consume other events
		end)
		self.deleteKeyWatcher:start()

		-- Store reference in picker manager
		self.pickerManager:setChooser(self.chooser)

		-- Automatically cleanup when chooser is hidden
		self.chooser:hideCallback(function()
			-- Stop DELETE key watcher
			if self.deleteKeyWatcher then
				self.deleteKeyWatcher:stop()
				self.deleteKeyWatcher = nil
			end

			-- Check if user pressed ESC or DELETE - navigate back to parent
			if self.pickerManager:hasParent() then
				local parent = self.pickerManager:popParent()

				-- Small delay before showing parent
				hs.timer.doAfter(0.05, function()
					self:restoreParentPicker(parent)
				end)
			else
				if self.chooser then
					self.chooser:delete()
					self.chooser = nil
				end
				self.pickerManager:clear()
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

	-- Set up Shift+ESC to close all pickers
	if self.escapeKeyWatcher then
		self.escapeKeyWatcher:stop()
		self.escapeKeyWatcher = nil
	end

	self.escapeKeyWatcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
		local keyCode = event:getKeyCode()
		local modifiers = event:getFlags()

		-- ESC key (keyCode 53) with Shift modifier
		if keyCode == 53 and modifiers.shift then
			-- Close all pickers
			self.pickerManager:clear()
			if self.chooser then
				self.chooser:hide()
			end
			return true -- Consume the event
		end

		return false -- Don't consume other events
	end)
	self.escapeKeyWatcher:start()

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
