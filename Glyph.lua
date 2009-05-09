local parchmentPrice = {
  [39354] = 12,		-- Light Parchment
  [10648] = 100,	-- Common Parchment
  [39501] = 1000,	-- Heavy Parchment
  [39502] = 4000,	-- Resilient Parchment
}

function TradeHelper:PickGlyph(lowestProfit, batchSize)
  if lowestProfit == nil or batchSize == nil then return end
  
  -- Open the trade skill window
  CastSpellByName("Inscription")
  
  local inkPrice = self.db.profile.glyph.inkPrice
  local subClass
  local profitTable = {}
  for recipeIndex=1, GetNumTradeSkills() do
    local name, type = GetTradeSkillInfo(recipeIndex)
    if type == "header" then
      subClass = name
    -- Filter out uninterested recipes
    elseif name:find("^Glyph of") and subClass ~= "Death Knight" then
      local product = GetTradeSkillItemLink(recipeIndex)
      local productCount = GetTradeSkillNumMade(recipeIndex)
      local productPrice, _, _, _, infoString = AucAdvanced.API.GetBestMatch(product, "market")
      -- Filter out those can not match lowest price
      if productPrice and not infoString:find("Can not match") then
        local cost = 0
        for reagentIndex=1, GetTradeSkillNumReagents(recipeIndex) do
          local _, _, reagentCount = GetTradeSkillReagentInfo(recipeIndex, reagentIndex)
          local reagentId = Enchantrix.Util.GetItemIdFromLink(GetTradeSkillReagentItemLink(recipeIndex, reagentIndex))
          local price = inkPrice[reagentId] or parchmentPrice[reagentId]
          if price == nil then cost = nil; break end
          cost = cost + price * reagentCount
        end
        if cost then
          local profit = productPrice * productCount * (1 - AucAdvanced.cutRate) - cost
          local num = self.db.profile.glyph.batchSize - self:ItemCountInStock(name)
          if profit >= lowestProfit and num > 0 then
            tinsert(profitTable, {
              SkillId = recipeIndex,
              Product = product,
              Profit = profit,
              Number = num,
            })
          end
        end
      end
    end
  end
  
  sort(profitTable, function (a,b)
    return a.Profit > b.Profit
  end)
  
  local inkNeed = {}
  local inkInStock = {}
  local msg = ""
  for _, v in ipairs(profitTable) do
    msg = msg.."\n"..v.Product..": "..self:FormatMoney(v.Profit).." x "..v.Number
    local recipeIndex = v.SkillId
    for reagentIndex=1, GetTradeSkillNumReagents(recipeIndex) do
      local reagent = GetTradeSkillReagentItemLink(recipeIndex, reagentIndex)
      local reagentId = Enchantrix.Util.GetItemIdFromLink(reagent)
      if inkPrice[reagentId] then
        local _, _, count, playerCount = GetTradeSkillReagentInfo(recipeIndex, reagentIndex)
        inkNeed[reagentId] = (inkNeed[reagentId] or 0) + count * v.Number
        inkInStock[reagentId] = playerCount
        local canMake = floor(playerCount / count)
        if canMake < v.Number then msg = msg.." ("..canMake..")" end
      end
    end
  end
  msg = msg.."\nMissing reagents:"
  local inkReagent = self.db.profile.glyph.inkReagent
  for inkId, inkCount in pairs(inkNeed) do
    local inkShort = inkCount - inkInStock[inkId]
    if inkShort > 0 then
      local _, ink = GetItemInfo(inkId)
      local _, pigment = GetItemInfo(inkReagent[inkId].id)
      local herbShort = ceil(inkReagent[inkId].count * inkShort / 3) * 5
      msg = msg.."\n"..ink.." x "..inkShort.." / "..pigment.." level herb x "..herbShort
    end
  end
  self:Print(ChatFrame2, msg)
end

function TradeHelper:GetInkInfo(marketPercent)
  if marketPercent == nil then return end
  
  -- Herb to pigment
  local pigmentPrice = {}
  for herbId, group in pairs(Enchantrix.Constants.MillableItems) do
    local _, link = GetItemInfo(herbId)
    local herbPrice = AucAdvanced.API.GetMarketValue(link)
    if herbPrice then
      for pigmentId, millCount in pairs(Enchantrix.Constants.MillGroupYields[group]) do
        local millPrice = herbPrice * marketPercent * 5 / millCount
        if pigmentPrice[pigmentId] == nil or pigmentPrice[pigmentId] > millPrice then
          pigmentPrice[pigmentId] = millPrice
        end
      end
    end
  end
  
  -- Pigment to ink
  CastSpellByName("Inscription")
  local inkPrice = self.db.profile.glyph.inkPrice
  local inkReagent = self.db.profile.glyph.inkReagent
  wipe(inkPrice)
  for recipeIndex=1, GetNumTradeSkills() do
    local name = GetTradeSkillInfo(recipeIndex)
    if name:find("Ink") then
      local inkId = Enchantrix.Util.GetItemIdFromLink(GetTradeSkillItemLink(recipeIndex))
      local inkCount = GetTradeSkillNumMade(recipeIndex)
      local _, _, pigmentCount = GetTradeSkillReagentInfo(recipeIndex, 1)
      local pigmentId = Enchantrix.Util.GetItemIdFromLink(GetTradeSkillReagentItemLink(recipeIndex, 1))
      inkPrice[inkId] = floor(pigmentPrice[pigmentId] * pigmentCount / inkCount)
      inkReagent[inkId] = {id = pigmentId, count = pigmentCount / inkCount}
    end
  end
  CloseTradeSkill()
end

function TradeHelper:BuildGlyphSnatchList()
  -- Ink
  local inkPrice = self.db.profile.glyph.inkPrice
  for id, price in pairs(inkPrice) do
    local _, link, quality = GetItemInfo(id)
    -- Rare, Ivory Ink and Moonglow Ink
    if quality == 1 and id ~= 37101 and id ~= 39469 then
      AucSearchUI.Searchers.Snatch.AddSnatch(link, price)
    end
  end
  
  -- Pigment
  local inkReagent = self.db.profile.glyph.inkReagent
  local pigmentPrice = {}
  for inkId, price in pairs(inkPrice) do
    local pigmentId = inkReagent[inkId].id
    local _, link, quality = GetItemInfo(pigmentId)
    -- Rare and Alabaster Pigment
    if quality == 1 and pigmentId ~= 39151 then
      pigmentPrice[pigmentId] = price / inkReagent[inkId].count
      AucSearchUI.Searchers.Snatch.AddSnatch(link, floor(pigmentPrice[pigmentId]))
    end
  end
  
  -- Herb
  for herbId, group in pairs(Enchantrix.Constants.MillableItems) do
    local _, link = GetItemInfo(herbId)
    for pigmentId, millCount in pairs(Enchantrix.Constants.MillGroupYields[group]) do
      if pigmentPrice[pigmentId] then
        local herbPrice = floor(pigmentPrice[pigmentId] * millCount / 5)
        AucSearchUI.Searchers.Snatch.AddSnatch(link, herbPrice)
      end
    end
  end
end

function TradeHelper:GetSelfMadeVellumPrice()
  CastSpellByName("Inscription")
  local inkPrice = self.db.profile.glyph.inkPrice
  local vellumPrice = {}
  for recipeIndex=1, GetNumTradeSkills() do
    local name = GetTradeSkillInfo(recipeIndex)
    if name:find("Vellum") then
      local cost = 0
      for reagentIndex=1, GetTradeSkillNumReagents(recipeIndex) do
        local _, _, reagentCount = GetTradeSkillReagentInfo(recipeIndex, reagentIndex)
        local reagentId = Enchantrix.Util.GetItemIdFromLink(GetTradeSkillReagentItemLink(recipeIndex, reagentIndex))
        local price = inkPrice[reagentId] or parchmentPrice[reagentId]
        if price == nil then cost = nil; break end
        cost = cost + price * reagentCount
      end
      if cost then
        local vellumId = Enchantrix.Util.GetItemIdFromLink(GetTradeSkillItemLink(recipeIndex))
        vellumPrice[vellumId] = cost
      end
    end
  end
  CloseTradeSkill()
  return vellumPrice
end
