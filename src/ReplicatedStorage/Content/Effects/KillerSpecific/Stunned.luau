local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ServerUtils = RunService:IsServer() and require(game:GetService("ServerScriptService").ServerUtils) or nil
local Effect = require(ReplicatedStorage.Classes.Effect)
local Types = require(ReplicatedStorage.Classes.Types)

return Effect.New({
    Name = "Stunned",
    Description = "Keeps the player still and unable to use their abilities for a specific amount of time.",
    Duration = 3,
    ShowInGUI = true,
    Apply = function(_own: Types.Effect, _level: number, char: Model)
        if RunService:IsServer() then
            return
        end
        require(Players.LocalPlayer.Character.PlayerAttributeScripts.SpeedManager):AddFactor("Stunned", 0)
    end,
    Remove = function(self: Types.Effect, char: Model)
        if not RunService:IsServer() then
            require(Players.LocalPlayer.Character.PlayerAttributeScripts.SpeedManager):RemoveFactor("Stunned")
            return
        end
        
        ServerUtils.Character.ApplyEffect({
            TargetHumanoid = char:FindFirstChildWhichIsA("Humanoid"),
            EffectSettings = {
                Name = "SpawnProtection",
                Subfolder = "KillerSpecific",
            },
        })
    end
})
