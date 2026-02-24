local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Utils = require(ReplicatedStorage.Modules.Utils)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local SpeedManager = {
    Factors = {},
    LastMultiplier = 1,
    CanSprint = true,
}

function SpeedManager:Init()
    local Character = Players.LocalPlayer.Character
    local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")

    --getting the character's role before the speed loop to not have to find it every frame in which BaseSpeed is missing
    local Role = Character:GetAttribute("Role")
    local CharacterModule
    if Role ~= "Spectator" then
        CharacterModule = Utils.Instance.GetCharacterModule(Role, Character:GetAttribute("CharacterName"), Character:GetAttribute("CharacterSkin"))
        if CharacterModule then
            CharacterModule = require(CharacterModule)
        end
    end

    --le janitor
    local CharacterJanitor = Janitor.new()
    CharacterJanitor:LinkToInstance(Character)

    --add renderstepped to janitor
    CharacterJanitor:Add(RunService.PreSimulation:Connect(function(_delta: number)
        --if the character isn't in the world, halt
        if not (Character and Character.Parent and Humanoid) then
            return
        end
        
        --get the base speed
        local CurrentSpeed = Character:GetAttribute("BaseSpeed")
        --if it's nil, get the fallback
        if CurrentSpeed == nil then
            CurrentSpeed = CharacterModule ~= nil and CharacterModule.GameplayConfig.BaseSpeed or 10.5
        end

        --multiply a number starting from 1 by every factor since they're all multipliers
        local TotalFactor = 1
        for _, factor in self.Factors do
            TotalFactor *= factor
        end

        --mutliply the speed by the total calculated factor
        CurrentSpeed *= TotalFactor
        --set the humanoid's speed to the final calculated speed
        Humanoid.WalkSpeed = CurrentSpeed
        
        --set the last multiplier for usage in different scripts
        self.LastMultiplier = TotalFactor
    end))
end

function SpeedManager:AddFactor(Name: string, Value: number)
    self.Factors[Name] = Value
end

function SpeedManager:RemoveFactor(Name: string)
    self.Factors[Name] = nil
end

return SpeedManager
