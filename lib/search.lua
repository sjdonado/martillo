-- Provides rank-based fuzzy search with configurable weights and tie breakers

local M = {}

local DEFAULT_WEIGHTS = {
  exact = 1000,
  prefix = 500,
  wordPrefix = 400,
  contains = 200,
  fuzzyBase = 100,
  fuzzyGapPenalty = 1,
  aliasBoost = 150,
  aliasShortBoost = 600,
}

local function toLower(str)
  return string.lower(str)
end

local function isWordChar(char)
  if not char or char == '' then
    return false
  end
  local byte = char:byte()
  if not byte then
    return false
  end
  -- 0-9
  if byte >= 48 and byte <= 57 then
    return true
  end
  -- A-Z
  if byte >= 65 and byte <= 90 then
    return true
  end
  -- a-z
  if byte >= 97 and byte <= 122 then
    return true
  end
  -- underscore
  return byte == 95
end

local function hasWordPrefix(text, query)
  local startPos = 1
  while true do
    local matchPos = string.find(text, query, startPos, true)
    if not matchPos then
      return false
    end
    if matchPos == 1 then
      return true
    end

    local prevChar = text:sub(matchPos - 1, matchPos - 1)
    if not isWordChar(prevChar) then
      return true
    end

    startPos = matchPos + 1
  end
end

local function computeFuzzyScore(text, query, queryLen, weights)
  local queryPos = 1
  local lastMatchPos = 0
  local firstMatchPos = nil
  local gaps = 0

  for i = 1, #text do
    if queryPos <= queryLen and text:sub(i, i) == query:sub(queryPos, queryPos) then
      if not firstMatchPos then
        firstMatchPos = i
      end
      gaps = gaps + (i - lastMatchPos - 1)
      lastMatchPos = i
      queryPos = queryPos + 1
    end
  end

  if queryPos > queryLen then
    local base = weights.fuzzyBase or DEFAULT_WEIGHTS.fuzzyBase
    local penalty = weights.fuzzyGapPenalty or DEFAULT_WEIGHTS.fuzzyGapPenalty
    local score = base - (gaps * penalty)
    if score > 0 then
      local span = 0
      if firstMatchPos and lastMatchPos >= firstMatchPos then
        span = lastMatchPos - firstMatchPos + 1
      end
      return score, {
        gaps = gaps,
        span = span,
        first = firstMatchPos,
        last = lastMatchPos,
      }
    end
  end

  return 0
end

local function computeMatchScore(text, query, queryLen, weights, opts)
  opts = opts or {}
  if queryLen == 0 or text == '' then
    return nil
  end

  if text == query then
    return weights.exact or DEFAULT_WEIGHTS.exact, 'exact'
  end

  if #text >= queryLen and text:sub(1, queryLen) == query then
    return weights.prefix or DEFAULT_WEIGHTS.prefix, 'prefix'
  end

  if (weights.wordPrefix or DEFAULT_WEIGHTS.wordPrefix) > 0 and hasWordPrefix(text, query) then
    return weights.wordPrefix or DEFAULT_WEIGHTS.wordPrefix, 'word_prefix'
  end

  if text:find(query, 1, true) then
    return weights.contains or DEFAULT_WEIGHTS.contains, 'contains'
  end

  local allowFuzzy = opts.enableFuzzy
  if allowFuzzy == nil then
    allowFuzzy = true
  end

  local minLen = opts.fuzzyMinQueryLength or 3

  if allowFuzzy and queryLen >= minLen then
    local fuzzyScore, extra = computeFuzzyScore(text, query, queryLen, weights)
    if fuzzyScore > 0 then
      local span = extra and extra.span or queryLen
      if span == 0 then
        span = queryLen
      end
      local coverage = queryLen / span
      local coverageThreshold = opts.fuzzyMinCoverage or 0.6
      local maxGapFactor = opts.fuzzyMaxGapFactor or 2
      local maxTotalGap = opts.fuzzyMaxTotalGap or (queryLen * maxGapFactor)
      local gaps = extra and extra.gaps or 0

      if coverage >= coverageThreshold and gaps <= maxTotalGap then
        return fuzzyScore, 'fuzzy', extra
      end
    end
  end

  return nil
end

--- Rank a list of items by fuzzy match score.
-- @param query string: the incoming search query
-- @param items table: list-like table of items to search
-- @param opts table: optional configuration
--   * getFields(item) -> { { value = "...", weight = 1, key = "text" }, ... }
--   * adjustScore(item, context) -> number
--   * tieBreaker(itemA, itemB, resultA, resultB) -> boolean
--   * maxResults -> limit number of returned items
--   * weights -> override DEFAULT_WEIGHTS (partial)
--   * caseSensitive -> disable automatic lowercase normalization
--   * normalize(text) -> custom normalization function
--   * enableFuzzy -> boolean to toggle subsequence matching (default true)
--   * fuzzyMinQueryLength -> minimum query length to enable fuzzy matching (default 3)
--   * fuzzyMinCoverage -> minimum ratio (queryLen / matchSpan) required for fuzzy matches (default 0.6)
--   * fuzzyMaxGapFactor -> maximum total gap allowed between fuzzy characters, as multiplier of query length (default 2)
--   * fuzzyMaxTotalGap -> absolute cap on total gap characters (overrides factor if provided)
-- @return rankedItems, detailedResults
function M.rank(query, items, opts)
  if not items or #items == 0 then
    return {}, {}
  end

  opts = opts or {}

  if not query or query == '' then
    return items, {}
  end

  local normalize = opts.normalize or toLower
  local weights = setmetatable(opts.weights or {}, {
    __index = DEFAULT_WEIGHTS,
  })

  local normalizedQuery = opts.caseSensitive and query or normalize(query)
  local queryLen = #normalizedQuery

  if queryLen == 0 then
    return items, {}
  end

  local getFields = opts.getFields or function(item)
    return { { value = item.text or item.name or '' } }
  end

  local results = {}
  local aliasShortLength = opts.aliasShortLength
  if aliasShortLength == nil then
    aliasShortLength = 2
  end

  for index, item in ipairs(items) do
    local fields = getFields(item)

    if fields and #fields > 0 then
      local bestScore = nil
      local bestInfo = nil

      for _, field in ipairs(fields) do
        local fieldValue
        local fieldWeight = 1
        local fieldKey

        if type(field) == 'table' then
          fieldValue = field.value or field.text or field[1]
          fieldWeight = field.weight or field[2] or 1
          fieldKey = field.key
        else
          fieldValue = field
        end

        if fieldValue and fieldValue ~= '' then
          local normalizedField = opts.caseSensitive and tostring(fieldValue) or normalize(tostring(fieldValue))

          if normalizedField ~= '' then
            local score, matchType, extra = computeMatchScore(normalizedField, normalizedQuery, queryLen, weights, opts)

            if score and score > 0 then
              local weightedScore = score * fieldWeight

              if fieldKey == 'alias' then
                if weights.aliasBoost and weights.aliasBoost ~= 0 then
                  weightedScore = weightedScore + weights.aliasBoost
                end
                if aliasShortLength > 0 and queryLen <= aliasShortLength then
                  weightedScore = weightedScore + (weights.aliasShortBoost or 0)
                end
              end

              if not bestScore or weightedScore > bestScore then
                bestScore = weightedScore
                bestInfo = {
                  matchType = matchType,
                  fieldKey = fieldKey,
                  rawScore = score,
                  weight = fieldWeight,
                  extra = extra,
                  value = fieldValue,
                }
              end
            end
          end
        end
      end

      if bestScore then
        local finalScore = bestScore

        if opts.adjustScore then
          finalScore = opts.adjustScore(item, {
            score = bestScore,
            match = bestInfo,
            index = index,
            item = item,
          }) or bestScore
        end

        if finalScore and finalScore > 0 then
          table.insert(results, {
            item = item,
            score = finalScore,
            index = index,
            match = bestInfo,
          })
        end
      end
    end
  end

  table.sort(results, function(a, b)
    if a.score == b.score then
      if opts.tieBreaker then
        return opts.tieBreaker(a.item, b.item, a, b)
      end
      return a.index < b.index
    end
    return a.score > b.score
  end)

  local rankedItems = {}
  local limit = opts.maxResults or #results
  for i = 1, math.min(limit, #results) do
    rankedItems[i] = results[i].item
  end

  return rankedItems, results
end

return M
