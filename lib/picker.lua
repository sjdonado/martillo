-- Picker state management for parent-child picker relationships
-- Provides state tracking for Nested Actions (child pickers)

local toast = require 'lib.toast'

local M = {}

--- Create a new picker manager
--- @return table PickerManager instance
function M.new()
  local manager = {
    stack = {},
    currentChooser = nil,
    logger = hs.logger.new('PickerManager', 'info'),
  }

  setmetatable(manager, { __index = M })
  return manager
end

--- Check if the current picker has a parent (i.e., there's at least one other picker in the stack)
--- Stack depth of 1 means only the current picker (no parent)
--- Stack depth > 1 means there are parent pickers below
--- @return boolean
function M:hasParent()
  return #self.stack > 1
end

--- Get the current depth of the picker stack
--- @return number
function M:depth()
  return #self.stack
end

--- Push a picker state onto the stack
--- @param state table State containing choices, placeholder, handlers, etc.
function M:pushPicker(state)
  table.insert(self.stack, state)
  self.logger:d('Pushed picker to stack, depth: ' .. #self.stack)
end

--- Pop a picker state from the stack
--- @return table|nil The picker state or nil if stack is empty
function M:popPicker()
  if #self.stack == 0 then
    return nil
  end

  local state = table.remove(self.stack)
  self.logger:d('Popped picker from stack, depth: ' .. #self.stack)
  return state
end

--- Clear all parent states from the stack
function M:clear()
  self.stack = {}
  self.logger:d 'Cleared picker stack'
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

--- Check if Shift key is held down
--- @return boolean True if Shift is held, false otherwise
function M.isShiftHeld()
  local modifiers = hs.eventtap.checkKeyboardModifiers()
  return modifiers.shift == true
end

return M
