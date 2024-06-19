addon.name    = 'TreasureTimer';
addon.author  = 'Apples_mmmmmmmm';
addon.version = '1.0';
addon.desc    = 'Displays expected maximum respawn timers for chests/coffers based on last open attempt. Requires: tTimers.';
addon.link    = 'https://github.com/Applesmmmmmmmm/TreasureTimer';


require('common');

local imgui = require('imgui');
local data = require('Data');
local hidden = require('Hidden');
local helper = require('Helpers');
local settingsPath = string.format('%saddons\\%s\\WindowSettings.lua', AshitaCore:GetInstallPath(), addon.name);
--local settings = require('WindowSettings');

local config = false

local entityManager = AshitaCore:GetMemoryManager():GetEntity();
local partyManager = AshitaCore:GetMemoryManager():GetParty();

local function CheckPointInRangeOfTable(treasurePoints, playerPos, openMaxRangeSq)
    for _, p in ipairs(treasurePoints) do
        --Input data is in X,Z,Y format, playerPos is X,Y,Z
        local distanceSq = helper.DistanceSquaredXZY_XYZ(p, playerPos)
        if distanceSq <= openMaxRangeSq then
            return true
        end
    end
    return false
end

local function GetZoneChestTypeAsString(zoneID, playerPos, openingRange)
    local cofferAtKey = data.coffer[zoneID]
    local chestAtKey = data.chest[zoneID]
    local openingRangeSq = openingRange^2
    if (chestAtKey) then
        if (CheckPointInRangeOfTable(chestAtKey.points, playerPos, openingRangeSq)) then
            return "Chest"
        end
    end    
    if (cofferAtKey) then
        if (CheckPointInRangeOfTable(cofferAtKey.points, playerPos, openingRangeSq)) then
            return "Coffer"
        end
    end
    return "Unknown"
end

ashita.events.register('packet_in', 'packet_in_cb', function(e)
    -- Packet: Zone Leave
    if (e.id == 0x000B) then
        hidden.zoning = true;
        return;
    end

    -- Packet: Inventory Update Completed
    if (e.id == 0x001D) then
        hidden.zoning = false;        
        return;
    end

    --[[
        -- msgBase offsets
        0 You unlock the chest!
        1 <name> fails to open the chest.
        2 The chest was trapped!
        3 You cannot open the chest when you are in a weakened state.
        4 The chest was a mimic!
        5 You cannot open the chest while participating in the moogle event.
        6 The chest was but an illusion...
        7 The chest appears to be locked. If only you had <item>, perhaps you could open it...
    --]]

    --[[
    if e.id == 0x02A then
        --I think these offsets are correct, but they might need to be +1?
        local entityId  = struct.unpack('I32', e.data, 0x04)
        local param0    = struct.unpack('I32', e.data, 0x08)
        local param1    = struct.unpack('I32', e.data, 0x0C)
        local param2    = struct.unpack('I32', e.data, 0x10)
        local param3    = struct.unpack('I32', e.data, 0x14)
        local targetID  = struct.unpack('I16', e.data, 0x18)
        local messageID = struct.unpack('I16', e.data, 0x1A)

        --We're gonna want to log these to a file to analyze the data later.
        print("Possible Chest Open Attempt, dumping data.\nValues:\nEntityID: "..entityId.."\nP0: "..param0.."\nP1: "..param1.."\nP2: "..param2.."\nP3: "..param3.."\nTargetID: "..targetID..'\nMessageID: '..messageID)
        print("Binary (least significant first):\nEntityID: "..decimalToBinary(entityId).."\nP0: "..decimalToBinary(param0).."\nP1: "..decimalToBinary(param1).."\nP2: "..decimalToBinary(param2).."\nP3: "..decimalToBinary(param3).."\nTargetID: "..decimalToBinary(targetID)..'\nMessageID: '..decimalToBinary(messageID))
        print("Hex :\nEntityID: "..decimalToHex(entityId).."\nP0: "..decimalToHex(param0).."\nP1: "..decimalToHex(param1).."\nP2: "..decimalToHex(param2).."\nP3: "..decimalToHex(param3).."\nTargetID: "..decimalToHex(targetID)..'\nMessageID: '..decimalToHex(messageID))
    end
     ]]
end);

ashita.events.register('packet_out', 'packet_out_cb', function(e)

end);

local function SetTimer(zoneName, newCurrentValue)
    AshitaCore:GetChatManager():QueueCommand(-1, '/tt custom \"'..zoneName..'\" '..newCurrentValue..'m'..' \"Estimated time that the chest or coffer will be available to open in this zone.\"'..' '..'30m')
end


local openingRange = 7.5

ashita.events.register('text_in', 'text_in_cb', function(e)
    
    if (partyManager:GetMemberIsActive(0) == 0 or partyManager:GetMemberServerId(0) == 0) then
        return;
    end
    local zoneID = partyManager:GetMemberZone(0)
    local zoneName = AshitaCore:GetResourceManager():GetString('zones.names', zoneID);

    if (e.message_modified:contains("The chest was a mimic!")) then
        local myIndex = partyManager:GetMemberTargetIndex(0);
        local playerPos = { entityManager:GetLocalPositionX(myIndex), entityManager:GetLocalPositionY(myIndex),
            entityManager:GetLocalPositionZ(myIndex) }
        zoneName = zoneName .. " " .. GetZoneChestTypeAsString(zoneID, playerPos, openingRange)
        SetTimer(zoneName, 30)
    elseif (e.message_modified:contains("You discern that the illusion will remain for ")) then
        --TODO: try to cut this code down by finding the second match of a valid number. Maybe we don't even have to do the silly check if number is 1 or 2 digits once we change to that.
        local rep = ashita.regex.replace(
        ashita.regex.replace(e.message_modified, "You discern that the illusion will remain for ", ""), " minutes.", "")
        local minutesRemaining = tonumber(helper.TrimWhiteSpace(string.sub(rep, string.len(rep) - 2)))
        if (minutesRemaining == nil) then
            minutesRemaining = tonumber(helper.TrimWhiteSpace(string.sub(rep, string.len(rep) - 1)))
        end        

        local myIndex = partyManager:GetMemberTargetIndex(0);
        local playerPos = { entityManager:GetLocalPositionX(myIndex), entityManager:GetLocalPositionY(myIndex),
            entityManager:GetLocalPositionZ(myIndex) }
        zoneName = zoneName .. " " .. GetZoneChestTypeAsString(zoneID, playerPos, openingRange)
        --Add 59 seconds and then set the table, so we don't open early.
        SetTimer(zoneName, minutesRemaining + (59 / 60))
    elseif (e.message_modified:contains("You unlock the chest!")) then
        local myIndex = partyManager:GetMemberTargetIndex(0);
        local playerPos = { entityManager:GetLocalPositionX(myIndex), entityManager:GetLocalPositionY(myIndex),
            entityManager:GetLocalPositionZ(myIndex) }
        zoneName = zoneName .. " " .. GetZoneChestTypeAsString(zoneID, playerPos, openingRange)
        SetTimer(zoneName, 30)
    -- elseif (e.message_modified:contains("fails to open the chest.")) then

    -- elseif (e.message_modified:contains("You cannot open the chest when you are in a weakened state.")) then

    -- elseif (e.message_modified:contains("The chest was trapped!")) then

    -- elseif (e.message_modified:contains("The chest appears to be locked. If only you had ")) then

    else
        return
    end
end);

ashita.events.register('command', 'command_cb', function(e)
    local args = e.command:args();
    if (#args == 0) then
        return;
    end
    args[1] = string.lower(args[1]);
    if (args[1] ~= '/treasuretimer') and (args[1] ~= '/treasuretimers') then
        return;
    end
    e.blocked = true;

    if (#args > 1) then
        if (string.lower(args[2]) == "resetgil") then
            if (partyManager:GetMemberIsActive(0) ~= 0 or partyManager:GetMemberServerId(0) ~= 0) then
                ResetGilPerHour()
            end
        elseif (string.lower(args[2]) == "config") then
            config = not config
        end
    else
        print("Usage: Lockpick a chest to add or update the illusion timer for that zone.")
        print("OR /treasuretimer set <\"ZoneName\"> <minutesRemaining>")
        print("to manually change the timer for an area.")
    end
    if (#args > 3) then
        if (args[2] == 'set' or args[2] == 'add') then
            local location = args[3]
            local timeInMinutes = args[4]
            SetTimer(location, timeInMinutes)
        end
    end
end);
