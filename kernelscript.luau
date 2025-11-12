--[[
MIT License

Copyright (c) 2025 compiledkernel-idk

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]

local VERSION = "3.1.0"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

repeat task.wait() until LocalPlayer.Character
repeat task.wait() until LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

print("[SYSTEM] Initializing Stealth Wallbang System v" .. VERSION)
print("[SYSTEM] Copyright (c) 2025 compiledkernel-idk")

local Config = {
    Enabled = false,
    FOV = 400,
    Smoothness = 0,
    Prediction = true,
    PredictionStrength = 0.165,
    TargetPart = "Head",
    Wallbang = false,
    ESP = true,
    ShowFOVCircle = true,
    SpeedHack = false,
    SpeedValue = 16,
    ESPBoxes = true,
    ESPTracers = true,
    ESPDistance = true,
    ESPHealth = true,
    FOVRainbow = false,
}

local Target = nil
local Locked = false
local Highlights = {}
local ESPObjects = {}
local VelocityData = {}
local WallbangActive = false
local OriginalWalkSpeed = 16

local function IsPlayerPart(part)
    if not part then return false end
    
    local current = part
    for i = 1, 10 do
        if not current then break end
        
        if current:IsA("Model") then
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character == current then
                    return true
                end
            end
        end
        
        current = current.Parent
    end
    
    return false
end

local function GetPlayerFromPart(part)
    if not part then return nil end
    
    local current = part
    for i = 1, 10 do
        if not current then break end
        
        if current:IsA("Model") then
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character == current then
                    return player
                end
            end
        end
        
        current = current.Parent
    end
    
    return nil
end

local oldFindPartOnRay
local oldFindPartOnRayWithIgnoreList
local oldFindPartOnRayWithWhitelist
local oldRaycast

local function SetupStealthHooks()
    task.spawn(function()
        pcall(function()
            if hookfunction then
                oldFindPartOnRay = hookfunction(workspace.FindPartOnRay, function(self, ray, ignoreDescendantsInstance, terrainCellsAreCubes, ignoreWater)
                    if not WallbangActive or checkcaller() then
                        return oldFindPartOnRay(self, ray, ignoreDescendantsInstance, terrainCellsAreCubes, ignoreWater)
                    end
                    
                    local ignore = ignoreDescendantsInstance
                    
                    for i = 1, 150 do
                        local part, position, normal, material = oldFindPartOnRay(self, ray, ignore, terrainCellsAreCubes, ignoreWater)
                        
                        if not part then
                            return nil, position, normal, material
                        end
                        
                        local player = GetPlayerFromPart(part)
                        if player and player ~= LocalPlayer then
                            return part, position, normal, material
                        end
                        
                        ignore = part
                    end
                    
                    return nil, nil, nil, nil
                end)
                
                print("[HOOK] FindPartOnRay hooked")
            end
            
            if hookfunction then
                oldFindPartOnRayWithIgnoreList = hookfunction(workspace.FindPartOnRayWithIgnoreList, function(self, ray, ignoreList, terrainCellsAreCubes, ignoreWater)
                    if not WallbangActive or checkcaller() then
                        return oldFindPartOnRayWithIgnoreList(self, ray, ignoreList, terrainCellsAreCubes, ignoreWater)
                    end
                    
                    local ignore = ignoreList or {}
                    
                    for i = 1, 150 do
                        local part, position, normal, material = oldFindPartOnRayWithIgnoreList(self, ray, ignore, terrainCellsAreCubes, ignoreWater)
                        
                        if not part then
                            return nil, position, normal, material
                        end
                        
                        local player = GetPlayerFromPart(part)
                        if player and player ~= LocalPlayer then
                            return part, position, normal, material
                        end
                        
                        table.insert(ignore, part)
                    end
                    
                    return nil, nil, nil, nil
                end)
                
                print("[HOOK] FindPartOnRayWithIgnoreList hooked")
            end
            
            if hookfunction then
                oldRaycast = hookfunction(workspace.Raycast, function(self, origin, direction, params)
                    if not WallbangActive or checkcaller() then
                        return oldRaycast(self, origin, direction, params)
                    end
                    
                    local rayParams = params or RaycastParams.new()
                    
                    for i = 1, 150 do
                        local result = oldRaycast(self, origin, direction, rayParams)
                        
                        if not result then
                            return nil
                        end
                        
                        local player = GetPlayerFromPart(result.Instance)
                        if player and player ~= LocalPlayer then
                            return result
                        end
                        
                        local ignoreList = rayParams.FilterDescendantsInstances or {}
                        table.insert(ignoreList, result.Instance)
                        rayParams.FilterDescendantsInstances = ignoreList
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                    end
                    
                    return nil
                end)
                
                print("[HOOK] Raycast hooked")
            end
        end)
    end)
end

SetupStealthHooks()

local function IsAlive(player)
    return player and player.Character and 
           player.Character:FindFirstChild("HumanoidRootPart") and
           player.Character:FindFirstChildOfClass("Humanoid") and
           player.Character:FindFirstChildOfClass("Humanoid").Health > 0
end

local function GetCharacterPart(player, partName)
    if not IsAlive(player) then return nil end
    return player.Character:FindFirstChild(partName)
end

local function WorldToScreen(position)
    local screenPoint, onScreen = Camera:WorldToViewportPoint(position)
    return Vector2.new(screenPoint.X, screenPoint.Y), onScreen
end

local function UpdateVelocityData(player, velocity)
    if not VelocityData[player.UserId] then
        VelocityData[player.UserId] = {velocities = {}}
    end
    
    local data = VelocityData[player.UserId]
    table.insert(data.velocities, velocity)
    
    if #data.velocities > 5 then
        table.remove(data.velocities, 1)
    end
end

local function GetSmoothedVelocity(player)
    local data = VelocityData[player.UserId]
    if not data or #data.velocities == 0 then return Vector3.zero end
    
    local sum = Vector3.zero
    for _, vel in ipairs(data.velocities) do
        sum = sum + vel
    end
    
    return sum / #data.velocities
end

local function CalculatePrediction(player, targetPart)
    if not Config.Prediction or not IsAlive(player) then return Vector3.zero end
    
    local hrp = player.Character.HumanoidRootPart
    local velocity = hrp.AssemblyLinearVelocity or hrp.Velocity or Vector3.zero
    
    UpdateVelocityData(player, velocity)
    local smoothedVel = GetSmoothedVelocity(player)
    
    if smoothedVel.Magnitude < 0.5 then return Vector3.zero end
    
    local distance = (Camera.CFrame.Position - targetPart.Position).Magnitude
    local prediction = smoothedVel * Config.PredictionStrength
    local distanceScale = math.clamp(distance / 100, 0.5, 3)
    
    return prediction * distanceScale
end

local function GetClosestTarget()
    local bestTarget = nil
    local bestDist = math.huge
    
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            local part = GetCharacterPart(player, Config.TargetPart)
            if part then
                local screenPos, onScreen = WorldToScreen(part.Position)
                if onScreen then
                    local dist = (screenPos - screenCenter).Magnitude
                    if dist < Config.FOV and dist < bestDist then
                        bestDist = dist
                        bestTarget = player
                    end
                end
            end
        end
    end
    
    return bestTarget
end

local function AimbotCore()
    if not Config.Enabled then
        Target = nil
        Locked = false
        return
    end
    
    if not Target or not IsAlive(Target) then
        Target = GetClosestTarget()
        Locked = Target ~= nil
    end
    
    if not Target then
        Locked = false
        return
    end
    
    local targetPart = GetCharacterPart(Target, Config.TargetPart)
    if not targetPart then
        Target = nil
        Locked = false
        return
    end
    
    local prediction = CalculatePrediction(Target, targetPart)
    local aimPos = targetPart.Position + prediction
    
    local camCFrame = CFrame.new(Camera.CFrame.Position, aimPos)
    
    if Config.Smoothness <= 0 then
        Camera.CFrame = camCFrame
    else
        Camera.CFrame = Camera.CFrame:Lerp(camCFrame, 1 - Config.Smoothness)
    end
    
    Locked = true
end

local ESPFolder = Instance.new("Folder", CoreGui)
ESPFolder.Name = "ESP_" .. tostring(math.random(1000, 9999))

local function CreateESP(player)
    if player == LocalPlayer or ESPObjects[player] then return end
    
    local objects = {
        Highlight = nil,
        Box = {},
        Tracer = nil,
        Distance = nil,
        Health = nil,
        Name = nil
    }
    
    if Config.ESP then
        local highlight = Instance.new("Highlight")
        highlight.Adornee = player.Character
        highlight.FillColor = Color3.fromRGB(0, 255, 255)
        highlight.FillTransparency = 0.5
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = ESPFolder
        objects.Highlight = highlight
    end
    
    if Config.ESPBoxes then
        for i = 1, 4 do
            local line = Drawing.new("Line")
            line.Thickness = 2
            line.Color = Color3.fromRGB(0, 255, 255)
            line.Transparency = 1
            table.insert(objects.Box, line)
        end
    end
    
    if Config.ESPTracers then
        local tracer = Drawing.new("Line")
        tracer.Thickness = 2
        tracer.Color = Color3.fromRGB(0, 255, 255)
        tracer.Transparency = 1
        objects.Tracer = tracer
    end
    
    if Config.ESPDistance then
        local distance = Drawing.new("Text")
        distance.Size = 14
        distance.Center = true
        distance.Outline = true
        distance.Color = Color3.fromRGB(255, 255, 255)
        distance.Transparency = 1
        objects.Distance = distance
    end
    
    if Config.ESPHealth then
        local health = Drawing.new("Text")
        health.Size = 14
        health.Center = true
        health.Outline = true
        health.Color = Color3.fromRGB(0, 255, 0)
        health.Transparency = 1
        objects.Health = health
    end
    
    local name = Drawing.new("Text")
    name.Size = 14
    name.Center = true
    name.Outline = true
    name.Color = Color3.fromRGB(255, 255, 255)
    name.Transparency = 1
    name.Text = player.Name
    objects.Name = name
    
    ESPObjects[player] = objects
end

local function UpdateESP()
    for player, objects in pairs(ESPObjects) do
        if not IsAlive(player) then
            if objects.Highlight then objects.Highlight:Destroy() end
            for _, line in ipairs(objects.Box) do line:Remove() end
            if objects.Tracer then objects.Tracer:Remove() end
            if objects.Distance then objects.Distance:Remove() end
            if objects.Health then objects.Health:Remove() end
            if objects.Name then objects.Name:Remove() end
            ESPObjects[player] = nil
        else
            local hrp = player.Character.HumanoidRootPart
            local head = player.Character:FindFirstChild("Head")
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            
            if hrp and head and humanoid then
                local screenPos, onScreen = WorldToScreen(hrp.Position)
                local headPos = WorldToScreen(head.Position + Vector3.new(0, 0.5, 0))
                local legPos = WorldToScreen(hrp.Position - Vector3.new(0, 3, 0))
                
                local distance = (Camera.CFrame.Position - hrp.Position).Magnitude
                local healthPercent = humanoid.Health / humanoid.MaxHealth
                
                local isTarget = (player == Target and Locked)
                local color = isTarget and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 255)
                
                if objects.Highlight then
                    objects.Highlight.FillColor = color
                    if objects.Highlight.Adornee ~= player.Character then
                        objects.Highlight.Adornee = player.Character
                    end
                end
                
                if onScreen and Config.ESPBoxes then
                    local size = (headPos - legPos).Magnitude
                    local width = size * 0.5
                    
                    local topLeft = Vector2.new(screenPos.X - width, headPos.Y)
                    local topRight = Vector2.new(screenPos.X + width, headPos.Y)
                    local bottomLeft = Vector2.new(screenPos.X - width, legPos.Y)
                    local bottomRight = Vector2.new(screenPos.X + width, legPos.Y)
                    
                    objects.Box[1].From = topLeft
                    objects.Box[1].To = topRight
                    objects.Box[1].Color = color
                    objects.Box[1].Visible = true
                    
                    objects.Box[2].From = topRight
                    objects.Box[2].To = bottomRight
                    objects.Box[2].Color = color
                    objects.Box[2].Visible = true
                    
                    objects.Box[3].From = bottomRight
                    objects.Box[3].To = bottomLeft
                    objects.Box[3].Color = color
                    objects.Box[3].Visible = true
                    
                    objects.Box[4].From = bottomLeft
                    objects.Box[4].To = topLeft
                    objects.Box[4].Color = color
                    objects.Box[4].Visible = true
                else
                    for _, line in ipairs(objects.Box) do
                        line.Visible = false
                    end
                end
                
                if Config.ESPTracers and objects.Tracer then
                    local screenBottom = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    objects.Tracer.From = screenBottom
                    objects.Tracer.To = screenPos
                    objects.Tracer.Color = color
                    objects.Tracer.Visible = onScreen
                end
                
                if Config.ESPDistance and objects.Distance then
                    objects.Distance.Text = string.format("%d studs", math.floor(distance))
                    objects.Distance.Position = Vector2.new(screenPos.X, legPos.Y + 20)
                    objects.Distance.Visible = onScreen
                end
                
                if Config.ESPHealth and objects.Health then
                    objects.Health.Text = string.format("HP: %d/%d", math.floor(humanoid.Health), math.floor(humanoid.MaxHealth))
                    objects.Health.Position = Vector2.new(screenPos.X, headPos.Y - 20)
                    objects.Health.Color = Color3.fromRGB(
                        math.floor(255 * (1 - healthPercent)),
                        math.floor(255 * healthPercent),
                        0
                    )
                    objects.Health.Visible = onScreen
                end
                
                if objects.Name then
                    objects.Name.Position = Vector2.new(screenPos.X, headPos.Y - 35)
                    objects.Name.Visible = onScreen
                    objects.Name.Color = color
                end
            end
        end
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer and player.Character then
        CreateESP(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(1)
        if player ~= LocalPlayer then
            CreateESP(player)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    if ESPObjects[player] then
        local objects = ESPObjects[player]
        if objects.Highlight then objects.Highlight:Destroy() end
        for _, line in ipairs(objects.Box) do line:Remove() end
        if objects.Tracer then objects.Tracer:Remove() end
        if objects.Distance then objects.Distance:Remove() end
        if objects.Health then objects.Health:Remove() end
        if objects.Name then objects.Name:Remove() end
        ESPObjects[player] = nil
    end
end)

local function UpdateSpeedHack()
    if Config.SpeedHack and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = Config.SpeedValue
        end
    elseif LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.WalkSpeed = OriginalWalkSpeed
        end
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        OriginalWalkSpeed = humanoid.WalkSpeed
    end
end)

local function CreateGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "WallbangGUI_" .. tostring(math.random(1000, 9999))
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 450, 0, 600)
    MainFrame.Position = UDim2.new(0.5, -225, 0.5, -300)
    MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 12)
    MainCorner.Parent = MainFrame
    
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(60, 120, 255)
    MainStroke.Thickness = 2
    MainStroke.Parent = MainFrame
    
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 45)
    TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 12)
    TitleCorner.Parent = TitleBar
    
    local TitleFix = Instance.new("Frame")
    TitleFix.Size = UDim2.new(1, 0, 0, 12)
    TitleFix.Position = UDim2.new(0, 0, 1, -12)
    TitleFix.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    TitleFix.BorderSizePixel = 0
    TitleFix.Parent = TitleBar
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -90, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "STEALTH WALLBANG v" .. VERSION
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 18
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TitleBar
    
    local CloseButton = Instance.new("TextButton")
    CloseButton.Size = UDim2.new(0, 35, 0, 35)
    CloseButton.Position = UDim2.new(1, -40, 0, 5)
    CloseButton.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 18
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Parent = TitleBar
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 8)
    CloseCorner.Parent = CloseButton
    
    CloseButton.MouseButton1Click:Connect(function()
        ScreenGui.Enabled = false
        print("[GUI] Menu hidden")
    end)
    
    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Size = UDim2.new(1, -30, 1, -65)
    ScrollFrame.Position = UDim2.new(0, 15, 0, 55)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.BorderSizePixel = 0
    ScrollFrame.ScrollBarThickness = 8
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ScrollFrame.Parent = MainFrame
    
    local ListLayout = Instance.new("UIListLayout")
    ListLayout.Padding = UDim.new(0, 10)
    ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ListLayout.Parent = ScrollFrame
    
    local function CreateToggle(name, configKey, order, callback)
        local ToggleFrame = Instance.new("Frame")
        ToggleFrame.Name = name
        ToggleFrame.Size = UDim2.new(1, -10, 0, 45)
        ToggleFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        ToggleFrame.BorderSizePixel = 0
        ToggleFrame.LayoutOrder = order
        ToggleFrame.Parent = ScrollFrame
        
        local TogCorner = Instance.new("UICorner")
        TogCorner.CornerRadius = UDim.new(0, 10)
        TogCorner.Parent = ToggleFrame
        
        local TogStroke = Instance.new("UIStroke")
        TogStroke.Color = Color3.fromRGB(50, 50, 60)
        TogStroke.Thickness = 1
        TogStroke.Parent = ToggleFrame
        
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(0.65, 0, 1, 0)
        Label.Position = UDim2.new(0, 15, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
        Label.TextSize = 15
        Label.Font = Enum.Font.GothamSemibold
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = ToggleFrame
        
        local ToggleButton = Instance.new("TextButton")
        ToggleButton.Size = UDim2.new(0, 70, 0, 32)
        ToggleButton.Position = UDim2.new(1, -80, 0.5, -16)
        ToggleButton.BackgroundColor3 = Config[configKey] and Color3.fromRGB(60, 200, 60) or Color3.fromRGB(200, 60, 60)
        ToggleButton.Text = Config[configKey] and "ON" or "OFF"
        ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        ToggleButton.TextSize = 14
        ToggleButton.Font = Enum.Font.GothamBold
        ToggleButton.Parent = ToggleFrame
        
        local TogBtnCorner = Instance.new("UICorner")
        TogBtnCorner.CornerRadius = UDim.new(0, 8)
        TogBtnCorner.Parent = ToggleButton
        
        ToggleButton.MouseButton1Click:Connect(function()
            Config[configKey] = not Config[configKey]
            ToggleButton.Text = Config[configKey] and "ON" or "OFF"
            
            local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local goal = {BackgroundColor3 = Config[configKey] and Color3.fromRGB(60, 200, 60) or Color3.fromRGB(200, 60, 60)}
            TweenService:Create(ToggleButton, tweenInfo, goal):Play()
            
            print(string.format("[GUI] %s: %s", name, Config[configKey] and "ENABLED" or "DISABLED"))
            
            if callback then
                callback(Config[configKey])
            end
        end)
        
        return ToggleFrame
    end
    
    local function CreateSlider(name, configKey, minVal, maxVal, increment, order)
        local SliderFrame = Instance.new("Frame")
        SliderFrame.Name = name
        SliderFrame.Size = UDim2.new(1, -10, 0, 60)
        SliderFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        SliderFrame.BorderSizePixel = 0
        SliderFrame.LayoutOrder = order or 0
        SliderFrame.Parent = ScrollFrame
        
        local SliderCorner = Instance.new("UICorner")
        SliderCorner.CornerRadius = UDim.new(0, 10)
        SliderCorner.Parent = SliderFrame
        
        local SliderStroke = Instance.new("UIStroke")
        SliderStroke.Color = Color3.fromRGB(50, 50, 60)
        SliderStroke.Thickness = 1
        SliderStroke.Parent = SliderFrame
        
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(0.5, 0, 0, 25)
        Label.Position = UDim2.new(0, 15, 0, 8)
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
        Label.TextSize = 15
        Label.Font = Enum.Font.GothamSemibold
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = SliderFrame
        
        local ValueLabel = Instance.new("TextLabel")
        ValueLabel.Size = UDim2.new(0.3, 0, 0, 25)
        ValueLabel.Position = UDim2.new(0.7, 0, 0, 8)
        ValueLabel.BackgroundTransparency = 1
        ValueLabel.Text = tostring(Config[configKey])
        ValueLabel.TextColor3 = Color3.fromRGB(60, 120, 255)
        ValueLabel.TextSize = 14
        ValueLabel.Font = Enum.Font.GothamBold
        ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
        ValueLabel.Parent = SliderFrame
        
        local SliderBG = Instance.new("Frame")
        SliderBG.Size = UDim2.new(1, -30, 0, 8)
        SliderBG.Position = UDim2.new(0, 15, 1, -20)
        SliderBG.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        SliderBG.BorderSizePixel = 0
        SliderBG.Parent = SliderFrame
        
        local SliderBGCorner = Instance.new("UICorner")
        SliderBGCorner.CornerRadius = UDim.new(1, 0)
        SliderBGCorner.Parent = SliderBG
        
        local SliderFill = Instance.new("Frame")
        SliderFill.Size = UDim2.new((Config[configKey] - minVal) / (maxVal - minVal), 0, 1, 0)
        SliderFill.BackgroundColor3 = Color3.fromRGB(60, 120, 255)
        SliderFill.BorderSizePixel = 0
        SliderFill.Parent = SliderBG
        
        local SliderFillCorner = Instance.new("UICorner")
        SliderFillCorner.CornerRadius = UDim.new(1, 0)
        SliderFillCorner.Parent = SliderFill
        
        local SliderButton = Instance.new("TextButton")
        SliderButton.Size = UDim2.new(1, 0, 1, 0)
        SliderButton.BackgroundTransparency = 1
        SliderButton.Text = ""
        SliderButton.Parent = SliderBG
        
        local dragging = false
        
        SliderButton.MouseButton1Down:Connect(function()
            dragging = true
        end)
        
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        
        SliderButton.MouseMoved:Connect(function(x, y)
            if dragging then
                local mousePos = UserInputService:GetMouseLocation()
                local sliderPos = SliderBG.AbsolutePosition.X
                local sliderSize = SliderBG.AbsoluteSize.X
                local relativePos = math.clamp((mousePos.X - sliderPos) / sliderSize, 0, 1)
                
                local value = minVal + (maxVal - minVal) * relativePos
                value = math.floor(value / increment + 0.5) * increment
                
                Config[configKey] = value
                ValueLabel.Text = string.format("%.2f", value)
                
                local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Linear)
                local goal = {Size = UDim2.new(relativePos, 0, 1, 0)}
                TweenService:Create(SliderFill, tweenInfo, goal):Play()
            end
        end)
        
        return SliderFrame
    end
    
    local function CreateDropdown(name, configKey, options, order)
        local DropdownFrame = Instance.new("Frame")
        DropdownFrame.Name = name
        DropdownFrame.Size = UDim2.new(1, -10, 0, 45)
        DropdownFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        DropdownFrame.BorderSizePixel = 0
        DropdownFrame.LayoutOrder = order or 0
        DropdownFrame.Parent = ScrollFrame
        
        local DropCorner = Instance.new("UICorner")
        DropCorner.CornerRadius = UDim.new(0, 10)
        DropCorner.Parent = DropdownFrame
        
        local DropStroke = Instance.new("UIStroke")
        DropStroke.Color = Color3.fromRGB(50, 50, 60)
        DropStroke.Thickness = 1
        DropStroke.Parent = DropdownFrame
        
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(0.45, 0, 1, 0)
        Label.Position = UDim2.new(0, 15, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
        Label.TextSize = 15
        Label.Font = Enum.Font.GothamSemibold
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = DropdownFrame
        
        local DropButton = Instance.new("TextButton")
        DropButton.Size = UDim2.new(0.5, -20, 0, 32)
        DropButton.Position = UDim2.new(0.5, 5, 0.5, -16)
        DropButton.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
        DropButton.Text = Config[configKey]
        DropButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        DropButton.TextSize = 13
        DropButton.Font = Enum.Font.GothamSemibold
        DropButton.Parent = DropdownFrame
        
        local DropBtnCorner = Instance.new("UICorner")
        DropBtnCorner.CornerRadius = UDim.new(0, 8)
        DropBtnCorner.Parent = DropButton
        
        local currentIndex = 1
        for i, opt in ipairs(options) do
            if opt == Config[configKey] then
                currentIndex = i
                break
            end
        end
        
        DropButton.MouseButton1Click:Connect(function()
            currentIndex = currentIndex % #options + 1
            Config[configKey] = options[currentIndex]
            DropButton.Text = Config[configKey]
            print(string.format("[GUI] %s: %s", name, Config[configKey]))
        end)
        
        return DropdownFrame
    end
    
    local function CreateButton(name, callback, order)
        local ButtonFrame = Instance.new("Frame")
        ButtonFrame.Name = name
        ButtonFrame.Size = UDim2.new(1, -10, 0, 45)
        ButtonFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
        ButtonFrame.BorderSizePixel = 0
        ButtonFrame.LayoutOrder = order or 0
        ButtonFrame.Parent = ScrollFrame
        
        local BtnCorner = Instance.new("UICorner")
        BtnCorner.CornerRadius = UDim.new(0, 10)
        BtnCorner.Parent = ButtonFrame
        
        local BtnStroke = Instance.new("UIStroke")
        BtnStroke.Color = Color3.fromRGB(50, 50, 60)
        BtnStroke.Thickness = 1
        BtnStroke.Parent = ButtonFrame
        
        local Button = Instance.new("TextButton")
        Button.Size = UDim2.new(1, -20, 0, 35)
        Button.Position = UDim2.new(0, 10, 0.5, -17.5)
        Button.BackgroundColor3 = Color3.fromRGB(60, 120, 255)
        Button.Text = name
        Button.TextColor3 = Color3.fromRGB(255, 255, 255)
        Button.TextSize = 15
        Button.Font = Enum.Font.GothamBold
        Button.Parent = ButtonFrame
        
        local ButtonCorner = Instance.new("UICorner")
        ButtonCorner.CornerRadius = UDim.new(0, 8)
        ButtonCorner.Parent = Button
        
        Button.MouseButton1Click:Connect(function()
            local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            local goal1 = {BackgroundColor3 = Color3.fromRGB(40, 100, 235)}
            local goal2 = {BackgroundColor3 = Color3.fromRGB(60, 120, 255)}
            
            local tween1 = TweenService:Create(Button, tweenInfo, goal1)
            local tween2 = TweenService:Create(Button, tweenInfo, goal2)
            
            tween1:Play()
            tween1.Completed:Connect(function()
                tween2:Play()
            end)
            
            callback()
        end)
        
        return ButtonFrame
    end
    
    CreateToggle("Aimbot", "Enabled", 0)
    CreateToggle("ESP", "ESP", 1)
    CreateToggle("Wallbang", "Wallbang", 2, function(enabled)
        WallbangActive = enabled
        if enabled then
            print("[WALLBANG] Stealth penetration active")
        end
    end)
    CreateToggle("Prediction", "Prediction", 3)
    CreateToggle("FOV Circle", "ShowFOVCircle", 4)
    CreateToggle("Rainbow FOV", "FOVRainbow", 5)
    CreateToggle("Speed Hack", "SpeedHack", 6)
    CreateToggle("ESP Boxes", "ESPBoxes", 7)
    CreateToggle("ESP Tracers", "ESPTracers", 8)
    CreateToggle("ESP Distance", "ESPDistance", 9)
    CreateToggle("ESP Health", "ESPHealth", 10)
    
    CreateSlider("FOV", "FOV", 50, 1000, 10, 20)
    CreateSlider("Smoothness", "Smoothness", 0, 0.9, 0.05, 21)
    CreateSlider("Prediction", "PredictionStrength", 0, 1, 0.01, 22)
    CreateSlider("Speed Value", "SpeedValue", 16, 200, 1, 23)
    
    CreateDropdown("Target Part", "TargetPart", {"Head", "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso"}, 30)
    
    CreateButton("Release Target (R)", function()
        Target = nil
        Locked = false
        print("[AIMBOT] Target released")
    end, 40)
    
    ScreenGui.Parent = CoreGui
    
    print("[GUI] Stealth menu created")
    print("[GUI] Press RIGHT CTRL to toggle")
    
    return ScreenGui
end

local MenuGUI = CreateGUI()

local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 3
FOVCircle.NumSides = 100
FOVCircle.Radius = Config.FOV
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.Color = Color3.fromRGB(60, 120, 255)
FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

local rainbowHue = 0

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    
    local key = input.KeyCode
    
    if key == Enum.KeyCode.RightControl then
        MenuGUI.Enabled = not MenuGUI.Enabled
        print("[GUI] Menu: " .. (MenuGUI.Enabled and "VISIBLE" or "HIDDEN"))
    end
    
    if key == Enum.KeyCode.E then
        Config.Enabled = not Config.Enabled
        print(string.format("[AIMBOT] %s", Config.Enabled and "ENABLED" or "DISABLED"))
    end
    
    if key == Enum.KeyCode.G then
        Config.Wallbang = not Config.Wallbang
        WallbangActive = Config.Wallbang
        print(string.format("[WALLBANG] %s", Config.Wallbang and "ENABLED" or "DISABLED"))
    end
    
    if key == Enum.KeyCode.Y then
        Config.ESP = not Config.ESP
        print(string.format("[ESP] %s", Config.ESP and "ENABLED" or "DISABLED"))
    end
    
    if key == Enum.KeyCode.R then
        Target = nil
        Locked = false
        print("[AIMBOT] Target released")
    end
    
    if key == Enum.KeyCode.T then
        local parts = {"Head", "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso"}
        for i, p in ipairs(parts) do
            if p == Config.TargetPart then
                Config.TargetPart = parts[(i % #parts) + 1]
                break
            end
        end
        print(string.format("[AIMBOT] Target: %s", Config.TargetPart))
    end
end)

RunService.RenderStepped:Connect(function()
    pcall(AimbotCore)
    pcall(UpdateESP)
    pcall(UpdateSpeedHack)
    
    if Config.ShowFOVCircle then
        FOVCircle.Visible = true
        FOVCircle.Radius = Config.FOV
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        
        if Config.FOVRainbow then
            rainbowHue = (rainbowHue + 0.005) % 1
            FOVCircle.Color = Color3.fromHSV(rainbowHue, 1, 1)
        else
            FOVCircle.Color = Color3.fromRGB(60, 120, 255)
        end
    else
        FOVCircle.Visible = false
    end
end)

print("[SYSTEM] ========================================")
print("[SYSTEM] Stealth system initialized")
print("[SYSTEM] Version: " .. VERSION)
print("[SYSTEM] ========================================")
print("[SYSTEM] Using hookfunction instead of __namecall")
print("[SYSTEM] No namecall detection")
print("[SYSTEM] ========================================")
print("[SYSTEM] GUI: RIGHT CTRL")
print("[SYSTEM] Aimbot: E | Wallbang: G | ESP: Y")
print("[SYSTEM] Release: R | Target: T")
print("[SYSTEM] ========================================")
print("[SYSTEM] Ready")