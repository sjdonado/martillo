-- F1 Drivers Championship Standings
-- Displays current F1 season driver standings from F1 Connect API

local toast = require 'lib.toast'
local events = require 'lib.events'
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

      actionsLauncher:openChildChooser {
        placeholder = 'F1 Drivers Championship (↩ copy driver, ⇧↩ copy team)',
        parentAction = 'f1_standings',
        handler = function(query, launcher)
          if loading then
            return {
              {
                text = 'Loading...',
                subText = 'Fetching from https://f1connectapi.vercel.app',
                uuid = launcher:generateUUID(),
              },
            }
          end

          -- Transform standings into results format with text/subText
          local results = {}
          for _, entry in ipairs(standings) do
            table.insert(results, {
              text = string.format(
                'P%d. %s %s (%s) - %d pts',
                entry.position,
                entry.driver.name,
                entry.driver.surname,
                entry.driver.shortName,
                entry.points
              ),
              subText = string.format(
                '%s • %d %s • %s',
                entry.team.teamName,
                entry.wins,
                entry.wins == 1 and 'win' or 'wins',
                entry.driver.nationality
              ),
              -- Store original entry for handler
              entry = entry,
            })
          end

          return events.buildSearchableChoices(query, results, launcher, {
            handler = function(result)
              local entry = result.entry
              return events.copyToClipboard(function(choice)
                return string.format(
                  '%s %s - P%d - %d points - %s',
                  entry.driver.name,
                  entry.driver.surname,
                  entry.position,
                  entry.points,
                  entry.team.teamName
                )
              end)
            end,
            searchFields = function(result)
              local entry = result.entry
              return {
                { value = entry.driver.name or '', weight = 1.0, key = 'name' },
                { value = entry.driver.surname or '', weight = 1.0, key = 'surname' },
                { value = entry.driver.shortName or '', weight = 0.8, key = 'shortName' },
                { value = entry.team.teamName or '', weight = 0.7, key = 'team' },
                { value = entry.driver.nationality or '', weight = 0.5, key = 'nationality' },
              }
            end,
            maxResults = 50,
          })
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
    end,
  },
}
