local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(ReplicatedStorage.Classes.Types)
local Effect = require(game:GetService("ReplicatedStorage").Classes.Effect)

return Effect.New({
    Name = "Slowness",
    Description = "Makes the player slower the higher the level.",
    Apply = function(_own: Types.Effect, level: number, char: Model)
        if RunService:IsServer() then
            return
        end
        require(Players.LocalPlayer.Character.PlayerAttributeScripts.SpeedManager):AddFactor("SlownessEffect", 1 - 0.1 * level)
        require(Players.LocalPlayer.Character.PlayerAttributeScripts.FOVManager):AddFactor("SlownessEffect", math.clamp(1 - 0.07 * level, 0, 1))
    end,
    Remove = function(_own: Types.Effect, char: Model)
        if RunService:IsServer() then
            return
        end
        require(Players.LocalPlayer.Character.PlayerAttributeScripts.SpeedManager):RemoveFactor("SlownessEffect")
        require(Players.LocalPlayer.Character.PlayerAttributeScripts.FOVManager):RemoveFactor("SlownessEffect")
    end,
})
