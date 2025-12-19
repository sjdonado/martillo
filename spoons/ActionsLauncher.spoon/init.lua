--- A customizable action palette for Hammerspoon that allows you to define and execute various actions
--- through a searchable interface using callback functions.
--- Supports child choosers for Nested Actions.

local searchUtils = require 'lib.search'
local chooserManager = require 'lib.chooser'
local icons = require 'lib.icons'

local obj = {}
obj.__index = obj

obj.hotkeys = {}
obj.actionHotkeys = {}
obj.chooser = nil
obj.actions = {}
obj.handlers = {}
obj.originalChoices = {}
obj.uuidCounter = 0
obj.chooserManager = nil
obj.deleteKeyWatcher = nil
obj.escapeKeyWatcher = nil
obj.currentChildHandler = nil
obj.childChooserOpening = false -- Track if a child chooser is being opened
obj.logger = hs.logger.new('ActionsLauncher', 'debug')

--- ActionsLauncher:init()
--- Method
--- Initialize the spoon
function obj:init()
  self.chooserManager = chooserManager.new()
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

  -- Reset child chooser opening flag before calling handler
  self.childChooserOpening = false

  local result = handler()

  -- Handle Nested Action (opens child chooser)
  -- Check if a child chooser was opened during handler execution
  if self.childChooserOpening then
    -- STACK ACTION: No change (keep current chooser in stack)
    -- RESULT: Child chooser will push itself on top, increasing depth
    self.logger:d('Child chooser opened, keeping current chooser in stack')
    return
  end

  -- ACTION COMPLETED (not opening child chooser)
  -- STACK ACTION: Pop current chooser + clear entire stack
  -- RESULT: All choosers close, stack depth = 0
  self.logger:d('Action completed, popping current chooser and clearing stack, depth before=' ..
  self.chooserManager:depth())
  self.chooserManager:popChooser()
  self.chooserManager:clear()
  self.logger:d('Popped and cleared, depth after=' .. self.chooserManager:depth())

  -- Note: String results from handlers are no longer automatically copied/pasted.
  -- Use action helpers from lib/actions.lua for common patterns:
  --   - actions.copyToClipboard() for copy only
  --   - actions.copyAndPaste() for copy + paste with Shift modifier support
  --   - actions.showToast() for displaying messages
  --   - actions.noAction() for display-only choosers

  -- Close all choosers after executing action (for non-string results or when not copying)
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
    if not choice then
      -- EVENT: Shift+ESC or programmatic cancel
      -- Note: Plain ESC is now intercepted by escTap and won't reach here
      self.logger:d('Main launcher - choice = nil (Shift+ESC or cancel)')
      return
    end

    -- EVENT: Enter pressed in main launcher
    -- STACK ACTION: Will be handled in executeActionWithModifiers
    self.logger:d('Main launcher - Enter pressed')
    self:executeActionWithModifiers(choice)
  end)

  self.chooser:rows(10)
  self.chooser:width(40)
  self.chooser:searchSubText(true)
  self.chooser:placeholderText 'Search actions...'

  -- Set up query change callback
  self.chooser:queryChangedCallback(function(query)
    self:handleQueryChange(query)
  end)

  self.chooser:choices(self.originalChoices)
  self.chooserManager:setChooser(self.chooser)

  -- Cleanup when hidden
  self.chooser:hideCallback(function()
    self.logger:d('Main launcher hideCallback - Always stopping key interceptions')
    -- Always stop key interceptions when hiding
    self.chooserManager:stopAllInterceptions()

    -- Check if we should keep the stack (ESC navigation in progress)
    if not self.chooserManager:shouldKeepStack() then
      self.logger:d('Main launcher hideCallback - Clearing stack')
      -- Clear stack (Shift+ESC, click-outside, or Enter)
      self.chooserManager:clear()
    end
    if self.chooser then
      self.chooser:delete()
      self.chooser = nil
    end
  end)

  -- Start key interceptions for navigation
  self.chooserManager:startEscInterception(function()
    -- ESC pressed - navigate to parent
    self.logger:d('ESC navigation - popping from stack, depth before=' .. self.chooserManager:depth())
    self.chooserManager:popChooser()
    local depthAfter = self.chooserManager:depth()
    self.logger:d('Popped, depth after=' .. depthAfter)

    if depthAfter > 0 then
      -- Restore parent chooser
      -- Stack still has items, so hideCallback will keep the stack
      local parentChooser = self.chooserManager.stack[depthAfter]
      self.logger:d('Restoring parent chooser')
      -- Hide current chooser first
      if self.chooser then
        self.chooser:hide()
      end
      -- Restore parent after hiding current
      hs.timer.doAfter(0, function()
        if parentChooser.isMainLauncher then
          self:restoreParentChooser(parentChooser)
        elseif parentChooser.isChildChooser then
          self:openChildChooser(parentChooser.config, { pushToStack = false })
        end
      end)
    else
      -- No parent, just close (stack is empty, hideCallback will clear)
      self.logger:d('No parent to restore, stopping key interceptions and closing')
      self.chooserManager:stopAllInterceptions()
      if self.chooser then
        self.chooser:hide()
      end
    end
  end)

  -- Start Tab interception for navigation
  self.chooserManager:startTabInterception()
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
    if action.description and action.description ~= '' then
      table.insert(subTextParts, action.description)
    end
    if action.alias and action.alias ~= '' then
      table.insert(subTextParts, 'alias: ' .. action.alias)
    end

    local choice = {
      text = action.name,
      subText = table.concat(subTextParts, ' • '),
      uuid = uuid,
      alias = action.alias,
      isDynamic = action.isDynamic or false,
    }

    -- Add icon if specified (icon should be an absolute path)
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
          -- Reset flag before calling handler
          self.childChooserOpening = false
          local result = handler()
          -- Don't show alert for child chooser actions or empty results
          if not self.childChooserOpening and result and type(result) == 'string' and result ~= '' then
            hs.alert.show(result, _G.MARTILLO_ALERT_DURATION or 2)
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
  -- If a chooser is already visible, close it and clear the stack first
  -- This handles opening main launcher via keystroke while another chooser is open
  if self.chooser and self.chooser:isVisible() then
    self.logger:d('Main launcher opened while chooser visible, closing and clearing stack')
    self.chooser:hide()
    self.chooserManager:clear()
  end

  -- Always clear the stack before opening main launcher
  -- This handles dirty stack from previous click-outside or other incomplete navigation
  if self.chooserManager:depth() > 0 then
    self.logger:d('Main launcher opening with dirty stack (depth=' .. self.chooserManager:depth() .. '), clearing')
    self.chooserManager:clear()
  end

  self:createChooser()

  -- EVENT: Main launcher opened (via toggle/show)
  -- STACK ACTION: Push to stack
  -- RESULT: Stack depth = 1
  local state = {
    choices = self.originalChoices,
    placeholder = 'Search actions...',
    handlers = hs.fnutils.copy(self.handlers),
    isMainLauncher = true,
  }
  self.chooserManager:pushChooser(state)
  self.logger:d('Main launcher opened, pushed to stack, depth: ' .. self.chooserManager:depth())

  self.chooser:show()
end

--- ActionsLauncher:hide()
--- Method
--- Hide the actions chooser
function obj:hide()
  if self.chooser then
    self.chooser:hide()
  end
  -- Clear stack when explicitly hiding
  self.chooserManager:clear()
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
--- Refresh the current child chooser by calling its handler again
--- This is useful when data changes and the chooser needs to be updated
function obj:refresh()
  if not self.chooser or not self.chooser:isVisible() then
    self.logger:w 'Cannot refresh: no visible chooser'
    return
  end

  if not self.currentChildHandler then
    self.logger:w 'Cannot refresh: no child handler stored'
    return
  end

  -- Get current query
  local query = self.chooser:query() or ''

  -- Call handler to get updated choices
  local choices = self.currentChildHandler(query, self)

  -- Update chooser with new choices
  if choices then
    self.chooser:choices(choices)
    self.logger:d('Refreshed chooser with ' .. #choices .. ' choices')
  end
end

--- ActionsLauncher:openChildChooser(config, options)
--- Method
--- Open a child chooser for Nested Actions
---
--- Parameters:
---  * config - A table containing:
---    * placeholder - Placeholder text for the child chooser
---    * handler - Function that takes query and returns choices
---    * parentAction - The parent action that opened this chooser
---  * options - Optional table with:
---    * pushToStack - Whether to push this chooser to stack (default: true)
---                    Set to false when restoring from ESC navigation
---    * cleanStack - Whether to clear the stack before opening (default: false)
---                   Set to true when opening from a keystroke while another chooser is visible
---
--- chooserManager behavior depends on whether the chooser has a parent:
---  * With parent (opened from ActionsLauncher):
---    - ESC on empty query: Navigate back to parent
---    - Enter: Execute action and close both child and parent
---  * Without parent (opened from keymap):
---    - ESC on empty query: Close the chooser
---    - Enter: Execute action and close the chooser
function obj:openChildChooser(config, options)
  -- Set flag to indicate a child chooser is being opened
  -- This allows executeActionWithModifiers to detect it without requiring a return value
  self.childChooserOpening = true

  options = options or {}
  local pushToStack = options.pushToStack
  if pushToStack == nil then
    pushToStack = true -- Default: push to stack
  end
  local cleanStack = options.cleanStack

  -- Auto-detect: if cleanStack not explicitly set and a chooser is visible with items in stack,
  -- and this is a new chooser (not restoring from ESC), then clean the stack
  if cleanStack == nil then
    if self.chooser and self.chooser:isVisible() and self.chooserManager:depth() > 0 and pushToStack then
      -- A chooser is already open and we're pushing a new one (not restoring)
      -- This likely means opening from keystroke, so clean the stack
      cleanStack = true
      self.logger:d('Auto-detected keystroke open while chooser visible, will clean stack')
    else
      cleanStack = false
    end
  end

  -- Always clear dirty stack when opening child chooser from keymap
  -- This handles the case where previous chooser was closed by clicking outside or Shift+ESC
  if not cleanStack and self.chooserManager:depth() > 1 and pushToStack then
    self.logger:d('Child chooser opening with dirty stack (depth=' .. self.chooserManager:depth() .. '), clearing')
    cleanStack = true
  end

  -- Store handler for refresh functionality
  self.currentChildHandler = config.handler

  -- Close current chooser if visible
  if self.chooser then
    self.logger:d('Closing current chooser, stack depth before: ' .. self.chooserManager:depth())
    self.chooser:hide()
  end

  -- Clear stack if needed (e.g., when opening from keystroke while another chooser is visible)
  if cleanStack then
    self.logger:d('Cleaning stack before opening new chooser')
    self.chooserManager:clear()
  end

  -- Small delay to ensure smooth transition
  hs.timer.doAfter(0, function()
    -- Create new chooser for child chooser
    if self.chooser then
      self.chooser:delete()
    end

    self.chooser = hs.chooser.new(function(choice)
      if not choice then
        -- EVENT: Shift+ESC or programmatic cancel
        -- Note: Plain ESC is now intercepted by escTap and won't reach here
        self.logger:d('Child chooser - choice = nil (Shift+ESC or cancel)')
        return
      end

      -- EVENT: Enter pressed in child chooser
      -- STACK ACTION: Will be handled in executeActionWithModifiers
      self.logger:d('Child chooser - Enter pressed')
      self:executeActionWithModifiers(choice)
    end)

    self.chooser:rows(10)
    self.chooser:width(40)
    self.chooser:searchSubText(true)
    self.chooser:placeholderText(config.placeholder or 'Type input...')

    -- Set up query change callback for child chooser
    self.chooser:queryChangedCallback(function(query)
      if not query or query == '' then
        -- Empty query - show results from handler
        local choices = config.handler('', self)
        self.chooser:choices(choices)
        return
      end

      -- Generate choices based on query
      local choices = config.handler(query, self)
      self.chooser:choices(choices)
    end)

    -- Set initial choices by calling handler with empty query
    local initialChoices = config.handler('', self)
    self.chooser:choices(initialChoices)

    -- Push to stack if requested (default behavior for new child choosers)
    -- Don't push when restoring from ESC navigation (chooser already in stack)
    if pushToStack then
      -- EVENT: Child chooser opened (from main launcher or another child)
      -- STACK ACTION: Push to stack
      local childState = {
        config = config,
        isChildChooser = true,
      }
      self.chooserManager:pushChooser(childState)
      self.logger:d('Child chooser opened, pushed to stack, depth: ' .. self.chooserManager:depth())
    else
      -- EVENT: Restoring child chooser from ESC navigation
      -- STACK ACTION: No push (chooser already in stack)
      self.logger:d('Child chooser restored (not pushed), stack depth: ' .. self.chooserManager:depth())
    end

    self.chooserManager:setChooser(self.chooser)

    -- Cleanup when hidden
    self.chooser:hideCallback(function()
      self.logger:d('Child chooser hideCallback - Always stopping key interceptions')
      -- Always stop key interceptions when hiding
      self.chooserManager:stopAllInterceptions()

      -- Check if we should keep the stack (ESC navigation in progress)
      if not self.chooserManager:shouldKeepStack() then
        self.logger:d('Child chooser hideCallback - Clearing stack')
        -- Clear stack (Shift+ESC, click-outside, or Enter)
        self.chooserManager:clear()
      end

      -- Call onClose callback if provided
      if config.onClose then
        config.onClose()
      end

      self.currentChildHandler = nil

      if self.chooser then
        self.chooser:delete()
        self.chooser = nil
      end
    end)

    -- Start ESC interception for navigation
    self.chooserManager:startEscInterception(function()
      -- ESC pressed - navigate to parent
      self.logger:d('ESC navigation from child - popping from stack, depth before=' .. self.chooserManager:depth())
      self.chooserManager:popChooser()
      local depthAfter = self.chooserManager:depth()
      self.logger:d('Popped, depth after=' .. depthAfter)

      if depthAfter > 0 then
        -- Restore parent chooser
        -- Stack still has items, so hideCallback will keep the stack
        local parentChooser = self.chooserManager.stack[depthAfter]
        self.logger:d('Restoring parent chooser')
        -- Hide current chooser first
        if self.chooser then
          self.chooser:hide()
        end
        -- Restore parent after hiding current
        hs.timer.doAfter(0, function()
          if parentChooser.isMainLauncher then
            self:restoreParentChooser(parentChooser)
          elseif parentChooser.isChildChooser then
            self:openChildChooser(parentChooser.config, { pushToStack = false })
          end
        end)
      else
        -- No parent, just close (stack is empty, hideCallback will clear)
        self.logger:d('No parent to restore, stopping key interceptions and closing')
        self.chooserManager:stopAllInterceptions()
        if self.chooser then
          self.chooser:hide()
        end
      end
    end)

    -- Start Tab interception for navigation
    self.chooserManager:startTabInterception()

    -- Set initial query if provided
    if config.initialQuery and config.initialQuery ~= '' then
      -- Show chooser first so it can receive keystrokes
      self.chooser:show()

      -- Small delay to ensure chooser is ready
      hs.timer.doAfter(0.01, function()
        self.chooser:query(config.initialQuery)

        -- Deselect text by moving cursor to end
        -- Try multiple approaches as fallback
        hs.timer.doAfter(0.02, function()
          -- Approach 1: Right arrow to deselect and move to end
          hs.eventtap.keyStroke({ 'cmd' }, 'right')
        end)
      end)

      -- Early return since we already called show()
      return
    end

    self.chooser:show()
  end)
end

--- ActionsLauncher:restoreParentChooser(parentState)
--- Method
--- Restore the parent chooser with its original state
---
--- Parameters:
---  * parentState - The saved parent state
function obj:restoreParentChooser(parentState)
  if self.chooser then
    self.chooser:delete()
  end

  -- Restore handlers
  self.handlers = parentState.handlers

  self.chooser = hs.chooser.new(function(choice)
    if not choice then
      -- EVENT: Shift+ESC or programmatic cancel
      -- Note: Plain ESC is now intercepted by escTap and won't reach here
      self.logger:d('Restored parent - choice = nil (Shift+ESC or cancel)')
      return
    end

    -- EVENT: Enter pressed in restored parent
    -- STACK ACTION: Will be handled in executeActionWithModifiers
    self.logger:d('Restored parent - Enter pressed')
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
  self.chooserManager:setChooser(self.chooser)

  -- Cleanup when hidden
  self.chooser:hideCallback(function()
    self.logger:d('Restored parent hideCallback - Always stopping key interceptions')
    -- Always stop key interceptions when hiding
    self.chooserManager:stopAllInterceptions()

    -- Check if we should keep the stack (ESC navigation in progress)
    if not self.chooserManager:shouldKeepStack() then
      self.logger:d('Restored parent hideCallback - Clearing stack')
      -- Clear stack (Shift+ESC, click-outside, or Enter)
      self.chooserManager:clear()
    end
    if self.chooser then
      self.chooser:delete()
      self.chooser = nil
    end
  end)

  -- Start ESC interception for navigation
  self.chooserManager:startEscInterception(function()
    -- ESC pressed - navigate to parent
    self.logger:d('ESC navigation from restored parent - popping from stack, depth before=' ..
    self.chooserManager:depth())
    self.chooserManager:popChooser()
    local depthAfter = self.chooserManager:depth()
    self.logger:d('Popped, depth after=' .. depthAfter)

    if depthAfter > 0 then
      -- Restore parent chooser
      -- Stack still has items, so hideCallback will keep the stack
      local parentChooser = self.chooserManager.stack[depthAfter]
      self.logger:d('Restoring parent chooser')
      -- Hide current chooser first
      if self.chooser then
        self.chooser:hide()
      end
      -- Restore parent after hiding current
      hs.timer.doAfter(0, function()
        if parentChooser.isMainLauncher then
          self:restoreParentChooser(parentChooser)
        elseif parentChooser.isChildChooser then
          self:openChildChooser(parentChooser.config, { pushToStack = false })
        end
      end)
    else
      -- No parent, just close (stack is empty, hideCallback will clear)
      self.logger:d('No parent to restore, stopping key interceptions and closing')
      self.chooserManager:stopAllInterceptions()
      if self.chooser then
        self.chooser:hide()
      end
    end
  end)

  -- Start Tab interception for navigation
  self.chooserManager:startTabInterception()

  self.chooser:show()
end

--- ActionsLauncher:handleQueryChange(query)
--- Method
--- Handle query changes for search filtering
---
--- Parameters:
---  * query - The current search query
function obj:handleQueryChange(query)
  if not query or query == '' then
    if self.chooser then
      self.chooser:choices(self.originalChoices)
    end
    return
  end

  local rankedChoices = searchUtils.rank(query, self.originalChoices, {
    getFields = function(choice)
      return {
        { value = choice.text or '',    weight = 1.0, key = 'text' },
        { value = choice.subText or '', weight = 0.6, key = 'subText' },
        { value = choice.alias or '',   weight = 1.2, key = 'alias' },
      }
    end,
    fuzzyMinQueryLength = 4,
    tieBreaker = function(a, b)
      local aText = a.text or ''
      local bText = b.text or ''
      if aText ~= bText then
        return aText < bText
      end
      return (a.uuid or '') < (b.uuid or '')
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
  return 'action_' .. tostring(self.uuidCounter) .. '_' .. tostring(os.time())
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
    type = 'rectangle',
    frame = { x = 0, y = 0, w = size.w, h = size.h },
    fillColor = { red = r / 255, green = g / 255, blue = b / 255, alpha = 1.0 },
    strokeColor = { red = 0.5, green = 0.5, blue = 0.5, alpha = 1.0 },
    strokeWidth = 1,
  }

  local image = canvas:imageFromCanvas()
  canvas:delete()
  return image
end

--- ActionsLauncher.executeShell(command, actionName, copyToClipboard)
--- Function
--- Execute a shell command with error handling and user feedback
---
--- Parameters:
---  * command - The shell command to execute
---  * actionName - The name of the action (for user feedback)
---  * copyToClipboard - Optional boolean flag to copy the output to clipboard (default: false)
function obj.executeShell(command, actionName, copyToClipboard)
  local task = hs.task.new('/bin/sh', function(exitCode, stdOut, stdErr)
    if exitCode == 0 then
      local output = stdOut and stdOut:gsub('%s+$', '') or ''
      if output ~= '' then
        if copyToClipboard then
          hs.pasteboard.setContents(output)
          hs.alert.show('📋 Copied ' .. output, _G.MARTILLO_ALERT_DURATION)
        else
          hs.alert.show('✅ ' .. output, _G.MARTILLO_ALERT_DURATION)
        end
      else
        hs.alert.show('✅ ' .. actionName .. ' completed', _G.MARTILLO_ALERT_DURATION)
      end
    else
      hs.alert.show(actionName .. ' failed: ' .. (stdErr or 'Unknown error'), _G.MARTILLO_ALERT_DURATION)
    end
  end, { '-c', command })
  task:start()
end

--- ActionsLauncher.executeAppleScript(script, actionName, copyToClipboard)
--- Function
--- Execute an AppleScript with error handling and user feedback
---
--- Parameters:
---  * script - The AppleScript to execute
---  * actionName - The name of the action (for user feedback)
---  * copyToClipboard - Optional boolean flag to copy the result to clipboard (default: false)
function obj.executeAppleScript(script, actionName, copyToClipboard)
  local success, result = hs.applescript.applescript(script)
  if success then
    if result ~= '' then
      if copyToClipboard then
        hs.pasteboard.setContents(result)
        hs.alert.show('📋 Copied ' .. result, _G.MARTILLO_ALERT_DURATION)
      else
        hs.alert.show('✅ ' .. result, _G.MARTILLO_ALERT_DURATION)
      end
    else
      hs.alert.show('✅ ' .. actionName .. ' completed', _G.MARTILLO_ALERT_DURATION)
    end
  else
    hs.alert.show(actionName .. ' failed: ' .. (result or 'Unknown error'), _G.MARTILLO_ALERT_DURATION)
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
