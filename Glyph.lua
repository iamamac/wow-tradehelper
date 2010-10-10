local ScribeHelper = TradeHelper:NewModule("ScribeHelper")

local parchmentPrice = {
  [39354] = 12,		-- Light Parchment
  [10648] = 100,	-- Common Parchment
  [39501] = 1000,	-- Heavy Parchment
  [39502] = 4000,	-- Resilient Parchment
}

local inkExchange = {
  [43126] = {       -- Ink of the Sea exchange in Dalaran
     [43127] = 10,  -- Snowfall Ink
     [43120] = 1,   -- Celestial Ink
     [43124] = 1,   -- Ethereal Ink
     [37101] = 1,   -- Ivory Ink
     [43118] = 1,   -- Jadefire Ink
     [43116] = 1,   -- Lion's Ink
     [39774] = 1,   -- Midnight Ink
     [39469] = 1,   -- Moonglow Ink
     [43122] = 1,   -- Shimmering Ink
  },
}

local defaults = {
  profile = {
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
  factionrealm = {
    inkPrice = {},
    inkReagent = {},
  },
}

ScribeHelper.glyphPattern = '^Glyph of '

function ScribeHelper:SetupOptions()
  local profile = self.db.profile
  local options = {
    type = "group",
    name = "Inscription Business",
    args = {
      desc1 = {
        type = "description",
        name = "Scan Auction",
        order = 0,
        cmdHidden = true,
      },
      scan_glyph = {
        type = "execute",
        name = "Glyph",
        desc = "Update glyphs' auction data image",
        order = 1,
        width = "half",
        func = function(info) ScribeHelper:ScanGlyphInAuction() end,
      },
      scan_reagent = {
        type = "execute",
        name = "Reagent",
        desc = "Update glyph-related reagents' auction data image",
        order = 2,
        width = "half",
        func = function(info) ScribeHelper:ScanReagentInAuction() end,
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
        func = function(info) ScribeHelper:PickGlyph() end,
      },
      profit = {
        type = "input",
        name = "Lowest Profit",
        desc = "Glyphs under this profit will not be picked out",
        order = 12,
        width = "half",
        cmdHidden = true,
        pattern = "^%d+$",
        get = function(info) return tostring(profile.lowestProfit) end,
        set = function(info, value) profile.lowestProfit = tonumber(value) end,
      },
      per = {
        type = "toggle",
        name = "Per Ink",
        desc = "Sort the result list by profit per ink",
        order = 13,
        cmdHidden = true,
        get = function(info) return profile.sortPerInk end,
        set = function(info, value) profile.sortPerInk = value end,
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
        func = function(info) TradeHelper:CancelUndercuttedAuction(ScribeHelper.glyphPattern, profile) end,
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
        desc = "Post glyphs which there is no competition",
        order = 41,
        func = function(info) TradeHelper:PostNoCompeteAuctions(ScribeHelper.glyphPattern, profile) end,
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
        desc = "The number of glyphs to post",
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
            get = function(info) return profile.marketPercent end,
            set = function(info, value) profile.marketPercent = value end,
          },
          reset = {
            type = "execute",
            name = "Reset",
            desc = "Reset reagent prices according to herb market price",
            order = -2,
            func = function(info) ScribeHelper:GetInkInfo(profile.marketPercent); ScribeHelper:SetupOptions() end,
          },
          snatch = {
            type = "execute",
            name = "Build Snatch List",
            desc = "Build reagent snatch list for Auctioneer Advanced - Search UI",
            order = -1,
            func = function(info) ScribeHelper:BuildSnatchList() end,
          },
        },
      },
    },
  }

  local inkPrice = self.db.factionrealm.inkPrice
  for id in pairs(inkPrice) do
    local _, link = GetItemInfo(id)
    options.args.reagent.args[tostring(id)] = {
      type = "input",
      name = link,
      cmdHidden = true,
      pattern = "^%d+$",
      get = function(info) return tostring(inkPrice[id]) end,
      set = function(info, value) inkPrice[id] = tonumber(value); wipe(TradeHelper.cost) end,
    }
  end

  TradeHelper.options.plugins[self:GetName()] = {
    scribe = options,
  }
end

function ScribeHelper:OnInitialize()
  self.db = TradeHelper.db:RegisterNamespace(self:GetName(), defaults)
  self:SetupOptions()
end

function ScribeHelper:PickGlyph()
  -- Open the trade skill window
  CastSpellByName("Inscription")

  local profile = self.db.profile
  local inkPrice = self.db.factionrealm.inkPrice
  local subClass
  local profitTable = {}
  for recipeIndex=1, GetNumTradeSkills() do
    local name, type = GetTradeSkillInfo(recipeIndex)
    if type == "header" then
      subClass = name
    -- Filter out uninterested recipes
    elseif name:find(self.glyphPattern) then
      local product = GetTradeSkillItemLink(recipeIndex)
      local productId = TradeHelper:GetItemIdFromLink(product)
      local productCount = GetTradeSkillNumMade(recipeIndex)

      if TradeHelper.cost[productId] == nil then
        local cost = 0
        for reagentIndex = 1, GetTradeSkillNumReagents(recipeIndex) do
          local _, _, reagentCount = GetTradeSkillReagentInfo(recipeIndex, reagentIndex)
          local reagentId = TradeHelper:GetItemIdFromLink(GetTradeSkillReagentItemLink(recipeIndex, reagentIndex))
          local price = inkPrice[reagentId] or parchmentPrice[reagentId]
          if price == nil then cost = nil; break end
          cost = cost + price * reagentCount
        end
        if cost then
          cost = math.ceil(cost / productCount)
          TradeHelper.cost[productId] = cost
        end
      end

      local productPrice, profit = TradeHelper:GetPrice(product, profile)
      if productPrice > 0 then
        local num = profile.batchSize - TradeHelper:ItemCountInStock(product)
        if num > 0 then
          local reagentId, count
          for reagentIndex=1, GetTradeSkillNumReagents(recipeIndex) do
            local reagent = GetTradeSkillReagentItemLink(recipeIndex, reagentIndex)
            reagentId = TradeHelper:GetItemIdFromLink(reagent)
            if inkPrice[reagentId] then
              _, _, count = GetTradeSkillReagentInfo(recipeIndex, reagentIndex)
              break
            end
          end
          tinsert(profitTable, {
            Product = product,
            Profit = profit,
            Number = num,
            InkId = reagentId,
            InkNeed = count,
          })
        end
      end
    end
  end

  sort(profitTable, function (a,b)
    if profile.sortPerInk then
      return a.Profit / a.InkNeed > b.Profit / b.InkNeed
    else
      return a.Profit > b.Profit
    end
  end)

  local inkNeed = {}
  local inkInStock = {}
  local msg = ""
  for _, v in ipairs(profitTable) do
    inkNameShort = GetItemInfo(v.InkId):sub(1,1)
    msg = msg.."\n"..v.Product.." "..v.InkNeed..inkNameShort..": "..TradeHelper:FormatMoney(v.Profit).." x "..v.Number
    inkNeed[v.InkId] = (inkNeed[v.InkId] or 0) + v.InkNeed * v.Number
    if inkInStock[v.InkId] == nil then inkInStock[v.InkId] = GetItemCount(v.InkId, true) end
    local canMake = floor(inkInStock[v.InkId] / v.InkNeed)
    if canMake < v.Number then msg = msg.." ("..canMake..")" end
  end
  msg = msg.."\nMissing reagents:"
  local inkReagent = self.db.factionrealm.inkReagent
  for toId, _ in pairs(inkNeed) do
    local fromId = inkReagent[toId].exchange
    if fromId ~= nil then
      inkNeed[fromId] = (inkNeed[fromId] or 0) + inkNeed[toId] * inkExchange[fromId][toId]
      inkNeed[toId] = 0
    end
  end
  for inkId, inkCount in pairs(inkNeed) do
    local inkShort = inkCount - inkInStock[inkId]
    if inkShort > 0 then
      local _, ink = GetItemInfo(inkId)
      local _, pigment = GetItemInfo(inkReagent[inkId].id)
      local herbShort = ceil(inkReagent[inkId].count * inkShort / 3) * 5
      msg = msg.."\n"..ink.." x "..inkShort.." / "..pigment.." level herb x "..herbShort
    end
  end
  TradeHelper:Print(msg)
end

function ScribeHelper:GetInkInfo(marketPercent)
  if marketPercent == nil then return end

  -- Herb to pigment
  local pigmentPrice = {}
  for herbId, group in pairs(Enchantrix.Constants.MillableItems) do
    local _, link = GetItemInfo(herbId)
    local herbPrice = AucAdvanced.API.GetMarketValue(link)
    if herbPrice then
      for pigmentId, millCount in pairs(Enchantrix.Constants.MillGroupYields[group]) do
        local millPrice = herbPrice * marketPercent * 5 / millCount
        if pigmentPrice[pigmentId] == nil or pigmentPrice[pigmentId] > millPrice then
          pigmentPrice[pigmentId] = millPrice
        end
      end
    end
  end

  -- Pigment to ink
  CastSpellByName("Inscription")
  local inkPrice = self.db.factionrealm.inkPrice
  local inkReagent = self.db.factionrealm.inkReagent
  wipe(inkPrice)
  for recipeIndex=1, GetNumTradeSkills() do
    local name = GetTradeSkillInfo(recipeIndex)
    if name:find("Ink") then
      local inkId = TradeHelper:GetItemIdFromLink(GetTradeSkillItemLink(recipeIndex))
      local inkCount = GetTradeSkillNumMade(recipeIndex)
      local _, _, pigmentCount = GetTradeSkillReagentInfo(recipeIndex, 1)
      local pigmentId = TradeHelper:GetItemIdFromLink(GetTradeSkillReagentItemLink(recipeIndex, 1))
      inkPrice[inkId] = floor(pigmentPrice[pigmentId] * pigmentCount / inkCount)
      inkReagent[inkId] = {id = pigmentId, count = pigmentCount / inkCount}
    end
  end
  CloseTradeSkill()

  -- Ink exchange
  for fromId, list in pairs(inkExchange) do
    for toId, cost in pairs(list) do
      if inkPrice[toId] > inkPrice[fromId] * cost then
        inkPrice[toId] = inkPrice[fromId] * cost
        inkReagent[toId].exchange = fromId

        local _, fromLink = GetItemInfo(fromId)
        local _, toLink = GetItemInfo(toId)
        TradeHelper:Print("Exchange "..fromLink.." for "..toLink.." is cheaper")
      end
    end
  end
end

function ScribeHelper:GetSelfMadeVellumPrice()
  CastSpellByName("Inscription")
  local inkPrice = self.db.factionrealm.inkPrice
  local vellumPrice = {}
  for recipeIndex=1, GetNumTradeSkills() do
    local name = GetTradeSkillInfo(recipeIndex)
    if name:find("Vellum") then
      local vellumCount = GetTradeSkillNumMade(recipeIndex)
      local cost = 0
      for reagentIndex=1, GetTradeSkillNumReagents(recipeIndex) do
        local _, _, reagentCount = GetTradeSkillReagentInfo(recipeIndex, reagentIndex)
        local reagentId = TradeHelper:GetItemIdFromLink(GetTradeSkillReagentItemLink(recipeIndex, reagentIndex))
        local price = inkPrice[reagentId] or parchmentPrice[reagentId]
        if price == nil then cost = nil; break end
        cost = cost + price * reagentCount
      end
      if cost then
        local vellumId = TradeHelper:GetItemIdFromLink(GetTradeSkillItemLink(recipeIndex))
        vellumPrice[vellumId] = math.ceil(cost / vellumCount)
      end
    end
  end
  CloseTradeSkill()
  return vellumPrice
end

function ScribeHelper:ScanGlyphInAuction()
  AucAdvanced.Scan.PushScan()
  -- Glyph (under Glyph)
  AucAdvanced.Scan.StartScan(nil, nil, nil, nil, 5, 0, nil, 1)
end

function ScribeHelper:ScanReagentInAuction()
  AucAdvanced.Scan.PushScan()
  -- Herb (under Trade Goods - Herb)
  AucAdvanced.Scan.StartScan(nil, nil, nil, nil, 6, 6, nil, 1)
  if not AucAdvanced.Scan.IsScanning() then return end
  -- Pigment (under Trade Goods - Other)
  AucAdvanced.Scan.StartPushedScan("Pigment", nil, nil, nil, 6, 13, nil, 1)
  -- Ink (under Trade Goods - Parts)
  AucAdvanced.Scan.StartPushedScan("Ink", nil, nil, nil, 6, 9, nil, 1)
end

function ScribeHelper:BuildSnatchList()
  -- Ink
  local inkPrice = self.db.factionrealm.inkPrice
  for id, price in pairs(inkPrice) do
    local _, link, quality = GetItemInfo(id)
    -- Rare, Ivory Ink and Moonglow Ink
    if quality == 1 and id ~= 37101 and id ~= 39469 then
      AucSearchUI.Searchers.Snatch.AddSnatch(link, price)
    end
  end

  -- Pigment
  local inkReagent = self.db.factionrealm.inkReagent
  local pigmentPrice = {}
  for inkId, price in pairs(inkPrice) do
    local pigmentId = inkReagent[inkId].id
    local _, link, quality = GetItemInfo(pigmentId)
    -- Rare and Alabaster Pigment
    if quality == 1 and pigmentId ~= 39151 then
      pigmentPrice[pigmentId] = price / inkReagent[inkId].count
      AucSearchUI.Searchers.Snatch.AddSnatch(link, floor(pigmentPrice[pigmentId]))
    end
  end

  -- Herb
  for herbId, group in pairs(Enchantrix.Constants.MillableItems) do
    local _, link = GetItemInfo(herbId)
    for pigmentId, millCount in pairs(Enchantrix.Constants.MillGroupYields[group]) do
      if pigmentPrice[pigmentId] then
        local herbPrice = floor(pigmentPrice[pigmentId] * millCount / 5)
        AucSearchUI.Searchers.Snatch.AddSnatch(link, herbPrice)
      end
    end
  end
end
