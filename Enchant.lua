local vellumUsage = {
  [{"armor", 0}] = 38682,	-- Armor Vellum
  [{"armor", 35}] = 37602,	-- Armor Vellum II
  [{"armor", 60}] = 43145,	-- Armor Vellum III
  [{"weapon", 0}] = 39349,	-- Weapon Vellum
  [{"weapon", 35}] = 39350,	-- Weapon Vellum II
  [{"weapon", 60}] = 43146,	-- Weapon Vellum III
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
