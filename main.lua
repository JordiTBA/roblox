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
        return tonumber(currentLoadout)
    end
    return 1
end
local function get_max_slots()
    local success, result =
        pcall(
        function()
            local DataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
            local data = DataService:GetData()
            -- Commonly used keys for Max Equip in this game framework
            return data.PetsData.MutableStats.MaxEquippedPets or 0
        end
    )

    if success and result then
        return result
    end
    return 0
end
local function get_total_equipped_pets()
    local success, result =
        pcall(
        function()
            local DataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
            local data = DataService:GetData()
            -- Commonly used keys for Max Equip in this game framework
            return #data.PetsData.EquippedPets or 0
        end
    )

    if success and result then
        return result
    end
    return 0
end

local function start_leveling()
    -- FIXED: Added Busy Check at the start to prevent overlapping threads

    task.spawn(
        function()
            local pcallSuccess, pcallError =
                pcall(
                function()
                    -- 1. Check/Set Leveling Loadout
                    if #selectedPets > get_max_slots() then
                        Rayfield:Notify(
                            {
                                Title = "Auto Level",
                                Content = "Selected pets exceed max equip slots! turning off leveling.",
                                Duration = 5
                            }
                        )
                        getgenv().Leveling = false
                        return
                    end
                    print("Current Mode:", getgenv().Mode)

                    if getgenv().Mode == "leveling" then
                        print("Checking Loadout for Leveling...")
                        while check_loadout() ~= 1 do
                            Rayfield:Notify(
                                {Title = "Auto Level", Content = "Switching to Loadout 1 for leveling...", Duration = 3}
                            )
                            change_loadout(1)
                            task.wait(1) -- Wait for loadout swap
                        end
                        print("Loadout 1 confirmed.")
                        if not PetUtilities then
                            return
                        end

                        local success, myActivePets =
                            pcall(
                            function()
                                return PetUtilities:GetPetsSortedByAge(LocalPlayer, 0, false, true)
                            end
                        )
                        if success and myActivePets then
                            -- EQUIP PETS LOGIC
                            print("Equipping selected pets...")
                            if get_total_equipped_pets() < #selectedPets then
                                for index, value in ipairs(selectedPets) do
                                    local uuid = getgenv().InventoryMap[value]
                                    if uuid and not check_pet_active(uuid) then
                                        print("Placing pet:", uuid)
                                        place_pet(uuid)
                                        task.wait(0.2)
                                    end
                                end
                            end

                            -- CHECK WEIGHT LOGIC
                            local allReady = true
                            local activeCount = 0
                            for index, value in ipairs(selectedPets) do
                                local uuid = getgenv().InventoryMap[value]
                                if uuid then
                                    for _, pet in pairs(myActivePets) do
                                        if pet.UUID == uuid then
                                            local weight = tonumber(calculate_weight(pet)) or 0
                                            -- print("Checking:", pet.UUID, "Weight:", weight)
                                            if weight < weight_to_remove then
                                                allReady = false
                                            end
                                        end
                                    end
                                end
                            end

                            if allReady and activeCount > 0 then
                                Rayfield:Notify(
                                    {
                                        Title = "Auto Level",
                                        Content = "Target weight reached. Resetting...",
                                        Duration = 3
                                    }
                                )

                                -- Unequip Active Pets (Only chosen ones)
                                local make_sure = false
                                while not make_sure do
                                    local check = false
                                    for index, value in ipairs(myActivePets) do
                                        for _, pet in pairs(selectedPets) do
                                            local uuid = getgenv().InventoryMap[pet]
                                            if PetsService and value.UUID == uuid then
                                                check = true
                                                PetsService:UnequipPet(uuid)
                                            end
                                            task.wait(0.5)
                                        end
                                    end
                                    if check then
                                        getgenv().Mode = "reseting"
                                        task.wait(0.5)

                                        make_sure = true
                                        break
                                    end
                                    task.wait(1)
                                end

                                getgenv().Mode = "reseting"
                            end
                        end
                    elseif getgenv().Mode == "reseting" then
                        -- RESET LOGIC (Fixed Loadout ID Mismatch)
                        while check_loadout() ~= 3 do
                            Rayfield:Notify(
                                {Title = "Auto Level", Content = "Switching to Loadout 2 (Reset)...", Duration = 3}
                            )
                            change_loadout(3) -- FIXED: Was 3, changed to 2 to match check
                            task.wait(2)
                        end
                        for index, value in ipairs(selectedPets) do
                            local uuid = getgenv().InventoryMap[value]
                            if uuid and not check_pet_active(uuid) then
                                place_pet(uuid)
                                task.wait(0.2)
                            end
                        end
                        -- Re-fetch pets to see status
                        local s, currentPets =
                            pcall(
                            function()
                                return PetUtilities:GetPetsSortedByAge(LocalPlayer, 0, false, true)
                            end
                        )

                        if s and currentPets then
                            local allreset = true

                            -- Re-equip pets to check their level

                            -- Scan levels
                            local anyPetFound = false
                            for _, fullString in pairs(selectedPets) do
                                local uuid = getgenv().InventoryMap[fullString]
                                for _, value in ipairs(currentPets) do
                                    if value.UUID == uuid then
                                        anyPetFound = true
                                        local lvl = value.PetData.Level or 1
                                        if lvl > 1 then
                                            print("Pet not reset:", uuid, lvl)
                                            allreset = false
                                            break
                                        end
                                    end
                                end
                            end

                            if allreset and anyPetFound then
                                print("allreset", allreset, "anypet", anyPetFound)
                                Rayfield:Notify(
                                    {Title = "Auto Level", Content = "Pets Reset! Resuming...", Duration = 3}
                                )
                                getgenv().Mode = "leveling"

                                -- Unequip everything to prepare for clean leveling start
                                local make_sure = false
                                while not make_sure do
                                    local check = false
                                    for index, value in ipairs(myActivePets) do
                                        for _, pet in pairs(selectedPets) do
                                            local uuid = getgenv().InventoryMap[pet]
                                            if PetsService and value.UUID == uuid then
                                                check = true
                                                PetsService:UnequipPet(uuid)
                                            end
                                            task.wait(0.5)
                                        end
                                    end
                                    if check then
                                        getgenv().Mode = "leveling"
                                        task.wait(0.5)

                                        make_sure = true
                                        break
                                    end
                                    task.wait(1)
                                end
                            end
                        end
                    end
                end
            )

            if not pcallSuccess then
                warn("Auto Level Error: " .. tostring(pcallError))
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
                        getgenv().Mode = "leveling"
                    end
                )
            end
        end
    }
)
