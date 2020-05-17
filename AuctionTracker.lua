local _, core = ...;

function core:retrieveHistory()
  core:log("Retrieving auction history...");
  core:clearAuctionsUpdateStructure();
  core:log("Cleared all finished auctions...");
  core:log("Displaying auctions...");
  core:displayAuctionTimers();
end

function core:displayAuctionTimers()
  for j=4,1,-1 do
    for key,item in pairs(TrackedAuctions) do 
      for i,suid in pairs(item) do
        if #suid[j] ~= 0 then
          print(core:getRgbFromBlock(j).. C_Item.GetItemNameByID(key) .. ' x' ..strsub(i, core:strpos(i, '_')+1));
          for k,timestamp in pairs(suid[j]) do
            local diff = timestamp - time() - 3600;
            print(date("%A %H:%M:%S", timestamp) .. ' (in ' .. date('%H', diff).. ' hours and ' .. date('%M', diff)..' minutes)'); 
          end
        end
      end
    end
  end
end


function core:strpos (haystack, needle, offset)
  local pattern = string.format("(%s)", needle)
  local i       = string.find (haystack, pattern, (offset or 0))

  return (i ~= nil and i or false)
end

function core:updateSnapshot()
  newSnapshot = core:takeAuctionSnapshot();
  keys = core:getKeysFromAuctionList(newSnapshot);  
  trackedKeys = core:getKeysFromAuctionList(TrackedAuctions);
  -- If we ever get an empty auction screen, opportunistically clear out our saved variables
  if #keys == 0 then
    core:log('Resetting Tracked Auctions Variable...');
    TrackedAuctions = {};
  end

  for i,key in pairs(trackedKeys) do
    if newSnapshot[key] ~= nil then
      for j,suid in pairs(TrackedAuctions[key]) do
        if newSnapshot[key][j] ~= null then
          for k,blocks in pairs(suid) do 
            if newSnapshot[key][j][k] == nil then
              TrackedAuctions[key][j][k] = nil;
            end
          end
        else
          TrackedAuctions[key][j] = nil;
        end
      end
    else
      TrackedAuctions[key] = nil
    end
  end

  for i,key in pairs(keys) do
    if TrackedAuctions[key] ~= nil then
      for j,suid in pairs(newSnapshot[key]) do
        if TrackedAuctions[key][j] ~= nil then
          for k,blocks in pairs(suid) do
            local trackedBlocks = TrackedAuctions[key][j][k];
            if #blocks ~= #trackedBlocks then
              if #blocks > #trackedBlocks then
                -- Insert the most recent blocks from our new snapshot into our tracked blocks
                local count = #blocks - #trackedBlocks; 
                while count > 0 do 
                  tinsert(trackedBlocks, count, blocks[count]);
                  count = count - 1;
                end
              else
                -- Remove the oldest blocks from our tracked blocks
                local count = #trackedBlocks - #blocks; 
                while count > 0 do 
                  tremove(trackedBlocks);
                  count = count - 1;
                end
              end
            end
          end
        else
          TrackedAuctions[key][j] = newSnapshot[key][j];
        end
      end
    else
      TrackedAuctions[key] = newSnapshot[key];
    end
  end
end

function core:getKeysFromAuctionList(list)
  local n = 0;
  local keys = {}; 
  for k,v in pairs(list) do
    n=n+1
    keys[n]=k
  end
  return keys;
end

function core:takeAuctionSnapshot()
  local auctions = {};
  local numAuctions = GetNumAuctionItems("owner");
  for i=numAuctions,1,-1 do
    local info={GetAuctionItemInfo("owner", i)};
    local isSold = info[16];
    local count = info[3];
    if isSold ~= 1 then
      local timeBlock = GetAuctionItemTimeLeft("owner", i);
      local secondsLeft = core:getTimestampFromBlock(timeBlock);
      local itemName = info[1];
      local itemId = info[17];
      local buyoutPrice = info[10];
      local quantity = info[3];
      local endTime = time() + secondsLeft; 
      local buyout_quantity = buyoutPrice .. '_' .. quantity; 

      if auctions[itemId] == nil then
        auctions[itemId] = {};
      end

      if auctions[itemId][buyout_quantity] == nil then
        auctions[itemId][buyout_quantity] = {};
        auctions[itemId][buyout_quantity][1] = {};
        auctions[itemId][buyout_quantity][2] = {};
        auctions[itemId][buyout_quantity][3] = {};
        auctions[itemId][buyout_quantity][4] = {};
      end

      tinsert(auctions[itemId][buyout_quantity][timeBlock], 1, endTime);
    end
  end
  return auctions;
end

function core:clearAuctionsUpdateStructure()
  for key,item in pairs(TrackedAuctions) do 
    for i,suid in pairs(item) do
      for j,block in pairs(suid) do
        for k, timestamp in pairs(block) do
          if (timestamp < time()) then 
            tremove(TrackedAuctions[key][i][j], k);
            -- Indexes get reset, so call recursively 
            core:clearAuctionsUpdateStructure();
          else
            local correctBlock = core:getBlockFromTimestamp(timestamp);
            if j ~= correctBlock then
              core:log("Moved timestamp " .. timestamp .. " from block " .. j .. " to block " .. correctBlock);
              tinsert(TrackedAuctions[key][i][correctBlock], 1, timestamp);
              tremove(TrackedAuctions[key][i][j], k);
              -- Indexes get reset, so call recursively 
              core:clearAuctionsUpdateStructure();
            end
          end
        end
      end
    end
  end
end

function core:getTimestampFromBlock(block)
  local t = {};
  t[1] = 1800; 
  t[2] = 7200; 
  t[3] = 28800; 
  t[4] = 86400; 

 return t[block];
end

function core:getBlockFromTimestamp(timestamp)
  local timeRemaining = timestamp - time();
  if timeRemaining > 43200 then 
    return 4;
  elseif timeRemaining > 7200 then
    return 3;
  elseif timeRemaining > 1800 then
    return 2;
  else 
    return 1;
  end
end

function core:getRgbFromBlock(block)
  local t = {};
  t[1] = core:convertRgb(255,0,0); 
  t[2] = core:convertRgb(255,128,0);
  t[3] = core:convertRgb(255,255,0); 
  t[4] = core:convertRgb(128,255,0); 
  return t[block];
end

function core:rgbToHex(rgb)
	local hexadecimal = ''

	for key, value in pairs(rgb) do
		local hex = ''

		while(value > 0)do
			local index = math.fmod(value, 16) + 1
			value = math.floor(value / 16)
			hex = string.sub('0123456789ABCDEF', index, index) .. hex			
		end

		if(string.len(hex) == 0)then
			hex = '00'

		elseif(string.len(hex) == 1)then
			hex = '0' .. hex
		end

		hexadecimal = hexadecimal .. hex
	end

	return hexadecimal
end

function core:convertRgb(r,g,b)
 rgb = core:rgbToHex({r, g, b});
 return '|cff' ..rgb; 
end

function core:log(string)
  print('-----==========-----');
  print(string);
  print('-----==========-----');
end

function core:init(event, name)
  if (name ~= "AuctionTracker") then return; end;

  if(TrackedAuctions == nil) then
    TrackedAuctions = {};
  end

  SLASH_AuctionTracker1 = "/auctimer";
  SlashCmdList.AuctionTracker = core.retrieveHistory;
end

function core:auction()
    core:log('Auction Snapshot Updated');
    core:updateSnapshot();
end

local frame = CreateFrame("Frame");
frame:RegisterEvent("ADDON_LOADED");
frame:SetScript("OnEvent", core.init); 

local auctionFrame = CreateFrame("Frame");
auctionFrame:RegisterEvent("AUCTION_OWNED_LIST_UPDATE");
auctionFrame:SetScript("OnEvent", core.auction);
