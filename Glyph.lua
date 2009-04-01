function TradeHelper:PickGlyph(lowestProfit)
  local subClass
  for recipeId=1, GetNumTradeSkills() do
    local name, type, _, _, _ = GetTradeSkillInfo(recipeId)
    if type == "header" then
      subClass = name
    -- Filter out uninterested recipes
    elseif strfind(name, "Glyph of") and subClass ~= "Death Knight" then
      local product = GetTradeSkillItemLink(recipeId)
      local productPrice, _, _, _, infoString = AucAdvanced.API.GetBestMatch(product, "market")
      -- Filter out those can not match lowest price
      if productPrice>0 and not infoString:find("Can not match") then
        self:Print(subClass.." - "..name..": "..productPrice)
        local cost = 0
        for reagentId=1, GetTradeSkillNumReagents(recipeId) do
          local reagentName, _, reagentCount, _ = GetTradeSkillReagentInfo(recipeId, reagentId)
          cost = cost + 1
        end
        local profit = productPrice - cost
      end
    end
  end
end
