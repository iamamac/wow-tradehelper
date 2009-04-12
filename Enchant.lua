vellumUsage = {
  armor0 = 38682,	-- Armor Vellum
  armor35 = 37602,	-- Armor Vellum II
  armor60 = 43145,	-- Armor Vellum III
  weapon0 = 39349,	-- Weapon Vellum
  weapon35 = 39350,	-- Weapon Vellum II
  weapon60 = 43146,	-- Weapon Vellum III
}

local slotType = {
  ["factor_item.bracer"] = "armor",
  ["factor_item.gloves"] = "armor",
  ["factor_item.boots"] = "armor",
  ["factor_item.shield"] = "armor",
  ["factor_item.chest"] = "armor",
  ["factor_item.cloak"] = "armor",
  ["factor_item.2hweap"] = "weapon",
  ["factor_item.weapon"] = "weapon",
  ["factor_item.ring"] = nil,	-- currently applies to the enchanter only, can"t sell
}

function TradeHelper:PickScroll(lowestProfit, batchSize)
  if lowestProfit == nil or batchSize == nil then return end
  
  -- Open the trade skill window
  CastSpellByName("Enchanting")
  
  local vellumPrice = self.db.profile.enchant.vellumPrice
  local subClass
  local profitTable = {}
  for recipeIndex=1, GetNumTradeSkills() do
    local name, type = GetTradeSkillInfo(recipeIndex)
    if type == "header" then
      subClass = name
    -- Filter out uninterested recipes
    elseif subClass == "Enchant" then
      local scrollName = "Scroll of "..name
      local scroll = Enchantrix.Util.GetLinkFromName(scrollName)
      local scrollPrice, _, _, _, infoString = AucAdvanced.API.GetBestMatch(scroll, "market")
      -- Filter out those can not match lowest price
      if scrollPrice and not infoString:find("Can not match") then
        local enchantType = slotType[EnchantrixBarker_GetItemCategoryKey(recipeIndex)]
        local level = GetTradeSkillDescription(recipeIndex):match("Requires a level (%d+) or higher item") or "0"
        local cost = vellumPrice[vellumUsage[enchantType..level]]
        for reagentIndex=1, GetTradeSkillNumReagents(recipeIndex) do
          local _, _, reagentCount = GetTradeSkillReagentInfo(recipeIndex, reagentIndex)
          local reagent = GetTradeSkillReagentItemLink(recipeIndex, reagentIndex)
          local price = Enchantrix_GetReagentHSP(reagent)
          if price == 0 then cost = nil; break end
          cost = cost + price * reagentCount
        end
        if cost then
          local profit = scrollPrice * (1 - AucAdvanced.cutRate) - cost
          local num = self.db.profile.enchant.batchSize - self:ItemCountInStock(scrollName)
          if profit >= lowestProfit and num > 0 then
            tinsert(profitTable, {
              SkillId = recipeIndex,
              Scroll = scroll,
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
  
  local reagentNeed = {}
  local reagentInStock = {}
  local msg = ""
  for _, v in ipairs(profitTable) do
    msg = msg.."\n"..v.Scroll..": "..self:FormatMoney(v.Profit).." x "..v.Number
    local recipeIndex = v.SkillId
    local _, _, canMake = GetTradeSkillInfo(recipeIndex)
    if canMake < v.Number then msg = msg.." ("..canMake..")" end
    for reagentIndex=1, GetTradeSkillNumReagents(recipeIndex) do
      local reagent = GetTradeSkillReagentItemLink(recipeIndex, reagentIndex)
      local reagentId = Enchantrix.Util.GetItemIdFromLink(reagent)
      local _, _, count, playerCount = GetTradeSkillReagentInfo(recipeIndex, reagentIndex)
      reagentNeed[reagentId] = (reagentNeed[reagentId] or 0) + count * v.Number
      reagentInStock[reagentId] = playerCount
    end
  end
  msg = msg.."\nMissing reagents:"
  for reagentId, reagentCount in pairs(reagentNeed) do
    local reagentShort = reagentCount - reagentInStock[reagentId]
    if reagentShort > 0 then
      local _, reagent = GetItemInfo(reagentId)
      msg = msg.."\n"..reagent.." x "..reagentShort
    end
  end
  self:Print(ChatFrame2, msg)
end

function TradeHelper:GetVellumPrice(marketPercent)
  self.db.profile.enchant.vellumPrice = self:GetSelfMadeVellumPrice()
  
  local vellumPrice = self.db.profile.enchant.vellumPrice
  for _, id in pairs(vellumUsage) do
    local _, link = GetItemInfo(id)
    local price = AucAdvanced.API.GetMarketValue(link)
    if price then
      price = floor(price * marketPercent)
      if vellumPrice[id] == nil or price < vellumPrice[id] then vellumPrice[id] = price end
    end
  end
end
