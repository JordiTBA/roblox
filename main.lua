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
    -- Getting pets sorted (Modify arguments as needed for your specific target list)
    return PetUtilities:GetPetsSortedByAge(LocalPlayer, 0, false, true)
end)

if not s or not currentPets then
    warn("Failed to retrieve pet data")
    return
end

-- Main Execution
for index, value in ipairs(currentPets) do
    local petUUID = value.UUID
    local currentMutation = value.PetData.MutationType
    
    print("Processing Pet:", petUUID, "| Mutation:", table_mutate[currentMutation] or "None")

    -- Find the Physical Model in Workspace
    -- The physical structure usually wraps the UUID in curly braces: {UUID}
    local physicalPetName = "{" .. petUUID .. "}"
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
        -- IMPORTANT: The server expects the MODEL, not the RootPart
        PetShardService_RE:FireServer("ApplyShard", petModel)
        warn("Shard applied to:", petUUID)
        
        -- Break after one use to prevent using all shards at once. 
        -- Remove 'break' if you want to loop through all pets.
        break 
    else
        warn("Physical model not found for UUID:", petUUID)
    end
end
