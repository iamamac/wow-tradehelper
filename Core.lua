TradeHelper = LibStub("AceAddon-3.0"):NewAddon("TradeHelper", "AceConsole-3.0")

local abacus = LibStub("LibAbacus-3.0")

function TradeHelper:OnInitialize()
end

function TradeHelper:FormatMoney(value)
  return abacus:FormatMoneyFull(value, true)
end
