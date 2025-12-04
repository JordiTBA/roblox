local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua"))()
end)

if not success or not Rayfield then
    -- Backup Link jika link pertama gagal
    success, Rayfield = pcall(function()
        return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
    end)
end

if not success or not Rayfield then
    warn("CRITICAL ERROR: Gagal memuat UI Library. Cek koneksi internet atau ganti Executor.")
    return
end

getgenv().Leveling = false

local Window = Rayfield:CreateWindow({
    Name = "Pet Manager GUI",
    LoadingTitle = "Loading...",
    ConfigurationSaving = {Enabled = false}
})

local Tab = Window:CreateTab("Main", 4483362458)

-- // Services & Variables // --
local petsFolder = game.Players.LocalPlayer.Backpack
local petList = {}
local selectedPets = {}
local weight_to_remove = 0 
-- // Blacklist Variables & Helper // --
getgenv().InventoryMap = {} -- Map to store UUIDs from the dropdown

getgenv().blacklistedUUIDs = {} -- This table will store the UUIDs of pets you selected
local ActivePetMap = {} -- Maps the Dropdown Display String -> Real UUID

local Workspace_upvr = game:GetService("Workspace")
local UserInputService_upvr = game:GetService("UserInputService")
local LocalPlayer_upvr = game:GetService("Players").LocalPlayer
local CurrentCamera_upvr = Workspace_upvr.CurrentCamera
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PetUtilitiesPath =
    ReplicatedStorage:WaitForChild("Modules"):WaitForChild("PetServices"):WaitForChild("PetUtilities")
local PetUtilities = require(PetUtilitiesPath)
local PetList_upvr = require(ReplicatedStorage.Data.PetRegistry).PetList
local PetUtilities_upvr = require(ReplicatedStorage.Modules.PetServices.PetUtilities)
local PetsService_upvr_2 = require(ReplicatedStorage.Modules.PetServices.PetsService)
-- // Helper Functions // --
local function select_pet(name)
    for index, pets in pairs(game:GetService("Players").LocalPlayer.Backpack:GetChildren()) do
        if pets:GetAttribute("PetType") and pets.Name:match("^(.-)%s*%[") == name then
            return pets:GetAttribute("PET_UUID")
        end
    end
    return nil
end

local function ScreenRaycast_upvr()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer_upvr.Character}
    
    local mouseLoc = UserInputService_upvr:GetMouseLocation()
    local ray = CurrentCamera_upvr:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
    
    return Workspace_upvr:Raycast(ray.Origin, ray.Direction * 1000, params)
end

local function place_pet(UUID)
    local rayResult = ScreenRaycast_upvr()
    if not rayResult then return end

    local pos = rayResult.Position
    local cframe = CFrame.new(pos.X, pos.Y, pos.Z)

    local success, petService = pcall(function()
        return require(game:GetService("ReplicatedStorage").Modules.PetServices.PetsService)
    end)

    if success and petService then
        petService:EquipPet(UUID, cframe)
    end
end
local function calculate_weight(var233)
    local var235 = PetList_upvr[var233.PetType]
    return string.format(
        "%.2f",
        PetUtilities_upvr:CalculateWeight(var233.PetData.BaseWeight or 1, math.min(var233.PetData.Level or 1, 100))
    )
end
local function check_blacklist(UUID)
    for _, blacklistedUUID in pairs(getgenv().blacklistedUUIDs) do
        if UUID == blacklistedUUID then
            return true
        end
    end
    return false
end 

local function start_leveling()
    task.spawn(function()
        if not PetUtilities then return end

        local success, myActivePets = pcall(function()
            return PetUtilities:GetPetsSortedByAge(LocalPlayer, 0, false, true)
        end)

        if success and myActivePets and #myActivePets > 0 then
            -- 1. Check if ALL active pets are overweight
            local allReadyToRemove = true
            
            print("--- CHECKING PET WEIGHTS ---")
            for _, pet in pairs(myActivePets) do
                local weight = tonumber(calculate_weight(pet)) or 0
                -- If ANY pet is still skinny (under weight), stop the process
                if weight < weight_to_remove then
                    allReadyToRemove = false
                    print(string.format("Waiting for: %s | Current: %.2f / %d", pet.PetData.Name, weight, weight_to_remove))
                end
            end

            -- 2. Only unequip if ALL are ready
            if allReadyToRemove then
                print("ALL PETS READY! SWAPPING NOW...")
                
                -- Unequip All Active Pets first
                for _, pet in pairs(selectedPets) do
                    -- Optional: Check blacklist here if you want
                    local uuid = getgenv().InventoryMap[pet]
                    if uuid then
                        print("Unequipping Pet UUID: " .. uuid)
                        PetsService_upvr_2:UnequipPet(uuid)
                        task.wait(0.1) -- Small delay to prevent network choke
                    end
                end
                
                -- Equip New Pets from Selected List
                -- Note: This loops through your selection and tries to equip them
                for _, fullString in pairs(selectedPets) do
                    local uuid = getgenv().InventoryMap[fullString] -- Use the Map we made in refreshPetData
                    if uuid then
                        print("Equipping Pet UUID: " .. uuid)
                        place_pet(uuid)
                        task.wait(0.2)
                    end
                end
            end
        end
    end)
end


local function refreshPetData()
    petList = {}
    getgenv().InventoryMap = {} -- Reset map
    
    -- Helper to process a pet entry
    local function addPetToList(petData, isEquipped)
        local uuid = petData.UUID or petData:GetAttribute("PET_UUID") or "NoUUID"
        local full = petData.Name or (petData.PetData and petData.PetData.Name) or "Unnamed"
        local name = full:match("^(.-)%s*%[") or full
        local level = 1
        if isEquipped then
            level = petData.PetData and petData.PetData.Level or 1
        else
            local lvlAttr = petData:GetAttribute("Level")
            local lvlMatch = full:match("Level%s*(%d+)") or full:match("Lvl%s*(%d+)") or full:match("Age%s*(%d+)")
            level = lvlAttr or (lvlMatch and tonumber(lvlMatch)) or 1
        end

        -- Format String
        local status = isEquipped and "[EQ] " or ""
        local displayString = string.format("%s{%s} Level %s %s", status, uuid:sub(1, 6), level, name)
        
        -- Store mapping
        getgenv().InventoryMap[displayString] = uuid
        table.insert(petList, displayString)
    end

    -- 1. Get Active Pets (Equipped)
    if PetUtilities then
        local success, myActivePets = pcall(function()
            return PetUtilities:GetPetsSortedByAge(LocalPlayer, 0, false, true)
        end)
        if success and myActivePets then
            for _, pet in pairs(myActivePets) do
                addPetToList(pet, true)
            end
        end
    end

    -- 2. Get Backpack Pets (Unequipped)
    local backpack = game.Players.LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, pet in pairs(backpack:GetChildren()) do
            if pet:GetAttribute("PetType") then
                addPetToList(pet, false)
            end
        end
    end

    return petList
end
-- // GUI Elements // --

local PetDropdown

local function CreateDropdown()
    local list = refreshPetData()
    PetDropdown = Tab:CreateDropdown({
        Name = "Inventory Pets",
        Options = list,
        CurrentOption = {},
        MultipleOptions = true,
        Flag = "PetDropdown",
        Callback = function(Option)
            selectedPets = Option
        end
    })
end

CreateDropdown()

Tab:CreateButton({
    Name = "Refresh Pet List",
    Callback = function()
        local newList = refreshPetData()
        PetDropdown:Refresh(newList, true)
    end
})

Tab:CreateSection("Automation Settings")

Tab:CreateInput({
    Name = "Weight to Remove (KG)",
    PlaceholderText = "Input Number (e.g. 10)",
    RemoveTextAfterFocusLost = false,
    Callback = function(Text)
        local numberValue = tonumber(Text)
        if numberValue then
            weight_to_remove = numberValue
        else
            Rayfield:Notify({Title = "Error", Content = "Please enter a valid number!", Duration = 3})
        end
    end
})

Tab:CreateToggle({
    Name = "Start Auto Leveling",
    CurrentValue = false,
    Flag = "AutoLevelToggle",
    Callback = function(Value)
        getgenv().Leveling = Value
        if Value then
            task.spawn(function()
                while getgenv().Leveling do
                    start_leveling()
                    task.wait(1.5)
                end
            end)
        end
    end
})

local function getActivePetsList()
    local list = {}
    ActivePetMap = {} -- Reset map on refresh

    if PetUtilities then
        local success, myActivePets = pcall(function()
            return PetUtilities:GetPetsSortedByAge(LocalPlayer, 0, false, true)
        end)
        
        if success and myActivePets then
            for _, pet in pairs(myActivePets) do
                local pName = (pet.PetData and pet.PetData.Name) or "Unnamed"
                -- Utilizing your existing calculate_weight function
                local weight = calculate_weight(pet) 
                
                -- Create a unique display string containing Name, Weight and a short UUID part
                -- This ensures distinct entries for pets with the same name
                local uniqueDisplay = string.format("%s | %skg [%s]", pName, weight, pet.UUID:sub(1, 5))
                
                ActivePetMap[uniqueDisplay] = pet.UUID
                table.insert(list, uniqueDisplay)
            end
        end
    end
    return list
end

-- // Blacklist GUI Elements // --
Tab:CreateSection("Blacklist Settings")

local BlacklistDropdown = Tab:CreateDropdown({
    Name = "Blacklist Active Pets",
    Options = getActivePetsList(), -- Populates with current active pets
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "BlacklistDropdown",
    Callback = function(Option)
        getgenv().blacklistedUUIDs = {} -- Clear previous selection
        for _, selectedString in pairs(Option) do
            local uuid = ActivePetMap[selectedString]
            if uuid then
                table.insert(getgenv().blacklistedUUIDs, uuid)
            end
        end
        print("Blacklist Updated. Total UUIDs: " .. #getgenv().blacklistedUUIDs)
    end
})

Tab:CreateButton({
    Name = "Refresh Active Pets",
    Callback = function()
        local newList = getActivePetsList()
        BlacklistDropdown:Refresh(newList, true)
    end
})
