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

local VERSION = "2.0.0"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

repeat task.wait() until LocalPlayer.Character
repeat task.wait() until LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

print("[SYSTEM] Initializing Wallbang System v" .. VERSION)
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
    ShowFOVCircle = false,
}

local Target = nil
local Locked = false
local Highlights = {}
local VelocityData = {}
local WallbangActive = false

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

local oldNamecall
local hookSuccess = pcall(function()
    local mt = getrawmetatable(game)
    oldNamecall = mt.__namecall
    
    setreadonly(mt, false)
    
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        if WallbangActive and (method == "FindPartOnRay" or 
                               method == "FindPartOnRayWithIgnoreList" or 
                               method == "FindPartOnRayWithWhitelist" or
                               method == "Raycast") then
            
            local ray = args[1]
            local origin, direction
            
            if typeof(ray) == "Ray" then
                origin = ray.Origin
                direction = ray.Direction
            elseif typeof(ray) == "Vector3" then
                origin = ray
                direction = args[2]
            end
            
            if origin and direction then
                for attempt = 1, 100 do
                    local result
                    
                    if method == "FindPartOnRayWithIgnoreList" then
                        local ignoreList = args[2] or {}
                        result = {oldNamecall(self, Ray.new(origin, direction), ignoreList, args[3], args[4])}
                        
                        local part = result[1]
                        if not part then
                            return unpack(result)
                        end
                        
                        if IsPlayerPart(part) then
                            return unpack(result)
                        end
                        
                        table.insert(ignoreList, part)
                        args[2] = ignoreList
                        
                    elseif method == "FindPartOnRay" then
                        local ignore = args[2]
                        result = {oldNamecall(self, Ray.new(origin, direction), ignore, args[3], args[4])}
                        
                        local part = result[1]
                        if not part then
                            return unpack(result)
                        end
                        
                        if IsPlayerPart(part) then
                            return unpack(result)
                        end
                        
                        args[2] = part
                        
                    elseif method == "Raycast" then
                        local params = args[3] or Instance.new("RaycastParams")
                        result = oldNamecall(self, origin, direction, params)
                        
                        if not result then
                            return nil
                        end
                        
                        if IsPlayerPart(result.Instance) then
                            return result
                        end
                        
                        local ignoreList = params.FilterDescendantsInstances or {}
                        table.insert(ignoreList, result.Instance)
                        params.FilterDescendantsInstances = ignoreList
                        params.FilterType = Enum.RaycastFilterType.Exclude
                        args[3] = params
                        
                    elseif method == "FindPartOnRayWithWhitelist" then
                        result = {oldNamecall(self, unpack(args))}
                        local part = result[1]
                        
                        if not part or IsPlayerPart(part) then
                            return unpack(result)
                        end
                        
                        return nil, result[2], result[3], result[4]
                    end
                end
            end
            
            if method == "Raycast" then
                return nil
            else
                return nil, nil, nil, nil
            end
        end
        
        return oldNamecall(self, ...)
    end)
    
    setreadonly(mt, true)
end)

if hookSuccess then
    print("[HOOK] Wallbang system initialized")
else
    warn("[HOOK] Failed to initialize - script may not work properly")
end

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
ESPFolder.Name = "ESP"

local LastESPUpdate = 0

local function CreateHighlight(player)
    if player == LocalPlayer or Highlights[player] or not player.Character then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Adornee = player.Character
    highlight.FillColor = Color3.fromRGB(0, 255, 255)
    highlight.FillTransparency = 0.5
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = ESPFolder
    
    Highlights[player] = highlight
end

local function UpdateHighlights()
    local now = tick()
    if now - LastESPUpdate < 0.1 then return end
    LastESPUpdate = now
    
    if not Config.ESP then
        for p, h in pairs(Highlights) do
            h:Destroy()
            Highlights[p] = nil
        end
        return
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if IsAlive(player) then
                if not Highlights[player] then
                    CreateHighlight(player)
                end
                
                local h = Highlights[player]
                if h then
                    h.FillColor = (player == Target and Locked) and Color3.new(1, 0, 0) or Color3.fromRGB(0, 255, 255)
                    if h.Adornee ~= player.Character then
                        h.Adornee = player.Character
                    end
                end
            else
                if Highlights[player] then
                    Highlights[player]:Destroy()
                    Highlights[player] = nil
                end
            end
        end
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        if player.Character then CreateHighlight(player) end
        player.CharacterAdded:Connect(function()
            task.wait(1)
            if Config.ESP then CreateHighlight(player) end
        end)
    end
end

Players.PlayerRemoving:Connect(function(player)
    if Highlights[player] then
        Highlights[player]:Destroy()
        Highlights[player] = nil
    end
end)

local function CreateGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "WallbangGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 400, 0, 500)
    MainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = MainFrame
    
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 10)
    TitleCorner.Parent = TitleBar
    
    local TitleFix = Instance.new("Frame")
    TitleFix.Size = UDim2.new(1, 0, 0, 10)
    TitleFix.Position = UDim2.new(0, 0, 1, -10)
    TitleFix.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    TitleFix.BorderSizePixel = 0
    TitleFix.Parent = TitleBar
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -80, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "Wallbang System v" .. VERSION
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 16
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = TitleBar
    
    local CloseButton = Instance.new("TextButton")
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Position = UDim2.new(1, -35, 0, 5)
    CloseButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 16
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.Parent = TitleBar
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseButton
    
    CloseButton.MouseButton1Click:Connect(function()
        ScreenGui.Enabled = false
        print("[GUI] Menu hidden")
    end)
    
    local ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Size = UDim2.new(1, -20, 1, -60)
    ScrollFrame.Position = UDim2.new(0, 10, 0, 50)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.BorderSizePixel = 0
    ScrollFrame.ScrollBarThickness = 6
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ScrollFrame.Parent = MainFrame
    
    local ListLayout = Instance.new("UIListLayout")
    ListLayout.Padding = UDim.new(0, 8)
    ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ListLayout.Parent = ScrollFrame
    
    local function CreateToggle(name, configKey, order, callback)
        local ToggleFrame = Instance.new("Frame")
        ToggleFrame.Name = name
        ToggleFrame.Size = UDim2.new(1, -10, 0, 40)
        ToggleFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        ToggleFrame.BorderSizePixel = 0
        ToggleFrame.LayoutOrder = order
        ToggleFrame.Parent = ScrollFrame
        
        local TogCorner = Instance.new("UICorner")
        TogCorner.CornerRadius = UDim.new(0, 8)
        TogCorner.Parent = ToggleFrame
        
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(0.7, 0, 1, 0)
        Label.Position = UDim2.new(0, 10, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
        Label.TextSize = 14
        Label.Font = Enum.Font.Gotham
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = ToggleFrame
        
        local ToggleButton = Instance.new("TextButton")
        ToggleButton.Size = UDim2.new(0, 60, 0, 30)
        ToggleButton.Position = UDim2.new(1, -70, 0, 5)
        ToggleButton.BackgroundColor3 = Config[configKey] and Color3.fromRGB(60, 180, 60) or Color3.fromRGB(180, 60, 60)
        ToggleButton.Text = Config[configKey] and "ON" or "OFF"
        ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        ToggleButton.TextSize = 12
        ToggleButton.Font = Enum.Font.GothamBold
        ToggleButton.Parent = ToggleFrame
        
        local TogBtnCorner = Instance.new("UICorner")
        TogBtnCorner.CornerRadius = UDim.new(0, 6)
        TogBtnCorner.Parent = ToggleButton
        
        ToggleButton.MouseButton1Click:Connect(function()
            Config[configKey] = not Config[configKey]
            ToggleButton.Text = Config[configKey] and "ON" or "OFF"
            ToggleButton.BackgroundColor3 = Config[configKey] and Color3.fromRGB(60, 180, 60) or Color3.fromRGB(180, 60, 60)
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
        SliderFrame.Size = UDim2.new(1, -10, 0, 50)
        SliderFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        SliderFrame.BorderSizePixel = 0
        SliderFrame.LayoutOrder = order or 0
        SliderFrame.Parent = ScrollFrame
        
        local SliderCorner = Instance.new("UICorner")
        SliderCorner.CornerRadius = UDim.new(0, 8)
        SliderCorner.Parent = SliderFrame
        
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(0.5, 0, 0, 20)
        Label.Position = UDim2.new(0, 10, 0, 5)
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
        Label.TextSize = 14
        Label.Font = Enum.Font.Gotham
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = SliderFrame
        
        local ValueLabel = Instance.new("TextLabel")
        ValueLabel.Size = UDim2.new(0.3, 0, 0, 20)
        ValueLabel.Position = UDim2.new(0.7, 0, 0, 5)
        ValueLabel.BackgroundTransparency = 1
        ValueLabel.Text = tostring(Config[configKey])
        ValueLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        ValueLabel.TextSize = 12
        ValueLabel.Font = Enum.Font.Gotham
        ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
        ValueLabel.Parent = SliderFrame
        
        local SliderBG = Instance.new("Frame")
        SliderBG.Size = UDim2.new(1, -20, 0, 6)
        SliderBG.Position = UDim2.new(0, 10, 1, -15)
        SliderBG.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
        SliderBG.BorderSizePixel = 0
        SliderBG.Parent = SliderFrame
        
        local SliderBGCorner = Instance.new("UICorner")
        SliderBGCorner.CornerRadius = UDim.new(1, 0)
        SliderBGCorner.Parent = SliderBG
        
        local SliderFill = Instance.new("Frame")
        SliderFill.Size = UDim2.new((Config[configKey] - minVal) / (maxVal - minVal), 0, 1, 0)
        SliderFill.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
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
                SliderFill.Size = UDim2.new(relativePos, 0, 1, 0)
                
                print(string.format("[GUI] %s: %.2f", name, value))
            end
        end)
        
        return SliderFrame
    end
    
    local function CreateDropdown(name, configKey, options, order)
        local DropdownFrame = Instance.new("Frame")
        DropdownFrame.Name = name
        DropdownFrame.Size = UDim2.new(1, -10, 0, 40)
        DropdownFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        DropdownFrame.BorderSizePixel = 0
        DropdownFrame.LayoutOrder = order or 0
        DropdownFrame.Parent = ScrollFrame
        
        local DropCorner = Instance.new("UICorner")
        DropCorner.CornerRadius = UDim.new(0, 8)
        DropCorner.Parent = DropdownFrame
        
        local Label = Instance.new("TextLabel")
        Label.Size = UDim2.new(0.5, -10, 1, 0)
        Label.Position = UDim2.new(0, 10, 0, 0)
        Label.BackgroundTransparency = 1
        Label.Text = name
        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
        Label.TextSize = 14
        Label.Font = Enum.Font.Gotham
        Label.TextXAlignment = Enum.TextXAlignment.Left
        Label.Parent = DropdownFrame
        
        local DropButton = Instance.new("TextButton")
        DropButton.Size = UDim2.new(0.5, -20, 0, 30)
        DropButton.Position = UDim2.new(0.5, 5, 0, 5)
        DropButton.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
        DropButton.Text = Config[configKey]
        DropButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        DropButton.TextSize = 12
        DropButton.Font = Enum.Font.Gotham
        DropButton.Parent = DropdownFrame
        
        local DropBtnCorner = Instance.new("UICorner")
        DropBtnCorner.CornerRadius = UDim.new(0, 6)
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
        ButtonFrame.Size = UDim2.new(1, -10, 0, 40)
        ButtonFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        ButtonFrame.BorderSizePixel = 0
        ButtonFrame.LayoutOrder = order or 0
        ButtonFrame.Parent = ScrollFrame
        
        local BtnCorner = Instance.new("UICorner")
        BtnCorner.CornerRadius = UDim.new(0, 8)
        BtnCorner.Parent = ButtonFrame
        
        local Button = Instance.new("TextButton")
        Button.Size = UDim2.new(1, -20, 0, 30)
        Button.Position = UDim2.new(0, 10, 0, 5)
        Button.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
        Button.Text = name
        Button.TextColor3 = Color3.fromRGB(255, 255, 255)
        Button.TextSize = 14
        Button.Font = Enum.Font.GothamBold
        Button.Parent = ButtonFrame
        
        local ButtonCorner = Instance.new("UICorner")
        ButtonCorner.CornerRadius = UDim.new(0, 6)
        ButtonCorner.Parent = Button
        
        Button.MouseButton1Click:Connect(callback)
        
        return ButtonFrame
    end
    
    CreateToggle("Aimbot", "Enabled", 0)
    CreateToggle("ESP", "ESP", 0)
    CreateToggle("Wallbang", "Wallbang", 0, function(enabled)
        WallbangActive = enabled
        if enabled then
            print("[WALLBANG] Raycast penetration active")
        end
    end)
    CreateToggle("Prediction", "Prediction", 0)
    CreateToggle("FOV Circle", "ShowFOVCircle", 0)
    
    CreateSlider("FOV", "FOV", 50, 1000, 10)
    CreateSlider("Smoothness", "Smoothness", 0, 0.9, 0.05)
    CreateSlider("Prediction Strength", "PredictionStrength", 0, 1, 0.01)
    
    CreateDropdown("Target Part", "TargetPart", {"Head", "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso"})
    
    CreateButton("Release Target (R)", function()
        Target = nil
        Locked = false
        print("[AIMBOT] Target lock released")
    end)
    
    ScreenGui.Parent = CoreGui
    
    print("[GUI] Menu created successfully")
    print("[GUI] Press RIGHT CTRL to toggle menu")
    
    return ScreenGui
end

local MenuGUI = CreateGUI()

local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 2
FOVCircle.NumSides = 64
FOVCircle.Radius = Config.FOV
FOVCircle.Filled = false
FOVCircle.Transparency = 1
FOVCircle.Color = Color3.fromRGB(100, 150, 255)
FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    
    local key = input.KeyCode
    
    if key == Enum.KeyCode.RightControl then
        MenuGUI.Enabled = not MenuGUI.Enabled
        print("[GUI] Menu: " .. (MenuGUI.Enabled and "VISIBLE" or "HIDDEN"))
    end
    
    if key == Enum.KeyCode.E then
        Config.Enabled = not Config.Enabled
        print(string.format("[AIMBOT] Status: %s", Config.Enabled and "ENABLED" or "DISABLED"))
    end
    
    if key == Enum.KeyCode.G then
        Config.Wallbang = not Config.Wallbang
        WallbangActive = Config.Wallbang
        print(string.format("[WALLBANG] Status: %s", Config.Wallbang and "ENABLED" or "DISABLED"))
    end
    
    if key == Enum.KeyCode.Y then
        Config.ESP = not Config.ESP
        print(string.format("[ESP] Status: %s", Config.ESP and "ENABLED" or "DISABLED"))
    end
    
    if key == Enum.KeyCode.R then
        Target = nil
        Locked = false
        print("[AIMBOT] Target released")
    end
    
    if key == Enum.KeyCode.T then
        local parts = {"Head", "HumanoidRootPart", "UpperTorso", "Torso"}
        for i, p in ipairs(parts) do
            if p == Config.TargetPart then
                Config.TargetPart = parts[(i % #parts) + 1]
                break
            end
        end
        print(string.format("[AIMBOT] Target part: %s", Config.TargetPart))
    end
    
    if key == Enum.KeyCode.LeftBracket then
        Config.FOV = math.max(50, Config.FOV - 50)
        print(string.format("[AIMBOT] FOV: %d", Config.FOV))
    end
    
    if key == Enum.KeyCode.RightBracket then
        Config.FOV = math.min(1000, Config.FOV + 50)
        print(string.format("[AIMBOT] FOV: %d", Config.FOV))
    end
    
    if key == Enum.KeyCode.Minus then
        Config.PredictionStrength = math.max(0, Config.PredictionStrength - 0.01)
        print(string.format("[AIMBOT] Prediction: %.3f", Config.PredictionStrength))
    end
    
    if key == Enum.KeyCode.Equals then
        Config.PredictionStrength = math.min(1, Config.PredictionStrength + 0.01)
        print(string.format("[AIMBOT] Prediction: %.3f", Config.PredictionStrength))
    end
end)

RunService.RenderStepped:Connect(function()
    pcall(AimbotCore)
    pcall(UpdateHighlights)
    
    if Config.ShowFOVCircle then
        FOVCircle.Visible = true
        FOVCircle.Radius = Config.FOV
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    else
        FOVCircle.Visible = false
    end
end)

print("[SYSTEM] Initialized successfully")
print("[SYSTEM] ========================================")
print("[SYSTEM] GUI Controls:")
print("[SYSTEM]   RIGHT CTRL - Toggle Menu")
print("[SYSTEM] ========================================")
print("[SYSTEM] Keybind Controls:")
print("[SYSTEM]   E - Aimbot")
print("[SYSTEM]   G - Wallbang")
print("[SYSTEM]   Y - ESP")
print("[SYSTEM]   R - Release Target")
print("[SYSTEM]   T - Target Part")
print("[SYSTEM]   [ ] - FOV")
print("[SYSTEM]   - = - Prediction")
print("[SYSTEM] ========================================")
print("[SYSTEM] Ready")