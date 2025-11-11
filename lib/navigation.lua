-- Picker state management for parent-child picker relationships
-- Provides state tracking for nested pickers (subpickers)

local M = {}

M.VERSION = "1.0.0"

--- Create a new picker manager
--- @return table PickerManager instance
function M.new()
    local manager = {
        stack = {},
        currentChooser = nil,
        logger = hs.logger.new('PickerManager', 'info')
    }

    setmetatable(manager, { __index = M })
    return manager
end

--- Check if there's a parent picker in the stack
--- @return boolean
function M:hasParent()
    return #self.stack > 0
end

--- Get the current depth of the picker stack
--- @return number
function M:depth()
    return #self.stack
end

--- Push a parent picker state onto the stack
--- @param state table State containing choices, placeholder, handlers, etc.
function M:pushParent(state)
    table.insert(self.stack, state)
    self.logger:d("Pushed parent to stack, depth: " .. #self.stack)
end

--- Pop the parent picker state from the stack
--- @return table|nil The parent state or nil if stack is empty
function M:popParent()
    if #self.stack == 0 then
        return nil
    end

    local state = table.remove(self.stack)
    self.logger:d("Popped parent from stack, depth: " .. #self.stack)
    return state
end

--- Peek at the parent picker state without removing it
--- @return table|nil The parent state or nil if stack is empty
function M:peekParent()
    if #self.stack == 0 then
        return nil
    end

    return self.stack[#self.stack]
end

--- Clear all parent states from the stack
function M:clear()
    self.stack = {}
    self.logger:d("Cleared picker stack")
end

--- Set the current chooser instance
--- @param chooser userdata The hs.chooser instance
function M:setChooser(chooser)
    self.currentChooser = chooser
end

--- Get the current chooser instance
--- @return userdata|nil The current chooser or nil
function M:getChooser()
    return self.currentChooser
end

--- Navigate back to parent picker
--- This is a helper that should be called when user wants to go back
--- @param onRestore function(state) Callback to restore parent picker with its state
--- @return boolean True if navigated back, false if no parent exists
function M:navigateBack(onRestore)
    local parentState = self:popParent()

    if not parentState then
        self.logger:d("No parent to navigate back to")
        return false
    end

    if onRestore then
        onRestore(parentState)
    end

    return true
end

--- Check if Shift key is held down
--- @return boolean True if Shift is held, false otherwise
function M.isShiftHeld()
    local modifiers = hs.eventtap.checkKeyboardModifiers()
    return modifiers.shift == true
end

--- Handle action completion with clipboard and paste logic
--- Regular Enter: Copy to clipboard only
--- Shift+Enter: Copy to clipboard AND paste/insert
---
--- @param result string|any The result from the action handler
--- @param options table Configuration options:
---   - onPaste: function(clipboardContent) Optional custom paste function
---   - skipClipboard: boolean If true, assume content already in clipboard
--- @return boolean True if handled, false otherwise
function M.handleActionResult(result, options)
    options = options or {}

    -- Only handle string results
    if not result or type(result) ~= "string" or result == "" then
        return false
    end

    -- Get Shift modifier state
    local shiftHeld = M.isShiftHeld()

    -- Get clipboard content (may have been set by handler already)
    local clipboardContent = hs.pasteboard.getContents()

    if shiftHeld then
        -- Shift+Enter: Copy and paste
        if not options.skipClipboard then
            hs.pasteboard.setContents(result)
            clipboardContent = result
        end

        -- Show alert
        hs.alert.show("✓ " .. result)

        -- Paste/insert content
        if options.onPaste then
            -- Use custom paste function if provided
            options.onPaste(clipboardContent)
        else
            -- Default: use keyStrokes to paste
            if clipboardContent and clipboardContent ~= "" then
                hs.eventtap.keyStrokes(clipboardContent)
            end
        end
    else
        -- Regular Enter: Copy only (no paste)
        if not options.skipClipboard then
            hs.pasteboard.setContents(result)
        end
        hs.alert.show("📋 " .. result)
    end

    return true
end

--- Wrap a chooser callback to close all pickers after execution
--- This is useful for ensuring pickers close after selecting an item
--- @param callback function(choice) The original callback
--- @param pickerManager table The picker manager instance
--- @param chooser userdata The chooser instance
--- @return function The wrapped callback
function M.wrapWithCloseAll(callback, pickerManager, chooser)
    return function(choice)
        if not choice then
            return
        end

        -- Execute the original callback
        local result = callback(choice)

        -- Don't close if opening a child picker
        if result == "OPEN_CHILD_PICKER" then
            return result
        end

        -- Close all pickers after action completes
        if pickerManager then
            pickerManager:clear()
        end
        if chooser then
            chooser:hide()
        end

        return result
    end
end

--- Setup keyboard event watcher for Shift+ESC (close all pickers)
--- @param pickerManager table The picker manager instance
--- @param chooser userdata The chooser instance
--- @return userdata The event tap watcher
function M.setupShiftEscapeWatcher(pickerManager, chooser)
    local watcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
        local keyCode = event:getKeyCode()
        local modifiers = event:getFlags()

        -- ESC key (keyCode 53) with Shift modifier
        if keyCode == 53 and modifiers.shift then
            -- Close all pickers
            if pickerManager then
                pickerManager:clear()
            end
            if chooser then
                chooser:hide()
            end
            return true -- Consume the event
        end

        return false -- Don't consume other events
    end)
    watcher:start()
    return watcher
end

--- Setup keyboard event watcher for DELETE key (go back to parent when query is empty)
--- Works for both parent and child pickers
--- @param pickerManager table The picker manager instance
--- @param chooser userdata The chooser instance
--- @param options table Optional configuration:
---   - onBackToParent: function() Callback when going back to parent (child picker only)
--- @return userdata The event tap watcher
function M.setupDeleteKeyWatcher(pickerManager, chooser, options)
    options = options or {}

    local watcher = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
        local keyCode = event:getKeyCode()
        local modifiers = event:getFlags()
        local query = chooser and chooser:query() or ""

        -- Shift+ESC: Close all pickers (handled by setupShiftEscapeWatcher)
        if keyCode == 53 and modifiers.shift then
            if pickerManager then
                pickerManager:clear()
            end
            if chooser then
                chooser:hide()
            end
            return true -- Consume the event
        end

        -- DELETE key (keyCode 51) pressed when query is empty
        if keyCode == 51 and (not query or query == "") and pickerManager:hasParent() then
            -- Navigate back to parent
            if chooser then
                chooser:hide()
            end

            -- Call callback if provided (for child pickers)
            if options.onBackToParent then
                options.onBackToParent()
            end

            return true -- Consume the event
        end

        return false -- Don't consume other events
    end)
    watcher:start()
    return watcher
end

return M
