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

function TradeHelper:CancelUndercuttedAuction(namePattern, timeLeftThreshold, risePercent, dryRun)
  if not (AuctionFrame and AuctionFrame:IsVisible()) then
    message("You need to talk to the auctioneer first!")
    return
  end
  
  local playerName = UnitName("player")
  local refresh = {}
  for i = 1, GetNumAuctionItems("owner") do
    local name, _, count, _, _, _, _, _, buyoutPrice, bidAmount = GetAuctionItemInfo("owner", i)
    if count > 0 and				-- not sold
       bidAmount == 0 and			-- no one bid
       name:find(namePattern) then	-- specified name
      local link = GetAuctionItemLink("owner", i)
      local undercutPrice, _, _, _, infoString = AucAdvanced.API.GetBestMatch(link, "market")
      -- Ignore those can not match lowest price
      if undercutPrice and not infoString:find("Can not match") then
        local cancel = false
        
        local timeLeft = GetAuctionItemTimeLeft("owner", i)
        if timeLeft <= timeLeftThreshold then
          cancel = true
          self:Print(ChatFrame2, "Cancel "..link.." because of short time left")
        elseif undercutPrice / buyoutPrice > 1 + risePercent then
          cancel = true
          self:Print(ChatFrame2, "Cancel "..link.." because of rising price: "..self:FormatMoney(buyoutPrice).." to "..self:FormatMoney(undercutPrice))
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
            if compet.sellerName ~= playerName and		-- not mine
               compet.buyoutPrice > 0 and				-- has buyout
               compet.buyoutPrice < buyoutPrice and		-- cheaper
               compet.timeLeft > timeLeftThreshold then	-- will stay long
              cancel = true
              self:Print(ChatFrame2, "Cancel "..link.." because of competition: "..self:FormatMoney(buyoutPrice).."(mine) vs "..self:FormatMoney(compet.buyoutPrice).."("..compet.sellerName..")")
              break
            end
          end
        end
        
        if cancel and not dryRun then
          CancelAuction(i)
          refresh[name] = true
        end
      end
    end
  end
  
  for name, _ in pairs(refresh) do
    AucAdvanced.Scan.StartPushedScan(name, nil, nil, nil, 0, 0, nil, 1)
  end
  AucAdvanced.Scan.PopScan()
end

function TradeHelper:PostNoCompeteAuctions(namePattern, dryRun)
  if not (AuctionFrame and AuctionFrame:IsVisible()) then
    message("You need to talk to the auctioneer first!")
    return
  end
  
  local frame = AucAdvanced.Modules.Util.Appraiser.Private.frame
  for _, item in ipairs(frame.list) do
    local sig = item[1]
    local link, name = AucAdvanced.API.GetLinkFromSig(sig)
    if name:find(namePattern) then
      local _, _, _, _, infoString = AucAdvanced.API.GetBestMatch(link, "market")
      -- Do not post those can not match lowest price
      if not infoString:find("Can not match") then
        frame.PostBySig(sig, dryRun)
      end
    end
  end
end
