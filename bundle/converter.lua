-- Converter Actions Bundle
-- Actions for encoding, decoding, and converting various formats

local icons = require 'lib.icons'
local events = require 'lib.events'

return {
  {
    id = 'converter_time',
    name = 'Time Converter',
    icon = icons.preset.clock,
    description = 'Convert between multiple time formats (timestamp, ISO, date, etc.)',
    handler = function()
      spoon.ActionsLauncher:openChildChooser {
        placeholder = 'Enter time (timestamp, ISO, date, etc.)...',
        parentAction = 'timestamp',
        handler = function(query, launcher)
          if not query or query == '' then
            return {}
          end

          local timestamp = nil

          -- Try to parse different input formats
          local numericValue = tonumber(query)
          if numericValue then
            -- Unix timestamp (seconds or milliseconds)
            if string.len(query) == 13 then
              timestamp = numericValue / 1000
            elseif string.len(query) == 10 then
              timestamp = numericValue
            end
          end

          -- Try ISO 8601 format: 2023-11-13T10:00:00Z or 2023-11-13T10:00:00+00:00
          if not timestamp then
            local year, month, day, hour, min, sec = query:match '^(%d%d%d%d)-(%d%d)-(%d%d)[T ](%d%d):(%d%d):(%d%d)'
            if year then
              timestamp = os.time {
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour),
                min = tonumber(min),
                sec = tonumber(sec),
              }
            end
          end

          -- Try date only format: 2023-11-13 or 2023/11/13
          if not timestamp then
            local year, month, day = query:match '^(%d%d%d%d)[/-](%d%d)[/-](%d%d)$'
            if year then
              timestamp = os.time {
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = 0,
                min = 0,
                sec = 0,
              }
            end
          end

          -- Try date and time format: 2023-11-13 10:00:00
          if not timestamp then
            local year, month, day, hour, min, sec = query:match '^(%d%d%d%d)[/-](%d%d)[/-](%d%d)%s+(%d%d):(%d%d):(%d%d)$'
            if year then
              timestamp = os.time {
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour),
                min = tonumber(min),
                sec = tonumber(sec),
              }
            end
          end

          -- Try relative formats
          if not timestamp then
            local lowerQuery = query:lower()
            if lowerQuery == 'now' then
              timestamp = os.time()
            elseif lowerQuery == 'today' then
              local now = os.date '*t'
              timestamp = os.time { year = now.year, month = now.month, day = now.day, hour = 0, min = 0, sec = 0 }
            elseif lowerQuery == 'yesterday' then
              local now = os.date '*t'
              timestamp = os.time {
                year = now.year,
                month = now.month,
                day = now.day - 1,
                hour = 0,
                min = 0,
                sec = 0,
              }
            elseif lowerQuery == 'tomorrow' then
              local now = os.date '*t'
              timestamp = os.time {
                year = now.year,
                month = now.month,
                day = now.day + 1,
                hour = 0,
                min = 0,
                sec = 0,
              }
            end
          end

          if not timestamp then
            return {
              {
                text = 'Invalid time format',
                subText = "Try: timestamp, ISO (2023-11-13T10:00:00Z), date (2023-11-13), or 'now'",
                uuid = launcher:generateUUID(),
              },
            }
          end

          -- Helper to format relative time
          local function formatRelativeTime(seconds)
            local absSeconds = math.abs(seconds)
            local suffix = seconds > 0 and ' ago' or ' from now'

            if absSeconds < 60 then
              return string.format('%.0f seconds%s', absSeconds, suffix)
            elseif absSeconds < 3600 then
              return string.format('%.1f minutes%s', absSeconds / 60, suffix)
            elseif absSeconds < 86400 then
              return string.format('%.1f hours%s', absSeconds / 3600, suffix)
            elseif absSeconds < 2592000 then
              return string.format('%.1f days%s', absSeconds / 86400, suffix)
            elseif absSeconds < 31536000 then
              return string.format('%.1f months%s', absSeconds / 2592000, suffix)
            else
              return string.format('%.1f years%s', absSeconds / 31536000, suffix)
            end
          end

          local results = {}
          local relativeTime = os.time() - timestamp

          -- Unix timestamp (seconds)
          local unixSecondsUuid = launcher:generateUUID()
          local unixSecondsValue = string.format('%.0f', timestamp)
          launcher.handlers[unixSecondsUuid] = events.copyToClipboard(function(choice)
            return unixSecondsValue
          end)
          table.insert(results, {
            text = unixSecondsValue,
            subText = 'Unix timestamp (seconds)',
            uuid = unixSecondsUuid,
          })

          -- Unix timestamp (milliseconds)
          local unixMillisUuid = launcher:generateUUID()
          local unixMillisValue = string.format('%.0f', timestamp * 1000)
          launcher.handlers[unixMillisUuid] = events.copyToClipboard(function(choice)
            return unixMillisValue
          end)
          table.insert(results, {
            text = unixMillisValue,
            subText = 'Unix timestamp (milliseconds)',
            uuid = unixMillisUuid,
          })

          -- ISO 8601 format
          local isoUuid = launcher:generateUUID()
          local isoValue = os.date('!%Y-%m-%dT%H:%M:%SZ', timestamp)
          launcher.handlers[isoUuid] = events.copyToClipboard(function(choice)
            return isoValue
          end)
          table.insert(results, {
            text = isoValue,
            subText = 'ISO 8601 (UTC)',
            uuid = isoUuid,
          })

          -- RFC 2822-like format
          local rfcUuid = launcher:generateUUID()
          local rfcValue = os.date('!%a, %d %b %Y %H:%M:%S +0000', timestamp)
          launcher.handlers[rfcUuid] = events.copyToClipboard(function(choice)
            return rfcValue
          end)
          table.insert(results, {
            text = rfcValue,
            subText = 'RFC 2822 format',
            uuid = rfcUuid,
          })

          -- Human-readable date (UTC)
          local humanUtcUuid = launcher:generateUUID()
          local humanUtcValue = os.date('!%B %d, %Y %H:%M:%S', timestamp)
          launcher.handlers[humanUtcUuid] = events.copyToClipboard(function(choice)
            return humanUtcValue
          end)
          table.insert(results, {
            text = humanUtcValue,
            subText = 'Human-readable (UTC)',
            uuid = humanUtcUuid,
          })

          -- Human-readable date (Local)
          local humanLocalUuid = launcher:generateUUID()
          local humanLocalValue = os.date('%B %d, %Y %H:%M:%S', timestamp)
          launcher.handlers[humanLocalUuid] = events.copyToClipboard(function(choice)
            return humanLocalValue
          end)
          table.insert(results, {
            text = humanLocalValue,
            subText = 'Human-readable (Local)',
            uuid = humanLocalUuid,
          })

          -- Date only
          local dateOnlyUuid = launcher:generateUUID()
          local dateOnlyValue = os.date('%Y-%m-%d', timestamp)
          launcher.handlers[dateOnlyUuid] = events.copyToClipboard(function(choice)
            return dateOnlyValue
          end)
          table.insert(results, {
            text = dateOnlyValue,
            subText = 'Date only (YYYY-MM-DD)',
            uuid = dateOnlyUuid,
          })

          -- Relative time
          local relativeUuid = launcher:generateUUID()
          local relativeValue = formatRelativeTime(relativeTime)
          launcher.handlers[relativeUuid] = events.copyToClipboard(function(choice)
            return relativeValue
          end)
          table.insert(results, {
            text = relativeValue,
            subText = 'Relative to now',
            uuid = relativeUuid,
          })

          return results
        end,
      }
    end,
  },
  {
    id = 'converter_base64',
    name = 'Base64 Encoder/Decoder',
    icon = icons.preset.calculator,
    description = 'Encode or decode base64',
    handler = function()
      spoon.ActionsLauncher:openChildChooser {
        placeholder = 'Enter text to encode/decode...',
        parentAction = 'base64',
        handler = function(query, launcher)
          if not query or query == '' then
            return {}
          end

          local results = {}

          -- Try to encode
          local encoded = hs.base64.encode(query)
          local encodeUuid = launcher:generateUUID()
          launcher.handlers[encodeUuid] = events.copyToClipboard(function(choice)
            return encoded
          end)

          table.insert(results, {
            text = encoded,
            subText = 'Base64 Encoded',
            uuid = encodeUuid,
          })

          -- Try to decode
          local success, decoded = pcall(function()
            return hs.base64.decode(query)
          end)

          if success and decoded then
            local decodeUuid = launcher:generateUUID()
            launcher.handlers[decodeUuid] = events.copyToClipboard(function(choice)
              return decoded
            end)

            table.insert(results, {
              text = decoded,
              subText = 'Base64 Decoded',
              uuid = decodeUuid,
            })
          end

          return results
        end,
      }
    end,
  },
  {
    id = 'converter_jwt',
    name = 'JWT Decoder',
    icon = icons.preset.calculator,
    description = 'Decode JWT token',
    handler = function()
      spoon.ActionsLauncher:openChildChooser {
        placeholder = 'Paste JWT token...',
        parentAction = 'jwt',
        handler = function(query, launcher)
          if not query or query == '' then
            return {}
          end

          local parts = {}
          for part in query:gmatch '[^.]+' do
            table.insert(parts, part)
          end

          if #parts ~= 3 then
            return {
              {
                text = 'Invalid JWT',
                subText = 'JWT must have 3 parts separated by dots',
                uuid = launcher:generateUUID(),
              },
            }
          end

          -- Helper function to decode JWT part
          local function decodeJWTPart(part)
            local paddedPart = part:gsub('-', '+'):gsub('_', '/')
            local padding = 4 - (string.len(paddedPart) % 4)
            if padding < 4 then
              paddedPart = paddedPart .. string.rep('=', padding)
            end
            return hs.base64.decode(paddedPart)
          end

          local results = {}

          -- Decode header
          local headerSuccess, header = pcall(decodeJWTPart, parts[1])
          if headerSuccess and header then
            local headerUuid = launcher:generateUUID()
            launcher.handlers[headerUuid] = events.copyToClipboard(function(choice)
              return header
            end)

            table.insert(results, {
              text = header,
              subText = 'JWT Header',
              uuid = headerUuid,
            })
          end

          -- Decode payload
          local payloadSuccess, payload = pcall(decodeJWTPart, parts[2])
          if payloadSuccess and payload then
            local payloadUuid = launcher:generateUUID()
            launcher.handlers[payloadUuid] = events.copyToClipboard(function(choice)
              return payload
            end)

            table.insert(results, {
              text = payload,
              subText = 'JWT Payload',
              uuid = payloadUuid,
            })
          end

          if #results == 0 then
            return {
              {
                text = 'Failed to decode JWT',
                subText = 'Invalid base64 encoding',
                uuid = launcher:generateUUID(),
              },
            }
          end

          return results
        end,
      }
    end,
  },
  {
    id = 'converter_colors',
    name = 'Color Converter',
    icon = icons.preset.color_palette,
    description = 'Convert between color formats (hex, rgb)',
    handler = function()
      spoon.ActionsLauncher:openChildChooser {
        placeholder = 'Enter color (hex or rgb)...',
        parentAction = 'colors',
        handler = function(query, launcher)
          if not query or query == '' then
            return {}
          end

          local results = {}

          -- Try to parse as hex color (#RRGGBB or RRGGBB)
          local hex = query:match '^#?([%x][%x][%x][%x][%x][%x])$'
          if hex then
            local r = tonumber(hex:sub(1, 2), 16)
            local g = tonumber(hex:sub(3, 4), 16)
            local b = tonumber(hex:sub(5, 6), 16)

            -- RGB result
            local rgbUuid = launcher:generateUUID()
            launcher.handlers[rgbUuid] = events.copyToClipboard(function(choice)
              return string.format('rgb(%d, %d, %d)', r, g, b)
            end)

            table.insert(results, {
              text = string.format('rgb(%d, %d, %d)', r, g, b),
              subText = 'RGB format',
              uuid = rgbUuid,
              image = launcher:createColorSwatch(r, g, b),
            })
          end

          -- Try to parse as RGB (rgb(r, g, b))
          local r, g, b = query:match 'rgb%s*%((%d+)%s*,%s*(%d+)%s*,%s*(%d+)%)'
          if r and g and b then
            r, g, b = tonumber(r), tonumber(g), tonumber(b)

            -- Hex result
            local hexUuid = launcher:generateUUID()
            launcher.handlers[hexUuid] = events.copyToClipboard(function(choice)
              return string.format('#%02X%02X%02X', r, g, b)
            end)

            table.insert(results, {
              text = string.format('#%02X%02X%02X', r, g, b),
              subText = 'Hex format',
              uuid = hexUuid,
              image = launcher:createColorSwatch(r, g, b),
            })
          end

          if #results == 0 then
            return {
              {
                text = 'Invalid color format',
                subText = 'Try: #FF5733 or rgb(255, 87, 51)',
                uuid = launcher:generateUUID(),
              },
            }
          end

          return results
        end,
      }
    end,
  },
}
