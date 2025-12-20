-- Switch Window Preset
-- Window switcher with fuzzy search

local searchUtils = require 'lib.search'
local chooserManager = require 'lib.chooser'
local toast = require 'lib.toast'
local icons = require 'lib.icons'
local events = require 'lib.events'

local M = {
  logger = hs.logger.new('SwitchWindow', 'info'),
}

-- Get list of all visible windows
local function getWindowList()
  local windows = {}
  local visibleWindows = hs.window.visibleWindows()

  for _, win in ipairs(visibleWindows) do
    local app = win:application()
    local appName = app and app:name() or 'Unknown'
    local winTitle = win:title() or 'Untitled'
    local winId = win:id()

    -- Skip windows without titles and the Hammerspoon console
    if winTitle ~= '' and appName ~= 'Hammerspoon' then
      table.insert(windows, {
        window = win,
        appName = appName,
        title = winTitle,
        winId = winId,
        text = winTitle,
        subText = appName,
      })
    end
  end

  -- Sort by application name, then by window title
  table.sort(windows, function(a, b)
    if a.appName == b.appName then
      return a.title < b.title
    end
    return a.appName < b.appName
  end)

  M.logger:d('Found ' .. #windows .. ' visible windows')
  return windows
end

-- Get filtered choices based on query with priority-based search
local function getFilteredChoices(query, allWindows)
  -- No search query - return all windows
  if not query or query == '' then
    return allWindows
  end

  -- Search filtering
  local rankedWindows = searchUtils.rank(query, allWindows, {
    getFields = function(win)
      return {
        { value = win.title or '',   weight = 1.0, key = 'title' },
        { value = win.appName or '', weight = 0.8, key = 'appName' },
      }
    end,
    adjustScore = function(win, context)
      local score = context.score
      local matchType = context.match and context.match.matchType or nil

      -- Boost prefix matches
      if matchType == 'prefix' then
        score = score * 1.2
      elseif matchType == 'word_prefix' then
        score = score * 1.1
      end

      return score
    end,
    tieBreaker = function(winA, winB)
      -- Prefer by app name, then by title
      if winA.appName ~= winB.appName then
        return winA.appName < winB.appName
      end
      return winA.title < winB.title
    end,
    fuzzyMinQueryLength = 3,
    maxResults = 100,
  })

  return rankedWindows
end

-- Return action definition
return {
  {
    id = 'switch_window',
    name = 'Switch Window',
    icon = icons.preset.umbrella,
    description = 'Switch to a window with fuzzy search',
    opts = {
      success_toast = true, -- Show success toast notification when switching windows
    },
    handler = function()
      -- Get ActionsLauncher instance
      local actionsLauncher = spoon.ActionsLauncher

      -- Get action configuration (user can override opts in their config)
      local showToast = events.getActionOpt('switch_window', 'success_toast', true)

      -- Get all windows once (will be filtered on each query change)
      local allWindows = getWindowList()

      if #allWindows == 0 then
        toast.error('No windows found')
        return
      end

      -- Function to build choices from filtered windows
      local function buildChoices(query, launcher)
        if not launcher then
          return {}
        end

        -- Get filtered windows based on query
        local filteredWindows = getFilteredChoices(query, allWindows)

        -- Build choices with handlers
        local choices = {}
        for _, winData in ipairs(filteredWindows) do
          -- Generate UUID for this choice
          local uuid = launcher:generateUUID()

          -- Get app icon
          local app = winData.window:application()
          local appIcon = nil
          if app then
            appIcon = hs.image.imageFromAppBundle(app:bundleID())
          end

          -- Create choice entry
          local choiceEntry = {
            text = winData.text,
            subText = winData.subText,
            uuid = uuid,
            image = appIcon or icons.getIcon(icons.preset.computer),
          }

          -- Register handler for this choice
          launcher.handlers[uuid] = events.custom(function(choice)
            -- Focus the selected window
            local win = winData.window
            if win and win:isVisible() then
              win:focus()
              if showToast then
                toast.success('Switched to: ' .. winData.appName)
              end
            else
              toast.error('Window no longer available')
            end
          end)

          table.insert(choices, choiceEntry)
        end

        return choices
      end

      actionsLauncher:openChildChooser {
        placeholder = 'Switch Window (↩ focus)',
        parentAction = 'switch_window',
        handler = function(query, launcher)
          return buildChoices(query, launcher)
        end,
      }
    end,
  },
}
