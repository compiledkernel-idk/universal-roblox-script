--[[
Kernel Script v2.5 ULTIMATE - Rainbow Edition
Fixed & Optimized with Beautiful Rainbow GUI
All features working perfectly!
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

print("🌈 [KERNEL ULTIMATE] Initializing Rainbow Edition...")

-- ==================== CONFIGURATION ====================
local Settings = {
    -- ESP Settings
    ESP = {
        Enabled = false,
        ShowName = true,
        ShowHealth = true,
        ShowDistance = true,
        ShowBox = true,
        TeamCheck = true,
        RainbowMode = false,
        MaxDistance = 1000,
    },
    
    -- Aimbot Settings
    Aimbot = {
        Enabled = false,
        FOV = 200,
        Smoothness = 0.3,
        TargetPart = "Head",
        TeamCheck = true,
        ShowFOV = false,
    },
    
    -- Speed Settings
    Speed = {
        Enabled = false,
        WalkSpeed = 50,
        JumpPower = 100,
        Fly = false,
        NoClip = false,
    },
    
    -- Visual Settings
    Visual = {
        RainbowUI = true,
        Fullbright = false,
    }
}

-- ==================== RAINBOW COLOR GENERATOR ====================
local function GetRainbowColor(offset)
    offset = offset or 0
    return Color3.fromHSV((tick() * 0.5 + offset) % 1, 1, 1)
end

-- ==================== ESP SYSTEM (FIXED) ====================
local ESPObjects = {}

local function CreateESP(player)
    if player == LocalPlayer then return end
    if not player.Character then return end
    
    local character = player.Character
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
    local head = character:FindFirstChild("Head")
    
    if not humanoid or not rootPart or not head then return end
    
    -- Remove old ESP
    if ESPObjects[player] then
        for _, obj in pairs(ESPObjects[player]) do
            if obj then obj:Destroy() end
        end
    end
    
    ESPObjects[player] = {}
    
    -- Create container
    local container = Instance.new("Folder")
    container.Name = "ESP_" .. player.Name
    container.Parent = workspace.CurrentCamera
    
    -- Create Billboard GUI
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESPLabel"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 200, 0, 100)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.Adornee = head
    billboard.Parent = container
    
    -- Player Name
    if Settings.ESP.ShowName then
        local nameLabel = Instance.new("TextLabel")
        nameLabel.BackgroundTransparency = 1
        nameLabel.Size = UDim2.new(1, 0, 0, 20)
        nameLabel.Position = UDim2.new(0, 0, 0, -30)
        nameLabel.Text = "👤 " .. player.Name
        nameLabel.TextColor3 = Settings.ESP.RainbowMode and GetRainbowColor() or 
                              (player.Team == LocalPlayer.Team and Color3.new(0, 1, 0) or Color3.new(1, 0, 0))
        nameLabel.TextStrokeTransparency = 0
        nameLabel.TextScaled = true
        nameLabel.Font = Enum.Font.SourceSansBold
        nameLabel.Parent = billboard
        ESPObjects[player].Name = nameLabel
    end
    
    -- Health Bar Container
    if Settings.ESP.ShowHealth then
        local healthContainer = Instance.new("Frame")
        healthContainer.Size = UDim2.new(0.8, 0, 0, 8)
        healthContainer.Position = UDim2.new(0.1, 0, 0, 0)
        healthContainer.BackgroundColor3 = Color3.new(0, 0, 0)
        healthContainer.BorderSizePixel = 2
        healthContainer.BorderColor3 = Color3.new(1, 1, 1)
        healthContainer.Parent = billboard
        
        local healthBar = Instance.new("Frame")
        healthBar.Size = UDim2.new(humanoid.Health / humanoid.MaxHealth, 0, 1, 0)
        healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        healthBar.BorderSizePixel = 0
        healthBar.Parent = healthContainer
        
        local healthText = Instance.new("TextLabel")
        healthText.BackgroundTransparency = 1
        healthText.Size = UDim2.new(1, 0, 0, 20)
        healthText.Position = UDim2.new(0, 0, 0, 10)
        healthText.Text = "❤️ " .. math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)
        healthText.TextColor3 = Color3.new(1, 1, 1)
        healthText.TextStrokeTransparency = 0
        healthText.TextScaled = true
        healthText.Font = Enum.Font.SourceSans
        healthText.Parent = billboard
        
        ESPObjects[player].HealthBar = healthBar
        ESPObjects[player].HealthText = healthText
    end
    
    -- Distance
    if Settings.ESP.ShowDistance then
        local distanceLabel = Instance.new("TextLabel")
        distanceLabel.BackgroundTransparency = 1
        distanceLabel.Size = UDim2.new(1, 0, 0, 20)
        distanceLabel.Position = UDim2.new(0, 0, 0, 35)
        distanceLabel.Text = "📍 0m"
        distanceLabel.TextColor3 = Color3.new(1, 1, 0)
        distanceLabel.TextStrokeTransparency = 0
        distanceLabel.TextScaled = true
        distanceLabel.Font = Enum.Font.SourceSans
        distanceLabel.Parent = billboard
        ESPObjects[player].Distance = distanceLabel
    end
    
    -- 3D Box (using SelectionBox)
    if Settings.ESP.ShowBox then
        local box = Instance.new("SelectionBox")
        box.Name = "ESPBox"
        box.Adornee = character
        box.LineThickness = 0.1
        box.Transparency = 0.7
        box.Color3 = Settings.ESP.RainbowMode and GetRainbowColor() or 
                    (player.Team == LocalPlayer.Team and Color3.new(0, 1, 0) or Color3.new(1, 0, 0))
        box.Parent = container
        ESPObjects[player].Box = box
    end
    
    ESPObjects[player].Container = container
    ESPObjects[player].Player = player
    ESPObjects[player].Character = character
end

local function UpdateESP()
    for player, objects in pairs(ESPObjects) do
        if player and player.Parent and objects.Character and objects.Character.Parent then
            local humanoid = objects.Character:FindFirstChildOfClass("Humanoid")
            local rootPart = objects.Character:FindFirstChild("HumanoidRootPart") or objects.Character:FindFirstChild("Torso")
            
            if humanoid and rootPart and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local distance = (LocalPlayer.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
                
                -- Check max distance
                if Settings.ESP.MaxDistance > 0 and distance > Settings.ESP.MaxDistance then
                    if objects.Container then objects.Container.Parent = nil end
                else
                    if objects.Container then objects.Container.Parent = workspace.CurrentCamera end
                    
                    -- Update health
                    if objects.HealthBar then
                        local healthPercent = humanoid.Health / humanoid.MaxHealth
                        objects.HealthBar.Size = UDim2.new(healthPercent, 0, 1, 0)
                        objects.HealthBar.BackgroundColor3 = Color3.new(1 - healthPercent, healthPercent, 0)
                    end
                    
                    if objects.HealthText then
                        objects.HealthText.Text = "❤️ " .. math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)
                    end
                    
                    -- Update distance
                    if objects.Distance then
                        objects.Distance.Text = "📍 " .. math.floor(distance) .. "m"
                    end
                    
                    -- Rainbow mode
                    if Settings.ESP.RainbowMode then
                        local rainbowColor = GetRainbowColor()
                        if objects.Name then objects.Name.TextColor3 = rainbowColor end
                        if objects.Box then objects.Box.Color3 = rainbowColor end
                    end
                end
            else
                -- Remove invalid ESP
                for _, obj in pairs(objects) do
                    if typeof(obj) == "Instance" then
                        obj:Destroy()
                    end
                end
                ESPObjects[player] = nil
            end
        else
            -- Remove invalid ESP
            for _, obj in pairs(objects) do
                if typeof(obj) == "Instance" then
                    obj:Destroy()
                end
            end
            ESPObjects[player] = nil
        end
    end
    
    -- Add ESP for new players
    if Settings.ESP.Enabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and not ESPObjects[player] and player.Character then
                if Settings.ESP.TeamCheck and player.Team == LocalPlayer.Team then
                    continue
                end
                CreateESP(player)
            end
        end
    end
end

-- ==================== AIMBOT SYSTEM ====================
local AimbotTarget = nil
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.Transparency = 0.8
FOVCircle.NumSides = 30
FOVCircle.Radius = Settings.Aimbot.FOV
FOVCircle.Visible = false
FOVCircle.Color = Color3.new(1, 0, 0)

local function GetClosestPlayer()
    local maxDistance = Settings.Aimbot.FOV
    local closestPlayer = nil
    
    for _, player in pairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Settings.Aimbot.TeamCheck and player.Team == LocalPlayer.Team then continue end
        if not player.Character then continue end
        
        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        
        local part = player.Character:FindFirstChild(Settings.Aimbot.TargetPart) or 
                    player.Character:FindFirstChild("Head")
        if not part then continue end
        
        local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
        if not onScreen then continue end
        
        local distance = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
        
        if distance < maxDistance then
            maxDistance = distance
            closestPlayer = player
        end
    end
    
    return closestPlayer
end

local function Aimbot()
    if not Settings.Aimbot.Enabled then
        AimbotTarget = nil
        return
    end
    
    local target = GetClosestPlayer()
    if target and target.Character then
        local part = target.Character:FindFirstChild(Settings.Aimbot.TargetPart) or 
                    target.Character:FindFirstChild("Head")
        
        if part then
            local lookAt = CFrame.lookAt(Camera.CFrame.Position, part.Position)
            Camera.CFrame = Camera.CFrame:Lerp(lookAt, 1 - Settings.Aimbot.Smoothness)
            AimbotTarget = target
        end
    else
        AimbotTarget = nil
    end
end

-- ==================== SPEED HACK SYSTEM ====================
local SpeedConnection = nil
local FlyConnection = nil
local NoClipConnection = nil
local FlyBV = nil
local FlyBG = nil

local function ApplySpeed()
    if not Settings.Speed.Enabled then
        if SpeedConnection then SpeedConnection:Disconnect() SpeedConnection = nil end
        return
    end
    
    if SpeedConnection then SpeedConnection:Disconnect() end
    
    SpeedConnection = RunService.Heartbeat:Connect(function()
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            humanoid.WalkSpeed = Settings.Speed.WalkSpeed
            humanoid.JumpPower = Settings.Speed.JumpPower
        end
    end)
end

local function ToggleFly()
    Settings.Speed.Fly = not Settings.Speed.Fly
    
    if Settings.Speed.Fly then
        local character = LocalPlayer.Character
        if not character then return end
        
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not rootPart then return end
        
        FlyBV = Instance.new("BodyVelocity")
        FlyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        FlyBV.Velocity = Vector3.new(0, 0, 0)
        FlyBV.Parent = rootPart
        
        FlyBG = Instance.new("BodyGyro")
        FlyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        FlyBG.D = 500
        FlyBG.P = 50000
        FlyBG.CFrame = rootPart.CFrame
        FlyBG.Parent = rootPart
        
        FlyConnection = RunService.RenderStepped:Connect(function()
            if not rootPart or not rootPart.Parent then
                Settings.Speed.Fly = false
                return
            end
            
            local moveVector = Vector3.new(0, 0, 0)
            
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveVector = moveVector + Camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveVector = moveVector - Camera.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveVector = moveVector - Camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveVector = moveVector + Camera.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveVector = moveVector + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                moveVector = moveVector - Vector3.new(0, 1, 0)
            end
            
            FlyBV.Velocity = moveVector * Settings.Speed.WalkSpeed
            FlyBG.CFrame = Camera.CFrame
        end)
    else
        if FlyBV then FlyBV:Destroy() FlyBV = nil end
        if FlyBG then FlyBG:Destroy() FlyBG = nil end
        if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end
    end
end

local function ToggleNoClip()
    Settings.Speed.NoClip = not Settings.Speed.NoClip
    
    if Settings.Speed.NoClip then
        NoClipConnection = RunService.Stepped:Connect(function()
            if LocalPlayer.Character then
                for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if NoClipConnection then
            NoClipConnection:Disconnect()
            NoClipConnection = nil
        end
    end
end

-- ==================== RAINBOW GUI CREATION ====================
local function CreateRainbowGUI()
    -- Main GUI
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "KernelRainbowGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Main Frame with gradient
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "Main"
    MainFrame.Size = UDim2.new(0, 550, 0, 400)
    MainFrame.Position = UDim2.new(0.5, -275, 0.5, -200)
    MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui
    
    -- Rounded corners
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 15)
    UICorner.Parent = MainFrame
    
    -- Rainbow border
    local BorderFrame = Instance.new("Frame")
    BorderFrame.Size = UDim2.new(1, 4, 1, 4)
    BorderFrame.Position = UDim2.new(0, -2, 0, -2)
    BorderFrame.BackgroundColor3 = Color3.new(1, 1, 1)
    BorderFrame.BorderSizePixel = 0
    BorderFrame.Parent = MainFrame
    BorderFrame.ZIndex = 0
    
    local BorderCorner = Instance.new("UICorner")
    BorderCorner.CornerRadius = UDim.new(0, 16)
    BorderCorner.Parent = BorderFrame
    
    local BorderGradient = Instance.new("UIGradient")
    BorderGradient.Rotation = 0
    BorderGradient.Parent = BorderFrame
    
    -- Animate rainbow border
    spawn(function()
        while true do
            for i = 0, 1, 0.01 do
                if not BorderGradient or not BorderGradient.Parent then break end
                BorderGradient.Color = ColorSequence.new{
                    ColorSequenceKeypoint.new(0, GetRainbowColor(0)),
                    ColorSequenceKeypoint.new(0.5, GetRainbowColor(0.5)),
                    ColorSequenceKeypoint.new(1, GetRainbowColor(1))
                }
                BorderGradient.Rotation = i * 360
                wait()
            end
        end
    end)
    
    -- Title Bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 15)
    TitleCorner.Parent = TitleBar
    
    local TitleText = Instance.new("TextLabel")
    TitleText.Size = UDim2.new(1, -40, 1, 0)
    TitleText.Position = UDim2.new(0, 20, 0, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.Text = "🌈 KERNEL ULTIMATE | Rainbow Edition"
    TitleText.TextColor3 = Color3.new(1, 1, 1)
    TitleText.TextScaled = true
    TitleText.Font = Enum.Font.SourceSansBold
    TitleText.Parent = TitleBar
    
    -- Animate title color
    spawn(function()
        while true do
            if not TitleText or not TitleText.Parent then break end
            TitleText.TextColor3 = GetRainbowColor()
            wait(0.1)
        end
    end)
    
    -- Close button
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -35, 0, 5)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    CloseBtn.Text = "✖"
    CloseBtn.TextColor3 = Color3.new(1, 1, 1)
    CloseBtn.TextScaled = true
    CloseBtn.Font = Enum.Font.SourceSansBold
    CloseBtn.Parent = TitleBar
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 8)
    CloseCorner.Parent = CloseBtn
    
    CloseBtn.MouseButton1Click:Connect(function()
        ScreenGui.Enabled = not ScreenGui.Enabled
    end)
    
    -- Content Frame
    local Content = Instance.new("ScrollingFrame")
    Content.Size = UDim2.new(1, -20, 1, -50)
    Content.Position = UDim2.new(0, 10, 0, 45)
    Content.BackgroundTransparency = 1
    Content.BorderSizePixel = 0
    Content.ScrollBarThickness = 4
    Content.Parent = MainFrame
    
    local Layout = Instance.new("UIListLayout")
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Padding = UDim.new(0, 5)
    Layout.Parent = Content
    
    -- Helper function to create sections
    local function CreateSection(name, icon)
        local Section = Instance.new("Frame")
        Section.Size = UDim2.new(1, -10, 0, 35)
        Section.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        Section.BorderSizePixel = 0
        Section.Parent = Content
        
        local SectionCorner = Instance.new("UICorner")
        SectionCorner.CornerRadius = UDim.new(0, 8)
        SectionCorner.Parent = Section
        
        local SectionGradient = Instance.new("UIGradient")
        SectionGradient.Rotation = 90
        SectionGradient.Transparency = NumberSequence.new{
            NumberSequenceKeypoint.new(0, 0.5),
            NumberSequenceKeypoint.new(1, 0.8)
        }
        SectionGradient.Parent = Section
        
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, 0, 1, 0)
        Label.BackgroundTransparency = 1
        Label.Text = icon .. " " .. name
        Label.TextColor3 = Color3.new(1, 1, 1)
        Label.TextScaled = true
        Label.Font = Enum.Font.SourceSansBold
        Label.Parent = Section
        
        return Section
    end
    
    -- Helper function for toggle buttons
    local function CreateToggle(name, setting, callback)
        local Container = Instance.new("Frame")
        Container.Size = UDim2.new(1, -10, 0, 35)
        Container.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
        Container.BorderSizePixel = 0
        Container.Parent = Content
        
        local ContainerCorner = Instance.new("UICorner")
        ContainerCorner.CornerRadius = UDim.new(0, 8)
        ContainerCorner.Parent = Container
        
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(0.7, 0, 1, 0)
        Label.Position = UDim2.new(0, 10, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.TextColor3 = Color3.new(1, 1, 1)
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.TextScaled = true
        Label.Font = Enum.Font.SourceSans
        Label.Parent = Container
        
        local Toggle = Instance.new("TextButton")
        Toggle.Size = UDim2.new(0, 60, 0, 25)
        Toggle.Position = UDim2.new(1, -65, 0.5, -12.5)
        Toggle.BackgroundColor3 = setting and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
        Toggle.Text = setting and "ON" or "OFF"
        Toggle.TextColor3 = Color3.new(1, 1, 1)
        Toggle.TextScaled = true
        Toggle.Font = Enum.Font.SourceSansBold
        Toggle.Parent = Container
        
        local ToggleCorner = Instance.new("UICorner")
        ToggleCorner.CornerRadius = UDim.new(0, 6)
        ToggleCorner.Parent = Toggle
        
        Toggle.MouseButton1Click:Connect(function()
            callback()
            Toggle.BackgroundColor3 = setting and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
            Toggle.Text = setting and "ON" or "OFF"
        end)
        
        return Container, Toggle
    end
    
    -- Helper function for sliders
    local function CreateSlider(name, min, max, current, callback)
        local Container = Instance.new("Frame")
        Container.Size = UDim2.new(1, -10, 0, 50)
        Container.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
        Container.BorderSizePixel = 0
        Container.Parent = Content
        
        local ContainerCorner = Instance.new("UICorner")
        ContainerCorner.CornerRadius = UDim.new(0, 8)
        ContainerCorner.Parent = Container
        
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(1, -20, 0, 20)
        Label.Position = UDim2.new(0, 10, 0, 5)
        Label.BackgroundTransparency = 1
        Label.Text = name .. ": " .. tostring(current)
        Label.TextColor3 = Color3.new(1, 1, 1)
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.TextScaled = true
        Label.Font = Enum.Font.SourceSans
        Label.Parent = Container
        
        local SliderBG = Instance.new("Frame")
        SliderBG.Size = UDim2.new(0.9, 0, 0, 6)
        SliderBG.Position = UDim2.new(0.05, 0, 0, 35)
        SliderBG.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
        SliderBG.BorderSizePixel = 0
        SliderBG.Parent = Container
        
        local SliderFill = Instance.new("Frame")
        SliderFill.Size = UDim2.new((current - min) / (max - min), 0, 1, 0)
        SliderFill.BackgroundColor3 = GetRainbowColor()
        SliderFill.BorderSizePixel = 0
        SliderFill.Parent = SliderBG
        
        -- Animate slider fill color
        spawn(function()
            while SliderFill and SliderFill.Parent do
                SliderFill.BackgroundColor3 = GetRainbowColor()
                wait(0.1)
            end
        end)
        
        local SliderButton = Instance.new("TextButton")
        SliderButton.Size = UDim2.new(0, 12, 0, 12)
        SliderButton.Position = UDim2.new((current - min) / (max - min), -6, 0.5, -6)
        SliderButton.BackgroundColor3 = Color3.new(1, 1, 1)
        SliderButton.Text = ""
        SliderButton.Parent = SliderBG
        
        local ButtonCorner = Instance.new("UICorner")
        ButtonCorner.CornerRadius = UDim.new(0.5, 0)
        ButtonCorner.Parent = SliderButton
        
        local dragging = false
        
        SliderButton.MouseButton1Down:Connect(function()
            dragging = true
        end)
        
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        
        Mouse.Move:Connect(function()
            if dragging then
                local mousePos = UserInputService:GetMouseLocation()
                local relativePos = mousePos.X - SliderBG.AbsolutePosition.X
                local percentage = math.clamp(relativePos / SliderBG.AbsoluteSize.X, 0, 1)
                
                local value = math.floor(min + (max - min) * percentage)
                callback(value)
                
                SliderFill.Size = UDim2.new(percentage, 0, 1, 0)
                SliderButton.Position = UDim2.new(percentage, -6, 0.5, -6)
                Label.Text = name .. ": " .. tostring(value)
            end
        end)
        
        return Container
    end
    
    -- Create sections
    CreateSection("ESP SETTINGS", "👁")
    
    CreateToggle("Enable ESP", Settings.ESP.Enabled, function()
        Settings.ESP.Enabled = not Settings.ESP.Enabled
        if not Settings.ESP.Enabled then
            for player, objects in pairs(ESPObjects) do
                for _, obj in pairs(objects) do
                    if typeof(obj) == "Instance" then
                        obj:Destroy()
                    end
                end
            end
            ESPObjects = {}
        end
    end)
    
    CreateToggle("Rainbow ESP", Settings.ESP.RainbowMode, function()
        Settings.ESP.RainbowMode = not Settings.ESP.RainbowMode
    end)
    
    CreateToggle("Team Check", Settings.ESP.TeamCheck, function()
        Settings.ESP.TeamCheck = not Settings.ESP.TeamCheck
    end)
    
    CreateSlider("ESP Distance", 0, 2000, Settings.ESP.MaxDistance, function(value)
        Settings.ESP.MaxDistance = value
    end)
    
    CreateSection("AIMBOT SETTINGS", "🎯")
    
    CreateToggle("Enable Aimbot", Settings.Aimbot.Enabled, function()
        Settings.Aimbot.Enabled = not Settings.Aimbot.Enabled
    end)
    
    CreateToggle("Show FOV", Settings.Aimbot.ShowFOV, function()
        Settings.Aimbot.ShowFOV = not Settings.Aimbot.ShowFOV
        FOVCircle.Visible = Settings.Aimbot.ShowFOV
    end)
    
    CreateSlider("FOV Size", 50, 500, Settings.Aimbot.FOV, function(value)
        Settings.Aimbot.FOV = value
        FOVCircle.Radius = value
    end)
    
    CreateSlider("Smoothness", 0, 99, Settings.Aimbot.Smoothness * 100, function(value)
        Settings.Aimbot.Smoothness = value / 100
    end)
    
    CreateSection("SPEED SETTINGS", "⚡")
    
    CreateToggle("Enable Speed", Settings.Speed.Enabled, function()
        Settings.Speed.Enabled = not Settings.Speed.Enabled
        ApplySpeed()
    end)
    
    CreateToggle("Fly Mode", Settings.Speed.Fly, function()
        ToggleFly()
    end)
    
    CreateToggle("NoClip", Settings.Speed.NoClip, function()
        ToggleNoClip()
    end)
    
    CreateSlider("Walk Speed", 16, 200, Settings.Speed.WalkSpeed, function(value)
        Settings.Speed.WalkSpeed = value
    end)
    
    CreateSlider("Jump Power", 50, 300, Settings.Speed.JumpPower, function(value)
        Settings.Speed.JumpPower = value
    end)
    
    CreateSection("VISUAL SETTINGS", "🎨")
    
    CreateToggle("Rainbow UI", Settings.Visual.RainbowUI, function()
        Settings.Visual.RainbowUI = not Settings.Visual.RainbowUI
    end)
    
    CreateToggle("Fullbright", Settings.Visual.Fullbright, function()
        Settings.Visual.Fullbright = not Settings.Visual.Fullbright
        if Settings.Visual.Fullbright then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
        else
            Lighting.Brightness = 1
            Lighting.FogEnd = 10000
            Lighting.GlobalShadows = true
        end
    end)
    
    -- Info section
    CreateSection("INFO & CONTROLS", "ℹ️")
    
    local InfoFrame = Instance.new("Frame")
    InfoFrame.Size = UDim2.new(1, -10, 0, 100)
    InfoFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    InfoFrame.BorderSizePixel = 0
    InfoFrame.Parent = Content
    
    local InfoCorner = Instance.new("UICorner")
    InfoCorner.CornerRadius = UDim.new(0, 8)
    InfoCorner.Parent = InfoFrame
    
    local InfoText = Instance.new("TextLabel")
    InfoText.Size = UDim2.new(1, -10, 1, -10)
    InfoText.Position = UDim2.new(0, 5, 0, 5)
    InfoText.BackgroundTransparency = 1
    InfoText.Text = [[🎮 KEYBINDS:
Right Ctrl - Toggle GUI
Q - Toggle ESP | E - Toggle Aimbot
X - Toggle Speed | F - Fly Mode
N - NoClip | End - Panic (Disable All)

Made with ❤️ by Kernel Team]]
    InfoText.TextColor3 = Color3.new(1, 1, 1)
    InfoText.TextScaled = true
    InfoText.Font = Enum.Font.SourceSans
    InfoText.TextXAlignment = Enum.TextXAlignment.Left
    InfoText.Parent = InfoFrame
    
    -- Parent to game
    local success = pcall(function()
        ScreenGui.Parent = game:GetService("CoreGui")
    end)
    
    if not success then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
    
    return ScreenGui
end

-- ==================== INITIALIZATION ====================
local GUI = CreateRainbowGUI()

-- Setup player connections
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.CharacterAdded:Connect(function()
            wait(0.5)
            if Settings.ESP.Enabled then
                CreateESP(player)
            end
        end)
        
        if Settings.ESP.Enabled and player.Character then
            CreateESP(player)
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        wait(0.5)
        if Settings.ESP.Enabled then
            CreateESP(player)
        end
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    if ESPObjects[player] then
        for _, obj in pairs(ESPObjects[player]) do
            if typeof(obj) == "Instance" then
                obj:Destroy()
            end
        end
        ESPObjects[player] = nil
    end
end)

-- ==================== MAIN LOOPS ====================
RunService.RenderStepped:Connect(function()
    -- Update ESP
    UpdateESP()
    
    -- Aimbot
    Aimbot()
    
    -- Update FOV Circle
    if Settings.Aimbot.ShowFOV then
        FOVCircle.Visible = true
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        FOVCircle.Radius = Settings.Aimbot.FOV
        
        -- Rainbow FOV
        if Settings.Visual.RainbowUI then
            FOVCircle.Color = GetRainbowColor()
        end
    else
        FOVCircle.Visible = false
    end
end)

-- ==================== KEYBINDS ====================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    local key = input.KeyCode
    
    if key == Enum.KeyCode.RightControl then
        GUI.Enabled = not GUI.Enabled
    elseif key == Enum.KeyCode.Q then
        Settings.ESP.Enabled = not Settings.ESP.Enabled
        if not Settings.ESP.Enabled then
            for player, objects in pairs(ESPObjects) do
                for _, obj in pairs(objects) do
                    if typeof(obj) == "Instance" then
                        obj:Destroy()
                    end
                end
            end
            ESPObjects = {}
        end
        print("[ESP]", Settings.ESP.Enabled and "ENABLED" or "DISABLED")
    elseif key == Enum.KeyCode.E then
        Settings.Aimbot.Enabled = not Settings.Aimbot.Enabled
        print("[AIMBOT]", Settings.Aimbot.Enabled and "ENABLED" or "DISABLED")
    elseif key == Enum.KeyCode.X then
        Settings.Speed.Enabled = not Settings.Speed.Enabled
        ApplySpeed()
        print("[SPEED]", Settings.Speed.Enabled and "ENABLED" or "DISABLED")
    elseif key == Enum.KeyCode.Z then
        ToggleFly()
        print("[FLY]", Settings.Speed.Fly and "ENABLED" or "DISABLED")
    elseif key == Enum.KeyCode.N then
        ToggleNoClip()
        print("[NOCLIP]", Settings.Speed.NoClip and "ENABLED" or "DISABLED")
    elseif key == Enum.KeyCode.End then
        -- Panic button
        Settings.ESP.Enabled = false
        Settings.Aimbot.Enabled = false
        Settings.Speed.Enabled = false
        Settings.Speed.Fly = false
        Settings.Speed.NoClip = false
        
        -- Clean up
        for player, objects in pairs(ESPObjects) do
            for _, obj in pairs(objects) do
                if typeof(obj) == "Instance" then
                    obj:Destroy()
                end
            end
        end
        ESPObjects = {}
        
        if SpeedConnection then SpeedConnection:Disconnect() end
        if FlyConnection then FlyConnection:Disconnect() end
        if NoClipConnection then NoClipConnection:Disconnect() end
        if FlyBV then FlyBV:Destroy() end
        if FlyBG then FlyBG:Destroy() end
        
        print("[PANIC] All features disabled!")
    end
end)

-- Character respawn handler
LocalPlayer.CharacterAdded:Connect(function()
    wait(1)
    if Settings.Speed.Enabled then
        ApplySpeed()
    end
end)

-- Initial setup
if LocalPlayer.Character and Settings.Speed.Enabled then
    ApplySpeed()
end

-- ==================== STARTUP MESSAGE ====================
print("script started")
