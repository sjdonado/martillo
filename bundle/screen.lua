-- Screen Actions Bundle
-- Visual effects and helper tools

local toast = require 'lib.toast'
local icons = require 'lib.icons'
local events = require 'lib.events'

return {
  {
    id = 'screen_confetti',
    name = 'Confetti',
    icon = icons.preset.star,
    description = 'Celebrate with confetti animation',
    handler = function()
      local canvas = nil
      local animationTimer = nil
      local clickWatcher = nil
      local particles = {}

      local colors = {
        { red = 1.0, green = 0.2, blue = 0.2 }, -- Red
        { red = 1.0, green = 0.8, blue = 0.0 }, -- Yellow
        { red = 0.2, green = 0.8, blue = 1.0 }, -- Blue
        { red = 1.0, green = 0.4, blue = 0.8 }, -- Pink
        { red = 0.4, green = 1.0, blue = 0.4 }, -- Green
        { red = 0.8, green = 0.4, blue = 1.0 }, -- Purple
      }

      local function createParticle(screen)
        local screenFrame = screen:fullFrame()
        return {
          x = math.random(0, screenFrame.w),
          y = -20,
          size = math.random(6, 18),
          color = colors[math.random(#colors)],
          velocityY = math.random(2, 5),
          velocityX = math.random(-2, 2),
          rotation = math.random(0, 360),
          rotationSpeed = math.random(-10, 10),
          shape = math.random(1, 2), -- 1 = rectangle, 2 = circle
        }
      end

      -- Initialize particles
      local screen = hs.screen.mainScreen()
      for i = 1, 80 do
        table.insert(particles, createParticle(screen))
        -- Stagger initial positions
        particles[i].y = math.random(-500, -20)
      end

      -- Update and draw particles
      local function animate()
        local screenFrame = screen:fullFrame()
        canvas:replaceElements()

        local activeParticles = 0
        for i, particle in ipairs(particles) do
          -- Update position
          particle.y = particle.y + particle.velocityY
          particle.x = particle.x + particle.velocityX
          particle.rotation = particle.rotation + particle.rotationSpeed

          -- Apply gravity
          particle.velocityY = particle.velocityY + 0.2

          -- Only draw if still on screen
          if particle.y < screenFrame.h + 50 then
            activeParticles = activeParticles + 1

            if particle.shape == 1 then
              -- Rectangle confetti
              canvas:insertElement {
                type = 'rectangle',
                action = 'fill',
                fillColor = particle.color,
                frame = {
                  x = particle.x,
                  y = particle.y,
                  w = particle.size,
                  h = particle.size / 2,
                },
                transformation = hs.canvas.matrix.translate(particle.x, particle.y):rotate(particle.rotation):translate(-particle.x, -particle.y),
              }
            else
              -- Circle confetti
              canvas:insertElement {
                type = 'circle',
                action = 'fill',
                fillColor = particle.color,
                center = { x = particle.x, y = particle.y },
                radius = particle.size / 2,
              }
            end
          end
        end

        -- If all particles have fallen off screen, cleanup
        if activeParticles == 0 then
          if animationTimer then
            animationTimer:stop()
            animationTimer = nil
          end
          if canvas then
            canvas:delete()
            canvas = nil
          end
          if clickWatcher then
            clickWatcher:stop()
            clickWatcher = nil
          end
        end
      end

      -- Create canvas
      local screenFrame = screen:fullFrame()
      canvas = hs.canvas.new(screenFrame)
      canvas:level 'overlay'
      canvas:behavior 'canJoinAllSpaces'
      canvas:alpha(1.0)
      canvas:clickActivating(false)
      canvas:show()

      -- Start animation (60 FPS)
      animationTimer = hs.timer.doEvery(1 / 60, animate)

      -- Click anywhere to dismiss
      clickWatcher = hs.eventtap.new({ hs.eventtap.event.types.leftMouseDown }, function(event)
        if animationTimer then
          animationTimer:stop()
          animationTimer = nil
        end
        if canvas then
          canvas:delete()
          canvas = nil
        end
        if clickWatcher then
          clickWatcher:stop()
          clickWatcher = nil
        end
        return false -- Don't consume the event
      end)

      clickWatcher:start()
    end,
  },
  {
    id = 'screen_ruler',
    name = 'Screen Ruler',
    icon = icons.preset.eyedropper,
    description = 'Measure distance in pixels between two points',
    handler = function()
      -- State variables
      local startPoint = nil
      local canvas = nil
      local updateTimer = nil
      local clickWatcher = nil

      -- Check if a line is exactly straight (horizontal or vertical)
      -- Horizontal: same Y coordinate, Vertical: same X coordinate
      local function isStraightLine(p1, p2)
        return math.floor(p1.x) == math.floor(p2.x) or math.floor(p1.y) == math.floor(p2.y)
      end

      -- Update canvas with crosshair, tooltip, and line
      local function updateLine()
        local currentPos = hs.mouse.absolutePosition()
        local screen = hs.screen.mainScreen()
        local screenFrame = screen:fullFrame()

        -- Clear canvas
        canvas:replaceElements()

        -- Add subtle background overlay to prevent click-through to apps behind
        -- Light purple overlay (12% opacity) - improves tooltip contrast on dark backgrounds
        canvas:insertElement {
          type = 'rectangle',
          action = 'fill',
          fillColor = { red = 0.6, green = 0.4, blue = 1, alpha = 0.12 },
          frame = { x = 0, y = 0, w = screenFrame.w, h = screenFrame.h },
        }

        -- Draw crosshair cursor (horizontal and vertical lines)
        local crosshairSize = 8
        local crosshairColor = { white = 1.0, alpha = 0.8 }

        -- Horizontal line
        canvas:insertElement {
          type = 'segments',
          action = 'stroke',
          strokeColor = crosshairColor,
          strokeWidth = 1,
          coordinates = {
            { x = currentPos.x - crosshairSize, y = currentPos.y },
            { x = currentPos.x + crosshairSize, y = currentPos.y },
          },
        }

        -- Vertical line
        canvas:insertElement {
          type = 'segments',
          action = 'stroke',
          strokeColor = crosshairColor,
          strokeWidth = 1,
          coordinates = {
            { x = currentPos.x, y = currentPos.y - crosshairSize },
            { x = currentPos.x, y = currentPos.y + crosshairSize },
          },
        }

        -- Center dot
        canvas:insertElement {
          type = 'circle',
          action = 'fill',
          fillColor = { white = 1.0, alpha = 0.8 },
          center = { x = currentPos.x, y = currentPos.y },
          radius = 2,
        }

        -- Tooltip with coordinates and distance (if measuring)
        local tooltipText = string.format('%d x %d', math.floor(currentPos.x), math.floor(currentPos.y))
        if startPoint then
          local distancePixels = math.floor(hs.geometry.point(startPoint):distance(currentPos))
          tooltipText = tooltipText .. string.format(' (%d px)', distancePixels)
        end
        local tooltipOffset = 12

        -- Position tooltip to avoid edge overflow
        local tooltipX = currentPos.x + tooltipOffset
        local tooltipY = currentPos.y + tooltipOffset
        local tooltipWidth = startPoint and 150 or 80 -- Wider when showing distance

        -- Adjust if near screen edges
        if tooltipX + tooltipWidth > screenFrame.x + screenFrame.w then
          tooltipX = currentPos.x - tooltipWidth - tooltipOffset
        end
        if tooltipY + 30 > screenFrame.y + screenFrame.h then
          tooltipY = currentPos.y - 30 - tooltipOffset
        end

        -- Tooltip background
        canvas:insertElement {
          type = 'rectangle',
          action = 'fill',
          fillColor = { white = 0.0, alpha = 0.8 },
          frame = { x = tooltipX, y = tooltipY, w = tooltipWidth, h = 16 },
          roundedRectRadii = { xRadius = 4, yRadius = 4 },
        }

        -- Tooltip text
        canvas:insertElement {
          type = 'text',
          text = tooltipText,
          textColor = { white = 1.0, alpha = 1.0 },
          textSize = 12,
          textAlignment = 'center',
          frame = { x = tooltipX, y = tooltipY, w = tooltipWidth, h = 24 },
        }

        -- If measuring, draw the line
        if startPoint then
          local isStraight = isStraightLine(startPoint, currentPos)
          local lineColor = isStraight and { green = 1.0, alpha = 0.8 } or { red = 1.0, alpha = 0.8 }

          canvas:insertElement {
            type = 'segments',
            action = 'stroke',
            strokeColor = lineColor,
            strokeWidth = 2,
            coordinates = {
              { x = startPoint.x, y = startPoint.y },
              { x = currentPos.x, y = currentPos.y },
            },
          }
        end
      end

      -- Create canvas that covers entire screen
      local screen = hs.screen.mainScreen()
      local screenFrame = screen:fullFrame()
      canvas = hs.canvas.new(screenFrame)
      canvas:level 'overlay'
      canvas:behavior 'canJoinAllSpaces'
      canvas:alpha(1.0)
      canvas:clickActivating(false) -- Don't activate other apps when clicking

      -- Add mouse callback to consume all mouse events and prevent pass-through
      canvas:mouseCallback(function(canvas, event, id, x, y)
        -- Consume all mouse events to prevent them from reaching apps behind
        return true
      end)

      canvas:show()

      -- Start update timer (60 FPS)
      updateTimer = hs.timer.doEvery(1 / 60, updateLine)

      -- Set up mouse event watcher (down to start, up to finish)
      clickWatcher = hs.eventtap.new({ hs.eventtap.event.types.leftMouseDown, hs.eventtap.event.types.leftMouseUp },
        function(event)
          local eventType = event:getType()

          if eventType == hs.eventtap.event.types.leftMouseDown then
            -- Mouse down: Start measuring
            startPoint = hs.mouse.absolutePosition()
            return true -- Consume the event to prevent pass-through
          elseif eventType == hs.eventtap.event.types.leftMouseUp then
            -- Mouse up: Finish measurement
            if startPoint then
              local endPoint = hs.mouse.absolutePosition()

              -- Calculate distance in pixels
              local distancePixels = math.floor(hs.geometry.point(startPoint):distance(endPoint))

              -- Only measure if there was actual movement
              if distancePixels > 0 then
                -- Format result
                local result = string.format('%d px', distancePixels)

                -- Clean up
                if updateTimer then
                  updateTimer:stop()
                  updateTimer = nil
                end
                if canvas then
                  canvas:delete()
                  canvas = nil
                end
                if clickWatcher then
                  clickWatcher:stop()
                  clickWatcher = nil
                end

                hs.pasteboard.setContents(result)
                toast.copied(result)
              else
                -- No movement, just reset
                startPoint = nil
              end
            end
            return true -- Consume the event to prevent pass-through
          end
        end)

      clickWatcher:start()
    end,
  },
}
