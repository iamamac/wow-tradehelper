function TradeHelper:UpdateAuctionInscriptionGlyph()
  AucAdvanced.Scan.PushScan()
  -- Glyph (under Glyph)
  AucAdvanced.Scan.StartScan(nil, nil, nil, nil, 5, 0, nil, 1)
end

function TradeHelper:UpdateAuctionInscriptionReagent()
  AucAdvanced.Scan.PushScan()
  -- Herb (under Trade Goods - Herb)
  AucAdvanced.Scan.StartScan(nil, nil, nil, nil, 6, 6, nil, 1)
  if not AucAdvanced.Scan.IsScanning() then return end
  -- Pigment (under Trade Goods - Other)
  AucAdvanced.Scan.StartPushedScan("Pigment", nil, nil, nil, 6, 13, nil, 1)
  -- Ink (under Trade Goods - Parts)
  AucAdvanced.Scan.StartPushedScan("Ink", nil, nil, nil, 6, 9, nil, 1)
end

function TradeHelper:CancelUndercuttedAuction(namePattern, profile, dryRun)
  if not (AuctionFrame and AuctionFrame:IsVisible()) then
    message("You need to talk to the auctioneer first!")
    return
  end
  
  local numAuction, numLowest, numCantUndercut, numShortTime, numRising, numCompete = 0, 0, 0, 0, 0, 0
  local playerName = UnitName("player")
  for i = 1, GetNumAuctionItems("owner") do
    local name, _, count, _, _, _, _, _, buyoutPrice, bidAmount = GetAuctionItemInfo("owner", i)
    if count > 0 and				-- not sold
       bidAmount == 0 and			-- no one bid
       name:find(namePattern) then	-- specified name
      numAuction = numAuction + 1
      local link = GetAuctionItemLink("owner", i)
      local undercutPrice = self:GetPrice(link, profile)
      if undercutPrice > 0 then
        local cancel = false
        
        local timeLeft = GetAuctionItemTimeLeft("owner", i)
        if timeLeft <= profile.timeLeftThreshold then
          cancel = true
          numShortTime = numShortTime + 1
          self:Print("Cancel "..link.." because of short time left")
        elseif undercutPrice / buyoutPrice > 1 + profile.risePercent then
          cancel = true
          numRising = numRising + 1
          self:Print("Cancel "..link.." because of rising price: "..self:FormatMoney(buyoutPrice).." to "..self:FormatMoney(undercutPrice))
        else
          local _, itemId, property, factor = AucAdvanced.DecodeLink(link)
          local data = AucAdvanced.API.QueryImage({
            itemId = itemId,
            suffix = property,
            factor = factor,
            minStack = count,
            maxStack = count,
            maxBuyout = buyoutPrice,
          })
          for _, v in ipairs(data) do
            local compet = AucAdvanced.API.UnpackImageItem(v)
            if compet.sellerName ~= playerName and				-- not mine
               compet.buyoutPrice > 0 and						-- has buyout
               compet.buyoutPrice < buyoutPrice and				-- cheaper
               compet.timeLeft > profile.timeLeftThreshold then	-- will stay long
              cancel = true
              numCompete = numCompete + 1
              self:Print("Cancel "..link.." because of competition: "..self:FormatMoney(buyoutPrice).."(mine) vs "..self:FormatMoney(compet.buyoutPrice).."("..compet.sellerName..")")
              break
            end
          end
        end
        
        if cancel then
          if not dryRun then CancelAuction(i) end
        else
          numLowest = numLowest + 1
        end
      else
        numCantUndercut = numCantUndercut + 1
      end
    end
  end
  
  self:Print('{{'..numAuction..'}} items in total, {{'..numLowest..'}} has lowest price, {{'..numCantUndercut..'}} can not undercut')
  msg = '{{'..(numShortTime + numRising + numCompete)..'}} items canceled'
  if numShortTime > 0 then msg = msg..', {{'..numShortTime..'}} because of short time' end
  if numRising > 0 then msg = msg..', {{'..numRising..'}} because of rising price' end
  if numCompete > 0 then msg = msg..', {{'..numCompete..'}} because of competition' end
  self:Print(msg)
end

function TradeHelper:PostNoCompeteAuctions(namePattern, profile, dryRun)
  if not (AuctionFrame and AuctionFrame:IsVisible()) then
    message("You need to talk to the auctioneer first!")
    return
  end
  
  local AucAdvancedGetSettingOrig = AucAdvanced.Settings.GetSetting
  AucAdvanced.Settings.GetSetting = function (setting, default)
    if setting:match('util\.appraiser\.item\.%d+\.numberonly$') then return true end
    return AucAdvancedGetSettingOrig(setting, default)
  end
  
  local buyPrice
  local AucAdvancedAppraiserGetPriceOrig = AucAdvanced.Modules.Util.Appraiser.GetPrice
  AucAdvanced.Modules.Util.Appraiser.GetPrice = function (link, serverKey, match)
    bidPrice = math.floor(buyPrice * (1 - profile.bidMarkDown) + 0.5)
    return buyPrice, bidPrice, nil, nil, nil, nil, 1, profile.batchSize, profile.postDuration
  end
  
  local frame = AucAdvanced.Modules.Util.Appraiser.Private.frame
  for _, item in ipairs(frame.list) do
    local sig = item[1]
    local link, name = AucAdvanced.API.GetLinkFromSig(sig)
    if name:find(namePattern) then
      buyPrice = self:GetPrice(link, profile)
      if buyPrice > 0 then
        frame.PostBySig(sig, dryRun)
      end
    end
  end
  
  AucAdvanced.Settings.GetSetting = AucAdvancedGetSettingOrig
  AucAdvanced.Modules.Util.Appraiser.GetPrice = AucAdvancedAppraiserGetPriceOrig
end
