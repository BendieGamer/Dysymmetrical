local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Modules.Network)
local Utils = require(ReplicatedStorage.Modules.Utils)

local ServerPlayerUtils = {
    AdminPerms = {
		-- {
		-- 	Name = "Dyscarn",
		-- 	UserId = 432073982,
		-- 	Rank = "Developer",
		-- },
	},
}

--- Function used instead of the typical `Player:Kick()` to auto-generate an anti-cheat kick message and keep consistency.
--- Use `ServerUtils.KickIDs`.
function ServerPlayerUtils.Kick(Player: Player, KickMessage: {
    ID: string,
    Message: string,
})

    Player:Kick(`\n\n[DysMemberer] {KickMessage.ID}:\n{KickMessage.Message}\n`)
end

type GrantedReward = {
	Money: number?,
	EXP: number?,
	Reason: string?,
}
--- Grants money and/or EXP to a player and displays a notification showing it.
--- The `Reason` is the source of the reward to display in the UI locally.
function ServerPlayerUtils.GrantRewardToPlayer(Player: Player, Reward: GrantedReward)
	--shouldn't give anything if in a private server
	if #game.PrivateServerId > 0 then
		return
	end

	local MoneyGranted = Reward.Money ~= nil and Reward.Money > 0 and Reward.Money or 0
	local EXPGranted = Reward.EXP ~= nil and Reward.EXP > 0 and Reward.EXP or 0
	
	--if none are granted somehow
	if MoneyGranted <= 0 and EXPGranted <= 0 then
		return
	end

	--if only EXP is granted
	if MoneyGranted <= 0 then
		ServerPlayerUtils._GrantEXPToPlayer(Player, {Reward = Reward.EXP, Visual = true, Reason = Reward.Reason})
		return
	end

	--if only money is granted
	if EXPGranted <= 0 then
		ServerPlayerUtils.UpdatePlayerStat(Player, "Currency.Money", MoneyGranted)
		Network:FireClientConnection(Player, "GrantReward", "REMOTE_EVENT", MoneyGranted, 0, Reward.Reason)
		return
	end

	--if both are granted
	ServerPlayerUtils.UpdatePlayerStat(Player, "Currency.Money", MoneyGranted)
	ServerPlayerUtils._GrantEXPToPlayer(Player, {Amount = EXPGranted, Visual = false, Reason = Reward.Reason})
	Network:FireClientConnection(Player, "GrantReward", "REMOTE_EVENT", MoneyGranted, EXPGranted, Reward.Reason)
end

type EXPGrantSettings = {
	Amount: number,
	Visual: boolean,
	Reason: string?,
}
--- INTERNAL FUNCTION: Function used to grant EXP to a player in `ServerPlayerUtils.GrantRewardToPlayer()`. Use that one instead.
function ServerPlayerUtils._GrantEXPToPlayer(Player: Player, GrantSettings: EXPGrantSettings)
	--shouldn't give anything if in a private server
	if #game.PrivateServerId > 0 then
		return
	end
	
	if GrantSettings.Visual then
		Network:FireClientConnection(Player, "GrantReward", "REMOTE_EVENT", 0, GrantSettings.Amount, GrantSettings.Reason)
	end

	local Role = Player.Character:FindFirstChild("Role")
	if not Role or Role.Value == "Spectator" then
		return
	end
	local CharacterName = Player.Character:GetAttribute("CharacterName")
	local SkinName = Player.Character:GetAttribute("CharacterSkinName")

	local CharValue = Utils.PlayerData.GetPlayerOwned(Player, Role.Value.."s."..CharacterName, false)
	CharValue.Value += GrantSettings.Amount

	local CharModule = require(Utils.Instance.GetCharacterModule(Role.Value, CharacterName))
	if CharModule.Config.Milestones then
		local CurrentLevel, _EXPRemaining, _EXPForNextLevel = Utils.Math.CalculateLevelFromEXP(CharValue.Value)
		for Level, Skin in CharModule.Config.Milestones do
			if Level <= CurrentLevel then
				ServerPlayerUtils.GrantCharacterItemToPlayer(Player, Role.Value, CharacterName, SkinName)
			end
		end
	end
end

--- Grants a character / skin to a player.
--- 
--- Should be called from achievements or milestone granting.
function ServerPlayerUtils.GrantCharacterItemToPlayer(Player: Player, Type: "Killer" | "Survivor", CharacterName: string, SkinName: string?)
	--shouldn't give anything if in a private server
	if #game.PrivateServerId > 0 then
		return
	end

	--checks for the parent
	--if SkinName is available, get the Skins folder
	--if not, get the role's folder
	local Parent = Utils.Instance.FindFirstChild(Player, "PlayerData.Purchased."..(SkinName and "Skins" or Type.."s"), 0)

	--if the value that's about to be created is already there, don't do anything
	if Utils.Instance.FindFirstChild(Parent, CharacterName..(SkinName and "."..SkinName or ""), 0) then
		return
	end

	--if the module supposedly doesn't exist, don't do anything
	local CharacterModule = Utils.Instance.GetCharacterModule(Type, CharacterName, SkinName)
	if not CharacterModule then
		return
	end

	--if SkinName is available, get an existing character skins's folder or create it if non-existent, then set the result as the value's parent
	if SkinName then
		local CharFolder = Parent:FindFirstChild(CharacterName)
		if not CharFolder then
			CharFolder = Instance.new("Folder")
			CharFolder.Name = CharacterName
			CharFolder.Parent = Parent
		end

		Parent = CharFolder
	end

	--create the item's value
	local Value = Instance.new("IntValue")
	Value.Name = SkinName or CharacterName --if SkinName is available, it should be named that
	Value.Parent = Parent

	--display the reward notification
	Network:FireClientConnection(Player, "ShowRewardNotification", "REMOTE_EVENT", CharacterModule, "QuotedGranted"..(SkinName and "Skin" or "Character"))
end

--- Grants an emote to a player.
--- 
--- Should be called from achievements or milestone granting.
function ServerPlayerUtils.GrantEmoteToPlayer(Player: Player, EmoteName: string)
	--shouldn't give anything if in a private server
	if #game.PrivateServerId > 0 then
		return
	end

	--checks for the parent
	--if SkinName is available, get the Skins folder
	--if not, get the role's folder
	local Parent = Utils.Instance.FindFirstChild(Player, "PlayerData.Purchased.Emotes", 0)

	--if the module supposedly doesn't exist, don't do anything
	local EmoteModule = Utils.Instance.GetEmoteModule(EmoteName)
	if not EmoteModule then
		return
	end

	--create the item's value
	local Value = Instance.new("IntValue")
	Value.Name = EmoteName --if SkinName is available, it should be named that
	Value.Parent = Parent

	--display the reward notification
	Network:FireClientConnection(Player, "ShowRewardNotification", "REMOTE_EVENT", EmoteModule, "QuotedGrantedEmote")
end

--- Gets a player's permission rank.
function ServerPlayerUtils.GetPlayerPermissionRank(Player: Player): number
	local HighestPlayerRank = Utils.Ranks.DefaultPlayer
	for _, Permission in ServerPlayerUtils.AdminPerms do
		if Permission.UserId == Player.UserId then
			local Value = Utils.Ranks[Permission.Rank] or tonumber(Permission.Rank) or Utils.Ranks.DefaultPlayer
			if Value < HighestPlayerRank then
				HighestPlayerRank = Value
			end
		end
	end

	return HighestPlayerRank
end

--- Checks if a player has a specific permission rank or higher.
--- 
--- The minimum rank should be grabbed from `ServerPlayerUtils.Ranks` through its name.
--- 
--- Inputting a number is still possible but the existing ranks should be checked.
--- 
--- @return If the player has the specified rank.
--- @return Its actual rank.
function ServerPlayerUtils.PlayerHasPermissionRank(Player: Player, MandatoryRank: string | number): (boolean, number)
	local Rank = ServerPlayerUtils.GetPlayerPermissionRank(Player)
	return Rank < (typeof(MandatoryRank) == "string" and Utils.Ranks[MandatoryRank] or MandatoryRank), Rank
end

return ServerPlayerUtils
