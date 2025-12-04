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
getgenv().InventoryMap = {} 
getgenv().Mode = "leveling"
local Window =
    Rayfield:CreateWindow(
    {
        Name = "Pet Manager GUI",
        LoadingTitle = "Loading...",
        ConfigurationSaving = {Enabled = false}
    }
)

local Tab = Window:CreateTab("Main", 4483362458)

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local CurrentCamera = Workspace.CurrentCamera

local PetUtilities, PetsService
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
end
local function check_loadout()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local DataService = require(ReplicatedStorage.Modules.DataService)
    local PlayerData = DataService:GetData()
    if PlayerData and PlayerData.PetsData then
        local currentLoadout = PlayerData.PetsData.SelectedPetLoadout or 1
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
            return #data.PetsData.EquippedPets or 0
        end
    )

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

                    if getgenv().Mode == "leveling" then
                        while check_loadout() ~= 1 do
                            Rayfield:Notify(
                                {Title = "Auto Level", Content = "Switching to Loadout 1 for leveling...", Duration = 3}
                            )
                            change_loadout(1)
                            task.wait(1) -- Wait for loadout swap
                        end
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
                            if get_total_equipped_pets() < #selectedPets then
                                for index, value in ipairs(selectedPets) do
                                    local uuid = getgenv().InventoryMap[value]
                                    if uuid and not check_pet_active(uuid) then
                                        place_pet(uuid)
                                        task.wait(0.2)
                                    end
                                end
                            end

                            local allReady = true
                            for index, value in ipairs(selectedPets) do
                                local uuid = getgenv().InventoryMap[value]
                                if uuid then
                                    for _, pet in pairs(myActivePets) do
                                        if pet.UUID == uuid then
                                            local weight = tonumber(calculate_weight(pet)) or 0
                                            if weight < weight_to_remove then
                                                allReady = false
                                            end
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
                            for _, fullString in pairs(selectedPets) do
                                local uuid = getgenv().InventoryMap[fullString]
                                for _, value in ipairs(currentPets) do
                                    if value.UUID == uuid then
                                        anyPetFound = true
                                        local lvl = value.PetData.Level or 1
                                        if lvl > 1 then
                                            allreset = false
                                            break
                                        end
                                    end
                                end
                            end

                            if allreset and anyPetFound then
                                Rayfield:Notify(
                                    {Title = "Auto Level", Content = "Pets Reset! Resuming...", Duration = 3}
                                )
                                getgenv().Mode = "leveling"

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

Tab:CreateSection("Automation Settings")

Tab:CreateInput(
    {
        Name = "Target Weight (KG)",
        PlaceholderText = "Example: 10",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            local num = tonumber(Text)
            if num then
                Rayfield:Notify(
                    {
                        Title = "Target Weight Set",
                        Content = "Target weight set to " .. tostring(num) .. "kg.",
                        Duration = 3
                    }
                )
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
                getgenv().Mode = "leveling"
            end
        end
    }
)
