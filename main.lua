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
    print("Mencari pet dengan nama: " .. name)
    for index, pets in pairs(game:GetService("Players").LocalPlayer.Backpack:GetChildren()) do
        print( pets:GetAttribute("PetType") and "lkontol"..pets.Name:match("^(.-)%s*%[") or "awa")
        if pets:GetAttribute("PetType") and pets.Name:match("^(.-)%s*%[") == name then
            print("ini nama petr"..pets.Name)
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
local function start_leveling()
task.spawn(
    function()
        if PetUtilities then
            local success, myActivePets =
                pcall(
                function()
                    return PetUtilities:GetPetsSortedByAge(LocalPlayer, 0, false, true)
                end
            )
            print("--- ACTIVE PETS LIST ---")
            for i, pet in pairs(myActivePets) do
                local pName = (pet.PetData and pet.PetData.Name) or "Unnamed"
                local pType = pet.PetType or "Unknown"
                local pID = pet.UUID or "No UUID"
                local weight = tonumber(calculate_weight(pet))
                print(string.format("[%d] %s | Type: %s | ID: %s | Weight: %.2fkg", i, pName, pType, pID, weight))
                if weight >= weight_to_remove then
                    PetsService_upvr_2:UnequipPet(pet.UUID)
                    Rayfield:Notify({
                        Title = "Auto Level",
                        Content = "Removing " .. (pName or "Pet") .. " (" .. weight .. "kg)",
                        Duration = 2
                    })
                    for _, fullString in pairs(selectedPets) do
                        print(fullString)
                        local realName = fullString:match("^(.-)%s*%[") or fullString
                        print("realName" .. realName)
                        local petUUID = select_pet(realName)
                        if petUUID then
                            place_pet(petUUID)
                            break
                        end
                    end
                end
            end
        end
    end
)
end

local function refreshPetData()
    petList = {}
    local counts = {}

    for _, pet in pairs(petsFolder:GetChildren()) do
        if pet:GetAttribute("PetType") then
            local full = pet.Name
            
            local name = full:match("^(.-)%s*%[") or full
            local weightStr = full:match("%[(.-)%s*KG%]")
            local weight = weightStr and tonumber(weightStr) or nil
            local ageStr = full:match("%[Age%s*(%d+)%]")
            local age = ageStr and tonumber(ageStr) or nil

            -- LOGIKA BARU (Tanpa goto):
            -- 1. Cek apakah weight ada
            -- 2. Cek apakah weight memenuhi syarat hapus
            -- 3. Cek pengecualian (Age 1 & Weight >= 6.6)
            
            if weight and weight < weight_to_remove then
                if not (age == 1 and weight >= 6.6) then
                    table.insert(petList, {Name = name, Instance = pet})
                    counts[name] = (counts[name] or 0) + 1
                end
            end
        end
    end

    local formattedList = {}
    for name, count in pairs(counts) do
        table.insert(formattedList, name .. " [" .. count .. "]")
    end
    return formattedList
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
