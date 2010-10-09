local EnchantHelper = TradeHelper:NewModule("EnchantHelper")

local vellumUsage = {
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

local defaults = {
  profile = {
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
  factionrealm = {
    vellumPrice = {},
  },
}

EnchantHelper.scrollPattern = '^Scroll of Enchant '

function EnchantHelper:SetupOptions()
  local profile = self.db.profile
  local options = {
    type = "group",
    name = "Enchanting Business",
    args = {
      desc1 = {
        type = "description",
        name = "Scan Auction",
        order = 0,
        cmdHidden = true,
      },
      scan_scroll = {
        type = "execute",
        name = "Scroll",
        desc = "Update enchanting scrolls' auction data image",
        order = 1,
        func = function(info) EnchantHelper:ScanScrollInAuction() end,
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
        func = function(info) EnchantHelper:PickScroll() end,
      },
      profit = {
        type = "input",
        name = "Lowest Profit",
        desc = "Enchanting scrolls under this profit will not be picked out",
        order = 12,
        width = "half",
        cmdHidden = true,
        pattern = "^%d+$",
        get = function(info) return tostring(profile.lowestProfit) end,
        set = function(info, value) profile.lowestProfit = tonumber(value) end,
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
        get = function(info) return profile.crazy end,
        set = function(info, value) profile.crazy = value end,
      },
      undercut = {
        type = "input",
        name = "Undercut",
        desc = "How much to undercut",
        order = 22,
        width = "half",
        cmdHidden = true,
        pattern = "^%d+$",
        get = function(info) return tostring(profile.undercutPrice) end,
        set = function(info, value) profile.undercutPrice = tonumber(value) end,
      },
      omstart = {
        type = "input",
        name = "OMStart",
        desc = "Use the following value to start undercutting if no fixed price: max[OMStart, market_price * (1 + OMPercent)]",
        order = 23,
        width = "half",
        cmdHidden = true,
        pattern = "^%d+$",
        get = function(info) return tostring(profile.overMarketStart) end,
        set = function(info, value) profile.overMarketStart = tonumber(value) end,
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
        get = function(info) return profile.overMarketPercent end,
        set = function(info, value) profile.overMarketPercent = value end,
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
        func = function(info) TradeHelper:CancelUndercuttedAuction(EnchantHelper.scrollPattern, profile) end,
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
        get = function(info) return profile.timeLeftThreshold end,
        set = function(info, value) profile.timeLeftThreshold = value end,
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
        get = function(info) return profile.risePercent end,
        set = function(info, value) profile.risePercent = value end,
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
        func = function(info) TradeHelper:PostNoCompeteAuctions(EnchantHelper.scrollPattern, profile) end,
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
        get = function(info) return profile.bidMarkDown end,
        set = function(info, value) profile.bidMarkDown = value end,
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
        get = function(info) return profile.batchSize end,
        set = function(info, value) profile.batchSize = value end,
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
        get = function(info) return profile.postDuration end,
        set = function(info, value) profile.postDuration = value end,
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
            get = function(info) return profile.marketPercent end,
            set = function(info, value) profile.marketPercent = value end,
          },
          reset = {
            type = "execute",
            name = "Reset",
            desc = "Reset reagent prices according to the lower between market price and self-made price",
            order = -1,
            func = function(info) EnchantHelper:GetVellumPrice(profile.marketPercent); EnchantHelper:SetupOptions() end,
          },
        },
      },
    },
  }

  local vellumPrice = self.db.factionrealm.vellumPrice
  for id in pairs(vellumPrice) do
    local _, link = GetItemInfo(id)
    options.args.reagent.args[tostring(id)] = {
      type = "input",
      name = link,
      cmdHidden = true,
      pattern = "^%d+$",
      get = function(info) return tostring(vellumPrice[id]) end,
      set = function(info, value) vellumPrice[id] = tonumber(value); wipe(TradeHelper.cost) end,
    }
  end

  TradeHelper.options.plugins[self:GetName()] = {
    enchant = options,
  }
end

function EnchantHelper:OnInitialize()
  self.db = TradeHelper.db:RegisterNamespace(self:GetName(), defaults)
  self:SetupOptions()
end

function EnchantHelper:PickScroll()
  -- Open the trade skill window
  CastSpellByName("Enchanting")

  local profile = self.db.profile
  local vellumPrice = self.db.factionrealm.vellumPrice
  local subClass
  local profitTable = {}
  for recipeIndex=1, GetNumTradeSkills() do
    local name, type = GetTradeSkillInfo(recipeIndex)
    if type == "header" then
      subClass = name
    -- Filter out uninterested recipes
    elseif subClass == "Enchant" then
      local enchantType = slotType[EnchantrixBarker_GetItemCategoryKey(recipeIndex)]
      local scrollName = "Scroll of "..name
      local scroll = Enchantrix.Util.GetLinkFromName(scrollName)
      if enchantType and scroll then
        -- Always update cost information
        if true then
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
            local scrollId = Enchantrix.Util.GetItemIdFromLink(scroll)
            TradeHelper.cost[scrollId] = cost
          end
        end

        local scrollPrice, profit = TradeHelper:GetPrice(scroll, profile)
        if scrollPrice > 0 then
          local num = profile.batchSize - TradeHelper:ItemCountInStock(scroll)
          if num > 0 then
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
    msg = msg.."\n"..v.Scroll..": "..TradeHelper:FormatMoney(v.Profit).." x "..v.Number
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
  TradeHelper:Print(msg)
end

function EnchantHelper:GetVellumPrice(marketPercent)
  self.db.factionrealm.vellumPrice = TradeHelper:GetModule("ScribeHelper"):GetSelfMadeVellumPrice()

  local vellumPrice = self.db.factionrealm.vellumPrice
  for _, id in pairs(vellumUsage) do
    local _, link = GetItemInfo(id)
    local price = AucAdvanced.API.GetMarketValue(link)
    if price then
      price = floor(price * marketPercent)
      if vellumPrice[id] == nil or price < vellumPrice[id] then vellumPrice[id] = price end
    end
  end
end

function EnchantHelper:ScanScrollInAuction()
  AucAdvanced.Scan.PushScan()
  -- Scroll (under Consumable - Item Enhancement)
  AucAdvanced.Scan.StartScan(nil, nil, nil, nil, 4, 6, nil, 1)
end
