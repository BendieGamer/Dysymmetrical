local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utils = require(ReplicatedStorage.Modules.Utils)

return {
    Init = function(_)
        Utils.Instance.ObserveChildren(workspace.Hitboxes, function(Hitbox: BasePart)
            Hitbox.Transparency = 0.75
        end, function(Hitbox: Instance): boolean
            return Utils.PlayerData.GetPlayerSetting(Players.LocalPlayer, "Advanced.ShowHitboxes") and Hitbox:IsA("BasePart")
        end)
    end,
}