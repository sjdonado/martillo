-- Encoders/Decoders Actions Bundle
-- Actions for encoding, decoding, and converting various formats

return {
	-- Dynamic Actions (open child pickers)
	{
		id = "timestamp",
		name = "Timestamp Converter",
		description = "Convert unix timestamp to date",
		handler = function()
			spoon.ActionsLauncher:openChildPicker({
				placeholder = "Enter unix timestamp...",
				parentAction = "timestamp",
				handler = function(query, launcher)
					if not query or query == "" then
						return {}
					end

					local timestamp = tonumber(query)
					if not timestamp then
						return {
							{
								text = "Invalid timestamp",
								subText = "Enter a valid unix timestamp (10 or 13 digits)",
								uuid = launcher:generateUUID(),
							},
						}
					end

					-- Convert to seconds if it's milliseconds
					if string.len(query) == 13 then
						timestamp = timestamp / 1000
					end

					local date = os.date("%Y-%m-%d %H:%M:%S", timestamp)
					local relativeTime = os.time() - timestamp
					local uuid = launcher:generateUUID()

					launcher.handlers[uuid] = function()
						return date
					end

					return {
						{
							text = date,
							subText = string.format("%.0f seconds ago", relativeTime),
							uuid = uuid,
							copyToClipboard = true,
						},
					}
				end,
			})
			return "OPEN_CHILD_PICKER"
		end,
	},

	{
		id = "base64",
		name = "Base64 Encoder/Decoder",
		description = "Encode or decode base64",
		handler = function()
			spoon.ActionsLauncher:openChildPicker({
				placeholder = "Enter text to encode/decode...",
				parentAction = "base64",
				handler = function(query, launcher)
					if not query or query == "" then
						return {}
					end

					local results = {}

					-- Try to encode
					local encoded = hs.base64.encode(query)
					local encodeUuid = launcher:generateUUID()
					launcher.handlers[encodeUuid] = function()
						return encoded
					end

					table.insert(results, {
						text = encoded,
						subText = "Base64 Encoded",
						uuid = encodeUuid,
						copyToClipboard = true,
					})

					-- Try to decode
					local success, decoded = pcall(function()
						return hs.base64.decode(query)
					end)

					if success and decoded then
						local decodeUuid = launcher:generateUUID()
						launcher.handlers[decodeUuid] = function()
							return decoded
						end

						table.insert(results, {
							text = decoded,
							subText = "Base64 Decoded",
							uuid = decodeUuid,
							copyToClipboard = true,
						})
					end

					return results
				end,
			})
			return "OPEN_CHILD_PICKER"
		end,
	},

	{
		id = "jwt",
		name = "JWT Decoder",
		description = "Decode JWT token",
		handler = function()
			spoon.ActionsLauncher:openChildPicker({
				placeholder = "Paste JWT token...",
				parentAction = "jwt",
				handler = function(query, launcher)
					if not query or query == "" then
						return {}
					end

					local parts = {}
					for part in query:gmatch("[^.]+") do
						table.insert(parts, part)
					end

					if #parts ~= 3 then
						return {
							{
								text = "Invalid JWT",
								subText = "JWT must have 3 parts separated by dots",
								uuid = launcher:generateUUID(),
							},
						}
					end

					-- Helper function to decode JWT part
					local function decodeJWTPart(part)
						local paddedPart = part:gsub("-", "+"):gsub("_", "/")
						local padding = 4 - (string.len(paddedPart) % 4)
						if padding < 4 then
							paddedPart = paddedPart .. string.rep("=", padding)
						end
						return hs.base64.decode(paddedPart)
					end

					local results = {}

					-- Decode header
					local headerSuccess, header = pcall(decodeJWTPart, parts[1])
					if headerSuccess and header then
						local headerUuid = launcher:generateUUID()
						launcher.handlers[headerUuid] = function()
							return header
						end

						table.insert(results, {
							text = header,
							subText = "JWT Header",
							uuid = headerUuid,
							copyToClipboard = true,
						})
					end

					-- Decode payload
					local payloadSuccess, payload = pcall(decodeJWTPart, parts[2])
					if payloadSuccess and payload then
						local payloadUuid = launcher:generateUUID()
						launcher.handlers[payloadUuid] = function()
							return payload
						end

						table.insert(results, {
							text = payload,
							subText = "JWT Payload",
							uuid = payloadUuid,
							copyToClipboard = true,
						})
					end

					if #results == 0 then
						return {
							{
								text = "Failed to decode JWT",
								subText = "Invalid base64 encoding",
								uuid = launcher:generateUUID(),
							},
						}
					end

					return results
				end,
			})
			return "OPEN_CHILD_PICKER"
		end,
	},

	{
		id = "colors",
		name = "Color Converter",
		description = "Convert between color formats (hex, rgb)",
		handler = function()
			spoon.ActionsLauncher:openChildPicker({
				placeholder = "Enter color (hex or rgb)...",
				parentAction = "colors",
				handler = function(query, launcher)
					if not query or query == "" then
						return {}
					end

					local results = {}

					-- Try to parse as hex color (#RRGGBB or RRGGBB)
					local hex = query:match("^#?([%x][%x][%x][%x][%x][%x])$")
					if hex then
						local r = tonumber(hex:sub(1, 2), 16)
						local g = tonumber(hex:sub(3, 4), 16)
						local b = tonumber(hex:sub(5, 6), 16)

						-- RGB result
						local rgbUuid = launcher:generateUUID()
						launcher.handlers[rgbUuid] = function()
							return string.format("rgb(%d, %d, %d)", r, g, b)
						end

						table.insert(results, {
							text = string.format("rgb(%d, %d, %d)", r, g, b),
							subText = "RGB format",
							uuid = rgbUuid,
							image = launcher:createColorSwatch(r, g, b),
							copyToClipboard = true,
						})
					end

					-- Try to parse as RGB (rgb(r, g, b))
					local r, g, b = query:match("rgb%s*%((%d+)%s*,%s*(%d+)%s*,%s*(%d+)%)")
					if r and g and b then
						r, g, b = tonumber(r), tonumber(g), tonumber(b)

						-- Hex result
						local hexUuid = launcher:generateUUID()
						launcher.handlers[hexUuid] = function()
							return string.format("#%02X%02X%02X", r, g, b)
						end

						table.insert(results, {
							text = string.format("#%02X%02X%02X", r, g, b),
							subText = "Hex format",
							uuid = hexUuid,
							image = launcher:createColorSwatch(r, g, b),
							copyToClipboard = true,
						})
					end

					if #results == 0 then
						return {
							{
								text = "Invalid color format",
								subText = "Try: #FF5733 or rgb(255, 87, 51)",
								uuid = launcher:generateUUID(),
							},
						}
					end

					return results
				end,
			})
			return "OPEN_CHILD_PICKER"
		end,
	},
}
