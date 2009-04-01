local reagentPrice = {
  [39354] = 12,		-- Light Parchment
  [10648] = 100,	-- Common Parchment
  [39501] = 1000,	-- Heavy Parchment
  [39502] = 4000,	-- Resilient Parchment
}

function TradeHelper:PickGlyph(lowestProfit)
  -- Open the trade skill window
  CastSpellByName("Inscription")
  
  local subClass
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
        self:Print(ChatFrame2, subClass.." - "..name.." * "..productCount..": "..productPrice)
        local cost = 0
        for reagentIndex=1, GetTradeSkillNumReagents(recipeIndex) do
          local reagentName, _, reagentCount, _ = GetTradeSkillReagentInfo(recipeIndex, reagentIndex)
          local reagentId = Enchantrix.Util.GetItemIdFromLink(GetTradeSkillReagentItemLink(recipeIndex, reagentIndex))
          cost = cost + reagentPrice[reagentId] * reagentCount
        end
        local profit = productPrice * productCount - cost
      end
    end
  end
end

function TradeHelper:GetInkPrice(marketPercent)
  if marketPercent == nil then marketPercent = 1 end
  
  -- Herb to pigment
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
  
  -- Pigment to ink
  CastSpellByName("Inscription")
  for recipeIndex=1, GetNumTradeSkills() do
    local name, type, _, _, _ = GetTradeSkillInfo(recipeIndex)
    if strfind(name, "Ink") then
      local inkId = Enchantrix.Util.GetItemIdFromLink(GetTradeSkillItemLink(recipeIndex))
      local inkCount = GetTradeSkillNumMade(recipeIndex)
      local _, _, pigmentCount, _ = GetTradeSkillReagentInfo(recipeIndex, 1)
      local pigmentId = Enchantrix.Util.GetItemIdFromLink(GetTradeSkillReagentItemLink(recipeIndex, 1))
      reagentPrice[inkId] = pigmentPrice[pigmentId] * pigmentCount / inkCount
      self:Print(GetTradeSkillItemLink(recipeIndex)..reagentPrice[inkId])
    end
  end
  CloseTradeSkill()
end
