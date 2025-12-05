--
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
local PetUtilities, PetList_Data, PetsService
local ModulesLoaded, LoadError =
    pcall(
    function()
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
    end 

    local rayResult = ScreenRaycast()
    if not rayResult then
        return
    end

    local pos = rayResult.Position
    local cframe = CFrame.new(pos.X, pos.Y, pos.Z)

    pcall(
        function()
            PetsService:EquipPet(UUID, cframe)
        end
    )
end

local function calculate_weight(petData)
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
        return "0.00" 
    end
end

-- Removed function check_blacklist(UUID)

-- // Core Logic: Refresh Data // --
local function refreshPetData()
    local displayList = {}
    getgenv().InventoryMap = {} 

    local function addPetToList(petData, isEquipped)
        local uuid = "NoUUID"
        local full = "Unnamed"
        local level = 1

        if typeof(petData) == "Instance" then
            uuid = petData:GetAttribute("PET_UUID") or petData:GetAttribute("UUID") or "NoUUID"
            full = petData.Name

            local lvlAttr = petData:GetAttribute("Level")
            local lvlMatch = full:match("Level%s*(%d+)") or full:match("Lvl%s*(%d+)") or full:match("Age%s*(%d+)")
            level = lvlAttr or (lvlMatch and tonumber(lvlMatch)) or 1
        elseif type(petData) == "table" then
            uuid = petData.UUID or "NoUUID"
            full = petData.Name or (petData.PetData and petData.PetData.Name) or "Unnamed"
            level = petData.PetData and petData.PetData.Level or 1
        end

        local name = full:match("^(.-)%s*%[") or full

        local status = ""
        local shortUUID = tostring(uuid):sub(1, 6)
        local displayString = string.format("%s{%s} Level %s %s", status, shortUUID, level, name)

        getgenv().InventoryMap[displayString] = uuid
        table.insert(displayList, displayString)
    end

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

    PetsService:FireServer("SwapPetLoadout", Slot)
    print("Request sent to swap to Loadout " .. Slot)
end

-- // Core Logic: Auto Leveling (Batch) // --
local function check_loadout()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local DataService = require(ReplicatedStorage.Modules.DataService)

    local PlayerData = DataService:GetData()

    if PlayerData and PlayerData.PetsData then
        local currentLoadout = PlayerData.PetsData.SelectedPetLoadout or 1
        print("You are currently on Loadout: " .. currentLoadout)
        return tonumber(currentLoadout)
    end
    return 1
end

local function get_max_slots()
    local success, result = pcall(function()
        local DataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
        local data = DataService:GetData()
        return data.PetsData.MutableStats.MaxEquippedPets or 0
    end)
    
    if success and result then
        return result
    end
    return 0
end

local function get_total_equipped_pets()
    local success, result = pcall(function()
        local DataService = require(game:GetService("ReplicatedStorage").Modules.DataService)
        local data = DataService:GetData()
        return #data.PetsData.EquippedPets or 0
    end)
    
    if success and result then
        return result
    end
    return 0
end

local function start_leveling()
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
                            task.wait(1) 
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
                                for index, value in ipairs(selectedPets) do
                                    local uuid = getgenv().InventoryMap[value]
                                    if uuid and not check_pet_active(uuid) then
                                        print("Placing pet:", uuid)
                                        place_pet(uuid)
                                        task.wait(0.2)
                                    end
                                end

                            print("Checking pet weights...")
                            -- CHECK WEIGHT LOGIC
                            -- local allReady = true
                            -- for index, value in ipairs(selectedPets) do
                            --     local uuid = getgenv().InventoryMap[value]
                            --     if uuid then
                            --         for _, pet in pairs(myActivePets) do
                            --             if pet.UUID == uuid then
                            --                 local weight = tonumber(calculate_weight(pet))
                            --                 print("Checking:", pet.UUID, "Weight:", weight)
                            --                 if weight and weight < weight_to_remove then
                            --                     allReady = false
                            --                 end
                            --             end
                            --         end
                            --     end
                            -- end
                                                        local                                         allReady = true

                            for _, fullString in pairs(selectedPets) do
                                local uuid = getgenv().InventoryMap[fullString]
                                for _, value in ipairs(myActivePets) do
                                    if value.UUID == uuid then
                                        local lvl = value.PetData.Level or 1
                                        if lvl < 40 then
                                            print("Pet not reset:", uuid, lvl)
                                            allReady = false
                                            break
                                        end
                                    end
                                end
                            end

                            if allReady then
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
                        while check_loadout() ~= 3 do
                            Rayfield:Notify(
                                {Title = "Auto Level", Content = "Switching to Loadout 2 (Reset)...", Duration = 3}
                            )
                            change_loadout(3) 
                            task.wait(2)
                        end
                        for index, value in ipairs(selectedPets) do
                                    local uuid = getgenv().InventoryMap[value]
                                    if uuid and not check_pet_active(uuid) then
                                        print("Placing pet:", uuid)
                                        place_pet(uuid)
                                        task.wait(0.2)
                                    end
                                end
                        local s, currentPets =
                            pcall(
                            function()
                                return PetUtilities:GetPetsSortedByAge(LocalPlayer, 0, false, true)
                            end
                        )

                        if s and currentPets then
                            local allreset = true

                            local anyPetFound = false
                            for i, fullString in pairs(selectedPets) do
                                local uuid = getgenv().InventoryMap[fullString]
                                for _, value in ipairs(currentPets) do
                                    if value.UUID == uuid then
                                        anyPetFound = true
                                        local lvl = value.PetData.Level or 1
                                        local weight = tonumber(calculate_weight(value))
                                        if lvl == 1 and weight >= 6.1 then
                                            table.remove(selectedPets, i)
                                            Rayfield:Notify(
                                                {
                                                    Title = "Auto Level",
                                                    Content = "Pet " .. fullString .. " fully reset and removed from list.",
                                                    Duration = 4
                                                }
                                            )
                                        end
                                        if lvl > 2 then
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
-- Removed Local BlacklistDropdown

local function CreateDropdowns()
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

    -- Removed Blacklist Section and Dropdown Logic
end

CreateDropdowns()

Tab:CreateButton(
    {
        Name = "Refresh Lists",
        Callback = function()
            local newList = refreshPetData()
            PetDropdown:Refresh(newList, true)
            -- Removed BlacklistDropdown:Refresh call
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
                Rayfield:Notify(
                    {
                        Title = "Auto Level",
                        Content = "Auto Leveling Started.",
                        Duration = 3
                    }
                )
                task.spawn(
                    function()
                        while getgenv().Leveling do
                            start_leveling()
                            task.wait(1.5)
                        end
                    end
                )
            else
                Rayfield:Notify(
                    {
                        Title = "Auto Level",
                        Content = "Auto Leveling Stopped.",
                        Duration = 3
                    }
                )
                print("Auto Leveling Stopped.")
                getgenv().Mode = "leveling"
            end
        end
    }
)
