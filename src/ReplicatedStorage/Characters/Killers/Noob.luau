local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil
local Character = require(ReplicatedStorage.Classes.Character)
local Ability = require(ReplicatedStorage.Classes.Ability)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Sounds = require(ReplicatedStorage.Modules.Sounds)

local PASSIVE_DURATION = 10
local PASSIVE_SCREEN_RED_DURATION = 10
local ENRAGE_CHECK_INTERVAL = 0.5

-- ============================================================
-- PASSIVE — ON KILL
-- Called when Noob kills a survivor
-- ============================================================
local OnKillPassive
OnKillPassive = function(killedCharacter: Model)
	if not RunService:IsServer() then
		return
	end
	if not killedCharacter or not killedCharacter:IsA("Model") then
		return
	end

	local killedRoot = killedCharacter:FindFirstChild("HumanoidRootPart")
	if not killedRoot or not CommonFunctions then
		return
	end

	-- On kill, no special passive effect for Noob (Enraged is triggered by survivor tasks)
end

-- ============================================================
-- SLASH ABILITY
-- Basic attack with 0.5 second windup dealing 20 damage.
-- ============================================================
local function SlashBehaviour(self: Types.Ability)
	if RunService:IsServer() then
		local hrp = self.OwnerProperties.HRP
		local humanoid = self.OwnerProperties.Humanoid
		local characterModel = self.OwnerProperties.Character

		Sounds.PlaySound(self.UseSound, { Parent = hrp })

		local moveDirection = humanoid.MoveDirection
		local moveDirFlat = Vector3.new(moveDirection.X, 0, moveDirection.Z)
		local useMovementDirection = moveDirFlat.Magnitude > 0.1

		local function createDynamicCFrame(offsetZ: number)
			return function()
				local currentHRP = self.Owner.Character and self.Owner.Character:FindFirstChild("HumanoidRootPart")
				if not currentHRP then
					return CFrame.new()
				end

				local lookDir = Vector3.new(currentHRP.CFrame.LookVector.X, 0, currentHRP.CFrame.LookVector.Z).Unit
				return CFrame.new(currentHRP.Position + lookDir * offsetZ, currentHRP.Position + lookDir)
			end
		end

		task.delay(self.Delay, function()
			require(ReplicatedStorage.Classes.Hitbox).New(self.Owner, {
				CFrame = createDynamicCFrame(3),
				Size = self.HitboxSize,
				Time = 0.2,
				Damage = 20,
				Reason = "Slash Attack",
				ExecuteOnKill = true,
				Connections = {
					PostHit = function(_, targetHumanoid, isFirstHit)
						if isFirstHit and targetHumanoid and targetHumanoid.Health <= 0 then
							local targetCharacter = targetHumanoid.Parent
							if targetCharacter and targetCharacter:IsA("Model") then
								OnKillPassive(targetCharacter)
							end
						end
					end,
				},
			})
		end)
	else
		self:PlayUseAnimation()
	end
end

-- ============================================================
-- GRAB ABILITY
-- Noob dashes forward and grabs a player, ramming them into
-- walls/objects to deal 10 damage and ragdoll them.
-- ============================================================
local function GrabBehaviour(self: Types.Ability)
	if RunService:IsServer() then
		local hrp = self.OwnerProperties.HRP
		local humanoid = self.OwnerProperties.Humanoid
		local characterModel = self.OwnerProperties.Character

		local survivors = Utils.Character.GetCharactersWithRoles(false).Survivor or {}
		local direction = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
		if direction.Magnitude < 0.1 then
			direction = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
		end

		if direction.Magnitude > 0 then
			direction = direction.Unit
			local speed = 60
			local maxDistance = 50
			local traveled = 0
			local grabbedSurvivor = false
			local grabStopped = false

			local connection
			local function finishGrab()
				if grabStopped then
					return
				end
				grabStopped = true
				if connection then
					connection:Disconnect()
					connection = nil
				end
			end

			connection = RunService.Heartbeat:Connect(function(deltaTime)
				if grabStopped then
					return
				end

				local inputDirection = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
				local lookDirection = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
				local targetDirection = inputDirection.Magnitude > 0.1 and inputDirection.Unit
					or (lookDirection.Magnitude > 0 and lookDirection.Unit or direction)
				local turnAlpha = math.clamp(8 * deltaTime, 0, 1)
				direction = direction:Lerp(targetDirection, turnAlpha)
				if direction.Magnitude > 0 then
					direction = direction.Unit
				end

				local moveDistance = speed * deltaTime
				local moveDir = direction
				if moveDir.Magnitude <= 0 then
					finishGrab()
					return
				end
				moveDir = moveDir.Unit

				local raycastParams = RaycastParams.new()
				raycastParams.FilterDescendantsInstances = { characterModel }
				raycastParams.FilterType = Enum.RaycastFilterType.Exclude

				local SKIN = 0.35
				local castDistance = moveDistance + SKIN
				local raycastResult = workspace:Raycast(hrp.Position, moveDir * castDistance, raycastParams)

				local allowedDistance = moveDistance
				local blocked = false
				if raycastResult then
					allowedDistance = math.max(0, raycastResult.Distance - SKIN)
					blocked = true
				end

				if allowedDistance <= 0 then
					finishGrab()
					return
				end

				local rawPosition = hrp.Position + moveDir * allowedDistance

				-- Raycast down from slightly above to snap the character onto the floor
				local floorParams = RaycastParams.new()
				floorParams.FilterDescendantsInstances = { characterModel }
				floorParams.FilterType = Enum.RaycastFilterType.Exclude
				local floorResult = workspace:Raycast(
					Vector3.new(rawPosition.X, rawPosition.Y + 2, rawPosition.Z),
					Vector3.new(0, -6, 0),
					floorParams
				)
				local groundY = floorResult and floorResult.Position.Y or rawPosition.Y
				-- HRP sits ~3 studs above the floor for R6/R15
				local newPosition = Vector3.new(rawPosition.X, math.max(rawPosition.Y, groundY + 3), rawPosition.Z)

				-- Check for survivors to grab
				for _, survivor in survivors do
					local survivorRoot = survivor:FindFirstChild("HumanoidRootPart")
					if survivorRoot then
						local survivorPos = survivorRoot.Position
						local distanceToSurvivor =
							Vector3.new(survivorPos.X - newPosition.X, 0, survivorPos.Z - newPosition.Z).Magnitude
						if distanceToSurvivor < 4 then
							grabbedSurvivor = true
							local survivorHumanoid = survivor:FindFirstChildWhichIsA("Humanoid")
							if survivorHumanoid then
								-- Grant EXP when grabbing a survivor
								CommonFunctions.GrantRewardToPlayer(self.Owner, { EXP = 15, Reason = "hit with Grab" })

								-- Deal damage from grab
								CommonFunctions.DamagePlayer({
									SourcePlayer = self.Owner,
									TargetHumanoid = survivorHumanoid,
									Damage = 10,
									Reason = "Grab Attack",
								})

								-- Fling horizontally only; no downward Y to avoid phasing through the floor
								survivorRoot.AssemblyLinearVelocity = Vector3.new(moveDir.X, 0, moveDir.Z) * 80

								-- Ragdoll the survivor
								CommonFunctions.ApplyEffect({
									TargetHumanoid = survivorHumanoid,
									EffectSettings = { Name = "Ragdoll", Level = 1, Duration = 2 },
								})
							end
							finishGrab()
							return
						end
					end
				end

				local faceDirection = Vector3.new(moveDir.X, 0, moveDir.Z)
				if faceDirection.Magnitude < 0.001 then
					faceDirection = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
				end
				if faceDirection.Magnitude > 0 then
					faceDirection = faceDirection.Unit
				end

				-- Offset from HRP to model pivot so PivotTo lands the HRP at newPosition
				local pivotOffset = characterModel:GetPivot().Position - hrp.Position
				local targetPivot = newPosition + pivotOffset
				characterModel:PivotTo(CFrame.new(targetPivot, targetPivot + faceDirection))
				traveled = traveled + allowedDistance

				if blocked then
					finishGrab()
					return
				end

				if traveled >= maxDistance then
					finishGrab()
				end
			end)

			task.delay(2, finishGrab)
		end
	else
		self:PlayUseAnimation()
	end
end

-- ============================================================
-- STRENGTH ABILITY
-- Noob impales themself, gaining increased speed for 5 seconds.
-- ============================================================
local function StrengthBehaviour(self: Types.Ability)
	if RunService:IsServer() then
		local humanoid = self.OwnerProperties.Humanoid
		local originalSpeed = humanoid.WalkSpeed

		-- Increase speed
		humanoid.WalkSpeed = originalSpeed * 1.5

		task.delay(self.Duration, function()
			if humanoid and humanoid.Parent and humanoid.Health > 0 then
				humanoid.WalkSpeed = originalSpeed
			end
		end)
	else
		self:PlayUseAnimation()
	end
end

-- ============================================================
-- SCREAM ABILITY
-- Noob screams, gaining complete stun immunity for 10 seconds.
-- ============================================================
local function ScreamBehaviour(self: Types.Ability)
	if RunService:IsServer() then
		Sounds.PlaySound(self.UseSound, { Parent = self.OwnerProperties.HRP })

		-- Apply stun immunity effect
		CommonFunctions.ApplyEffect({
			TargetHumanoid = self.OwnerProperties.Humanoid,
			EffectSettings = { Name = "StunImmunity", Level = 1, Duration = self.Duration },
		})
	else
		self:PlayUseAnimation()
	end
end

-- ============================================================
-- PASSIVE — ENRAGED
-- When a survivor completes a task, the screen of the killer
-- turns red for 10 seconds and highlights the survivor who
-- completed the task.
-- ============================================================
local function OnTaskCompletedPassive(survivor: Model)
	if not RunService:IsServer() then
		return
	end
	if not survivor or not survivor:IsA("Model") then
		return
	end

	-- Highlight the survivor who completed the task
	Utils.Player.RevealPlayerAuraTo(nil, survivor, PASSIVE_SCREEN_RED_DURATION)
end

local Noob: Types.Killer = Character.CreateKiller({
	Config = {
		Name = "Noob",
		Quote = "DIE DIE DIE!!!",
		Render = "rbxassetid://74125322169300", -- Using Bit render as placeholder
		Price = 0, -- FREE

		Origin = {
			TooltipText = "Starter Killer",
			Icon = "rbxasset://90863791545676",
		},
		Voicelines = {
			Idle = {
				"rbxassetid://0",
				"rbxassetid://0",
			},
			Kill = {
				Default = {
					"rbxassetid://0",
					"rbxassetid://0",
				},
			},
			LMS = {
				Default = {
					"rbxassetid://0",
					"rbxassetid://0",
				},
			},
			Stunned = {
				"rbxassetid://0",
				"rbxassetid://0",
			},
		},
		AnimationIDs = {
			IdleAnimation = "rbxassetid://112795426241330",
			WalkAnimation = "rbxassetid://137324262326661",
			RunAnimation = "rbxassetid://137312877674818",
			Execution = {
				Default = {
					Killer = "rbxassetid://115650093821822",
					Survivor = "rbxassetid://110235158621615",
				},
			},
		},
	},

	GameplayConfig = {
		BaseSpeed = 12,
		Health = 1500,
		StaminaProperties = {
			MaxStamina = 100,
		},

		Abilities = {
			Slash = Ability.New({
				Name = "Slash",
				InputName = "Slash",
				Cooldown = 1,
				Duration = 0.5,
				Damage = 20,
				RenderImage = "rbxassetid://11218451110",
				UseSound = "rbxassetid://12222200",
				UseAnimation = "rbxassetid://125284531450977",
				UICorner = true,
				Delay = 0.5,
				HitboxSize = Vector3.new(6, 6, 6),
				HitboxOffset = CFrame.new(0, 0, 3),
				Behaviour = SlashBehaviour,
			}),

			Grab = Ability.New({
				Name = "Grab",
				Cooldown = 20,
				InputName = "FirstAbility",
				RenderImage = "rbxassetid://11218451110",
				UseAnimation = "rbxassetid://93664378263660",
				EXP = 0,
				Behaviour = GrabBehaviour,
			}),

			Strength = Ability.New({
				Name = "Strength",
				Cooldown = 20,
				InputName = "SecondAbility",
				Duration = 5,
				RenderImage = "rbxassetid://11218451110",
				UseAnimation = "rbxassetid://74189155372575",
				EXP = 10,
				Behaviour = StrengthBehaviour,
			}),

			Scream = Ability.New({
				Name = "Scream",
				Cooldown = 30,
				InputName = "ThirdAbility",
				Duration = 10,
				RenderImage = "rbxassetid://11218451110",
				UseAnimation = "rbxassetid://139387993657669",
				UseSound = "rbxassetid://12222200",
				EXP = 15,
				Behaviour = ScreamBehaviour,
			}),
		},
	},

	OnExecution = function(_, killedCharacter)
		OnKillPassive(killedCharacter)
	end,
})

local NoobNameLabel = '<font color="rgb(255, 100, 100)">Noob</font>'
Noob.Config.Description = {
	{
		Type = "Separator",
		Text = "GENERAL INFO",
	},
	{
		Type = "Header",
		Text = "NOOB",
	},
	{
		Type = "Quote",
		Text = '"' .. Noob.Config.Quote .. '"',
	},
	{
		Type = "Text",
		Text = "A chaotic killer with raw power and unpredictable attacks. Noob charges forward with reckless abandon, "
			.. "grabbing survivors and smashing them into walls. When survivors complete tasks, Noob enters an "
			.. NoobNameLabel
			.. " ENRAGED state, hunting the last survivor to complete the task with renewed fury.",
	},
	{
		Type = "Header",
		Text = "STATS",
	},
	{
		Type = "Text",
		Text = {
			"Difficulty: ★★☆☆☆",
			"Health: " .. tostring(Noob.GameplayConfig.Health),
		},
	},
	{
		Type = "Separator",
		Text = "ABILITIES",
	},
	{
		Type = "Header",
		Text = "SLASH",
	},
	{
		Type = "Text",
		Text = NoobNameLabel
			.. " slashes forward with a 0.5 second windup, dealing <b>20 damage</b>. Quick and straightforward. "
			.. "Cooldown: <b>1s</b>.",
	},
	{
		Type = "Header",
		Text = "GRAB",
	},
	{
		Type = "Text",
		Text = NoobNameLabel
			.. " dashes forward and grabs a survivor in their path, <b>ramming them into walls or objects</b> to deal <b>10 damage</b> and <b>Ragdoll</b> them for 2 seconds. Cooldown: <b>20s</b>.",
	},
	{
		Type = "Header",
		Text = "STRENGTH",
	},
	{
		Type = "Text",
		Text = NoobNameLabel
			.. " impales themself, gaining <b>50% increased movement speed</b> for <b>5 seconds</b>. Perfect for chasing down fleeing survivors. Cooldown: <b>20s</b>.",
	},
	{
		Type = "Header",
		Text = "SCREAM",
	},
	{
		Type = "Text",
		Text = NoobNameLabel
			.. " unleashes a primal scream, gaining <b>complete stun immunity</b> for <b>10 seconds</b>. Cannot be stopped! Cooldown: <b>30s</b>.",
	},
	{
		Type = "Header",
		Text = "PASSIVE — ENRAGED",
	},
	{
		Type = "Text",
		Text = "When any survivor completes a task, the killer's screen turns <b>red</b> for <b>10 seconds</b> and "
			.. "the <b>last survivor to complete the task is highlighted</b>. "
			.. NoobNameLabel
			.. " knows exactly who to hunt next.",
	},
}

return Noob
