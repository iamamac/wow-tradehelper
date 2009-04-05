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
    timeLeftThreshold = 1,
    risePercent = 0.5,
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
        desc1 = {
          type = "description",
          name = "Update Auction Image",
          order = 0,
          cmdHidden = true,
        },
        update = {
          type = "execute",
          name = "Update",
          desc = "Update glyph-related items' auction data image",
          order = 1,
          width = "half",
          func = function(info) TradeHelper:UpdateAuctionInscription() end,
        },
        desc2 = {
          type = "description",
          name = "Pick Glyphs to Make",
          order = 2,
          cmdHidden = true,
        },
        profit = {
          type = "input",
          name = "Lowest Profit",
          desc = "Glyphs under this profit will not be picked out",
          order = 3,
          width = "half",
          pattern = "^%d+$",
          get = function(info) return tostring(profileDB.lowestProfit) end,
          set = function(info, value) profileDB.lowestProfit = tonumber(value) end,
        },
        batch = {
          type = "input",
          name = "Batch Size",
          desc = "Glyphs with enough stock will not be picked out",
          order = 4,
          width = "half",
          pattern = "^%d+$",
          get = function(info) return tostring(profileDB.batchSize) end,
          set = function(info, value) profileDB.batchSize = tonumber(value) end,
        },
        pick = {
          type = "execute",
          name = "Pick",
          desc = "Pick glyphs which have the most profit",
          order = 5,
          width = "half",
          func = function(info) TradeHelper:PickGlyph(profileDB.lowestProfit, profileDB.batchSize) end,
        },
        desc3 = {
          type = "description",
          name = "Cancel Undercutted Auctions",
          order = 6,
          cmdHidden = true,
        },
        time = {
          type = "select",
          name = "Time Left",
          desc = "Auctions have shorter time will be canceled(own) or ignored(competitor's)",
          order = 7,
          width = "half",
          values = {
            [0] = "-",
            [1] = "30 m",
            [2] = "2 h",
          },
          get = function(info) return profileDB.timeLeftThreshold end,
          set = function(info, value) profileDB.timeLeftThreshold = value end,
        },
        rise = {
          type = "range",
          name = "Rise Percent",
          desc = "Cancel an auction if it can rise up much",
          order = 8,
          width = "half",
          min = 0,
          max = 1,
          step = 0.01,
          isPercent = true,
          get = function(info) return profileDB.risePercent end,
          set = function(info, value) profileDB.risePercent = value end,
        },
        cancel = {
          type = "execute",
          name = "Cancel",
          desc = "Cancel your auctions to adjust their price",
          order = 9,
          width = "half",
          func = function(info) TradeHelper:CancelUndercuttedAuction("Glyph of", profileDB.timeLeftThreshold, profileDB.risePercent) end,
        },
        reagent = {
          type = "group",
          name = "Reagent Price",
          order = 10,
          inline = true,
          args = {
            separator = {
              type = "description",
              name = "",
              order = -4,
              cmdHidden = true,
            },
            market = {
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
