local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
getgenv().Leveling = false

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
local petsFolder = game.Players.LocalPlayer.Backpack
local petList = {}
local selectedPets = {}
local weight_to_remove = 10 -- Default value
local Workspace_upvr = game:GetService("Workspace")
local UserInputService_upvr = game:GetService("UserInputService")
local LocalPlayer_upvr = game:GetService("Players").LocalPlayer
local CurrentCamera_upvr = Workspace_upvr.CurrentCamera

-- // Helper Functions // --

local function select_pet(name)
    for index, pets in pairs(game:GetService("Players").LocalPlayer.Backpack:GetChildren()) do
        if pets:GetAttribute("PetType") and pets.Name == name then
            return pets:GetAttribute("PET_UUID")
        end
    end
    return nil
end

local function ScreenRaycast_upvr()
    local RaycastParams_new_result1 = RaycastParams.new()
    RaycastParams_new_result1.FilterType = Enum.RaycastFilterType.Exclude
    RaycastParams_new_result1.FilterDescendantsInstances = {LocalPlayer_upvr.Character}
    local any_GetMouseLocation_result1 = UserInputService_upvr:GetMouseLocation()
    local any_ViewportPointToRay_result1 =
        CurrentCamera_upvr:ViewportPointToRay(any_GetMouseLocation_result1.X, any_GetMouseLocation_result1.Y)
    return Workspace_upvr:Raycast(
        any_ViewportPointToRay_result1.Origin,
        any_ViewportPointToRay_result1.Direction * 1000,
        RaycastParams_new_result1
    )
end

local function place_pet(UUID)
    local ScreenRaycast_result1 = ScreenRaycast_upvr()
    if not ScreenRaycast_result1 then
        return
    end

    local Position_2 = ScreenRaycast_result1.Position
    local cframe = CFrame.new(Position_2.X, Position_2.Y, Position_2.Z)

    local success, petService =
        pcall(
        function()
            return require(game:GetService("ReplicatedStorage").Modules.PetServices.PetsService)
        end
    )

    if success and petService then
        petService:EquipPet(UUID, cframe)
    end
end

local function start_leveling()
    local playerGui = game:GetService("Players").LocalPlayer.PlayerGui

    if not playerGui:FindFirstChild("ActivePetUI") then
        return
    end

    local sensor = LocalPlayer_upvr.PlayerGui.ActivePetUI.Frame.Opener.SENSOR

    if sensor then
        firesignal(sensor.MouseButton1Click)
        task.wait(1)
    end

    local scrollFrame = LocalPlayer_upvr.PlayerGui.ActivePetUI.Frame.Main.PetDisplay.ScrollingFrame
    for _, frame_weight in pairs(scrollFrame:GetChildren()) do
        if frame_weight:FindFirstChild("Dropdown") and tostring(frame_weight):find("{") then
            local tombolView =
                frame_weight.Dropdown.Main.Main.VIEW_BUTTON.Holder.Main:FindFirstChildWhichIsA("TextButton")
            if tombolView then
                firesignal(tombolView.Activated)
                task.wait(0.5)

                local weightText =
                    game:GetService("Players").LocalPlayer.PlayerGui.PetUI.PetCard.Main.Holder.Stats.Holder:GetChildren(

                )[5].PET_WEIGHT.Text

                local weight = tonumber(string.match(tostring(weightText), "%d+%.?%d*"))
                local nameRaw =
                    game:GetService("Players").LocalPlayer.PlayerGui.PetUI.PetCard.Main.Holder.Header.PET_TEXT.Text
                print("Raw pet name:", nameRaw)
                local clean = nameRaw:gsub("<[^>]->", "")
                local nameClean = clean:match("^(%S+)")
                print("Checking pet:", nameClean, "with weight:", weight)
                if weight and weight >= weight_to_remove then
                    Rayfield:Notify(
                        {
                            Title = "Auto Level",
                            Content = "Removing " .. nameClean and nameClean or "Pet" .. " (" .. weight .. "kg)",
                            Duration = 2
                        }
                    )

                    local tombolPickup =
                        frame_weight.Dropdown.Main.Main.PICKUP_BUTTON.Holder.Main:FindFirstChildWhichIsA("TextButton")
                    if tombolPickup then
                        firesignal(tombolPickup.Activated)
                        task.wait(0.5)
                        print("finding pets")
                        for _, fullString in pairs(selectedPets) do
                            local petUUID = select_pet(fullString)
                            print("Selected Pet UUID:", petUUID)
                            if petUUID then
                                print("Placing pet:", nameClean)
                                place_pet(petUUID)
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end

local function refreshPetData()
    petList = {}
    local counts = {}

    for _, pet in pairs(petsFolder:GetChildren()) do
        if pet:GetAttribute("PetType") then
            local full = pet.Name
            local name = full:match("^(.-)%s*%[") or full
            local weight = full:match("%[(.-)%s*KG%]")
            weight = weight and tonumber(weight) or nil
            local age = full:match("%[Age%s*(%d+)%]")
            age = age and tonumber(age) or nil
            -- local name = full:match("^(.-)%s*%[") or full
            if weight < weight_to_remove then
                goto continue
            end
            if age == 1 and weight >= 6.6 then
                goto continue
            end
            table.insert(petList, {Name = name, Instance = pet})
            counts[name] = (counts[name] or 0) + 1
        end
        ::continue::
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
    PetDropdown =
        Tab:CreateDropdown(
        {
            Name = "Inventory Pets",
            Options = list,
            CurrentOption = {},
            MultipleOptions = true,
            Flag = "PetDropdown",
            Callback = function(Option)
                selectedPets = Option
            end
        }
    )
end

CreateDropdown()

Tab:CreateButton(
    {
        Name = "Refresh Pet List",
        Callback = function()
            local newList = refreshPetData()
            PetDropdown:Refresh(newList, true)
        end
    }
)

Tab:CreateSection("Automation Settings")

-- [NEW] Input Box untuk Weight (Ganti Slider)
Tab:CreateInput(
    {
        Name = "Weight to Remove (KG)",
        PlaceholderText = "Input Number (e.g. 10)",
        RemoveTextAfterFocusLost = false,
        Callback = function(Text)
            -- Konversi text ke number
            local numberValue = tonumber(Text)
            if numberValue then
                weight_to_remove = numberValue
                print("Weight set to:", weight_to_remove)
            else
                Rayfield:Notify({Title = "Error", Content = "Please enter a valid number!", Duration = 3})
            end
        end
    }
)

-- [TOGGLE] Auto Leveling
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
