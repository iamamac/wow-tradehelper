TradeHelper = LibStub("AceAddon-3.0"):NewAddon("TradeHelper", "AceConsole-3.0")

local abacus = LibStub("LibAbacus-3.0")

local defaults = {
  factionrealm = {
    cost = {},
  },
}

TradeHelper.options = {
  type = "group",
  childGroups = "tab",
  args = {
  },
  plugins = {},
}

function TradeHelper:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("TradeHelperDB", defaults, true)
  self.cost = self.db.factionrealm.cost

  LibStub("AceConfig-3.0"):RegisterOptionsTable(self.name, self.options, {"th"})
  LibStub("AceConfigDialog-3.0"):AddToBlizOptions(self.name, self.name)
end

function TradeHelper:FormatMoney(value)
  return abacus:FormatMoneyFull(value, true)
end

function TradeHelper:Print(...)
  AucAdvanced.Print(...)
end

function TradeHelper:ItemCountInStock(item)
  -- Inventory (including bank)
  local count = GetItemCount(item, true)

  -- Auction
  local name = GetItemInfo(item)
  local own = AucAdvanced.Modules.Util.Appraiser.ownResults
  if own and own[name] then
    for _, res in pairs(own[name]) do
      count = count + res.countBid
    end
  end

  return count
end

function TradeHelper:GetPrice(link, profile, undercutStart)
  local marketPrice = AucAdvanced.API.GetMarketValue(link)
  if marketPrice == nil then
    self:Print('No market price available for '..link)
    return 0
  end

  local overMarket
  local sig = AucAdvanced.API.GetSigFromLink(link)
  if AucAdvanced.Settings.GetSetting("util.appraiser.item."..sig..".model") == 'fixed' then
    overMarket = AucAdvanced.Settings.GetSetting("util.appraiser.item."..sig..".fixed.buy")
    self:Print('Use fixed price ('..self:FormatMoney(overMarket)..', {{'..math.floor((overMarket / marketPrice - 1) * 100 + 0.5)..'%}} up) for '..link)
  else
    overMarket = math.max(profile.overMarketStart, marketPrice * (1 + profile.overMarketPercent))
  end
  if undercutStart then overMarket = math.max(overMarket, undercutStart) end
  local settingOverride = {
    ['match.undercut.enable'] = true,
    ['match.undermarket.undermarket'] = -100,
    ['match.undermarket.overmarket'] = (overMarket / marketPrice - 1) * 100,
    ['match.undercut.usevalue'] = true,
    ['match.undercut.value'] = profile.undercutPrice,
  }
  local AucAdvancedGetSettingOrig = AucAdvanced.Settings.GetSetting
  AucAdvanced.Settings.GetSetting = function (setting, default)
    if settingOverride[setting] ~= nil then return settingOverride[setting] end
    return AucAdvancedGetSettingOrig(setting, default)
  end

  local AucAdvancedQueryImageOrig = AucAdvanced.API.QueryImage
  AucAdvanced.API.QueryImage = function (query, faction, realm, ...)
    query.maxStack = 1
    query.filter = function (data)
      return data[AucAdvanced.Const.TLEFT] <= profile.timeLeftThreshold
    end
    return AucAdvancedQueryImageOrig(query, faction, realm, ...)
  end

  local matchArray = AucAdvanced.Modules.Match.Undercut.GetMatchArray(link, marketPrice)

  AucAdvanced.Settings.GetSetting = AucAdvancedGetSettingOrig
  AucAdvanced.API.QueryImage = AucAdvancedQueryImageOrig

  local cost = self.cost[Enchantrix.Util.GetItemIdFromLink(link)]
  if cost == nil then
    self:Print('No cost record for '..link..'. Please run PICK first!')
    return 0
  end

  local price = matchArray.value
  local profit = price * (1 - AucAdvanced.cutRate) - cost

  -- Ignore if profit is low
  -- In normal mode, also ignore if price under market
  if profit < profile.lowestProfit or (not profile.crazy and matchArray.diff < 0) then price = 0 end

  return price, profit
end
