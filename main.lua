local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local LocalPlayer = Players.LocalPlayer

-- 1. WAIT FOR DATA LOADING
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

if not ModulesLoaded then warn("Failed to load modules:", LoadError) return end

local PetShardService_RE = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetShardService_RE")

-- 2. FUNCTION TO EQUIP SHARD
local function EquipShard()
    local char = LocalPlayer.Character
    if not char then return false end
    
    -- Check if already holding it
    local equipped = char:FindFirstChild("Pet Shard") or char:FindFirstChild("Cleansing Pet Shard") or char:FindFirstChildWhichIsA("Tool")
    if equipped and string.find(equipped.Name, "Shard") then
        return equipped
    end

    -- Look in Backpack
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        local shard = backpack:FindFirstChild("Pet Shard") or backpack:FindFirstChild("Cleansing Pet Shard")
        -- Try finding any item with "Shard" in name if exact match fails
        if not shard then
            for _, tool in pairs(backpack:GetChildren()) do
                if tool:IsA("Tool") and string.find(tool.Name, "Shard") then
                    shard = tool
                    break
                end
            end
        end
        
        if shard then
            char.Humanoid:EquipTool(shard)
            task.wait(0.2) -- Wait for server to register equip
            return shard
        end
    end
    return false
end

-- 3. GET PETS
local s, currentPets = pcall(function()
    return PetUtilities:GetPetsSortedByAge(LocalPlayer, 0, false, true)
end)

if not s or not currentPets then warn("Failed to retrieve pet data") return end

-- 4. MAIN LOOP
local tool = EquipShard()
if not tool then
    warn("❌ You do not have a Pet Shard in your inventory!")
    return
end

print("✅ Shard Equipped. Scanning pets...")

for index, value in ipairs(currentPets) do
    local rawUUID = value.UUID -- This likely looks like "{f307...}"
    
    -- Ensure UUID has brackets for the search (Physical models use brackets)
    local searchName = rawUUID
    if string.sub(searchName, 1, 1) ~= "{" then
        searchName = "{" .. searchName .. "}"
    end
    
    -- Find the Physical Model
    local petModel = nil
    local petsFolder = workspace:FindFirstChild("PetsPhysical")

    if petsFolder then
        -- Check inside PetMover (Common structure)
        if petsFolder:FindFirstChild("PetMover") then
            petModel = petsFolder.PetMover:FindFirstChild(searchName)
        end
        -- Check directly in PetsPhysical
        if not petModel then
            petModel = petsFolder:FindFirstChild(searchName)
        end
    end

    -- Verify it is a valid Pet Model
    if petModel then
        -- IMPORTANT: Check if it has the PetModel tag (Original script constraint)
        if CollectionService:HasTag(petModel, "PetModel") or petModel:FindFirstChild("RootPart") then
            
            PetShardService_RE:FireServer("ApplyShard", petModel)
            
            print("✨ ATTEMPTED APPLY ON:", searchName)
            
            -- Keep break to test one at a time. Remove to do all.
            break 
        end
    else
        -- Only warn if you expected this specific pet to be equipped
        warn("Skipping " .. searchName .. " (Not in workspace/Not equipped)")
    end
end
