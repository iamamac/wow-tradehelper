TradeHelper = LibStub("AceAddon-3.0"):NewAddon("TradeHelper", "AceConsole-3.0")

local abacus = LibStub("LibAbacus-3.0")

local defaults = {}
defaults.profile = {
  inkPrice = {},
}

function TradeHelper:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("TradeHelperDB", defaults)
end

function TradeHelper:FormatMoney(value)
  return abacus:FormatMoneyFull(value, true)
end
