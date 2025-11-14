-- Utilities Actions Bundle
-- Text processing and generation utilities

local icons = require 'lib.icons'
local events = require 'lib.events'

-- Count words in text
local function countWords(text)
	if not text or text == '' then
		return 0
	end

	local count = 0
	for word in text:gmatch('%S+') do
		count = count + 1
	end
	return count
end

-- Count sentences in text
local function countSentences(text)
	if not text or text == '' then
		return 0
	end

	-- Count sentences by looking for .!? followed by space/newline/end of string
	local count = 0
	for _ in text:gmatch('[.!?]+%s') do
		count = count + 1
	end

	-- Check if the last character is a sentence ending
	if text:match('[.!?]$') then
		count = count + 1
	elseif count == 0 and text:match('%S') then
		-- If no sentence endings found but text is not empty, count as 1 sentence
		count = 1
	end

	return count
end

-- Count paragraphs in text
local function countParagraphs(text)
	if not text or text == '' then
		return 0
	end

	-- Count paragraphs by splitting on double newlines or treating single newlines as paragraphs
	local count = 0
	local inParagraph = false

	for line in (text .. '\n'):gmatch('(.-)\n') do
		local trimmed = line:match('^%s*(.-)%s*$')
		if trimmed ~= '' then
			if not inParagraph then
				count = count + 1
				inParagraph = true
			end
		else
			inParagraph = false
		end
	end

	-- If text doesn't end with newline and has content, ensure it's counted
	if count == 0 and text:match('%S') then
		count = 1
	end

	return count
end

-- Format number with thousands separator
local function formatNumber(num)
	local formatted = tostring(num)
	local k
	while true do
		formatted, k = formatted:gsub('^(-?%d+)(%d%d%d)', '%1,%2')
		if k == 0 then
			break
		end
	end
	return formatted
end

return {
	{
		id = 'generate_uuid',
		name = 'Generate UUID',
		icon = icons.preset.key,
		description = 'Generate UUID v4 and copy to clipboard',
		handler = function()
			spoon.ActionsLauncher.executeShell(
				"uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '\\n' | pbcopy && pbpaste",
				'Generate UUID',
				true
			)
		end,
	},
	{
		id = 'word_count',
		name = 'Word Count',
		icon = icons.preset.text,
		description = 'Count characters, words, sentences, and paragraphs in text',
		handler = function()
			local clipboardText = hs.pasteboard.getContents() or ''

			spoon.ActionsLauncher:openChildPicker({
				placeholder = 'Enter or paste text to analyze...',
				parentAction = 'word_count',
				handler = function(query, launcher)
					-- Use clipboard text as default if query is empty
					local text = query
					if not text or text == '' then
						text = clipboardText
					end

					-- Auto-fill clipboard text on first open
					if launcher.chooser and not launcher.initialTextSet then
						launcher.chooser:query(clipboardText)
						launcher.initialTextSet = true
					end

					local results = {}

					if not text or text == '' then
						table.insert(results, {
							text = 'Paste or type text to analyze',
							subText = 'Character, word, sentence, and paragraph counts will appear here',
							uuid = launcher:generateUUID(),
						})
						return results
					end

					-- Count statistics
					local charCount = #text
					local charCountNoSpaces = #(text:gsub('%s', ''))
					local wordCount = countWords(text)
					local sentenceCount = countSentences(text)
					local paragraphCount = countParagraphs(text)

					-- Characters (with spaces)
					local charsUuid = launcher:generateUUID()
					launcher.handlers[charsUuid] = events.copyToClipboard(function(choice)
						return tostring(charCount)
					end)
					table.insert(results, {
						text = formatNumber(charCount) .. ' characters',
						subText = 'Total characters including spaces',
						uuid = charsUuid,
					})

					-- Characters (without spaces)
					local charsNoSpacesUuid = launcher:generateUUID()
					launcher.handlers[charsNoSpacesUuid] = events.copyToClipboard(function(choice)
						return tostring(charCountNoSpaces)
					end)
					table.insert(results, {
						text = formatNumber(charCountNoSpaces) .. ' characters (no spaces)',
						subText = 'Total characters excluding spaces',
						uuid = charsNoSpacesUuid,
					})

					-- Words
					local wordsUuid = launcher:generateUUID()
					launcher.handlers[wordsUuid] = events.copyToClipboard(function(choice)
						return tostring(wordCount)
					end)
					table.insert(results, {
						text = formatNumber(wordCount) .. ' words',
						subText = 'Total word count',
						uuid = wordsUuid,
					})

					-- Sentences
					local sentencesUuid = launcher:generateUUID()
					launcher.handlers[sentencesUuid] = events.copyToClipboard(function(choice)
						return tostring(sentenceCount)
					end)
					table.insert(results, {
						text = formatNumber(sentenceCount) .. ' sentences',
						subText = 'Total sentence count',
						uuid = sentencesUuid,
					})

					-- Paragraphs
					local paragraphsUuid = launcher:generateUUID()
					launcher.handlers[paragraphsUuid] = events.copyToClipboard(function(choice)
						return tostring(paragraphCount)
					end)
					table.insert(results, {
						text = formatNumber(paragraphCount) .. ' paragraphs',
						subText = 'Total paragraph count',
						uuid = paragraphsUuid,
					})

					-- Average words per sentence
					if sentenceCount > 0 then
						local avgWordsPerSentence = wordCount / sentenceCount
						local avgUuid = launcher:generateUUID()
						launcher.handlers[avgUuid] = events.copyToClipboard(function(choice)
							return string.format('%.1f', avgWordsPerSentence)
						end)
						table.insert(results, {
							text = string.format('%.1f words per sentence', avgWordsPerSentence),
							subText = 'Average words per sentence',
							uuid = avgUuid,
						})
					end

					return results
				end,
			})

			return 'OPEN_CHILD_PICKER'
		end,
	},
}
