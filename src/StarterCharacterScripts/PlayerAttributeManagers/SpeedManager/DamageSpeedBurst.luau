local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Modules.Network)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

return {
    Init = function(_)
        local Character = Players.LocalPlayer.Character
        if Character:GetAttribute("Role") == "Killer" then
            return
        end
        local SpeedManager = require(script.Parent)

        local CharacterJanitor = Janitor.new()
        CharacterJanitor:LinkToInstance(Character)

        CharacterJanitor:Add(Network:SetConnection("DamagePlayer", "REMOTE_EVENT", function(_Source: Player, _Reason: string, Damage: number)
            if Damage <= 0 then
                return
            end

            SpeedManager:AddFactor("DamageSpeedBurst", 1.26)
            task.delay(1, function()
                SpeedManager:RemoveFactor("DamageSpeedBurst")
            end)
        end))
    end,
}