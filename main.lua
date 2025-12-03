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

-- // Helper Functions // --
local function select_pet(name)
    -- name = name:match("^%s*(.-)%s*$") -- Trim spasi
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

local function start_leveling()
    local playerGui = LocalPlayer_upvr:FindFirstChild("PlayerGui")
    if not playerGui or not playerGui:FindFirstChild("ActivePetUI") then return end

    -- Buka Sensor UI jika belum terbuka
    local sensor = playerGui.ActivePetUI.Frame.Opener:FindFirstChild("SENSOR")
    if sensor then
        firesignal(sensor.MouseButton1Click)
        task.wait(1)
    end

    local scrollFrame = playerGui.ActivePetUI.Frame.Main.PetDisplay.ScrollingFrame
    
    for _, frame_weight in pairs(scrollFrame:GetChildren()) do
        if frame_weight:FindFirstChild("Dropdown") and tostring(frame_weight):find("{") then
            
            local tombolView = frame_weight.Dropdown.Main.Main.VIEW_BUTTON.Holder.Main:FindFirstChildWhichIsA("TextButton")
            
            if tombolView then
                firesignal(tombolView.Activated)
                task.wait(0.5)

                -- Safe UI Finding
                local statsHolder = playerGui.PetUI.PetCard.Main.Holder.Stats.Holder
                if not statsHolder then return end
                
                -- Pastikan index child benar (kadang urutan berubah)
                local weightLabel = nil
                for _, child in pairs(statsHolder:GetChildren()) do
                    if child:FindFirstChild("PET_WEIGHT") then
                        weightLabel = child
                        break
                    end
                end
                
                if not weightLabel then return end

                local weightText = weightLabel.PET_WEIGHT.Text
                local weight = tonumber(string.match(tostring(weightText), "%d+%.?%d*"))
                
                local nameRaw = playerGui.PetUI.PetCard.Main.Holder.Header.PET_TEXT.Text
                local clean = nameRaw:gsub("<[^>]->", "")
                local nameClean = clean:match("^(%S+)")

                if weight and weight >= weight_to_remove then
                    Rayfield:Notify({
                        Title = "Auto Level",
                        Content = "Removing " .. (nameClean or "Pet") .. " (" .. weight .. "kg)",
                        Duration = 2
                    })

                    local tombolPickup = frame_weight.Dropdown.Main.Main.PICKUP_BUTTON.Holder.Main:FindFirstChildWhichIsA("TextButton")
                    print(tombolPickup)
                    if tombolPickup then
                        firesignal(tombolPickup.Activated)
                        task.wait(0.5)
                        
                        print("Attempting to place pet...")
                        -- FIX LOGIC LOOP
                        for _, fullString in pairs(selectedPets) do
                            print(fullString)

                            local realName = fullString:match("^(.-)%s*%[") or fullString
                            print("realName" ..realName)
                            -- realName = realName:gsub("%s+$", "")

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
    end
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
