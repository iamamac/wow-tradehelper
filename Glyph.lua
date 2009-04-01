local parchmentPrice = {
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
          if parchmentPrice[reagentId] then
            -- Parchment
            cost = cost + parchmentPrice[reagentId] * reagentCount
        self:Print(ChatFrame2, reagentName.." - "..parchmentPrice[reagentId])
          else
            -- Ink
            
            cost = cost + 1
          end
        end
        local profit = productPrice * productCount - cost
      end
    end
  end
end
