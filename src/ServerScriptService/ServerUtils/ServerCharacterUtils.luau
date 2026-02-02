local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Types = require(ReplicatedStorage.Classes.Types)
local PlayerSpeedManager = require(ServerScriptService.Managers.PlayerManager.CharacterManager.PlayerSpeedManager)
local Network = require(ReplicatedStorage.Modules.Network)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local ServerCharacterUtils = {}

type DamagePlayerSettings = {
	--- The `Player` that's inflicting the damage.
	SourcePlayer: Player,
	--- The `Humanoid` receiving the damage.
	TargetHumanoid: Humanoid,
	--- The damage to be inflicted (base).
	Damage: number,
	--- A reason tag for the source of the damage.
	Reason: string?,
	--- The direction of any knockback to be applied.
	KnockbackDirection: Vector3?,
	--- The magnitude of any knockback to be applied.
	KnockbackMagnitude: number?,
}
--- Function that should be used to damage a player from another player's attack.
--- Handles resistance, weakness...
function ServerCharacterUtils.DamagePlayer(DamageSettings: DamagePlayerSettings)
    local Char = DamageSettings.TargetHumanoid.Parent
	local HRP: BasePart = Utils.Character.GetRootPart(Char)
    local targetPos = HRP.Position
	local TargetPlayer = Players:GetPlayerFromCharacter(Char)

	-- leaving these comments here as memories from may 2025 lol -dys
	--decided to remove server-side checking because BRO. THEY DON'T DO THAT IN FORSAKEN.
	--correction: the hitboxes in Forsaken are FULLY server-handled, but it doesn't lag because THEIR GAME SOMEHOW DOESN'T LAG AT ALL. WHAT????
	--quick thing: hitboxes are now fully server-sided. yup. i had to. :(

	if DamageSettings.Damage == 0 or (Utils.Instance.FindFirstChild(Char, "Effects.StunSpawnProtection", 0) and not DamageSettings.SourcePlayer.Character:GetAttribute("BypassStunProtection")) then
		return
	end

	local Role = Char:GetAttribute("Role")
	if DamageSettings.Damage > 0 then
		if Char:FindFirstChild("Killer") and Role == "Survivor" then
			Char.Killer.Value = DamageSettings.SourcePlayer
		end

		local ResistanceValue = Utils.Instance.FindFirstChild(Char, "Effects.Resistance", 0)
		if ResistanceValue then
			DamageSettings.Damage /= 0.1 * ResistanceValue + 1 --since lvl 1 should do the trick already
		end

		Network:FireClientConnection(DamageSettings.SourcePlayer, "DisplayHitmarker", "REMOTE_EVENT", targetPos, DamageSettings.Damage)
		if Utils.PlayerData.GetPlayerSetting(DamageSettings.SourcePlayer, "Miscellaneous.ImageFlashOnHit") then
			Network:FireClientConnection(DamageSettings.SourcePlayer, "ShowJokeSettingImage", "REMOTE_EVENT", false, DamageSettings.SourcePlayer.Character:GetAttribute("Role"))
		end
	end
	
	DamageSettings.Reason = DamageSettings.Reason or "HAHAHA" --OnlyIvo

	DamageSettings.TargetHumanoid:TakeDamage(DamageSettings.Damage)

	DamageSettings.KnockbackDirection = DamageSettings.KnockbackDirection or Vector3.zero
	DamageSettings.KnockbackMagnitude = DamageSettings.KnockbackMagnitude or 1
	ServerCharacterUtils.RigImpulse(HRP, DamageSettings.KnockbackMagnitude, DamageSettings.KnockbackDirection)

	--printing
    if workspace:GetAttribute("DebugAllowed") then
		Utils.Misc.Print("[DamageDealt] Target: "..Char.Name.." || InflictedDamage: "..tostring(DamageSettings.Damage).." || Reason: "..DamageSettings.Reason)
	end

	if TargetPlayer then

		if DamageSettings.Damage > 0 and Role == "Survivor" then
			PlayerSpeedManager.AddSpeedFactor(TargetPlayer, "DamageSpeedBurst", 1.26)
			task.delay(1, function()
				PlayerSpeedManager.RemoveSpeedFactor(TargetPlayer, "DamageSpeedBurst")
			end)
		end
		
		Network:FireClientConnection(TargetPlayer, "DamagePlayer", "REMOTE_EVENT", DamageSettings.SourcePlayer, DamageSettings.Reason)

		if Utils.PlayerData.GetPlayerSetting(TargetPlayer, "Miscellaneous.ImageFlashOnHit") then
			Network:FireClientConnection(TargetPlayer, "ShowJokeSettingImage", "REMOTE_EVENT", true, Role or "Survivor")
		end

	end
	Network:FireClientConnection(DamageSettings.SourcePlayer, "DamagedPlayer", "REMOTE_EVENT", TargetPlayer, DamageSettings.TargetHumanoid, DamageSettings.Reason)
end

type ApplyEffectSettings = {
	TargetHumanoid: Humanoid,
	EffectSettings: {
		Name: string,
		Level: number?,
		Duration: number?,
		Subfolder: string?,
	},
	OverwriteExistingEffect: boolean?,
}
--- Applies an effect on a specific humanoid. It can be a player or an NPC, it doesn't matter.
function ServerCharacterUtils.ApplyEffect(EffectSettings: ApplyEffectSettings) : NumberValue?
	if EffectSettings.OverwriteExistingEffect == nil then
		EffectSettings.OverwriteExistingEffect = true
	end

	local char = EffectSettings.TargetHumanoid.Parent

	local CharEffects = char:FindFirstChild("Effects")
	if not CharEffects then
		return
	end

	if EffectSettings.EffectSettings.Name == "Stunned" then
		if CharEffects:FindFirstChild("SpawnProtection") then
			return
		end
	end

	local ExistingEffect = CharEffects:FindFirstChild(EffectSettings.EffectSettings.Name)
	if ExistingEffect then
		if not EffectSettings.OverwriteExistingEffect then
			return
		end

		ExistingEffect:Destroy()
	end
	
	local EffectModule = Utils.Instance.GetEffectModule(EffectSettings.EffectSettings.Name, EffectSettings.EffectSettings.Subfolder)

	local EffectValue = Instance.new("NumberValue")

	EffectValue.Name = EffectSettings.EffectSettings.Name
	EffectValue.Value = EffectSettings.EffectSettings.Level or EffectModule.Level
	if EffectSettings.EffectSettings.Subfolder and #EffectSettings.EffectSettings.Subfolder > 0 then
		EffectValue:SetAttribute("Subfolder", EffectSettings.EffectSettings.Subfolder)
	end
	EffectValue:SetAttribute("Duration", EffectSettings.EffectSettings.Duration or EffectModule.Duration)

	EffectValue.Parent = CharEffects
	
	task.delay(EffectSettings.EffectSettings.Duration or EffectModule.Duration, function()
		if EffectValue then
			EffectModule:Remove(char)
			EffectValue:Destroy()
		end
	end)
	EffectModule:Apply(EffectSettings.EffectSettings.Level or EffectModule.Level, char, EffectSettings.EffectSettings.Duration or EffectModule.Duration)

	return EffectValue
end

--- Removes an applied effect from a specific humanoid.
function ServerCharacterUtils.RemoveEffect(char: Model | Humanoid, name: string)
	char = char:IsA("Model") and char or char.Parent

	local CharEffects = char:FindFirstChild("Effects")
	if not CharEffects then
		return
	end

	local EffectInst = CharEffects:FindFirstChild(name)
	if not EffectInst then
		return
	end
	
	local EffectModule = Utils.Instance.GetEffectModule(name, EffectInst:GetAttribute("Subfolder"))
	EffectModule:Remove(char)
	EffectInst:Destroy()
end

--- Applies an instant amount of force to a Part.
--- 
--- If a rig is passed, it'll be applied on its root part.
function ServerCharacterUtils.RigImpulse(Rig: Model | BasePart, magnitude: number, direction: Vector3, allowAssembly: boolean?)
	if magnitude <= 0 or direction == Vector3.zero then
		return
	end

	if allowAssembly == nil then
		allowAssembly = true
	end

	local HRP = Rig:IsA("Model") and Utils.Character.GetRootPart(Rig) or Rig

	-- If the knockback property of the hitbox is greater than 15, fling the target(?) -itred
	-- FLINGING GO BOOM -dys
	if magnitude >= 15 and allowAssembly then
		HRP.AssemblyLinearVelocity = direction * magnitude * 10
	
	-- Otherwise, lightly push the target instead. -itred
	--using linearvel generally works better with less than 15 magnitude -dys
	elseif magnitude > 0 then
		local Att = Instance.new("Attachment")
        Att.Name = "LVAtt"
        Att.Parent = HRP

        local LinearVel = Instance.new("LinearVelocity")
        LinearVel.MaxForce = 16000
        LinearVel.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
        LinearVel.LineVelocity = magnitude * 10
        LinearVel.LineDirection = direction
        LinearVel.Attachment0 = Att
        LinearVel.Parent = HRP

        Debris:AddItem(Att, 0.05)
        Debris:AddItem(LinearVel, 0.05)
	end
end

type ApplyVelocitySettings = {
	--- The initial velocity to apply to this `LinearVelocity` when instancing it.
	--- 
	--- Defaults to `0`.
	InitialVelocity: number?,
	--- If `true`, the `LineDirection` of this `LinearVelocity` will gradually turn into the `LookVector` of the part it's applied on.
	--- 
	--- The delta value of this lerp is defined by `ApplyVelocitySettings.LerpDelta`.
	--- 
	--- Defaults to `false`.
	LerpTowardsLookVector: boolean?,
	--- The delta of the gradual change in the `LineDirection` of this `LinearVelocity` if `LerpTowardsLookVector` is `true`.
	--- 
	--- Defaults to `0.5`.
	LerpDelta: number?,
}
--- Applies a `LinearVelocity` to a part / character.
--- 
--- Useful for dash abilities.
--- 
--- For a turning dash, check `ApplyVelocitySettings.LerpTowardsLookVector` in this function's parameters.
function ServerCharacterUtils.ApplyVelocity(Part: Model | BasePart, FuncSettings: ApplyVelocitySettings?): (LinearVelocity, Types.Janitor)
	if Part:IsA("Model") then
		Part = Utils.Character.GetRootPart(Part)
	end

	--if there's no part, don't do anything
	if not Part then
		return
	end

	--since every param of the settings is optional, just default it and make the param itself optional
	FuncSettings = FuncSettings or {}

	--calculate all of the mass of the model to correspondingly limit the force
	local TotalMass = 0
	for _, Descendant in Part.Parent:GetDescendants() do
		if not (Descendant:IsA("BasePart") and not Descendant.Massless) then
			continue
		end

		TotalMass += Descendant.AssemblyMass
	end

	--get the initial look vector of the target
	local LookVector = Part.CFrame.LookVector
	--create the velocity
	local LinearVel = Instance.new("LinearVelocity")
	LinearVel.MaxForce = TotalMass * 300
	--make it line for easier use
	LinearVel.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	--set the direction (non-vertical)
	LinearVel.LineDirection = Vector3.new(LookVector.X, 0, LookVector.Z)
	--set FuncSettings.InitialVelocity if it's specified
	LinearVel.LineVelocity = FuncSettings.InitialVelocity or 0
	
	--create the mandatory attachment and joint it to the target's pivot to set the origin point for the velocity
	local Attachment = Instance.new("Attachment")
	Attachment.Name = "ApplyVelocityAttachment"
	Attachment.Parent = Part

	--pass the attachment to the velocity for it to work
	LinearVel.Attachment0 = Attachment
	--parent it to the part
	LinearVel.Parent = Part

	--create a janitor just in case anything related to the new velocity is destroyed (let it be the velocity itself or its parent)
	local JanitorInstance = Janitor.new()
	JanitorInstance:LinkToInstances(Part, LinearVel)

	--add the attachment to the janitor just in case the velocity is destroyed to destroy it accordingly
	JanitorInstance:Add(Attachment, "Destroy")

	--make the lerp connection if specified to
	if FuncSettings.LerpTowardsLookVector then
		JanitorInstance:Add(RunService.PostSimulation:Connect(function(_delta: number)
			--if the part or its parent are gone, destroy
			if not (Part and Part.Parent) then
				JanitorInstance:Destroy()
				return
			end

			--if the velocity is inactive, wait
			if not LinearVel.Active then
				return
			end

			--set the lookvector again
			LookVector = Part.CFrame.LookVector
			--set the lerped velocity accordingly relative to FuncSettings.LerpDelta or 0.5 (half point) if it's not specified
			LinearVel.LineDirection = LinearVel.LineDirection:Lerp(Vector3.new(LookVector.X, 0, LookVector.Z), FuncSettings.LerpDelta or 0.5)
		end))
	end

	--return all the stuffs
	return LinearVel, JanitorInstance
end

--- Gives an item (cola, medkit...) to a player if its character exists.
function ServerCharacterUtils.GivePhysicalItemToPlayer(Player: Player, Item: ModuleScript | Types.Item)
	if not Player.Character then
		return
	end

	if not Item then
		return
	end

	--if it's not a table it's automatically guessed to be a module
	if typeof(Item) ~= "table" then
		Item = require(Item)
	end

	Utils.Type.CopyTable(Item):Init(Player)
end

return ServerCharacterUtils
