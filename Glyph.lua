local parchmentPrice = {
  [39354] = 12,		-- Light Parchment
  [10648] = 100,	-- Common Parchment
  [39501] = 1000,	-- Heavy Parchment
  [39502] = 4000,	-- Resilient Parchment
}

TradeHelper.glyphPattern = '^Glyph of '

function TradeHelper:PickGlyph()
  -- Open the trade skill window
  CastSpellByName("Inscription")
  
  local profile = self.db.profile.glyph
  local inkPrice = profile.inkPrice
  local subClass
  local profitTable = {}
  for recipeIndex=1, GetNumTradeSkills() do
    local name, type = GetTradeSkillInfo(recipeIndex)
    if type == "header" then
      subClass = name
    -- Filter out uninterested recipes
    elseif name:find(self.glyphPattern) and subClass ~= "Death Knight" then
      local product = GetTradeSkillItemLink(recipeIndex)
      local productId = Enchantrix.Util.GetItemIdFromLink(product)
      local productCount = GetTradeSkillNumMade(recipeIndex)
      
      if profile.cost[productId] == nil then
        local cost = 0
        for reagentIndex = 1, GetTradeSkillNumReagents(recipeIndex) do
          local _, _, reagentCount = GetTradeSkillReagentInfo(recipeIndex, reagentIndex)
          local reagentId = Enchantrix.Util.GetItemIdFromLink(GetTradeSkillReagentItemLink(recipeIndex, reagentIndex))
          local price = inkPrice[reagentId] or parchmentPrice[reagentId]
          if price == nil then cost = nil; break end
          cost = cost + price * reagentCount
        end
        if cost then
          cost = math.ceil(cost / productCount)
          profile.cost[productId] = cost
        end
      end
      
      local productPrice, profit = self:GetPrice(product, profile)
      if productPrice > 0 then
        local num = profile.batchSize - self:ItemCountInStock(product)
        if num > 0 then
          local reagentId, count
          for reagentIndex=1, GetTradeSkillNumReagents(recipeIndex) do
            local reagent = GetTradeSkillReagentItemLink(recipeIndex, reagentIndex)
            reagentId = Enchantrix.Util.GetItemIdFromLink(reagent)
            if inkPrice[reagentId] then
              _, _, count = GetTradeSkillReagentInfo(recipeIndex, reagentIndex)
              break
            end
          end
          tinsert(profitTable, {
            Product = product,
            Profit = profit,
            Number = num,
            InkId = reagentId,
            InkNeed = count,
          })
        end
      end
    end
  end
  
  sort(profitTable, function (a,b)
    if profile.sortPerInk then
      return a.Profit / a.InkNeed > b.Profit / b.InkNeed
    else
      return a.Profit > b.Profit
    end
  end)
  
  local inkNeed = {}
  local inkInStock = {}
  local msg = ""
  for _, v in ipairs(profitTable) do
    inkNameShort = GetItemInfo(v.InkId):sub(1,1)
    msg = msg.."\n"..v.Product.." "..v.InkNeed..inkNameShort..": "..self:FormatMoney(v.Profit).." x "..v.Number
    inkNeed[v.InkId] = (inkNeed[v.InkId] or 0) + v.InkNeed * v.Number
    if inkInStock[v.InkId] == nil then inkInStock[v.InkId] = GetItemCount(v.InkId, true) end
    local canMake = floor(inkInStock[v.InkId] / v.InkNeed)
    if canMake < v.Number then msg = msg.." ("..canMake..")" end
  end
  msg = msg.."\nMissing reagents:"
  local inkReagent = profile.inkReagent
  for inkId, inkCount in pairs(inkNeed) do
    local inkShort = inkCount - inkInStock[inkId]
    if inkShort > 0 then
      local _, ink = GetItemInfo(inkId)
      local _, pigment = GetItemInfo(inkReagent[inkId].id)
      local herbShort = ceil(inkReagent[inkId].count * inkShort / 3) * 5
      msg = msg.."\n"..ink.." x "..inkShort.." / "..pigment.." level herb x "..herbShort
    end
  end
  self:Print(msg)
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
      local vellumCount = GetTradeSkillNumMade(recipeIndex)
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
        vellumPrice[vellumId] = math.ceil(cost / vellumCount)
      end
    end
  end
  CloseTradeSkill()
  return vellumPrice
end
