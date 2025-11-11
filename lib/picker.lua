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

return M
