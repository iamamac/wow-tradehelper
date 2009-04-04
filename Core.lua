TradeHelper = LibStub("AceAddon-3.0"):NewAddon("TradeHelper", "AceConsole-3.0")

local abacus = LibStub("LibAbacus-3.0")

local profileDB
local defaults = {
  profile = {
    inkPrice = {},
    inkReagent = {},
    marketPercent = 1,
    lowestProfit = 0,
    batchSize = 2,
  },
}

local options = {
  type = "group",
  args = {
    general = {
      type = "group",
      name = "General",
      cmdInline = true,
      args = {},
    },
    glyph = {
      type = "group",
      name = "Glyph Business",
      args = {
        profit = {
          type = "input",
          name = "Lowest Profit",
          desc = "Glyphs under this profit will not be picked out",
          order = 0,
          pattern = "^%d+$",
          get = function(info) return tostring(profileDB.lowestProfit) end,
          set = function(info, value) profileDB.lowestProfit = tonumber(value) end,
        },
        batch = {
          type = "input",
          name = "Batch Size",
          desc = "Glyphs with enough stock will not be picked out",
          order = 1,
          pattern = "^%d+$",
          get = function(info) return tostring(profileDB.batchSize) end,
          set = function(info, value) profileDB.batchSize = tonumber(value) end,
        },
        pick = {
          type = "execute",
          name = "Pick",
          desc = "Pick glyphs which have the most profit",
          order = 2,
          func = function(info) TradeHelper:PickGlyph(profileDB.lowestProfit, profileDB.batchSize) end,
        },
        reagent = {
          type = "group",
          name = "Reagent Price",
          order = 3,
          inline = true,
          args = {
            separator = {
              type = "description",
              name = "",
              order = -4,
              cmdHidden = true,
            },
            percent = {
              type = "range",
              name = "Market Percent",
              desc = "The percent of market price to purchase reagents",
              order = -3,
              min = 0,
              max = 1,
              step = 0.01,
              isPercent = true,
              get = function(info) return profileDB.marketPercent end,
              set = function(info, value) profileDB.marketPercent = value end,
            },
            reset = {
              type = "execute",
              name = "Reset",
              desc = "Reset reagent prices according to herb market price",
              order = -2,
              func = function(info) TradeHelper:GetInkInfo(profileDB.marketPercent) end,
            },
            snatch = {
              type = "execute",
              name = "Build Snatch List",
              desc = "Build reagent snatch list for Auctioneer Advanced - Search UI",
              order = -1,
              func = function(info) TradeHelper:BuildReagentSnatchList(profileDB.marketPercent) end,
            },
          },
        },
      },
    },
  },
}

function TradeHelper:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("TradeHelperDB", defaults)
  profileDB = self.db.profile
  if #profileDB.inkPrice == 0 then self:GetInkInfo(profileDB.marketPercent) end
  self:SetupOptions()
end

function TradeHelper:FormatMoney(value)
  return abacus:FormatMoneyFull(value, true)
end

function TradeHelper:SetupOptions()
  local inkPrice = profileDB.inkPrice
  for id, price in pairs(inkPrice) do
    local _, link = GetItemInfo(id)
    options.args.glyph.args.reagent.args[link] = {
      type = "input",
      name = link,
      cmdHidden = true,
      pattern = "^%d+$",
      get = function(info) return tostring(inkPrice[id]) end,
      set = function(info, value) inkPrice[id] = tonumber(value) end,
    }
  end
  
  LibStub("AceConfig-3.0"):RegisterOptionsTable(self.name, options, {"th"})
  local aceConfigDialog = LibStub("AceConfigDialog-3.0")
  aceConfigDialog:AddToBlizOptions(self.name, nil, nil, "general")
  aceConfigDialog:AddToBlizOptions(self.name, "Glyph", self.name, "glyph")
end
