TradeHelper = LibStub("AceAddon-3.0"):NewAddon("TradeHelper", "AceConsole-3.0")

local abacus = LibStub("LibAbacus-3.0")

local glyphDB, enchantDB
local defaults = {
  profile = {
    glyph = {
      inkPrice = {},
      inkReagent = {},
      cost = {},
      marketPercent = 1.0,
      lowestProfit = 0,
      sortPerInk = true,
      crazy = false,
      undercutPrice = 100,
      overMarketStart = 0,
      overMarketPercent = 1.0,
      timeLeftThreshold = 1,
      risePercent = 0.5,
      bidMarkDown = 0.1,
      batchSize = 2,
      postDuration = 1440,
    },
    enchant = {
      vellumPrice = {},
      cost = {},
      marketPercent = 1.0,
      lowestProfit = 0,
      crazy = false,
      undercutPrice = 100,
      overMarketStart = 0,
      overMarketPercent = 1.0,
      timeLeftThreshold = 1,
      risePercent = 0.05,
      bidMarkDown = 0.1,
      batchSize = 2,
      postDuration = 2880,
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
          order = 10,
          cmdHidden = true,
        },
        pick = {
          type = "execute",
          name = "Pick",
          desc = "Pick out the most profitable glyphs",
          order = 11,
          func = function(info) TradeHelper:PickGlyph() end,
        },
        profit = {
          type = "input",
          name = "Lowest Profit",
          desc = "Glyphs under this profit will not be picked out",
          order = 12,
          width = "half",
          cmdHidden = true,
          pattern = "^%d+$",
          get = function(info) return tostring(glyphDB.lowestProfit) end,
          set = function(info, value) glyphDB.lowestProfit = tonumber(value) end,
        },
        per = {
          type = "toggle",
          name = "Per Ink",
          desc = "Sort the result list by profit per ink",
          order = 13,
          cmdHidden = true,
          get = function(info) return glyphDB.sortPerInk end,
          set = function(info, value) glyphDB.sortPerInk = value end,
        },
        desc3 = {
          type = "description",
          name = "Redistribute Auctions",
          order = 20,
          cmdHidden = true,
        },
        crazy = {
          type = "toggle",
          name = "Crazy mode",
          desc = "Undercut no matter whether above market. May destroy the market. USE WITH CAUTION!",
          order = 21,
          cmdHidden = true,
          get = function(info) return glyphDB.crazy end,
          set = function(info, value) glyphDB.crazy = value end,
        },
        undercut = {
          type = "input",
          name = "Undercut",
          desc = "How much to undercut",
          order = 22,
          width = "half",
          cmdHidden = true,
          pattern = "^%d+$",
          get = function(info) return tostring(glyphDB.undercutPrice) end,
          set = function(info, value) glyphDB.undercutPrice = tonumber(value) end,
        },
        omstart = {
          type = "input",
          name = "OMStart",
          desc = "Use the following value to start undercutting if no fixed price: max[OMStart, market_price * (1 + OMPercent)]",
          order = 23,
          width = "half",
          cmdHidden = true,
          pattern = "^%d+$",
          get = function(info) return tostring(glyphDB.overMarketStart) end,
          set = function(info, value) glyphDB.overMarketStart = tonumber(value) end,
        },
        ompercent = {
          type = "range",
          name = "OMPercent",
          desc = "Use the following value to start undercutting if no fixed price: max[OMStart, market_price * (1 + OMPercent)]",
          order = 24,
          width = "half",
          cmdHidden = true,
          min = 0,
          max = 3,
          step = 0.1,
          isPercent = true,
          get = function(info) return glyphDB.overMarketPercent end,
          set = function(info, value) glyphDB.overMarketPercent = value end,
        },
        desc4 = {
          type = "description",
          name = "",
          order = 30,
          cmdHidden = true,
        },
        cancel = {
          type = "execute",
          name = "Auto Cancel",
          desc = "Cancel your auctions to adjust their price",
          order = 31,
          func = function(info) TradeHelper:CancelUndercuttedAuction(TradeHelper.glyphPattern, glyphDB) end,
        },
        timeleft = {
          type = "select",
          name = "Time Left",
          desc = "Auctions have shorter time will be canceled(own) or ignored(competitor's)",
          order = 32,
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
          order = 33,
          width = "half",
          cmdHidden = true,
          min = 0,
          max = 1,
          step = 0.01,
          isPercent = true,
          get = function(info) return glyphDB.risePercent end,
          set = function(info, value) glyphDB.risePercent = value end,
        },
        desc5 = {
          type = "description",
          name = "",
          order = 40,
          cmdHidden = true,
        },
        post = {
          type = "execute",
          name = "Auto Post",
          desc = "Post glyphs which there is no competition",
          order = 41,
          func = function(info) TradeHelper:PostNoCompeteAuctions(TradeHelper.glyphPattern, glyphDB) end,
        },
        bid = {
          type = "range",
          name = "Bid Down",
          desc = "How many percent the bid price is below the buyout price",
          order = 42,
          width = "half",
          cmdHidden = true,
          min = 0,
          max = 1,
          step = 0.01,
          isPercent = true,
          get = function(info) return glyphDB.bidMarkDown end,
          set = function(info, value) glyphDB.bidMarkDown = value end,
        },
        batch = {
          type = "range",
          name = "Batch Size",
          desc = "The number of glyphs to post",
          order = 43,
          width = "half",
          cmdHidden = true,
          min = 1,
          max = 5,
          step = 1,
          get = function(info) return glyphDB.batchSize end,
          set = function(info, value) glyphDB.batchSize = value end,
        },
        duration = {
          type = "select",
          name = "Duration",
          desc = "Post duration",
          order = 44,
          width = "half",
          cmdHidden = true,
          values = {
            [720] = "12 h",
            [1440] = "24 h",
            [2880] = "48 h",
          },
          get = function(info) return glyphDB.postDuration end,
          set = function(info, value) glyphDB.postDuration = value end,
        },
        reagent = {
          type = "group",
          name = "Reagent Price",
          order = 50,
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
        desc1 = {
          type = "description",
          name = "Update Auction Image",
          order = 0,
          cmdHidden = true,
        },
        upd_scroll = {
          type = "execute",
          name = "Scroll",
          desc = "Update enchanting scrolls' auction data image",
          order = 1,
          func = function(info) TradeHelper:UpdateAuctionEnchantingScroll() end,
        },
        desc2 = {
          type = "description",
          name = "Make Profitable Enchanting Scrolls",
          order = 10,
          cmdHidden = true,
        },
        pick = {
          type = "execute",
          name = "Pick",
          desc = "Pick out the most profitable enchanting scrolls",
          order = 11,
          func = function(info) TradeHelper:PickScroll() end,
        },
        profit = {
          type = "input",
          name = "Lowest Profit",
          desc = "Enchanting scrolls under this profit will not be picked out",
          order = 12,
          width = "half",
          cmdHidden = true,
          pattern = "^%d+$",
          get = function(info) return tostring(enchantDB.lowestProfit) end,
          set = function(info, value) enchantDB.lowestProfit = tonumber(value) end,
        },
        desc3 = {
          type = "description",
          name = "Redistribute Auctions",
          order = 20,
          cmdHidden = true,
        },
        crazy = {
          type = "toggle",
          name = "Crazy mode",
          desc = "Undercut no matter whether above market. May destroy the market. USE WITH CAUTION!",
          order = 21,
          cmdHidden = true,
          get = function(info) return enchantDB.crazy end,
          set = function(info, value) enchantDB.crazy = value end,
        },
        undercut = {
          type = "input",
          name = "Undercut",
          desc = "How much to undercut",
          order = 22,
          width = "half",
          cmdHidden = true,
          pattern = "^%d+$",
          get = function(info) return tostring(enchantDB.undercutPrice) end,
          set = function(info, value) enchantDB.undercutPrice = tonumber(value) end,
        },
        omstart = {
          type = "input",
          name = "OMStart",
          desc = "Use the following value to start undercutting if no fixed price: max[OMStart, market_price * (1 + OMPercent)]",
          order = 23,
          width = "half",
          cmdHidden = true,
          pattern = "^%d+$",
          get = function(info) return tostring(enchantDB.overMarketStart) end,
          set = function(info, value) enchantDB.overMarketStart = tonumber(value) end,
        },
        ompercent = {
          type = "range",
          name = "OMPercent",
          desc = "Use the following value to start undercutting if no fixed price: max[OMStart, market_price * (1 + OMPercent)]",
          order = 24,
          width = "half",
          cmdHidden = true,
          min = 0,
          max = 3,
          step = 0.1,
          isPercent = true,
          get = function(info) return enchantDB.overMarketPercent end,
          set = function(info, value) enchantDB.overMarketPercent = value end,
        },
        desc4 = {
          type = "description",
          name = "",
          order = 30,
          cmdHidden = true,
        },
        cancel = {
          type = "execute",
          name = "Auto Cancel",
          desc = "Cancel your auctions to adjust their price",
          order = 31,
          func = function(info) TradeHelper:CancelUndercuttedAuction(TradeHelper.scrollPattern, enchantDB) end,
        },
        timeleft = {
          type = "select",
          name = "Time Left",
          desc = "Auctions have shorter time will be canceled(own) or ignored(competitor's)",
          order = 32,
          width = "half",
          cmdHidden = true,
          values = {
            [0] = "-",
            [1] = "30 m",
            [2] = "2 h",
          },
          get = function(info) return enchantDB.timeLeftThreshold end,
          set = function(info, value) enchantDB.timeLeftThreshold = value end,
        },
        rise = {
          type = "range",
          name = "Rise Percent",
          desc = "Cancel an auction if it can rise up much",
          order = 33,
          width = "half",
          cmdHidden = true,
          min = 0,
          max = 1,
          step = 0.01,
          isPercent = true,
          get = function(info) return enchantDB.risePercent end,
          set = function(info, value) enchantDB.risePercent = value end,
        },
        desc5 = {
          type = "description",
          name = "",
          order = 40,
          cmdHidden = true,
        },
        post = {
          type = "execute",
          name = "Auto Post",
          desc = "Post enchanting scrolls which there is no competition",
          order = 41,
          func = function(info) TradeHelper:PostNoCompeteAuctions(TradeHelper.scrollPattern, enchantDB) end,
        },
        bid = {
          type = "range",
          name = "Bid Down",
          desc = "How many percent the bid price is below the buyout price",
          order = 42,
          width = "half",
          cmdHidden = true,
          min = 0,
          max = 1,
          step = 0.01,
          isPercent = true,
          get = function(info) return enchantDB.bidMarkDown end,
          set = function(info, value) enchantDB.bidMarkDown = value end,
        },
        batch = {
          type = "range",
          name = "Batch Size",
          desc = "The number of enchanting scrolls to post",
          order = 43,
          width = "half",
          cmdHidden = true,
          min = 1,
          max = 5,
          step = 1,
          get = function(info) return enchantDB.batchSize end,
          set = function(info, value) enchantDB.batchSize = value end,
        },
        duration = {
          type = "select",
          name = "Duration",
          desc = "Post duration",
          order = 44,
          width = "half",
          cmdHidden = true,
          values = {
            [720] = "12 h",
            [1440] = "24 h",
            [2880] = "48 h",
          },
          get = function(info) return enchantDB.postDuration end,
          set = function(info, value) enchantDB.postDuration = value end,
        },
        reagent = {
          type = "group",
          name = "Reagent Price",
          order = 50,
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

function TradeHelper:Print(...)
  AucAdvanced.Print(...)
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
  local marketPrice = AucAdvanced.API.GetMarketValue(link)
  if marketPrice == nil then
    self:Print('No market price available for '..link)
    return 0
  end
  
  local overMarket
  local sig = AucAdvanced.API.GetSigFromLink(link)
  if AucAdvanced.Settings.GetSetting("util.appraiser.item."..sig..".model") == 'fixed' then
    overMarket = AucAdvanced.Settings.GetSetting("util.appraiser.item."..sig..".fixed.buy")
    self:Print('Use fixed price ('..self:FormatMoney(overMarket)..') for '..link)
  else
    overMarket = math.max(profile.overMarketStart, marketPrice * (1 + profile.overMarketPercent))
  end
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
  
  cost = profile.cost[Enchantrix.Util.GetItemIdFromLink(link)]
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
