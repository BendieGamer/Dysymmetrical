local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local EffectManager = {
    Effects = {},
    -- Janitor = nil,
}

function EffectManager:Init()
    local Char = Players.LocalPlayer.Character

    self.Janitor = Janitor.new()
    self.Janitor:LinkToInstance(Char)

    self.Janitor:Add(RunService.PreSimulation:Connect(function(delta: number)
        for _, effect: Types.Effect in self.Effects do
            effect.TimeLeft -= delta
        end
    end))

    local Effects = Char:FindFirstChild("Effects")

    self.Janitor:Add(Effects.ChildAdded:Connect(function(EffectValue: Instance)
        if not EffectValue:IsA("NumberValue") then
            return
        end
        
        while EffectValue:GetAttribute("Duration") == nil do
            task.wait()
        end

        local Module = Utils.Instance.GetEffectModule(EffectValue.Name, EffectValue:GetAttribute("Subfolder"), true)
        self:AddEffect(Module, EffectValue.Value, EffectValue:GetAttribute("Duration"))

        Utils.Instance.ObserveAttribute(EffectValue, "Duration", function(Duration: number)
            if self.Effects[EffectValue.Name] == nil then
                return
            end

            self.Effects[EffectValue.Name].TimeLeft = Duration
        end)
    end))

    self.Janitor:Add(Effects.ChildRemoved:Connect(function(EffectValue: Instance)
        if EffectValue:IsA("NumberValue") then
            self:RemoveEffect(EffectValue.Name)
        end
    end))
end

function EffectManager:AddEffect(Effect: ModuleScript, level: number?, duration: number?)
    local EffectModule = Utils.Type.CopyTable(require(Effect)) :: Types.Effect
    self.Effects[Effect.Name] = EffectModule

    EffectModule.TimeLeft = duration or EffectModule.Duration
    EffectModule.Level = level or EffectModule.Level

    if EffectModule.Apply == nil then
        return
    end
    EffectModule:Apply(level, Players.LocalPlayer.Character, duration or EffectModule.Duration)
end

function EffectManager:RemoveEffect(effect: string)
    local Effect = self.Effects[effect]
    if Effect == nil then return end

    if Effect.Remove ~= nil then
        self.Effects[effect]:Remove(Players.LocalPlayer.Character)
    end

    self.Effects[effect] = nil
end

return EffectManager
