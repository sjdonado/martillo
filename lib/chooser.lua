-- Chooser state management for parent-child chooser relationships
-- Provides state tracking for Nested Actions (child choosers)

local toast = require 'lib.toast'

local M = {}

--- Create a new chooser manager
--- @return table ChooserManager instance
function M.new()
  local manager = {
    stack = {},
    currentChooser = nil,
    escTap = nil,
    onEscNavigate = nil,
    logger = hs.logger.new('ChooserManager', 'info'),
  }

  setmetatable(manager, { __index = M })
  return manager
end

--- Check if the current chooser has a parent (i.e., there's at least one other chooser in the stack)
--- Stack depth of 1 means only the current chooser (no parent)
--- Stack depth > 1 means there are parent choosers below
--- @return boolean
function M:hasParent()
  return #self.stack > 1
end

--- Get the current depth of the chooser stack
--- @return number
function M:depth()
  return #self.stack
end

--- Push a chooser state onto the stack
--- @param state table State containing choices, placeholder, handlers, etc.
function M:pushChooser(state)
  table.insert(self.stack, state)
  self.logger:d('Pushed chooser to stack, depth: ' .. #self.stack)
end

--- Pop a chooser state from the stack
--- @return table|nil The chooser state or nil if stack is empty
function M:popChooser()
  if #self.stack == 0 then
    return nil
  end

  local state = table.remove(self.stack)
  self.logger:d('Popped chooser from stack, depth: ' .. #self.stack)
  return state
end

--- Clear all parent states from the stack
function M:clear()
  self.stack = {}
  self.logger:d 'Cleared chooser stack'
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

--- Check if we should skip clearing the stack in hideCallback
--- This returns true when we're in the middle of ESC navigation:
--- - Stack has been popped but still has items (parent to restore)
--- - hideCallback is firing because we called hide() to transition
--- @return boolean True if we should keep the stack (navigating), false otherwise
function M:shouldKeepStack()
  local keepStack = #self.stack > 0
  if keepStack then
    self.logger:d('shouldKeepStack: YES (depth=' .. #self.stack .. ', navigating to parent)')
  else
    self.logger:d('shouldKeepStack: NO (depth=0, close all)')
  end
  return keepStack
end

--- Start ESC key interception for chooser navigation
--- This intercepts ESC before it reaches the chooser to distinguish:
---   - ESC alone: navigate to parent (event consumed)
---   - Shift+ESC: close all choosers (event propagates)
---   - Click outside: close all choosers (no ESC event)
--- @param onNavigate function Callback to execute when ESC is pressed (for parent navigation)
function M:startEscInterception(onNavigate)
  self.onEscNavigate = onNavigate

  if self.escTap then
    self.escTap:stop()
  end

  self.escTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
    local keyCode = event:getKeyCode()
    local flags = event:getFlags()

    -- ESC key is keycode 53
    if keyCode == 53 then
      if flags.shift then
        -- Shift+ESC: Let event through to close all choosers
        self.logger:d('Shift+ESC detected - closing all choosers')
        return false
      else
        -- ESC alone: Consume event and navigate to parent
        self.logger:d('ESC detected - navigating to parent')

        if self.onEscNavigate then
          self.onEscNavigate()
        end

        -- Consume the event to prevent chooser from closing
        return true
      end
    end

    -- Let all other keys through
    return false
  end)

  self.escTap:start()
  self.logger:d('ESC interception started')
end

--- Stop ESC key interception
function M:stopEscInterception()
  if self.escTap then
    self.escTap:stop()
    self.escTap = nil
    self.logger:d('ESC interception stopped')
  end
  self.onEscNavigate = nil
end

return M
