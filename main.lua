local success, Rayfield =
    pcall(
    function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua"))(

        )
    end
)

if not success or not Rayfield then
    success, Rayfield =
        pcall(
        function()
            return loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
        end
    )
end

if not success or not Rayfield then
    warn("CRITICAL ERROR: Failed to load UI Library.")
    return
end

getgenv().Leveling = false
getgenv().blacklistedUUIDs = {}
getgenv().InventoryMap = {} -- Maps Display String -> Real UUID
getgenv().Mode = "leveling" -- leveling // reseting
local Window =
    Rayfield:CreateWindow(
    {
        Name = "Pet Manager GUI",
        LoadingTitle = "Loading...",
        ConfigurationSaving = {Enabled = false}
    }
)

local Tab = Window:CreateTab("Main", 4483362458)

-- // Services & Variables // --
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local CurrentCamera = Workspace.CurrentCamera

-- // SAFE MODULE LOADING // --
-- We use pcall here so the UI still loads even if the game updated the paths
local PetUtilities, PetList_Data, PetsService
local ModulesLoaded, LoadError =
    pcall(
    function()
        -- Attempt to find folders with a small timeout to prevent infinite freezing
        local Modules = ReplicatedStorage:WaitForChild("Modules", 5)
        if not Modules then
            error("Modules folder not found")
        end

        local PetServices = Modules:WaitForChild("PetServices", 2)
        if PetServices then
            local UtilMod = PetServices:WaitForChild("PetUtilities", 2)
            if UtilMod then
                PetUtilities = require(UtilMod)
            end

            local SvcMod = PetServices:WaitForChild("PetsService", 2)
            if SvcMod then
                PetsService = require(SvcMod)
            end
        end

        local DataFolder = ReplicatedStorage:WaitForChild("Data", 2)
        if DataFolder then
            local Registry = DataFolder:WaitForChild("PetRegistry", 2)
            if Registry then
                PetList_Data = require(Registry).PetList
            end
        end
    end
)

if not ModulesLoaded or not PetUtilities then
    Rayfield:Notify(
        {
            Title = "Warning",
            Content = "Some Game Modules failed to load. Features might be broken.",
            Duration = 6.5,
            Image = 4483362458
        }
    )
    warn("Module Load Error:", LoadError)
end

local selectedPets = {}
local weight_to_remove = 0

-- // Helper Functions // --

local function ScreenRaycast()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character}

    local mouseLoc = UserInputService:GetMouseLocation()
    local ray = CurrentCamera:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)

    return Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
end

local function place_pet(UUID)
    if not PetsService then
        return
    end -- Safety check

    local rayResult = ScreenRaycast()
    if not rayResult then
        return
    end

    local pos = rayResult.Position
    local cframe = CFrame.new(pos.X, pos.Y, pos.Z)

    -- Try to equip
    pcall(
        function()
            PetsService:EquipPet(UUID, cframe)
        end
    )
end

local function calculate_weight(petData)
    -- Handles both raw data and active pet objects
    local pType = petData.PetType
    local pData = petData.PetData

    if not pType or not pData then
        return "0.00"
    end

    local baseWeight = pData.BaseWeight or 1
    local level = pData.Level or 1

    if PetUtilities then
        return string.format("%.2f", PetUtilities:CalculateWeight(baseWeight, math.min(level, 100)))
    else
        return "0.00" -- Fallback if utils missing
    end
end

local function check_blacklist(UUID)
    for _, id in pairs(getgenv().blacklistedUUIDs) do
        if id == UUID then
            return true
        end
    end
    return false
end

-- // Core Logic: Refresh Data // --
local function refreshPetData()
    local displayList = {}
    getgenv().InventoryMap = {} -- Reset map

    -- Helper to process a pet entry
    local function addPetToList(petData, isEquipped)
        local uuid = "NoUUID"
        local full = "Unnamed"
        local level = 1

        -- FIX: Safely check if petData is a Tool Instance or a Table
        if typeof(petData) == "Instance" then
            -- It is a Tool in Backpack
            uuid = petData:GetAttribute("PET_UUID") or petData:GetAttribute("UUID") or "NoUUID"
            full = petData.Name

            local lvlAttr = petData:GetAttribute("Level")
            local lvlMatch = full:match("Level%s*(%d+)") or full:match("Lvl%s*(%d+)") or full:match("Age%s*(%d+)")
            level = lvlAttr or (lvlMatch and tonumber(lvlMatch)) or 1
        elseif type(petData) == "table" then
            -- It is a Data Table from PetUtilities
            uuid = petData.UUID or "NoUUID"
            full = petData.Name or (petData.PetData and petData.PetData.Name) or "Unnamed"
            level = petData.PetData and petData.PetData.Level or 1
        end

        -- Clean Name
        local name = full:match("^(.-)%s*%[") or full

        -- Format String: [EQ] {123456} Level 50 Dog
        local status = ""
        local shortUUID = tostring(uuid):sub(1, 6)
        local displayString = string.format("%s{%s} Level %s %s", status, shortUUID, level, name)

        -- Store strict mapping
        getgenv().InventoryMap[displayString] = uuid
        table.insert(displayList, displayString)
    end

    -- 1. Get Active Pets (Equipped)
    if PetUtilities then
        local success, myActivePets =
            pcall(
            function()
                return PetUtilities:GetPetsSortedByAge(LocalPlayer, 0, false, true)
            end
        )
        if success and myActivePets then
            for _, pet in pairs(myActivePets) do
                addPetToList(pet, true)
            end
        end
    end

    -- 2. Get Backpack Pets (Unequipped)
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, pet in pairs(backpack:GetChildren()) do
            if pet:GetAttribute("PetType") then
                addPetToList(pet, false)
            end
        end
    end

    return displayList
end
local function check_pet_active(uuid)
    if PetUtilities then
        local success, myActivePets =
            pcall(
            function()
                return PetUtilities:GetPetsSortedByAge(LocalPlayer, 0, false, true)
            end
        )
        if success and myActivePets then
            for _, pet in pairs(myActivePets) do
                if pet.UUID == uuid then
                    return true
                end
            end
        end
    end
    return false
end
local function change_loadout(Slot)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local PetsService = ReplicatedStorage:WaitForChild("GameEvents"):WaitForChild("PetsService")

    -- Change this number to the loadout slot you want (1, 2, 3, etc.)
    PetsService:FireServer("SwapPetLoadout", Slot)
    print("Request sent to swap to Loadout " .. Slot)
end
-- // Core Logic: Auto Leveling (Batch) // --
local function check_loadout()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local DataService = require(ReplicatedStorage.Modules.DataService)

    -- Get the full data table
    local PlayerData = DataService:GetData()

    -- Access the specific path found in the decompiled code
    if PlayerData and PlayerData.PetsData then
        local currentLoadout = PlayerData.PetsData.SelectedPetLoadout or 1
        print("You are currently on Loadout: " .. currentLoadout)
        return currentLoadout
    end
    return 1
end
local function start_leveling()
    task.spawn(
        function()
            if not PetUtilities then
                return
            end

            local success, myActivePets =
                pcall(
                function()
                    return PetUtilities:GetPetsSortedByAge(LocalPlayer, 0, false, true)
                end
            )
            print(success, myActivePets, #myActivePets)
            if success and myActivePets then
                if check_loadout() ~= 1 then
                    Rayfield:Notify(
                        {
                            Title = "Auto Level",
                            Content = "Switching to Loadout 1 for leveling...",
                            Duration = 3
                        }
                    )
                    change_loadout(1)
                end
                print("Current Mode:", getgenv().Mode)
                if getgenv().Mode == "leveling" then
                    for index, value in ipairs(selectedPets) do
                        if not check_pet_active(getgenv().InventoryMap[value]) then
                            print("Placing pet for leveling:", getgenv().InventoryMap[value], value)
                            place_pet(getgenv().InventoryMap[value])
                            task.wait(0.2)
                        end
                    end
                    local allReady = true
                    local activeCount = 0

                    for _, pet in pairs(myActivePets) do
                        if not check_blacklist(pet.UUID) then
                            activeCount = activeCount + 1
                            local weight = tonumber(calculate_weight(pet)) or 0
                            print("Checking pet:", pet.UUID, "Weight:", weight, pet.PetData.Level, pet.PetData.Name)
                            if weight < weight_to_remove then
                                allReady = false
                            end
                        end
                    end

                    -- 2. Only unequip/swap if ALL are ready and we have active pets
                    if allReady and activeCount > 0 then
                        Rayfield:Notify(
                            {
                                Title = "Auto Level",
                                Content = "All pets reached target weight. Swapping...",
                                Duration = 3
                            }
                        )

                        -- Unequip Active Pets
                        for _, pet in pairs(selectedPets) do
                            local uuid = getgenv().InventoryMap[pet]
                            if PetsService and uuid then
                                print("Unequipping pet UUID:", uuid, pet)
                                PetsService:UnequipPet(uuid)
                            end
                            task.wait(0.1)
                        end

                        task.wait(0.5)

                        getgenv().Mode = "reseting"
                    end
                elseif getgenv().Mode == "reseting" then
                    if check_loadout() ~= 2 then
                        Rayfield:Notify(
                            {
                                Title = "Auto Level",
                                Content = "Switching to Loadout 2 for resetting...",
                                Duration = 3
                            }
                        )
                        change_loadout(2)
                        task.wait(2)
                    end
                    local success, myActivePets =
                pcall(
                function()
                    return PetUtilities:GetPetsSortedByAge(LocalPlayer, 0, false, true)
                end
            )
            if success and myActivePets then
                    local allreset = true

                    task.wait(0.5)
                        for index, value in ipairs(selectedPets) do
                            if not check_pet_active(getgenv().InventoryMap[value]) then
                                print("Placing pet for leveling:", getgenv().InventoryMap[value], value)
                                place_pet(getgenv().InventoryMap[value])
                                task.wait(0.2)
                            end
                        end
                    for _, fullString in pairs(selectedPets) do
                        -- if equippedCount >= 4 then break end -- Safety limit (max equip slot usually 4-5)

                        local uuid = getgenv().InventoryMap[fullString]
                        print("Checking reset pet:", uuid, fullString,myActivePets[uuid])
                        if myActivePets[uuid] then
                            print("Checking if pet needs leveling:", uuid, fullString,myActivePets[uuid].pet.PetData.Level,allreset)
                            if myActivePets[uuid].pet.PetData and (myActivePets[uuid].pet.PetData.Level or 1) > 1 then
                                allreset = false
                            end
                        end
                    end
                    if allreset then
                        getgenv().Mode = "leveling"
                        for _, pet in pairs(selectedPets) do
                            local uuid = getgenv().InventoryMap[pet]
                            if PetsService and uuid then
                                print("Unequipping pet UUID:", uuid, pet)
                                PetsService:UnequipPet(uuid)
                            end
                            task.wait(0.1)
                        end
                    end
                end
                end
            end
        end
    )
end

-- // GUI Elements // --

local PetDropdown
local BlacklistDropdown

local function CreateDropdowns()
    -- Use pcall here so if refresh fails, the UI still creates the dropdown (empty)
    local list = {}
    local s, e =
        pcall(
        function()
            list = refreshPetData()
        end
    )
    if not s then
        warn("Data Refresh Error: " .. tostring(e))
        list = {"Error loading pets (Check Console)"}
    end

    PetDropdown =
        Tab:CreateDropdown(
        {
            Name = "Inventory (Select pets to Equip)",
            Options = list,
            CurrentOption = {},
            MultipleOptions = true,
            Flag = "PetDropdown",
            Callback = function(Option)
                selectedPets = Option
            end
        }
    )

    Tab:CreateSection("Blacklist Settings")

    BlacklistDropdown =
        Tab:CreateDropdown(
        {
            Name = "Blacklist (Select pets to IGNORE)",
            Options = list,
            CurrentOption = {},
            MultipleOptions = true,
            Flag = "BlacklistDropdown",
            Callback = function(Option)
                getgenv().blacklistedUUIDs = {}
                for _, selectedString in pairs(Option) do
                    local uuid = getgenv().InventoryMap[selectedString]
                    if uuid then
                        table.insert(getgenv().blacklistedUUIDs, uuid)
                    end
                end
            end
        }
    )
end

CreateDropdowns()

Tab:CreateButton(
    {
        Name = "Refresh Lists",
        Callback = function()
            local newList = refreshPetData()
            PetDropdown:Refresh(newList, true)
            BlacklistDropdown:Refresh(newList, true)
        end
    }
)

Tab:CreateSection("Automation Settings")

Tab:CreateInput(
    {
        Name = "Target Weight (KG)",
        PlaceholderText = "Example: 10",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            local num = tonumber(Text)
            if num then
                weight_to_remove = num
            end
        end
    }
)

Tab:CreateToggle(
    {
        Name = "Start Auto Leveling",
        CurrentValue = false,
        Flag = "AutoLevelToggle",
        Callback = function(Value)
            getgenv().Leveling = Value
            if Value then
                task.spawn(
                    function()
                        while getgenv().Leveling do
                            start_leveling()
                            task.wait(1.5)
                        end
                    end
                )
            end
        end
    }
)
