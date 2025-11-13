-- Random Quote Action
-- Fetches a random inspirational quote from an API

local toast = require 'lib.toast'

return {
  {
    id = 'random_quote',
    name = 'Random Quote',
    icon = 'notebook',
    description = 'Get a random inspirational quote',
    handler = function()
      local actionsLauncher = spoon.ActionsLauncher

      local quote_text = 'Loading...'
      local author = 'Loading...'

      actionsLauncher:openChildPicker {
        placeholder = '',
        parentAction = 'random_quote',
        handler = function(query, launcher)
          local choices = {}

          table.insert(choices, {
            text = quote_text,
            subText = 'Quote',
            uuid = launcher:generateUUID(),
            copyToClipboard = true,
          })

          table.insert(choices, {
            text = author,
            subText = 'Author',
            uuid = launcher:generateUUID(),
            copyToClipboard = true,
          })

          return choices
        end,
      }

      hs.http.asyncGet('https://quotes.domiadi.com/api', nil, function(status, body, headers)
        if status == 200 then
          local success, quote_data = pcall(function()
            return hs.json.decode(body)
          end)

          if success and quote_data then
            quote_text = quote_data.quote or 'No quote available'
            author = quote_data.author or 'Unknown'

            actionsLauncher:refresh()
          else
            toast.error 'Failed to parse quote'
          end
        else
          toast.error 'Failed to fetch quote'
        end
      end)

      return 'OPEN_CHILD_PICKER'
    end,
  },
}
