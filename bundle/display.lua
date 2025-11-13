return {
  {
    id = 'confetti',
    name = 'Confetti',
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
}
