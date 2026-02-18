local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Network = require(script.Parent.Network)

local LightingModule = {
    -- CurrentLighting = nil,
}

local DefaultProperties = {
    Ambient = Color3.fromRGB(0, 0, 0),
    Brightness = 3,
    ColorShift_Bottom = Color3.fromRGB(0, 0, 0),
    ColorShift_Top = Color3.fromRGB(0, 0, 0),
    EnvironmentDiffuseScale = 1,
    EnvironmentSpecularScale = 1,
    GlobalShadows = true,
    OutdoorAmbient = Color3.fromRGB(70, 70, 70),
    ShadowSoftness = 0.2,
    ClockTime = 5.4,
    GeographicLatitude = 0,
    ExposureCompensation = 1.24,
    FogColor = Color3.fromRGB(192, 192, 192),
    FogEnd = 100000,
    FogStart = 0,
}

function LightingModule:Init()
    if RunService:IsServer() then
        Network:SetConnection("GetCurrentLighting", "REMOTE_FUNCTION", function(Player: Player)
            if LightingModule.CurrentLighting then
                local Props = LightingModule.CurrentLighting:Clone()
                Props.Parent = Player.PlayerGui
                Debris:AddItem(Props, 20)
                return Props
            end

            return {}
        end)
    else
        Network:SetConnection("SetCustomLighting", "REMOTE_EVENT", function(Properties: {[string]: any} | Folder)
            LightingModule.SetCustomLighting(Properties)
        end)
        Network:SetConnection("SetDefaultLighting", "REMOTE_EVENT", function()
            LightingModule.SetDefaultLighting()
        end)
    end

    LightingModule.SetDefaultLighting()
end

function LightingModule.ReplicateServerLighting()
    if RunService:IsServer() then
        return
    end

    local Current = Network:FireServerConnection("GetCurrentLighting", "REMOTE_FUNCTION")
    if not Current then
        return
    end
    LightingModule.SetCustomLighting(Current)
end

function LightingModule.SetCustomLighting(Properties: {[string]: any} | Folder)
    if RunService:IsServer() then
        if typeof(Properties) == "table" then
            Network:FireAllClientConnection("SetCustomLighting", "REMOTE_EVENT", Properties)

            Properties = Properties or {}
            for name, value in Properties do
                Lighting[name] = value
            end

            return
        end

        if Properties:IsA("Folder") then
            local Current = ReplicatedStorage:FindFirstChild("CurrentReplicatedLighting")
            if Current then
                Current:Destroy()
            end

            Properties = Properties:Clone()
            Properties.Name = "CurrentReplicatedLighting"
            Properties.Parent = ReplicatedStorage
        end

        LightingModule.CurrentLighting = Properties
        Network:FireAllClientConnection("SetCustomLighting", "REMOTE_EVENT", Properties)

        return
    end

    if typeof(Properties) == "Instance" then
        if Properties:IsA("Folder") then
            Lighting:ClearAllChildren()

            for _, Child in Properties:GetChildren() do
                if Child:IsA("ModuleScript") then
                    LightingModule.SetCustomLighting(require(Child))
                else
                    Child:Clone().Parent = Lighting
                end
            end

            return
        end

        if Properties:IsA("ModuleScript") then
            if #Properties:GetChildren() > 0 then
                Lighting:ClearAllChildren()

                for _, Child in Properties:GetChildren() do
                    Child:Clone().Parent = Lighting
                end
            end

            LightingModule.SetCustomLighting(require(Properties))

            return
        end

        return
    end

    Properties = Properties or {}
    for name, value in Properties do
        Lighting[name] = value
    end
end

function LightingModule.SetDefaultLighting()
    LightingModule.SetCustomLighting(DefaultProperties)
    LightingModule.SetCustomLighting(script.DefaultLighting)
    
    if RunService:IsServer() then
        if typeof(LightingModule.CurrentLighting) == "Instance" then
            LightingModule.CurrentLighting:Destroy()
        end
        LightingModule.CurrentLighting = nil

        Network:FireAllClientConnection("SetDefaultLighting", "REMOTE_EVENT")

        return
    end
end

return LightingModule
