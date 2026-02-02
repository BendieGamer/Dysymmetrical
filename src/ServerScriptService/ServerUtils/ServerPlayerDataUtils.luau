local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Classes.Types)
local Achievements = require(ReplicatedStorage.Content.Achievements)
local Network = require(ReplicatedStorage.Modules.Network)
local Utils = require(ReplicatedStorage.Modules.Utils)

local ServerPlayerDataUtils = {}

--- Sets a player's progress of a specific achievement.
--- 
--- Useful for milestone achievements.
function ServerPlayerDataUtils.SetAchievementProgress(Player: Player, AchievementPath: string, Amount: number)
	local SplitPath = Utils.Type.SplitStringPath(AchievementPath)
	local Achievement: Types.Achievement = Achievements
	for _, step in SplitPath do
		Achievement = Achievement[step]
		if not Achievement then
			warn("[ServerPlayerDataUtils.SetAchievementProgress] Achievement from path "..AchievementPath.." not found!", debug.traceback())
			return
		end
	end
	if not Achievement.Requirement then
		warn("[ServerPlayerDataUtils.SetAchievementProgress] Achievement from path "..AchievementPath.." doesn't have a numeric requirement! If this is intentional, make sure to use `ServerPlayerDataUtils.CompleteAchievement()` instead!", debug.traceback())
		return
	end

	local AValue = Utils.PlayerData.GetAchievementObject(Player, AchievementPath)

	if Amount >= Achievement.Requirement then
		task.defer(ServerPlayerDataUtils.CompleteAchievement, Player, AchievementPath)
		return
	end

	AValue.Value = Amount
end

--- Increments a player's progress of a specific achievement.
function ServerPlayerDataUtils.IncrementAchievementProgress(Player: Player, AchievementPath: string, Amount: number)
	local SplitPath = Utils.Type.SplitStringPath(AchievementPath)
	local Achievement: Types.Achievement = Achievements
	for _, step in SplitPath do
		Achievement = Achievement[step]
		if not Achievement then
			warn("[ServerPlayerDataUtils.IncrementAchievementProgress] Achievement from path "..AchievementPath.." not found!", debug.traceback())
			return
		end
	end
	if not Achievement.Requirement then
		warn("[ServerPlayerDataUtils.IncrementAchievementProgress] Achievement from path "..AchievementPath.." doesn't have a numeric requirement! If this is intentional, make sure to use `ServerPlayerDataUtils.CompleteAchievement()` instead!", debug.traceback())
		return
	end

	local AValue = Utils.PlayerData.GetAchievementObject(Player, AchievementPath)

	if AValue.Value + Amount >= Achievement.Requirement then
		task.defer(ServerPlayerDataUtils.CompleteAchievement, Player, AchievementPath)
		return
	end

	AValue.Value += Amount
end

--- Grants a player an achievement instantly.
--- 
--- Useful to grant boolean achievements or just complete achievements that have a numeric requirement.
--- 
--- ### ANY CALLS TO THIS FUNCTION SHOULD BE DEFERRED IF THE ACHIEVEMENT TO GRANT HAS A `BadgeId` PROPERTY SET!
function ServerPlayerDataUtils.CompleteAchievement(Player: Player, AchievementPath: string)
	print(`Granting achievement "{AchievementPath}"...`)
	local SplitPath = Utils.Type.SplitStringPath(AchievementPath)
	local Achievement: Types.Achievement = Achievements[SplitPath[1]].Achievements[SplitPath[2]]
	if not Achievement then
		warn("[ServerPlayerDataUtils.CompleteAchievement] Achievement from path "..AchievementPath.." not found!", debug.traceback())
		return
	end

	Utils.Instance.FindFirstChild(Player, "PlayerData.Achievements."..AchievementPath).Value = Achievement.Requirement or true

	--granting achievement reward
	task.defer(function()
		if not Achievement.RewardType then
			return
		end

		if Achievement.RewardType == "Currency" then
			ServerPlayerDataUtils.UpdatePlayerStat(Player, "Currency.Money", Achievement.Amount)
			return
		end

		if Achievement.RewardType == "Emote" then
			ServerPlayerDataUtils.GrantEmoteToPlayer(Player, Achievement.Item)
			return
		end

		ServerPlayerDataUtils.GrantCharacterItemToPlayer(Player,
			Achievement.CharacterRole,
			Achievement.Item,
			Achievement.RewardType == "Skin" and Achievement.Skin or nil
		)
	end)

	--display the reward notification
	Network:FireClientConnection(Player, "ShowRewardNotification", "REMOTE_EVENT", AchievementPath, "Achievement")

	--grant the badge if applicable
	if Achievement.BadgeID then
		BadgeService:AwardBadgeAsync(Player.UserId, Achievement.BadgeID)
	end
end

return ServerPlayerDataUtils
