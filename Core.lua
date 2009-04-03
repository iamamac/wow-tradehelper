TradeHelper = LibStub("AceAddon-3.0"):NewAddon("TradeHelper", "AceConsole-3.0")

local abacus = LibStub("LibAbacus-3.0")

local defaults = {
  profile = {
    inkPrice = {},
  },
}

local options = {
  type = "group",
  args = {
    general = {
      type = "group",
      name = "General",
      args = {},
    },
    glyph = {
      type = "group",
      name = "Glyph Business",
      args = {},
    },
  },
}

function TradeHelper:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("TradeHelperDB", defaults)
  self:SetupOptions()
end

function TradeHelper:FormatMoney(value)
  return abacus:FormatMoneyFull(value, true)
end

function TradeHelper:SetupOptions()
  local inkPrice = self.db.profile.inkPrice
  for id, price in pairs(inkPrice) do
    local _, link = GetItemInfo(id)
    options.args.glyph.args[link] = {
      type = "input",
      name = link,
      get = function(info) return tostring(inkPrice[id]) end,
      set = function(info, value) inkPrice[id] = tonumber(value) end,
    }
  end
  
  LibStub("AceConfig-3.0"):RegisterOptionsTable("TradeHelper", options, {"th"})
  LibStub("AceConfigDialog-3.0"):AddToBlizOptions("TradeHelper", nil, nil, "general")
  LibStub("AceConfigDialog-3.0"):AddToBlizOptions("TradeHelper", "Glyph", "TradeHelper", "glyph")
end
