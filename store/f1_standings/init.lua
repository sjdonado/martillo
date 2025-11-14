-- F1 Drivers Championship Standings
-- Displays current F1 season driver standings from F1 Connect API

local toast = require 'lib.toast'
local actions = require 'lib.actions'
local icons = require 'lib.icons'

return {
  {
    id = 'f1_standings',
    name = 'F1 Drivers Standings',
    icon = icons.preset.trophy,
    description = 'View current F1 drivers championship standings',
    handler = function()
      local actionsLauncher = spoon.ActionsLauncher

      local standings = {}
      local loading = true

      actionsLauncher:openChildPicker {
        placeholder = 'F1 Drivers Championship 2024',
        parentAction = 'f1_standings',
        handler = function(query, launcher)
          local choices = {}

          if loading then
            table.insert(choices, {
              text = 'Loading...',
              subText = 'Fetching from https://f1connectapi.vercel.app',
              uuid = launcher:generateUUID(),
            })
          else
            for _, entry in ipairs(standings) do
              local uuid = launcher:generateUUID()

              -- Format: "P1. Max Verstappen (VER) - 437 pts"
              local text = string.format(
                'P%d. %s %s (%s) - %d pts',
                entry.position,
                entry.driver.name,
                entry.driver.surname,
                entry.driver.shortName,
                entry.points
              )

              -- Format: "Red Bull Racing • 9 wins • Netherlands"
              local subText = string.format(
                '%s • %d %s • %s',
                entry.team.teamName,
                entry.wins,
                entry.wins == 1 and 'win' or 'wins',
                entry.driver.nationality
              )

              table.insert(choices, {
                text = text,
                subText = subText,
                uuid = uuid,
              })

              launcher.handlers[uuid] = actions.copyToClipboard(function(choice)
                return string.format(
                  '%s %s - P%d - %d points - %s',
                  entry.driver.name,
                  entry.driver.surname,
                  entry.position,
                  entry.points,
                  entry.team.teamName
                )
              end)
            end
          end

          return choices
        end,
      }

      -- Fetch standings from API
      hs.http.asyncGet('https://f1connectapi.vercel.app/api/current/drivers-championship', nil, function(
        status,
        body,
        headers
      )
        loading = false

        if status == 200 then
          local success, data = pcall(function()
            return hs.json.decode(body)
          end)

          if success and data and data.drivers_championship then
            standings = data.drivers_championship
            actionsLauncher:refresh()
          else
            toast.error 'Failed to parse F1 standings'
          end
        else
          toast.error('Failed to fetch F1 standings: HTTP ' .. status)
        end
      end)

      return 'OPEN_CHILD_PICKER'
    end,
  },
}
