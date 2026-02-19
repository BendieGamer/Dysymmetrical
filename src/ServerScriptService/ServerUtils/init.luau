local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Modules.Network)
local Utils = require(ReplicatedStorage.Modules.Utils)

local ServerUtils = {
	--- IDs used in the anti-cheat to display kick messages.
	KickIDs = {
		Noclipping = {
			ID = "0001",
			Message = "Player assumed to be noclipping.",
		},
		Flying = {
			ID = "0002",
			Message = "Player assumed to be flying.",
		},
		TPing = {
			ID = "0003",
			Message = "Player assumed to be teleporting across great distances.",
		},
	},

	--don't add anything in here
	Commands = {},
	CommandDebounce = {},

    Player = require(script.ServerPlayerUtils),
    PlayerData = require(script.ServerPlayerDataUtils),
    Character = require(script.ServerCharacterUtils),
}

function ServerUtils:Init()
    for _, CommandScript in ReplicatedStorage.Security.ModeratorCommands:GetChildren() do
        if not CommandScript:IsA("ModuleScript") then
            continue
        end
        ServerUtils.Commands[CommandScript.Name] = require(CommandScript)
    end

	Network:SetConnection("GetPermRank", "REMOTE_FUNCTION", function(Player: Player): number
		return ServerUtils.Player.GetPlayerPermissionRank(Player)
	end)
	Network:SetConnection("HasPermRank", "REMOTE_FUNCTION", function(Player: Player, Rank: string | number): boolean
		return ServerUtils.Player.PlayerHasPermissionRank(Player, Rank)
	end)
	Network:SetConnection("ExecCmd", "REMOTE_FUNCTION", function(Player: Player, CommandName: string, ...)
        task.defer(function()
			ServerUtils.CommandDebounce[Player.UserId] = 0.5

            repeat
                ServerUtils.CommandDebounce[Player.UserId] -= task.wait(0.05)
            until ServerUtils.CommandDebounce[Player.UserId] <= 0

			ServerUtils.CommandDebounce[Player.UserId] = nil
		end)
        
        return ServerUtils.Commands[CommandName]:Executed(...)
    end, function(Player: Player, CommandName: string, ...): boolean
		return not (ServerUtils.CommandDebounce[Player.UserId] and not ServerUtils.Player.PlayerHasPermissionRank(Player, ServerUtils.Commands[CommandName].RankRequired or Utils.Ranks.ServerOwner) or ServerUtils.Commands[CommandName] == nil)
    end)
end

return ServerUtils
