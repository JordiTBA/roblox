local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Module Loader
local PetUtilities
local ModulesLoaded, LoadError = pcall(function()
    local Modules = ReplicatedStorage:WaitForChild("Modules", 5)
    local PetServices = Modules and Modules:WaitForChild("PetServices", 2)
    local UtilMod = PetServices and PetServices:WaitForChild("PetUtilities", 2)
    if UtilMod then
        PetUtilities = require(UtilMod)
    else
        error("PetUtilities not found")
    end
end)

if not ModulesLoaded then
    warn("Failed to load modules:", LoadError)
    return
end

-- Services & Tables
local PetMutationRegistry = require(ReplicatedStorage.Data.PetRegistry.PetMutationRegistry)
local PetShardService_RE = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetShardService_RE")

-- Debug Table for Mutations
local table_mutate = {}
if PetMutationRegistry.EnumToPetMutation then
    for id, name in pairs(PetMutationRegistry.EnumToPetMutation) do
        table_mutate[id] = tostring(name)
    end
end

-- Get Player's Pets
local s, currentPets = pcall(function()
    return PetUtilities:GetPetsSortedByAge(LocalPlayer, 0, false, true)
end)

if not s or not currentPets then
    warn("Failed to retrieve pet data")
    return
end

-- Main Execution
for index, value in ipairs(currentPets) do
    local petUUID = value.UUID -- This already contains the "{ }" braces based on your logs
    local currentMutation = value.PetData.MutationType
    
    print("Processing Pet:", petUUID, "| Mutation:", table_mutate[currentMutation] or "None")
--
    -- FIX: Use the UUID directly since it already has braces.
    -- We force check if braces exist just in case, to ensure consistency.
    local physicalPetName = petUUID
    if string.sub(physicalPetName, 1, 1) ~= "{" then
        physicalPetName = "{" .. physicalPetName .. "}"
    end
    
    local petModel = nil

    -- Check likely paths for the physical model
    if workspace.PetsPhysical:FindFirstChild("PetMover") then
        petModel = workspace.PetsPhysical.PetMover:FindFirstChild(physicalPetName)
    end
    
    -- Fallback check if it's directly in PetsPhysical
    if not petModel then
        petModel = workspace.PetsPhysical:FindFirstChild(physicalPetName)
    end

    -- Fire Event
    if petModel then
        -- The server script likely uses petModel:GetAttribute("UUID") or checks the name.
        -- Passing the Model itself is usually the correct argument for these interaction events.
        PetShardService_RE:FireServer("ApplyShard", petModel)
        
        warn("✅ Shard applied to:", physicalPetName)
        
        -- IMPORTANT: Break is here so you only use 1 shard at a time. 
        -- Remove 'break' if you want to shard your entire inventory instantly.
        break 
    else
        warn("❌ Physical model not found for name:", physicalPetName)
    end
end
