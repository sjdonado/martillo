-- Keyboard Actions Bundle
-- Actions for keyboard management and automation

local toast = require 'lib.toast'
local icons = require 'lib.icons'

local M = {
  keyboardLockTap = nil,
  keyboardLocked = false,
  lockChooserChooser = nil,
  keepAliveTimer = nil,
  keepAliveActive = false,
  logger = hs.logger.new('KeyboardBundle', 'debug'),
}

-- Get the leader key combination as a string
local function getLeaderKeysString()
  local leaderKey = _G.MARTILLO_LEADER_KEY or { 'alt', 'ctrl' }
  local parts = {}
  for _, key in ipairs(leaderKey) do
    if key == 'alt' or key == 'option' then
      table.insert(parts, '⌥')
    elseif key == 'ctrl' or key == 'control' then
      table.insert(parts, '⌃')
    elseif key == 'cmd' or key == 'command' then
      table.insert(parts, '⌘')
    elseif key == 'shift' then
      table.insert(parts, '⇧')
    end
  end
  return table.concat(parts, '') .. '↩'
end

-- Check if current modifiers match leader key + return
local function isLeaderReturn(flags)
  local leaderKey = _G.MARTILLO_LEADER_KEY or { 'alt', 'ctrl' }

  -- Convert leader keys to flags
  local requiredFlags = {}
  for _, key in ipairs(leaderKey) do
    if key == 'alt' or key == 'option' then
      requiredFlags.alt = true
    elseif key == 'ctrl' or key == 'control' then
      requiredFlags.ctrl = true
    elseif key == 'cmd' or key == 'command' then
      requiredFlags.cmd = true
    elseif key == 'shift' then
      requiredFlags.shift = true
    end
  end

  -- Check if all required flags are present
  for flag, _ in pairs(requiredFlags) do
    if not flags[flag] then
      return false
    end
  end

  -- Check if no extra flags are present (allow fn flag)
  for flag, value in pairs(flags) do
    if value and flag ~= 'fn' and not requiredFlags[flag] then
      return false
    end
  end

  return true
end

-- Unlock the keyboard
local function unlockKeyboard(showToast)
  M.logger:d 'Unlocking keyboard'

  -- Stop the event tap
  if M.keyboardLockTap then
    M.keyboardLockTap:stop()
    M.keyboardLockTap = nil
  end

  M.keyboardLocked = false

  -- Close the chooser if it's open
  if M.lockChooserChooser then
    M.lockChooserChooser:hide()
    M.lockChooserChooser = nil
  end

  -- Clear chooser manager state
  if spoon.ActionsLauncher and spoon.ActionsLauncher.chooserManager then
    spoon.ActionsLauncher.chooserManager:clear()
  end

  if showToast then
    toast.success 'Keyboard unlocked'
  end
end

-- Lock the keyboard
local function lockKeyboard()
  if M.keyboardLocked then
    return
  end

  M.logger:d 'Locking keyboard'
  M.keyboardLocked = true
  -- Store showToast in module for access in event tap
  -- (it will be set before lockKeyboard is called)

  -- Create event tap to intercept all keyboard events
  M.keyboardLockTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
    local keyCode = event:getKeyCode()
    local flags = event:getFlags()

    -- Check for leader+return to unlock
    if keyCode == 36 and isLeaderReturn(flags) then -- 36 is Return/Enter key
      M.logger:d 'Leader+Return detected, unlocking keyboard'
      unlockKeyboard(M.showToast)
      return true -- Consume the event
    end

    -- Block all other keyboard events
    M.logger:d('Blocking keyboard event: keyCode=' .. tostring(keyCode))
    return true -- Consume the event
  end)

  M.keyboardLockTap:start()
end

return {
  {
    id = 'keyboard_lock',
    name = 'Lock Keyboard',
    icon = icons.preset.lock,
    description = 'Lock keyboard for cleaning (unlock with <leader>+Enter)',
    opts = {
      success_toast = true, -- Show success toast notification when unlocking keyboard
    },
    handler = function()
      -- Get action configuration (user can override opts in their config)
      local events = require 'lib.events'
      local showToast = events.getActionOpt('keyboard_lock', 'success_toast', true)

      spoon.ActionsLauncher:openChildChooser {
        placeholder = '🔒 Keyboard Locked - Clean away!',
        parentAction = 'keyboard_lock',
        handler = function(query, launcher)
          -- Store reference to the chooser
          M.lockChooserChooser = launcher.chooser

          -- Store showToast for use in event tap
          M.showToast = showToast

          -- Start keyboard lock after chooser is ready
          if not M.keyboardLocked then
            hs.timer.doAfter(0.1, function()
              lockKeyboard()
            end)
          end

          local results = {}
          local unlockUuid = launcher:generateUUID()

          table.insert(results, {
            text = 'Press ' .. getLeaderKeysString() .. ' to unlock',
            subText = 'Keyboard is locked - all keys except unlock combination are blocked',
            uuid = unlockUuid,
          })

          return results
        end,
      }
    end,
  },
  {
    id = 'keyboard_keep_alive',
    name = 'Toggle Keep-Alive',
    icon = icons.preset.magic_trick,
    description = 'Toggle keyboard activity to keep screen active and apps thinking you are active',
    opts = {
      success_toast = true, -- Show success toast notification when stopping keep-alive
    },
    handler = function()
      -- Get action configuration (user can override opts in their config)
      local events = require 'lib.events'
      local showToast = events.getActionOpt('keyboard_keep_alive', 'success_toast', true)

      if M.keepAliveActive then
        if not M.keepAliveActive then
          M.logger:d 'Keep-alive not active'
          return
        end

        M.logger:d 'Stopping keep-alive'

        if M.keepAliveTimer then
          M.keepAliveTimer:stop()
          M.keepAliveTimer = nil
        end

        M.keepAliveActive = false
        if showToast then
          toast.success 'Keep-alive stopped'
        end
      else
        if M.keepAliveActive then
          M.logger:d 'Keep-alive already active'
          return
        end

        M.logger:d 'Starting keep-alive'
        M.keepAliveActive = true

        -- Press F15 every 2 minutes (120 seconds)
        -- F15 is a safe key that won't interfere with normal operations
        M.keepAliveTimer = hs.timer.doEvery(120, function()
          M.logger:d 'Pressing F15 to keep system active'
          hs.eventtap.keyStroke({}, 'F15', 0)
        end)

        toast.info('Keep-alive started (F15 every 2 min)', 4)
      end
    end,
  },
}
