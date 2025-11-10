--[[
Copyright © 2025 compiledkernel-idk

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


]]

local VERSION = "1.0.0"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

print("Aimbot hooking")
print("[SYSTEM] Copyright (c) 2025")

local Config = {
    Enabled = false,
    FOV = 400,
    Smoothness = 0,
    Prediction = true,
    PredictionStrength = 0.165,
    TargetPart = "Head",
    Wallbang = false,
    ESP = true,
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

local hookSuccess = pcall(function()
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    local oldIndex = mt.__index
    
    setreadonly(mt, false)
    
    mt.__namecall = function(self, ...)
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
            
            for attempt = 1, 50 do
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
            
            if method == "Raycast" then
                return nil
            else
                return nil, nil, nil, nil
            end
        end
        
        return oldNamecall(self, ...)
    end
    
    setreadonly(mt, true)
end)

if hookSuccess then
    print("[HOOK] Metamethod hooks successfully installed")
    print("[HOOK] Raycast interception active")
else
    warn("[HOOK] Metamethod hooking failed, attempting fallback method")
    
    pcall(function()
        local oldFindPartIgnore = workspace.FindPartOnRayWithIgnoreList
        workspace.FindPartOnRayWithIgnoreList = function(self, ray, ignoreList, ...)
            if not WallbangActive then
                return oldFindPartIgnore(workspace, ray, ignoreList, ...)
            end
            
            local ignore = ignoreList or {}
            
            for i = 1, 50 do
                local part, pos, norm, mat = oldFindPartIgnore(workspace, ray, ignore, ...)
                
                if not part then return nil, pos, norm, mat end
                if IsPlayerPart(part) then return part, pos, norm, mat end
                
                table.insert(ignore, part)
            end
            
            return nil, nil, nil, nil
        end
        
        print("[HOOK] Fallback hooks successfully installed")
    end)
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

local ESPFolder = Instance.new("Folder", game:GetService("CoreGui"))
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

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    
    local key = input.KeyCode
    
    if key == Enum.KeyCode.E then
        Config.Enabled = not Config.Enabled
        print(string.format("[AIMBOT] Status: %s", Config.Enabled and "ENABLED" or "DISABLED"))
    end
    
    if key == Enum.KeyCode.G then
        Config.Wallbang = not Config.Wallbang
        WallbangActive = Config.Wallbang
        print(string.format("[WALLBANG] Status: %s", Config.Wallbang and "ENABLED" or "DISABLED"))
        if Config.Wallbang then
            print("[WALLBANG] Raycast penetration active")
        end
    end
    
    if key == Enum.KeyCode.Y then
        Config.ESP = not Config.ESP
        print(string.format("[ESP] Status: %s", Config.ESP and "ENABLED" or "DISABLED"))
    end
    
    if key == Enum.KeyCode.R then
        Target = nil
        Locked = false
        print("[AIMBOT] Target lock released")
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
        print(string.format("[AIMBOT] Prediction strength: %.3f", Config.PredictionStrength))
    end
    
    if key == Enum.KeyCode.Equals then
        Config.PredictionStrength = math.min(1, Config.PredictionStrength + 0.01)
        print(string.format("[AIMBOT] Prediction strength: %.3f", Config.PredictionStrength))
    end
end)

RunService.RenderStepped:Connect(function()
    pcall(AimbotCore)
    pcall(UpdateHighlights)
end)

print("[SYSTEM] All systems initialized successfully")
print("[SYSTEM] Aimbot: Press E to toggle")
print("[SYSTEM] Wallbang: Press G to toggle")
print("[SYSTEM] ESP: Press Y to toggle")
print("[SYSTEM] Target Release: Press R")
print("[SYSTEM] Change Target Part: Press T")
print("[SYSTEM] Adjust FOV: Press [ or ]")
print("[SYSTEM] Adjust Prediction: Press - or =")
print("[SYSTEM] Ready for operation")