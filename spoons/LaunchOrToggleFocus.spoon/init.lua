--- === LaunchOrToggleFocus ===
---
--- Launch applications or toggle focus if already running

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "LaunchOrToggleFocus"
obj.version = "1.0"
obj.author = "sjdonado"
obj.homepage = "https://github.com/sjdonado/martillo/spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.hotkeys = {}
obj.applications = {}
obj.logger = hs.logger.new('LaunchOrToggleFocus', 'info')

--- LaunchOrToggleFocus:init()
--- Method
--- Initialize the spoon
function obj:init()
    return self
end

--- LaunchOrToggleFocus:launchOrToggle(appName)
--- Method
--- Launch application or toggle focus if already running
---
--- Parameters:
---  * appName - The name of the application to launch or toggle
function obj:launchOrToggle(appName)
    local app = hs.application.get(appName)
    if app and app:isFrontmost() then
        -- If app is running and focused, unfocus it (hide)
        app:hide()
    else
        -- Launch or focus the app
        hs.application.launchOrFocus(appName)
    end
end

--- LaunchOrToggleFocus:setup(keys)
--- Method
--- Bind hotkeys with explicit app names
---
--- Parameters:
---  * keys - An array of hotkey configurations where each entry contains
---    modifiers, key, and app name
---
--- Example:
---   spoon.LaunchOrToggleFocus:setup({
---     { { "alt", "shift" }, "s", app = "Safari" },
---     { { "alt", "shift" }, "space", app = "Zed" },
---     { { "alt", "shift" }, "g", app = "ChatGPT" }
---   })
function obj:setup(keys)
    for _, config in ipairs(keys) do
        local mods = config[1]
        local key = config[2]
        if mods and key and config.app then
            hs.hotkey.bind(mods, key, function()
                self:launchOrToggle(config.app)
            end)
        end
    end
    return self
end

--- LaunchOrToggleFocus:bindHotkeys(mapping)
--- Method
--- Bind hotkeys for LaunchOrToggleFocus using standard spoon format
---
--- Parameters:
---  * mapping - A table containing hotkey mappings where keys are app names
---    and values are hotkey definitions
---
--- Example:
---   spoon.LaunchOrToggleFocus:bindHotkeys({
---     safari = { { "alt", "shift" }, "s" },
---     terminal = { { "alt", "shift" }, "t" }
---   })
function obj:bindHotkeys(mapping)
    local def = {}
    for appKey, hotkey in pairs(mapping) do
        def[appKey] = function()
            -- Convert appKey to proper app name (capitalize first letter)
            local appName = appKey:gsub("^%l", string.upper)
            self:launchOrToggle(appName)
        end
    end
    hs.spoons.bindHotkeysToSpec(def, mapping)
    return self
end

return obj
