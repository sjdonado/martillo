-- Test script to validate ESC interception approach for chooser navigation
-- This validates the solution proposed in AGENTS.md for distinguishing:
--   - ESC (navigate to parent)
--   - Shift+ESC (close all choosers)
--   - Click outside (close all choosers)
--
-- HOW TO RUN:
--   1. Open Hammerspoon console
--   2. Run: dofile("/Users/juan/projects/martillo/test_esc_intercept.lua")
--   3. Test the behaviors described below
--   4. Cleanup: escTap:stop(); chooser:hide()
--
-- EXPECTED BEHAVIOR:
--   - Press ESC: Event is consumed, chooser stays open, message "ESC detected - would navigate to parent"
--   - Press Shift+ESC: Event propagates, chooser closes, hideCallback fires
--   - Click outside: Chooser closes, hideCallback fires (no ESC event)
--   - Press Enter on item: Normal selection, chooser closes
--
-- This proves we can:
--   1. Intercept ESC before chooser sees it
--   2. Distinguish ESC vs Shift+ESC reliably based on modifiers
--   3. Let click-outside work through normal hideCallback
--   4. Avoid race conditions with synchronous event handling

local chooser = nil
local escTap = nil

print("========================================")
print("ESC Interception Test")
print("========================================")

-- Create chooser
chooser = hs.chooser.new(function(choice)
  if not choice then
    print("⚠️  Chooser callback: choice = nil (ESC or cancel)")
    print("    This should ONLY happen with Shift+ESC, not plain ESC")
    return
  end
  print("✅ Chooser callback: selected " .. choice.text)
  chooser:hide()
end)

chooser:choices({
  { text = "Option 1" },
  { text = "Option 2" },
  { text = "Option 3" },
})

chooser:hideCallback(function()
  print("🔽 hideCallback: chooser is hiding")
  print("    This should fire for: Shift+ESC, click-outside, Enter selection")
  print("    This should NOT fire for: plain ESC (event consumed)")
end)

-- Create ESC key interceptor
escTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
  local keyCode = event:getKeyCode()
  local flags = event:getFlags()

  -- ESC key is keycode 53
  if keyCode == 53 then
    print("")
    print("🔑 ESC intercepted! Shift: " .. tostring(flags.shift or false))

    if flags.shift then
      print("   → Shift+ESC: Letting event through to CLOSE ALL")
      -- Let it propagate to close the chooser
      return false
    else
      print("   → ESC alone: CONSUMING event, would navigate to parent")
      -- Block the event to prevent chooser from closing
      return true -- Delete the event (chooser stays open)
    end
  end

  return false -- Let other keys through
end)

-- Start the interceptor
escTap:start()

-- Show chooser
chooser:show()

print("")
print("Test running... Try these actions:")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("1. Press ESC:")
print("   Expected: Event consumed, chooser stays open")
print("")
print("2. Press Shift+ESC:")
print("   Expected: Chooser closes, hideCallback fires")
print("")
print("3. Click outside chooser:")
print("   Expected: Chooser closes, hideCallback fires")
print("")
print("4. Select an item (Enter):")
print("   Expected: Normal selection, chooser closes")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("")
print("To cleanup: escTap:stop(); chooser:hide()")
print("========================================")
print("")
