return function(config)
    local pets = config.pets
    local seeds = config.seeds
    
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local packetEvent = ReplicatedStorage:FindFirstChild("SharedModules")
        and ReplicatedStorage.SharedModules:FindFirstChild("Packet")
        and ReplicatedStorage.SharedModules.Packet:FindFirstChild("RemoteEvent")

    if not packetEvent then warn("Cobalt: RemoteEvent not found."); return end

    print("Cobalt: Engine running with " .. #pets .. " pets and " .. #seeds .. " seeds.")
    
    -- Insert your heavy scanning/firing logic here.
    -- Use 'pets' and 'seeds' tables directly.
    -- Example: 
    -- for _, pet in pairs(pets) do print("Processing " .. pet) end
end
