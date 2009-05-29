TradeHelper = LibStub("AceAddon-3.0"):NewAddon("TradeHelper", "AceConsole-3.0")

local abacus = LibStub("LibAbacus-3.0")

local glyphDB, enchantDB
local defaults = {
  profile = {
    glyph = {
      inkPrice = {},
      inkReagent = {},
      marketPercent = 1,
      lowestProfit = 0,
      batchSize = 2,
      timeLeftThreshold = 1,
      risePercent = 0.5,
      cost = {},
      crazy = false,
      overMarketPrice = 500000,
      undercutPrice = 100,
      bidMarkDown = 0.1,
      postDuration = 1440,
    },
    enchant = {
      vellumPrice = {},
      marketPercent = 1,
      lowestProfit = 0,
      batchSize = 2,
      cost = {},
      crazy = false,
      overMarketPrice = 0,
      undercutPrice = 100,
    },
  },
}

local options = {
  type = "group",
  childGroups = "tab",
  args = {
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
        upd_glyph = {
          type = "execute",
          name = "Glyph",
          desc = "Update glyphs' auction data image",
          order = 1,
          width = "half",
          func = function(info) TradeHelper:UpdateAuctionInscriptionGlyph() end,
        },
        upd_reagent = {
          type = "execute",
          name = "Reagent",
          desc = "Update glyph-related reagents' auction data image",
          order = 2,
          width = "half",
          func = function(info) TradeHelper:UpdateAuctionInscriptionReagent() end,
        },
        desc2 = {
          type = "description",
          name = "Make Profitable Glyphs",
          order = 3,
          cmdHidden = true,
        },
        profit = {
          type = "input",
          name = "Lowest Profit",
          desc = "Glyphs under this profit will not be picked out",
          order = 4,
          width = "half",
          cmdHidden = true,
          pattern = "^%d+$",
          get = function(info) return tostring(glyphDB.lowestProfit) end,
          set = function(info, value) glyphDB.lowestProfit = tonumber(value) end,
        },
        batch = {
          type = "input",
          name = "Batch Size",
          desc = "Glyphs with enough stock will not be picked out",
          order = 5,
          width = "half",
          cmdHidden = true,
          pattern = "^%d+$",
          get = function(info) return tostring(glyphDB.batchSize) end,
          set = function(info, value) glyphDB.batchSize = tonumber(value) end,
        },
        pick = {
          type = "execute",
          name = "Pick",
          desc = "Pick out the most profitable glyphs",
          order = 6,
          width = "half",
          func = function(info) TradeHelper:PickGlyph(glyphDB.lowestProfit, glyphDB.batchSize) end,
        },
        desc3 = {
          type = "description",
          name = "Redistribute Auctions",
          order = 7,
          cmdHidden = true,
        },
        time = {
          type = "select",
          name = "Time Left",
          desc = "Auctions have shorter time will be canceled(own) or ignored(competitor's)",
          order = 8,
          width = "half",
          cmdHidden = true,
          values = {
            [0] = "-",
            [1] = "30 m",
            [2] = "2 h",
          },
          get = function(info) return glyphDB.timeLeftThreshold end,
          set = function(info, value) glyphDB.timeLeftThreshold = value end,
        },
        rise = {
          type = "range",
          name = "Rise Percent",
          desc = "Cancel an auction if it can rise up much",
          order = 9,
          width = "half",
          cmdHidden = true,
          min = 0,
          max = 1,
          step = 0.01,
          isPercent = true,
          get = function(info) return glyphDB.risePercent end,
          set = function(info, value) glyphDB.risePercent = value end,
        },
        cancel = {
          type = "execute",
          name = "Cancel",
          desc = "Cancel your auctions to adjust their price",
          order = 10,
          width = "half",
          func = function(info) TradeHelper:CancelUndercuttedAuction(TradeHelper.glyphPattern, glyphDB) end,
        },
        post = {
          type = "execute",
          name = "Post",
          desc = "Post glyphs which there is no competition",
          order = 11,
          width = "half",
          func = function(info) TradeHelper:PostNoCompeteAuctions(TradeHelper.glyphPattern, glyphDB) end,
        },
        reagent = {
          type = "group",
          name = "Reagent Price",
          order = 12,
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
              cmdHidden = true,
              min = 0,
              max = 1,
              step = 0.01,
              isPercent = true,
              get = function(info) return glyphDB.marketPercent end,
              set = function(info, value) glyphDB.marketPercent = value end,
            },
            reset = {
              type = "execute",
              name = "Reset",
              desc = "Reset reagent prices according to herb market price",
              order = -2,
              func = function(info) TradeHelper:GetInkInfo(glyphDB.marketPercent); TradeHelper:SetupOptions() end,
            },
            snatch = {
              type = "execute",
              name = "Build Snatch List",
              desc = "Build reagent snatch list for Auctioneer Advanced - Search UI",
              order = -1,
              func = function(info) TradeHelper:BuildGlyphSnatchList() end,
            },
          },
        },
      },
    },
    enchant = {
      type = "group",
      name = "Enchanting Business",
      args = {
        desc = {
          type = "description",
          name = "Make Profitable Enchanting Scrolls",
          order = 0,
          cmdHidden = true,
        },
        profit = {
          type = "input",
          name = "Lowest Profit",
          desc = "Scrolls under this profit will not be picked out",
          order = 1,
          width = "half",
          cmdHidden = true,
          pattern = "^%d+$",
          get = function(info) return tostring(enchantDB.lowestProfit) end,
          set = function(info, value) enchantDB.lowestProfit = tonumber(value) end,
        },
        batch = {
          type = "input",
          name = "Batch Size",
          desc = "Scrolls with enough stock will not be picked out",
          order = 2,
          width = "half",
          cmdHidden = true,
          pattern = "^%d+$",
          get = function(info) return tostring(enchantDB.batchSize) end,
          set = function(info, value) enchantDB.batchSize = tonumber(value) end,
        },
        pick = {
          type = "execute",
          name = "Pick",
          desc = "Pick out the most profitable scrolls",
          order = 3,
          width = "half",
          func = function(info) TradeHelper:PickScroll(enchantDB.lowestProfit, enchantDB.batchSize) end,
        },
        reagent = {
          type = "group",
          name = "Reagent Price",
          order = 4,
          inline = true,
          args = {
            separator = {
              type = "description",
              name = "",
              order = -3,
              cmdHidden = true,
            },
            market = {
              type = "range",
              name = "Market Percent",
              desc = "The percent of market price to purchase reagents",
              order = -2,
              cmdHidden = true,
              min = 0,
              max = 1,
              step = 0.01,
              isPercent = true,
              get = function(info) return enchantDB.marketPercent end,
              set = function(info, value) enchantDB.marketPercent = value end,
            },
            reset = {
              type = "execute",
              name = "Reset",
              desc = "Reset reagent prices according to the lower between market price and self-made price",
              order = -1,
              func = function(info) TradeHelper:GetVellumPrice(enchantDB.marketPercent); TradeHelper:SetupOptions() end,
            },
          },
        },
      },
    },
  },
}

function TradeHelper:OnInitialize()
  self.db = LibStub("AceDB-3.0"):New("TradeHelperDB", defaults, "Default")
  glyphDB = self.db.profile.glyph
  enchantDB = self.db.profile.enchant
  self:SetupOptions(true)
end

function TradeHelper:FormatMoney(value)
  return abacus:FormatMoneyFull(value, true)
end

function TradeHelper:SetupOptions(init)
  local inkPrice = glyphDB.inkPrice
  for id in pairs(inkPrice) do
    local _, link = GetItemInfo(id)
    options.args.glyph.args.reagent.args[tostring(id)] = {
      type = "input",
      name = link,
      cmdHidden = true,
      pattern = "^%d+$",
      get = function(info) return tostring(inkPrice[id]) end,
      set = function(info, value) inkPrice[id] = tonumber(value); wipe(glyphDB.cost) end,
    }
  end

  local vellumPrice = enchantDB.vellumPrice
  for id in pairs(vellumPrice) do
    local _, link = GetItemInfo(id)
    options.args.enchant.args.reagent.args[tostring(id)] = {
      type = "input",
      name = link,
      cmdHidden = true,
      pattern = "^%d+$",
      get = function(info) return tostring(vellumPrice[id]) end,
      set = function(info, value) vellumPrice[id] = tonumber(value); wipe(enchantDB.cost) end,
    }
  end
  
  if init then
    LibStub("AceConfig-3.0"):RegisterOptionsTable(self.name, options, {"th"})
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(self.name, self.name)
  else
    LibStub("AceConfigRegistry-3.0"):NotifyChange(self.name)
  end
end

function TradeHelper:ItemCountInStock(name)
  -- Inventory (including bank)
  local count = GetItemCount(name, true)
  
  -- Auction
  local own = AucAdvanced.Modules.Util.Appraiser.ownResults
  if own and own[name] then
    for _, res in pairs(own[name]) do
      count = count + res.countBid
    end
  end
  
  return count
end

function TradeHelper:GetPrice(link, profile)
  local buyPrice = AucAdvanced.API.GetMarketValue(link)
  if buyPrice == nil then
    self:Print(ChatFrame2, 'No market price available for '..link)
    return 0
  end
  
  local settingOverride = {
    ['match.undercut.enable'] = true,
    ['match.undermarket.undermarket'] = -100,
    ['match.undermarket.overmarket'] = math.max(1, profile.overMarketPrice / buyPrice - 1) * 100,
    ['match.undercut.usevalue'] = true,
    ['match.undercut.value'] = profile.undercutPrice,
  }
  local AucAdvancedGetSettingOrig = AucAdvanced.Settings.GetSetting
  AucAdvanced.Settings.GetSetting = function (setting, default)
    if settingOverride[setting] ~= nil then return settingOverride[setting] end
    return AucAdvancedGetSettingOrig(setting, default)
  end
  local matchArray = AucAdvanced.Modules.Match.Undercut.GetMatchArray(link, buyPrice)
  AucAdvanced.Settings.GetSetting = AucAdvancedGetSettingOrig
  
  cost = profile.cost[Enchantrix.Util.GetItemIdFromLink(link)]
  if cost == nil then
    self:Print(ChatFrame2, 'No cost record for '..link..'. Please run PICK first!')
    return 0
  end
  
  local price = matchArray.value
  local profit = price * (1 - AucAdvanced.cutRate) - cost
  
  -- Ignore if profit is low
  -- In normal mode, also ignore if price under market
  if profit < profile.lowestProfit or (not profile.crazy and matchArray.diff < 0) then price = 0 end
  
  return price, profit
end
