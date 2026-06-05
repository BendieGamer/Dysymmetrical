local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil
local SimplePath = RunService:IsServer() and require(ReplicatedStorage.Utils.SimplePath) or nil
local Character = require(ReplicatedStorage.Classes.Character)
local Ability = require(ReplicatedStorage.Classes.Ability)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Sounds = require(ReplicatedStorage.Modules.Sounds)

local PASSIVE_DURATION = 10
local ChargeAnimToken = 0

local HEAD_TEXTURE_DEFAULT = "rbxassetid://112188028181640"
local HEAD_TEXTURE_SWING = "rbxassetid://109718873180961" -- TODO: replace
local HEAD_TEXTURE_CHARGE = "rbxassetid://PLACEHOLDER_CHARGE" -- TODO: replace
local HEAD_TEXTURE_BITSUMMON = "rbxassetid://PLACEHOLDER_BITSUMMON" -- TODO: replace
local HEAD_TEXTURE_DIGITALEYE = "rbxassetid://PLACEHOLDER_DIGITALEYE" -- TODO: replace
local HEAD_TEXTURE_STATEEDIT = "rbxassetid://PLACEHOLDER_STATEEDIT" -- TODO: replace
local HEAD_TEXTURE_STUNNED = "rbxassetid://PLACEHOLDER_STUNNED" -- TODO: replace

--- Finds the "Main head" part in the character and sets its TextureID.
--- Handles MeshPart (TextureID on the part itself) and Part+SpecialMesh setups.
local function SetHeadTexture(character: Model, textureId: string)
	local head = character:FindFirstChild("Main head")
	if not head then
		warn("[BIT] SetHeadTexture: 'Main head' not found in character", character.Name)
		return
	end
	if head:IsA("MeshPart") then
		head.TextureID = textureId
		print("[BIT] SetHeadTexture: set MeshPart TextureID →", textureId, "on", character.Name)
		return
	end
	local mesh = head:FindFirstChildWhichIsA("SpecialMesh")
	if not mesh then
		warn("[BIT] SetHeadTexture: no SpecialMesh found inside 'Main head' on", character.Name)
		return
	end
	mesh.TextureId = textureId
	print("[BIT] SetHeadTexture: set SpecialMesh TextureId →", textureId, "on", character.Name)
end

-- Per-player clone tracking (keyed by Player instance)
local activeClonesPerPlayer = {}
local MAX_CLONES = 3

-- Client-side: called via ExecuteReplicatedModule from the server
local function _ApplyConfusedClient(duration: number)
	if RunService:IsServer() then
		return function() end
	end
	local ContextActionService = game:GetService("ContextActionService")

	local function invertedForward(_, inputState)
		ContextActionService:CallFunction("moveBackwardAction", inputState, nil)
		return Enum.ContextActionResult.Sink
	end
	local function invertedBackward(_, inputState)
		ContextActionService:CallFunction("moveForwardAction", inputState, nil)
		return Enum.ContextActionResult.Sink
	end
	local function invertedLeft(_, inputState)
		ContextActionService:CallFunction("moveRightAction", inputState, nil)
		return Enum.ContextActionResult.Sink
	end
	local function invertedRight(_, inputState)
		ContextActionService:CallFunction("moveLeftAction", inputState, nil)
		return Enum.ContextActionResult.Sink
	end

	ContextActionService:BindActionAtPriority(
		"BITConfusedForward",
		invertedForward,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.PlayerActions.CharacterForward
	)
	ContextActionService:BindActionAtPriority(
		"BITConfusedBackward",
		invertedBackward,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.PlayerActions.CharacterBackward
	)
	ContextActionService:BindActionAtPriority(
		"BITConfusedLeft",
		invertedLeft,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.PlayerActions.CharacterLeft
	)
	ContextActionService:BindActionAtPriority(
		"BITConfusedRight",
		invertedRight,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.PlayerActions.CharacterRight
	)

	task.delay(duration, function()
		ContextActionService:UnbindAction("BITConfusedForward")
		ContextActionService:UnbindAction("BITConfusedBackward")
		ContextActionService:UnbindAction("BITConfusedLeft")
		ContextActionService:UnbindAction("BITConfusedRight")
	end)

	return function()
		ContextActionService:UnbindAction("BITConfusedForward")
		ContextActionService:UnbindAction("BITConfusedBackward")
		ContextActionService:UnbindAction("BITConfusedLeft")
		ContextActionService:UnbindAction("BITConfusedRight")
	end
end

local OnKillPassive

local function BITSummonLog(...)
	print("[BIT][Summon]", ...)
end

-- ============================================================
-- CHARGE ABILITY
-- Dash in the current move/facing direction, deals 20 damage.
-- ============================================================
local function ChargeBehaviour(self: Types.Ability)
	if RunService:IsServer() then
		SetHeadTexture(self.OwnerProperties.Character, HEAD_TEXTURE_CHARGE)
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
			local speed = 50
			local maxDistance = 250
			local traveled = 0
			local hitSurvivor = false
			local chargeStopped = false

			local connection
			local function finishCharge()
				if chargeStopped then
					return
				end
				chargeStopped = true
				if connection then
					connection:Disconnect()
					connection = nil
				end
				SetHeadTexture(self.OwnerProperties.Character, HEAD_TEXTURE_DEFAULT)
				if not hitSurvivor then
					CommonFunctions.ApplyEffect({
						TargetHumanoid = humanoid,
						EffectSettings = { Name = "Slowness", Level = 1, Duration = 3 },
					})
				end
			end

			connection = RunService.Heartbeat:Connect(function(deltaTime)
				if chargeStopped then
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
					finishCharge()
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
					finishCharge()
					return
				end

				local newPosition = hrp.Position + moveDir * allowedDistance

				for _, survivor in survivors do
					local survivorRoot = survivor:FindFirstChild("HumanoidRootPart")
					if survivorRoot then
						local survivorPos = survivorRoot.Position
						local distanceToSurvivor =
							Vector3.new(survivorPos.X - newPosition.X, 0, survivorPos.Z - newPosition.Z).Magnitude
						if distanceToSurvivor < 3 then
							hitSurvivor = true
							-- Grant EXP when hitting a survivor with Charge
							CommonFunctions.GrantRewardToPlayer(self.Owner, { EXP = 15, Reason = "hit with Charge" })
							require(ReplicatedStorage.Classes.Hitbox).New(self.Owner, {
								CFrameOffset = CFrame.new(0, -1.5, -2),
								Size = Vector3.new(8, 7, 8),
								Time = 0.1,
								Damage = 20,
								Reason = "Charge Attack",
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
							finishCharge()
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

				characterModel:PivotTo(CFrame.new(newPosition, newPosition + faceDirection))
				traveled += allowedDistance

				if blocked then
					finishCharge()
					return
				end

				if traveled >= maxDistance then
					finishCharge()
				end
			end)

			task.delay(3, finishCharge)
		end
	else
		ChargeAnimToken += 1
		local thisToken = ChargeAnimToken

		self:PlayUseAnimation()

		local track = self.UseAnimationTrack
		if track then
			local function stopIfCurrent()
				if ChargeAnimToken ~= thisToken then
					return
				end
				if track.IsPlaying then
					track:Stop(0.1)
				end
			end

			-- End charge animation after the server-side charge window.
			self:AddConnection(task.delay(3, stopIfCurrent))

			-- Also stop on stun if it happens before timeout.
			local effects = self.OwnerProperties.Character and self.OwnerProperties.Character:FindFirstChild("Effects")
			if effects then
				self:AddConnection(effects.ChildAdded:Connect(function(child)
					if child.Name == "Stunned" then
						stopIfCurrent()
					end
				end))
			end
		end
	end
end

-- ============================================================
-- SWING ABILITY
-- Basic attack with 10-15 damage. Hitbox size increased to fit bit.
-- Fixed: Now accounts for movement direction so hitboxes don't appear behind when moving.
-- ============================================================
local function SwingBehaviour(self: Types.Ability)
	if RunService:IsServer() then
		SetHeadTexture(self.OwnerProperties.Character, HEAD_TEXTURE_SWING)
		task.delay(self.Duration, function()
			SetHeadTexture(self.OwnerProperties.Character, HEAD_TEXTURE_DEFAULT)
		end)

		Sounds.PlaySound(self.UseSound, { Parent = self.OwnerProperties.HRP })

		local hrp = self.OwnerProperties.HRP
		local humanoid = self.OwnerProperties.Humanoid
		local hitboxOffset = self.HitboxOffset
		local hitboxSize = self.HitboxSize
		local duration = self.Duration
		local damage = math.random(10, 15)

		-- Get movement direction at time of swing
		local moveDirection = humanoid.MoveDirection
		local moveDirFlat = Vector3.new(moveDirection.X, 0, moveDirection.Z)
		local useMovementDirection = moveDirFlat.Magnitude > 0.1

		-- Helper to create a dynamic CFrame that re-calculates each frame based on current facing direction
		-- This ensures the hitbox appears in front of the player regardless of when they swing
local function createDynamicCFrame(offsetZ: number, useMoveDir: boolean)
			return function()
				local currentHRP = self.Owner.Character and self.Owner.Character:FindFirstChild("HumanoidRootPart")
				if not currentHRP then
					return CFrame.new()
				end

				local lookDir
				if useMoveDir then
					local currentMoveDir = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
					if currentMoveDir.Magnitude > 0.1 then
						lookDir = currentMoveDir.Unit
					else
						lookDir = Vector3.new(currentHRP.CFrame.LookVector.X, 0, currentHRP.CFrame.LookVector.Z).Unit
					end
				else
					-- Use character's current facing
					lookDir = Vector3.new(currentHRP.CFrame.LookVector.X, 0, currentHRP.CFrame.LookVector.Z).Unit
				end

			-- Place hitbox in front of player using CFrame.new with lookAt direction
				return CFrame.new(currentHRP.Position + lookDir * offsetZ, currentHRP.Position + lookDir)
			end
		end

		task.delay(self.Delay, function()
			-- Spawn 5 hitbox frames spread evenly over the swing duration
			-- But only ONE frame should deal damage - subsequent frames are for coverage only
			local numFrames = 5
			local frameDelay = duration / numFrames
			local hasHit = false

			for frameIndex = 0, numFrames - 1 do
				task.delay(frameIndex * frameDelay, function()
					-- Skip if already hit with this swing
					if hasHit then
						return
					end

					local offsetZ = useMovementDirection and 6 or 3
					require(ReplicatedStorage.Classes.Hitbox).New(self.Owner, {
						CFrame = createDynamicCFrame(offsetZ, false),
						Size = hitboxSize,
						Time = frameDelay * 1.5,
						Damage = damage,
						Reason = "Swing Attack",
						ExecuteOnKill = true,
						HitMultiple = false, -- Each frame hits only one target
						Connections = {
							Hit = function()
								hasHit = true
							end,
						},
					})
				end)
			end

			-- Additional frame in movement direction if moving (also skip if already hit)
			if useMovementDirection then
				task.delay(frameDelay * 2, function()
					if hasHit then
						return
					end

					require(ReplicatedStorage.Classes.Hitbox).New(self.Owner, {
						CFrame = createDynamicCFrame(8, true),
						Size = hitboxSize,
						Time = frameDelay * 2,
						Damage = damage,
						Reason = "Swing Attack",
						ExecuteOnKill = true,
						HitMultiple = false,
						Connections = {
							Hit = function()
								hasHit = true
							end,
						},
					})
				end)
			end
		end)
	else
		self.OwnerProperties.TurnToMoveDirection:AddHeadPreventionFactor("Swing")
		self:AddConnection(task.delay(0.7, function()
			self.OwnerProperties.TurnToMoveDirection:RemoveHeadPreventionFactor("Swing")
		end))
	end
end

-- ============================================================
-- DETONATE CLONE (helper)
-- Teleports BIT to the clone's position.
-- ============================================================
local function DetonateClone(cloneData, owner, clones, hrp)
	local bitHumanoid = hrp.Parent:FindFirstChildWhichIsA("Humanoid")
	local originalWalkSpeed = bitHumanoid and bitHumanoid.WalkSpeed or 12
	cloneData.Frozen = true

	-- Stop clone pathing/motion during detonation windup.
	if cloneData.Path then
		pcall(function()
			cloneData.Path:Stop()
		end)
	end
	if cloneData.Humanoid then
		cloneData.Humanoid.WalkSpeed = 0
	end
	if cloneData.Root then
		cloneData.Root.Anchored = true
	end

	local bitOriginalCFrame = hrp.CFrame
	local windupElapsed = 0

	local windupConn
	windupConn = RunService.Heartbeat:Connect(function(dt)
		if not cloneData.Model or not cloneData.Model.Parent then
			windupConn:Disconnect()
			if bitHumanoid then
				bitHumanoid.WalkSpeed = originalWalkSpeed
			end
			return
		end

		windupElapsed += dt

		local t = math.min(windupElapsed / 2, 1)
		local intensity = 0.05 + t * 0.35

		hrp.CFrame = bitOriginalCFrame
			+ Vector3.new(
				(math.random() - 0.5) * 2 * intensity,
				(math.random() - 0.5) * intensity * 0.3,
				(math.random() - 0.5) * 2 * intensity
			)

		-- I think blud is a litte cold -Bendie

		local cp = cloneData.Root.Position
		cloneData.Model:PivotTo(
			CFrame.new(
				cp.X + (math.random() - 0.5) * 2 * intensity,
				cp.Y + (math.random() - 0.5) * intensity * 0.3,
				cp.Z + (math.random() - 0.5) * 2 * intensity
			)
		)

		if windupElapsed < 2 then
			return
		end
		windupConn:Disconnect()

		if bitHumanoid then
			bitHumanoid.WalkSpeed = originalWalkSpeed
		end

		local clonePos = cloneData.Root.Position

		hrp.CFrame = CFrame.new(clonePos + Vector3.new(0, 3, 0))

		-- Spawn a cyan neon sphere cuz why not.
		local inGame = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("InGame")
		local domain = Instance.new("Part")
		domain.Name = "BITDomain"
		domain.Shape = Enum.PartType.Ball
		domain.Size = Vector3.new(1, 1, 1)
		domain.Material = Enum.Material.Neon
		domain.Color = Color3.fromRGB(0, 200, 255)
		domain.Transparency = 0.3
		domain.CanCollide = false
		domain.Anchored = true
		domain.CFrame = CFrame.new(clonePos)
		domain.Parent = inGame or workspace

		-- Expand the sphere quickly then let Debris remove it at 0.9 seconds - had to rewrite this like 999 times btw -Bendie
		local expandConn
		local size = 1
		expandConn = RunService.Heartbeat:Connect(function(dt2)
			size = math.min(size + dt2 * 200, 60)
			domain.Size = Vector3.new(size, size, size)
			if size >= 60 then
				expandConn:Disconnect()
			end
		end)

		-- Blast visual disappears after 0.9 seconds
		Debris:AddItem(domain, 0.9)

		local PHASE1_DURATION = 8
		local PHASE2_DURATION = 4

		local survivors = Utils.Character.GetCharactersWithRoles(false).Survivor or {}
		for _, survivor in survivors do
			local survivorRoot = survivor:FindFirstChild("HumanoidRootPart")
			local survivorHumanoid = survivor:FindFirstChildWhichIsA("Humanoid")
			if not survivorRoot or not survivorHumanoid or survivorHumanoid.Health <= 0 then
				continue
			end

			local dist = (survivorRoot.Position - clonePos).Magnitude
			if dist <= 50 then
				-- Grant EXP when hitting a survivor with BIT Summon detonation
				CommonFunctions.GrantRewardToPlayer(owner, { EXP = 20, Reason = "hit with BIT Summon detonation" })
				CommonFunctions.DamagePlayer({
					SourcePlayer = owner,
					TargetHumanoid = survivorHumanoid,
					Damage = 20,
					Reason = "BIT Clone Detonation",
				})
				CommonFunctions.ApplyEffect({
					TargetHumanoid = survivorHumanoid,
					EffectSettings = {
						Name = "Helpless",
						Level = 1,
						Duration = PHASE1_DURATION,
						OverwriteExisting = true,
					},
				})
				CommonFunctions.ApplyEffect({
					TargetHumanoid = survivorHumanoid,
					EffectSettings = {
						Name = "Slowness",
						Level = 3,
						Duration = PHASE1_DURATION,
						OverwriteExisting = true,
					},
				})
			end
		end

		task.delay(PHASE1_DURATION, function()
			if domain.Parent then
				local shrinkConn
				shrinkConn = RunService.Heartbeat:Connect(function(dt3)
					domain.Size = domain.Size - Vector3.new(1, 1, 1) * dt3 * 40
					if domain.Size.X <= 0 then
						shrinkConn:Disconnect()
						domain:Destroy()
					end
				end)
			end

			for _, survivor in Utils.Character.GetCharactersWithRoles(false).Survivor or {} do
				local survivorRoot = survivor:FindFirstChild("HumanoidRootPart")
				local survivorHumanoid = survivor:FindFirstChildWhichIsA("Humanoid")
				if not survivorRoot or not survivorHumanoid or survivorHumanoid.Health <= 0 then
					continue
				end

				local dist = (survivorRoot.Position - clonePos).Magnitude
				if dist <= 50 then
					CommonFunctions.ApplyEffect({
						TargetHumanoid = survivorHumanoid,
						EffectSettings = {
							Name = "Slowness",
							Level = 2,
							Duration = PHASE2_DURATION,
							OverwriteExisting = true,
						},
					})
				end
			end
		end)

		local idx = table.find(clones, cloneData)
		if idx then
			table.remove(clones, idx)
		end
		cloneData.Cleanup()
	end)
end

-- ============================================================
-- BIT SUMMON
-- Summons a clone built from BIT's actual character model.
-- The clone chases survivors; touching one applies Glitched +
-- Slowness and destroys the clone.
-- Click the highlighted clone to teleport to it and trigger
-- ============================================================
local function BITSummonBehaviour(self: Types.Ability)
	if RunService:IsServer() then
		SetHeadTexture(self.OwnerProperties.Character, HEAD_TEXTURE_BITSUMMON)
		task.delay(2, function()
			if self.OwnerProperties.Character and self.OwnerProperties.Character.Parent then
				SetHeadTexture(self.OwnerProperties.Character, HEAD_TEXTURE_DEFAULT)
			end
		end)

		local owner = self.Owner
		local ownerCharacter = self.OwnerProperties.Character
		local ownerHRP = self.OwnerProperties.HRP
		if not owner or not ownerCharacter or not ownerHRP then
			BITSummonLog("abort: missing owner/character/hrp", owner, ownerCharacter, ownerHRP)
			return
		end
		BITSummonLog("start", "owner=", owner.Name, "character=", ownerCharacter.Name, "hrp=", ownerHRP:GetFullName())

		self:SetOnCooldown()

		local clones = activeClonesPerPlayer[owner] or {}

		if #clones >= MAX_CLONES then
			local oldest = table.remove(clones, 1)
			BITSummonLog("max clones reached, removing oldest", #clones + 1, ">", MAX_CLONES)
			if oldest and oldest.Cleanup then
				oldest.Cleanup()
			end
		end

		local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
		local charactersFolder = assetsFolder and assetsFolder:FindFirstChild("Characters")
		local killerFolder = charactersFolder and charactersFolder:FindFirstChild("Killer")
		local bitAssetModel = killerFolder and killerFolder:FindFirstChild("bit")
		local cloneSource = bitAssetModel and bitAssetModel:FindFirstChild("BIT_default")

		if not cloneSource or not cloneSource:IsA("Model") then
			BITSummonLog(
				"abort: asset source missing",
				"expected ReplicatedStorage.Assets.Characters.Killer.bit.BIT_default"
			)
			warn("[BIT] BITSummon: missing asset model ReplicatedStorage.Assets.Characters.Killer.bit.BIT_default")
			return
		end

		BITSummonLog("found asset BIT_default source", cloneSource:GetFullName())
		local cloneModel = cloneSource:Clone()

		cloneModel.Name = ownerCharacter.Name .. "_BITClone"

		local mapFolder = workspace:FindFirstChild("Map")
		local inGameFolder = mapFolder and mapFolder:FindFirstChild("InGame")
		if inGameFolder then
			cloneModel.Parent = inGameFolder
		else
			cloneModel.Parent = workspace
			BITSummonLog("warning: Map/InGame missing, using workspace fallback parent")
		end
		BITSummonLog("clone parented", cloneModel:GetFullName(), "parent=", cloneModel.Parent:GetFullName())

		local cloneHumanoid = cloneModel:FindFirstChildWhichIsA("Humanoid")
		local cloneRoot = cloneModel:FindFirstChild("HumanoidRootPart") or cloneModel:FindFirstChild("HumaniodRootPart")
		if not cloneHumanoid or not cloneRoot then
			cloneHumanoid = cloneModel:FindFirstChildWhichIsA("Humanoid", true)

			local rootCandidates = {}
			for _, d in cloneModel:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(rootCandidates, d.Name)
					if not cloneRoot then
						if d.Name == "HumanoidRootPart" or d.Name == "HumaniodRootPart" then
							cloneRoot = d
						else
							if d.Name == "Torso" or d.Name == "UpperTorso" then
								cloneRoot = d
							end
						end
					end
				end
			end

			BITSummonLog("root scan", table.concat(rootCandidates, ","))
		end
		if not cloneRoot and cloneModel:IsA("Model") then
			cloneRoot = cloneModel.PrimaryPart or cloneModel:FindFirstChildWhichIsA("BasePart", true)
		end
		if not cloneHumanoid or not cloneRoot then
			warn(string.format("[BIT] BITSummon: clone missing Humanoid or clickable root for %s", ownerCharacter.Name))
			BITSummonLog("abort: clone missing humanoid/root", "humanoid=", cloneHumanoid, "root=", cloneRoot)
			cloneModel:Destroy()
			return
		end
		BITSummonLog("clone rig resolved", "humanoid=", cloneHumanoid:GetFullName(), "root=", cloneRoot:GetFullName())

		if cloneModel:IsA("Model") then
			cloneModel.PrimaryPart = cloneRoot
		end

		cloneModel:PivotTo(ownerHRP.CFrame * CFrame.new(0, 0, -8))
		cloneHumanoid.Health = math.max(1, cloneHumanoid.MaxHealth)
		cloneHumanoid.WalkSpeed = 18
		cloneHumanoid.PlatformStand = false

		-- Wait briefly so everything can initialize before movement starts
		task.wait(0.5)

		local basePartCount = 0
		local visibleBasePartCount = 0
		for _, d in cloneModel:GetDescendants() do
			if d:IsA("BasePart") then
				basePartCount += 1
				if d.Transparency < 1 then
					visibleBasePartCount += 1
				end
			end
		end

		BITSummonLog(
			"clone positioned",
			tostring(cloneRoot.Position),
			"walkspeed=",
			cloneHumanoid.WalkSpeed,
			"parts=",
			basePartCount,
			"visibleParts=",
			visibleBasePartCount
		)

		for _, descendant in cloneModel:GetDescendants() do
			if descendant:IsA("Script") or descendant:IsA("LocalScript") then
				descendant:Destroy()
			elseif descendant:IsA("BasePart") then
				descendant.CanCollide = false
			end
		end

		-- Show highlight only to the killer, not survivors
		-- Use InstanceUtils to fire remote event to killer client only
		task.delay(0.1, function()
			Utils.Instance.HighlightInstanceFor(owner, cloneModel, 35, Color3.fromRGB(255, 0, 0))
		end)

		local cloneData = {
			Model = cloneModel,
			Humanoid = cloneHumanoid,
			Root = cloneRoot,
			Frozen = false,
			Path = nil,
		}

		local connections = {}
		local cleaned = false
		local function cleanup()
			if cleaned then
				return
			end
			cleaned = true
			for _, conn in connections do
				if conn and conn.Disconnect then
					conn:Disconnect()
				end
			end
			if cloneData.Path then
				pcall(function()
					cloneData.Path:Stop()
				end)
			end
			if cloneModel and cloneModel.Parent then
				cloneModel:Destroy()
			end
			local idx = table.find(clones, cloneData)
			if idx then
				table.remove(clones, idx)
			end
		end
		cloneData.Cleanup = cleanup

		table.insert(clones, cloneData)
		BITSummonLog("clone registered", "activeClones=", #clones)

		local clickablePart = cloneRoot
		if not clickablePart:IsA("BasePart") then
			clickablePart = cloneModel:FindFirstChildWhichIsA("BasePart", true)
		end
		if not clickablePart then
			warn(string.format("[BIT] BITSummon: no clickable BasePart found for %s clone", ownerCharacter.Name))
			BITSummonLog("abort: no clickable part")
			cleanup()
			return
		end
		BITSummonLog("click detector part", clickablePart:GetFullName())

		local clickDetector = Instance.new("ClickDetector")
		clickDetector.MaxActivationDistance = 32
		clickDetector.Parent = clickablePart

		table.insert(
			connections,
			clickDetector.MouseClick:Connect(function(player)
				BITSummonLog(
					"click received",
					"from=",
					player and player.Name or "nil",
					"owner=",
					owner.Name,
					"frozen=",
					cloneData.Frozen
				)
				if player == owner and not cloneData.Frozen then
					BITSummonLog("detonate triggered")
					DetonateClone(cloneData, owner, clones, ownerHRP)
				end
			end)
		)

		local function getNearestSurvivorRoot()
			local nearestRoot, nearestDist = nil, math.huge
			for _, survivor in Utils.Character.GetCharactersWithRoles(false).Survivor or {} do
				local hum = survivor:FindFirstChildWhichIsA("Humanoid")
				local root = survivor:FindFirstChild("HumanoidRootPart") or survivor:FindFirstChild("HumaniodRootPart")
				if hum and root and hum.Health > 0 and survivor:GetAttribute("Dead") ~= true then
					local dist = (root.Position - cloneRoot.Position).Magnitude
					if dist < nearestDist then
						nearestDist = dist
						nearestRoot = root
					end
				end
			end
			return nearestRoot
		end

		local function moveDirectlyToTarget(targetRoot)
			if not targetRoot then
				return
			end
			cloneHumanoid:MoveTo(targetRoot.Position)
		end

		if SimplePath then
			cloneData.Path = SimplePath.new(cloneModel, {
				AgentRadius = 2,
				AgentHeight = 5,
				AgentCanJump = true,
				AgentCanClimb = true,
			})

			local retargetAccumulator = 0
			table.insert(
				connections,
				RunService.Heartbeat:Connect(function(dt)
					if cloneData.Frozen or cleaned then
						return
					end
					retargetAccumulator += dt
					if retargetAccumulator < 0.25 then
						return
					end
					retargetAccumulator = 0

					local targetRoot = getNearestSurvivorRoot()
					if targetRoot then
						local ok = pcall(function()
							cloneData.Path:Run(targetRoot.Position)
						end)
						if not ok then
							moveDirectlyToTarget(targetRoot)
						end
					end
				end)
			)
		else
			table.insert(
				connections,
				RunService.Heartbeat:Connect(function()
					if cloneData.Frozen or cleaned then
						return
					end
					local targetRoot = getNearestSurvivorRoot()
					if targetRoot then
						moveDirectlyToTarget(targetRoot)
					end
				end)
			)
		end

		table.insert(
			connections,
			cloneHumanoid.MoveToFinished:Connect(function(reached)
				if cloneData.Frozen or cleaned then
					return
				end
				if not reached then
					local targetRoot = getNearestSurvivorRoot()
					if targetRoot then
						moveDirectlyToTarget(targetRoot)
					end
				end
			end)
		)

		local touchedDebounce = false
		table.insert(
			connections,
			cloneRoot.Touched:Connect(function(hit)
				if cloneData.Frozen or cleaned or touchedDebounce then
					return
				end
				local victimCharacter = hit and hit.Parent
				if not victimCharacter or victimCharacter == ownerCharacter then
					return
				end
				local victimHumanoid = victimCharacter:FindFirstChildWhichIsA("Humanoid")
				if not victimHumanoid or victimHumanoid.Health <= 0 then
					return
				end

				local isSurvivor = false
				for _, survivor in Utils.Character.GetCharactersWithRoles(false).Survivor or {} do
					if survivor == victimCharacter then
						isSurvivor = true
						break
					end
				end
				if not isSurvivor then
					return
				end

				touchedDebounce = true

				-- Grant EXP when clone touches a survivor
				CommonFunctions.GrantRewardToPlayer(owner, { EXP = 10, Reason = "hit with BIT Clone" })
				Utils.Player.RevealPlayerAuraTo(owner, victimCharacter, 10)
				CommonFunctions.ApplyEffect({
					TargetHumanoid = victimHumanoid,
					EffectSettings = { Name = "Glitched", Level = 1, Duration = 10, OverwriteExisting = true },
				})
				CommonFunctions.ApplyEffect({
					TargetHumanoid = victimHumanoid,
					EffectSettings = { Name = "Slowness", Level = 2, Duration = 5, OverwriteExisting = true },
				})

				cleanup()
			end)
		)

		table.insert(connections, cloneHumanoid.Died:Connect(cleanup))
		Debris:AddItem(cloneModel, 35)
	else
		self:PlayUseAnimation()
	end
end

-- ============================================================
-- DIGITAL EYE
-- Highlight all players for the duration.
-- ============================================================
local function DigitalEyeBehaviour(self: Types.Ability)
	if RunService:IsServer() then
		SetHeadTexture(self.OwnerProperties.Character, HEAD_TEXTURE_DIGITALEYE)
		task.delay(self.Duration, function()
			SetHeadTexture(self.OwnerProperties.Character, HEAD_TEXTURE_DEFAULT)
		end)
		local survivors = Utils.Character.GetCharactersWithRoles(false).Survivor or {}
		for _, survivor in survivors do
			Utils.Player.RevealPlayerAuraTo(self.Owner, survivor, self.Duration)
		end
	else
		self:PlayUseAnimation()
	end
end

-- ============================================================
-- STATE EDIT
-- Apply a random debuff to a random survivor.
-- ============================================================
local function StateEditBehaviour(self: Types.Ability)
	if RunService:IsServer() then
		SetHeadTexture(self.OwnerProperties.Character, HEAD_TEXTURE_STATEEDIT)
		task.delay(1, function()
			SetHeadTexture(self.OwnerProperties.Character, HEAD_TEXTURE_DEFAULT)
		end)
		local survivors = Utils.Character.GetCharactersWithRoles(false).Survivor or {}
		if #survivors > 0 then
			local randomSurvivor = survivors[math.random(1, #survivors)]
			local effects = { "Blindness", "Confused", "Helpless", "Slowness" }
			local randomEffect = effects[math.random(1, #effects)]
			CommonFunctions.ApplyEffect({
				TargetHumanoid = randomSurvivor:FindFirstChildWhichIsA("Humanoid"),
				EffectSettings = { Name = randomEffect, Level = 1, Duration = 10 },
			})
		end
	else
		self:PlayUseAnimation()
	end
end

-- ============================================================
-- PASSIVE — CORRUPTION CASCADE
-- When killing a player, the nearest surviving player gets
-- inverted controls for PASSIVE_DURATION seconds.
-- ============================================================
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

	local survivors = Utils.Character.GetCharactersWithRoles(false).Survivor or {}
	local nearestSurvivor = nil
	local nearestDistance = math.huge

	for _, survivor in survivors do
		if survivor and survivor:IsA("Model") and survivor ~= killedCharacter then
			local survivorHumanoid = survivor:FindFirstChildWhichIsA("Humanoid")
			local survivorRoot = survivor:FindFirstChild("HumanoidRootPart")
			if
				survivorHumanoid
				and survivorRoot
				and survivorHumanoid.Health > 0
				and survivor:GetAttribute("Dead") ~= true
			then
				local distance = (survivorRoot.Position - killedRoot.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestSurvivor = survivor
				end
			end
		end
	end

	if nearestSurvivor then
		local nearestHumanoid = nearestSurvivor:FindFirstChildWhichIsA("Humanoid")
		if nearestHumanoid then
			CommonFunctions.ApplyEffect({
				TargetHumanoid = nearestHumanoid,
				EffectSettings = { Name = "Confused", Level = 1, Duration = PASSIVE_DURATION },
			})
		end
	end
end

local Bit: Types.Killer = Character.CreateKiller({
	Config = {
		Name = "BIT_09",
		Quote = "THE BEST BIT TECHNOLOGY AVIAILABLE!1111 :)",
		Render = "rbxassetid://74125322169300",

		Origin = {
			TooltipText = "XxNamedzxX Archive",
			Icon = "rbxasset://90863791545676",
		},
		Voicelines = {
			Idle = {
				"rbxassetid://0000000000",
				"rbxassetid://0000000000",
				"rbxassetid://0000000000",
			},
			Kill = {
				Default = {
					"rbxassetid://0000000000",
					"rbxassetid://0000000000",
					"rbxassetid://0000000000",
				},
				XxNamedzxX = {
					"rbxassetid://110113577789098",
				},
			},
			LMS = {
				Default = {
					"rbxassetid://0000000000",
					"rbxassetid://0000000000",
					"rbxassetid://0000000000",
				},
				Commander = {
					"rbxassetid://0000000000",
					"rbxassetid://0000000000",
					"rbxassetid://0000000000",
				},
				CommanderYourselfCommander = {
					"rbxassetid://0000000000",
					"rbxassetid://0000000000",
					"rbxassetid://0000000000",
				},
			},
			Stunned = {
				"rbxassetid://0000000000",
				"rbxassetid://0000000000",
				"rbxassetid://0000000000",
			},
		},
		Price = 1500,
		AnimationIDs = {
			IdleAnimation = "rbxassetid://78224944531383",
			WalkAnimation = "rbxassetid://103440617174686",
			RunAnimation = "rbxassetid://115121258542938",
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
		Health = 1900,
		StaminaProperties = {
			MaxStamina = 100,
		},

		Abilities = {
			Swing = Ability.New({
				Name = "Swing",
				InputName = "Slash",
				Cooldown = 2,
				Duration = 0.4,
				Damage = 12,
				RenderImage = "rbxassetid://11218451110",
				UseSound = "rbxassetid://12222200",
				UseAnimation = "rbxassetid://125284531450977", -- TODO: replace with BIT m1/slash animation ID
				UICorner = true,
				Delay = 0.1,
				HitboxSize = Vector3.new(4, 7, 5.5),
				HitboxOffset = CFrame.new(0, 0, 4),
				Behaviour = SwingBehaviour,
				ExtraInit = function(self: Types.Ability)
					if not RunService:IsServer() then
						return
					end
					local effects = self.OwnerProperties.Character:FindFirstChild("Effects")
					if not effects then
						return
					end
					-- WHY THE FLIP IS THERE NO ON STUN FUNCTION FOR KILLERS -Bendie
					self:AddConnection(effects.ChildAdded:Connect(function(child)
						if child.Name == "Stunned" then
							SetHeadTexture(self.OwnerProperties.Character, HEAD_TEXTURE_STUNNED)
						end
					end))
					self:AddConnection(effects.ChildRemoved:Connect(function(child)
						if child.Name == "Stunned" then
							SetHeadTexture(self.OwnerProperties.Character, HEAD_TEXTURE_DEFAULT)
						end
					end))
				end,
			}),

			Charge = Ability.New({
				Name = "Charge",
				Cooldown = 20,
				InputName = "FirstAbility",
				UseAnimation = "rbxassetid://93664378263660",
				Behaviour = ChargeBehaviour,
			}),

			BITSummon = Ability.New({
				Name = "BIT Summon",
				Cooldown = 15,
				InputName = "SecondAbility",
				UseAnimation = "rbxassetid://74189155372575",
				Behaviour = BITSummonBehaviour,
			}),

			DigitalEye = Ability.New({
				Name = "Digital EYE",
				Cooldown = 30,
				InputName = "ThirdAbility",
				Duration = 10,
				UseAnimation = "rbxassetid://139387993657669",
				EXP = 15,
				Behaviour = DigitalEyeBehaviour,
			}),

			StateEdit = Ability.New({
				Name = "STATE EDIT",
				Cooldown = 30,
				InputName = "FourthAbility",
				UseAnimation = "rbxassetid://109178595486916",
				EXP = 10,
				Behaviour = StateEditBehaviour,
			}),
		},
	},

	OnExecution = function(_, killedCharacter)
		OnKillPassive(killedCharacter)
	end,
})

local BitNameLabel = '<font color="rgb(0, 255, 255)">' .. Bit.Config.Name .. "</font>"
Bit.Config.Description = {
	{
		Type = "Separator",
		Text = "GENERAL INFO",
	},
	{
		Type = "Header",
		Text = Bit.Config.Name:upper(),
	},
	{
		Type = "Quote",
		Text = '"' .. Bit.Config.Quote .. '"',
	},
	{
		Type = "Text",
		Text = "A rogue digital entity born from corrupted code. "
			.. BitNameLabel
			.. " tears through the fabric of the game world, rewriting its rules to hunt survivors. "
			.. "She warps reality, scrambles senses, and leaves chaos in her wake, a glitch that cannot be patched.",
	},
	{
		Type = "Header",
		Text = "STATS",
	},
	{
		Type = "Text",
		Text = {
			"Difficulty: ★★★★☆",
			"Health: " .. tostring(Bit.GameplayConfig.Health),
		},
	},
	{
		Type = "Separator",
		Text = "ABILITIES",
	},
	{
		Type = "Header",
		Text = Bit.GameplayConfig.Abilities.Swing.Name:upper(),
	},
	{
		Type = "Text",
		Text = BitNameLabel
			.. " swings her arm with corrupted force, dealing <b>10–15 damage</b>. Quick and reliable — the backbone of her kit. Cooldown: <b>2s</b>.",
	},
	{
		Type = "Header",
		Text = Bit.GameplayConfig.Abilities.Charge.Name:upper(),
	},
	{
		Type = "Text",
		Text = BitNameLabel
			.. " rockets forward in her current movement direction, dealing <b>20 damage</b> on impact. Hitting a wall or missing leaves her briefly <b>Slowed</b>. Cooldown: <b>20s</b>.",
	},
	{
		Type = "Header",
		Text = Bit.GameplayConfig.Abilities.BITSummon.Name:upper(),
	},
	{
		Type = "Text",
		Text = BitNameLabel
			.. " summons a clone of herself that roams the map chasing survivors. Clones are always visible. "
			.. "Any survivor they touch is <b>highlighted</b>, <b>Glitched</b> for 10s, and <b>Slowed</b> for 5s — then the clone is destroyed. "
			.. "<b>Click</b> a highlighted clone to teleport to its position and trigger a <b>domain explosion</b>: "
			.. "survivors within 50 studs take <b>20 damage</b>, <b>Helpless</b>, and <b>Slowness III</b> for 8s, "
			.. "followed by a lingering <b>Slowness II</b> for 4s. Up to 3 clones active. Cooldown: <b>15s</b>.",
	},
	{
		Type = "Header",
		Text = Bit.GameplayConfig.Abilities.DigitalEye.Name:upper(),
	},
	{
		Type = "Text",
		Text = BitNameLabel
			.. " activates her scanning vision, revealing the aura of <b>every survivor</b> on the map for <b>10 seconds</b>. No hiding from the eye. Cooldown: <b>30s</b>.",
	},
	{
		Type = "Header",
		Text = Bit.GameplayConfig.Abilities.StateEdit.Name:upper(),
	},
	{
		Type = "Text",
		Text = BitNameLabel
			.. " corrupts a random survivor's state, inflicting one of the following at random: <b>Blindness</b>, <b>Confused</b>, <b>Helpless</b>, or <b>Slowness</b> — each for <b>10 seconds</b>. Cooldown: <b>30s</b>.",
	},
	{
		Type = "Header",
		Text = "PASSIVE — CORRUPTION CASCADE",
	},
	{
		Type = "Text",
		Text = "When "
			.. BitNameLabel
			.. " kills a survivor, the nearest remaining survivor's controls are <b>inverted</b> for <b>10 seconds</b>. "
			.. "Left becomes right, forward becomes backward — a parting gift from the glitch.",
	},
}

return Bit
