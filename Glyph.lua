local parchmentPrice = {
  [39354] = 12,		-- Light Parchment
  [10648] = 100,	-- Common Parchment
  [39501] = 1000,	-- Heavy Parchment
  [39502] = 4000,	-- Resilient Parchment
}

function TradeHelper:PickGlyph(lowestProfit)
  if lowestProfit == nil then lowestProfit = 0 end
  
  -- Open the trade skill window
  CastSpellByName("Inscription")
  
  local inkPrice = self.db.profile.inkPrice
  local subClass
  local profitTable = {}
  for recipeIndex=1, GetNumTradeSkills() do
    local name, type, _, _, _ = GetTradeSkillInfo(recipeIndex)
    if type == "header" then
      subClass = name
    -- Filter out uninterested recipes
    elseif strfind(name, "Glyph of") and subClass ~= "Death Knight" then
      local product = GetTradeSkillItemLink(recipeIndex)
      local productCount = GetTradeSkillNumMade(recipeIndex)
      local productPrice, _, _, _, infoString = AucAdvanced.API.GetBestMatch(product, "market")
      -- Filter out those can not match lowest price
      if productPrice>0 and not infoString:find("Can not match") then
        local cost = 0
        for reagentIndex=1, GetTradeSkillNumReagents(recipeIndex) do
          local reagentName, _, reagentCount, _ = GetTradeSkillReagentInfo(recipeIndex, reagentIndex)
          local reagentId = Enchantrix.Util.GetItemIdFromLink(GetTradeSkillReagentItemLink(recipeIndex, reagentIndex))
          local price = inkPrice[reagentId] or parchmentPrice[reagentId]
          if price == nil then cost = nil; break end
          cost = cost + price * reagentCount
        end
        if cost then
          local profit = productPrice * productCount - cost
          if profit >= lowestProfit then
            tinsert(profitTable, {Product = product, Profit = profit})
          end
        end
      end
    end
  end
  
  sort(profitTable, function (a,b)
    return a.Profit > b.Profit
  end)
  
  for _, v in ipairs(profitTable) do
    self:Print(ChatFrame2, v.Product..": "..self:FormatMoney(v.Profit))
  end
end

function TradeHelper:GetPigmentPrice(marketPercent)
  if marketPercent == nil then marketPercent = 1 end
  
  local pigmentPrice = {}
  for herbId, group in pairs(Enchantrix.Constants.MillableItems) do
    for pigmentId, millCount in pairs(Enchantrix.Constants.MillGroupYields[group]) do
      local _, link = GetItemInfo(herbId)
      local herbPrice = AucAdvanced.API.GetMarketValue(link)
      if herbPrice then
        millPrice = herbPrice * marketPercent * 5 / millCount
        if pigmentPrice[pigmentId] == nil or pigmentPrice[pigmentId] > millPrice then
          pigmentPrice[pigmentId] = millPrice
        end
      end
    end
  end
  return pigmentPrice
end

function TradeHelper:GetInkPrice(marketPercent)
  -- Herb to pigment
  local pigmentPrice = self:GetPigmentPrice(marketPercent)
  
  -- Pigment to ink
  CastSpellByName("Inscription")
  local inkPrice = self.db.profile.inkPrice
  for recipeIndex=1, GetNumTradeSkills() do
    local name, type, _, _, _ = GetTradeSkillInfo(recipeIndex)
    if strfind(name, "Ink") then
      local inkId = Enchantrix.Util.GetItemIdFromLink(GetTradeSkillItemLink(recipeIndex))
      local inkCount = GetTradeSkillNumMade(recipeIndex)
      local _, _, pigmentCount, _ = GetTradeSkillReagentInfo(recipeIndex, 1)
      local pigmentId = Enchantrix.Util.GetItemIdFromLink(GetTradeSkillReagentItemLink(recipeIndex, 1))
      inkPrice[inkId] = floor(pigmentPrice[pigmentId] * pigmentCount / inkCount)
    end
  end
  CloseTradeSkill()
end

function TradeHelper:BuildReagentSnatchList(marketPercent)
  -- Ink
  for id, price in pairs(self.db.profile.inkPrice) do
    local _, link, quality = GetItemInfo(id)
    -- Rare quality inks are almost of no use
    if quality == 1 then
      AucSearchUI.Searchers.Snatch.AddSnatch(link, price)
    end
  end
  
  -- Pigment
  local pigmentPrice = self:GetPigmentPrice(marketPercent)
  for id, price in pairs(pigmentPrice) do
    local _, link, quality = GetItemInfo(id)
    if quality == 1 then
      AucSearchUI.Searchers.Snatch.AddSnatch(link, price)
    end
  end
  
  -- Herb
  for herbId, group in pairs(Enchantrix.Constants.MillableItems) do
    for pigmentId, millCount in pairs(Enchantrix.Constants.MillGroupYields[group]) do
      if pigmentPrice[pigmentId] then
        local _, link = GetItemInfo(herbId)
        local herbPrice = pigmentPrice[pigmentId] * millCount / 5
        AucSearchUI.Searchers.Snatch.AddSnatch(link, herbPrice)
      end
    end
  end
end
