local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Modules.Network)
local PlayerRespawnManager = require(script.PlayerRespawnManager)
local Utils = require(ReplicatedStorage.Modules.Utils)

local PlayerManager = {}

function PlayerManager:Init()
    Network:SetConnection("PlayerLoad", "REMOTE_EVENT", PlayerManager._OnPlayerLoaded, function(Player: Player): boolean
        return not Player:GetAttribute("Loaded")
    end)

    Utils.Player.ObservePlayers(function(Player: Player)
        PlayerRespawnManager.LoadCharacter(Player)
    end)
end

function PlayerManager._OnPlayerLoaded(Player: Player)
    --wait for a while to make sure the player doesn't get sent to a round directly if it starts as they join
    --also to make sure that the changelog appears on next boot if the player leaves before these 3 seconds just in case
    task.wait(3)

    --obviously, if there is no player, halt
    if not Player then
        return
    end

    --set them as loaded
    Player:SetAttribute("Loaded", true)

    --try to fetch their LastSeenLog and, if it's there, update it
    --this is done mainly for changelogs to show up on boot if there's a new update
    local LastSeen = Utils.PlayerData.GetSpecificObject(Player, "Misc.LastSeenLog")
    if LastSeen then
        LastSeen.Value = game.PlaceVersion
    end
end

return PlayerManager
