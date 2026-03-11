local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(ReplicatedStorage.Classes.Types)
local Effect = require(game:GetService("ReplicatedStorage").Classes.Effect)

return Effect.New({
    Name = "Speed",
    Description = "Makes the player faster the higher the level.",
    Apply = function(_own: Types.Effect, level: number, char: Model)
        if RunService:IsServer() then
            return
        end
        require(Players.LocalPlayer.Character.PlayerAttributeScripts.SpeedManager):AddFactor("SpeedEffect", 1 + 0.1 * level)
        require(Players.LocalPlayer.Character.PlayerAttributeScripts.FOVManager):AddFactor("SpeedEffect", math.clamp(1 + 0.07 * level, 1, 1.5))
    end,
    Remove = function(_own: Types.Effect, char: Model)
        if RunService:IsServer() then
            return
        end
        require(Players.LocalPlayer.Character.PlayerAttributeScripts.SpeedManager):RemoveFactor("SpeedEffect")
        require(Players.LocalPlayer.Character.PlayerAttributeScripts.FOVManager):RemoveFactor("SpeedEffect")
    end,
})
