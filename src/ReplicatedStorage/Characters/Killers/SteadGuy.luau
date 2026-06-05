local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil
local Character = require(ReplicatedStorage.Classes.Character)
local Ability = require(ReplicatedStorage.Classes.Ability)
local Slash = require(ReplicatedStorage.Classes.Ability.Slash)
local Hitbox = require(ReplicatedStorage.Classes.Hitbox)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Sounds = require(ReplicatedStorage.Modules.Sounds)

-- ============================================================
-- CURSED JAB
-- A short-range jab that deals more damage the closer the hit.
-- Server: fires a tight hitbox after a small delay.
-- Client: plays the use animation.
-- ============================================================
local function CursedJabBehaviour(self: Types.Ability)
	if RunService:IsServer() then
		Sounds.PlaySound(self.UseSound, { Parent = self.OwnerProperties.HRP })
		task.delay(0.2, function()
			Hitbox.New(self.Owner, {
				CFrameOffset = CFrame.new(0, 0, 2.5),
				Size = Vector3.new(5, 6, 5),
				Time = 0.25,
				Damage = math.random(20, 30),
				Reason = "Cursed Jab",
				ExecuteOnKill = true,
			})
		end)
	else
		self:PlayUseAnimation()
	end
end

-- ============================================================
-- PLASMA ARC
-- SteadGuy fires a slow-moving cursed energy projectile that
-- travels forward, damages on contact, and applies Slowness.
-- Server: spawns a moving part; checks proximity each frame.
-- Client: plays the use animation.
-- ============================================================
local function PlasmaArcBehaviour(self: Types.Ability)
	if RunService:IsServer() then
		Sounds.PlaySound(self.UseSound, { Parent = self.OwnerProperties.HRP })

		local hrp = self.OwnerProperties.HRP
		local proj = Instance.new("Part")
		proj.Name = "PlasmaArc"
		proj.Size = Vector3.new(1.5, 1.5, 3)
		proj.Material = Enum.Material.Neon
		proj.BrickColor = BrickColor.new("Bright blue")
		proj.CanCollide = false
		proj.Anchored = true
		proj.CFrame = hrp.CFrame * CFrame.new(0, 0, -4)
		proj.Parent = workspace.Map.InGame

		local direction = hrp.CFrame.LookVector
		local speed = 30
		local hitTargets = {}
		local alive = true

		local moveConn = RunService.Heartbeat:Connect(function(dt)
			if not alive or not proj.Parent then return end
			proj.CFrame = proj.CFrame + direction * speed * dt

			for _, survivor in Utils.Character.GetCharactersWithRoles(false).Survivor or {} do
				if hitTargets[survivor] then continue end
				local survivorRoot = survivor:FindFirstChild("HumanoidRootPart")
				local survivorHumanoid = survivor:FindFirstChildWhichIsA("Humanoid")
if not survivorRoot or not survivorHumanoid or survivorHumanoid.Health <= 0 then continue end

			if (survivorRoot.Position - proj.Position).Magnitude < 4 then
					hitTargets[survivor] = true
					Hitbox.New(self.Owner, {
						CFrameOffset = CFrame.new(0, 0, 4),
						Size = Vector3.new(5, 6, 5),
						Time = 0.1,
						Damage = 15,
						Reason = "Plasma Arc",
						ExecuteOnKill = true,
						EffectsToApply = {
							{
								Name = "Slowness",
								Level = 2,
								Duration = 5,
								OverwriteExisting = true,
							},
						},
					})
					alive = false
					proj:Destroy()
				end
			end
		end)

		-- Destroy after max travel time
		task.delay(4, function()
			alive = false
			moveConn:Disconnect()
			if proj.Parent then
				proj:Destroy()
			end
		end)
	else
		self:PlayUseAnimation()
	end
end

-- ============================================================
-- HEAT SEEKER
-- SteadGuy trades vision for speed and aura awareness.
-- Blinds himself, gains Speed, and reveals all survivor auras
-- to himself for the duration.
-- ============================================================
local function HeatSeekerBehaviour(self: Types.Ability)
	if RunService:IsServer() then
		local humanoid = self.OwnerProperties.Humanoid

		CommonFunctions.ApplyEffect({
			TargetHumanoid = humanoid,
			EffectSettings = {
				Name = "Blindness",
				Level = 1,
				Duration = self.Duration,
			},
		})

		CommonFunctions.ApplyEffect({
			TargetHumanoid = humanoid,
			EffectSettings = {
				Name = "Speed",
				Level = 2,
				Duration = self.Duration,
			},
		})

		-- Reveal all survivors' auras to SteadGuy only
		for _, survivor in Utils.Character.GetCharactersWithRoles(false).Survivor or {} do
			Utils.Player.RevealPlayerAuraTo(self.Owner, survivor, self.Duration)
		end
	end
end

-- ============================================================
-- DOMAIN EXPANSION: VOID ERADICATION
-- SteadGuy expands his cursed domain, trapping all survivors.
-- Phase 1 (10s): all survivors gain Helpless and Slowness III.
-- Phase 2 (after): survivors shed Helpless but keep lingering
--   Slowness II for 6 more seconds.
-- A visual domain sphere appears in the world for atmosphere.
-- ============================================================
local function DomainExpansionBehaviour(self: Types.Ability)
	if RunService:IsServer() then
		Sounds.PlaySound(self.UseSound, { Parent = self.OwnerProperties.HRP })

		-- Spawn a visual domain sphere
		local hrp = self.OwnerProperties.HRP
		local domain = Instance.new("Part")
		domain.Name = "VoidDomain"
		domain.Shape = Enum.PartType.Ball
		domain.Size = Vector3.new(1, 1, 1)
		domain.Material = Enum.Material.Neon
		domain.BrickColor = BrickColor.new("Really black")
		domain.Transparency = 0.3
		domain.CanCollide = false
		domain.Anchored = true
		domain.CFrame = hrp.CFrame
		domain.Parent = workspace.Map.InGame

		-- Expand the sphere over 1 second
		local expandConn
		local size = 1
		expandConn = RunService.Heartbeat:Connect(function(dt)
			size = math.min(size + dt * 60, 60)
			domain.Size = Vector3.new(size, size, size)
			if size >= 60 then
				expandConn:Disconnect()
			end
		end)

		local PHASE1_DURATION = 10
		local PHASE2_DURATION = 6

		-- Phase 1: apply Helpless + Slowness III to all survivors
		for _, survivor in Utils.Character.GetCharactersWithRoles(false).Survivor or {} do
			local survivorHumanoid = survivor:FindFirstChildWhichIsA("Humanoid")
			if not survivorHumanoid or survivorHumanoid.Health <= 0 then continue end

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

		-- Phase 2: after domain collapses, linger Slowness II
		task.delay(PHASE1_DURATION, function()
			-- Shrink and destroy the domain sphere
			if domain.Parent then
				local shrinkConn
				shrinkConn = RunService.Heartbeat:Connect(function(dt)
					domain.Size = domain.Size - Vector3.new(1, 1, 1) * dt * 40
					if domain.Size.X <= 0 then
						shrinkConn:Disconnect()
						domain:Destroy()
					end
				end)
			end

			for _, survivor in Utils.Character.GetCharactersWithRoles(false).Survivor or {} do
				local survivorHumanoid = survivor:FindFirstChildWhichIsA("Humanoid")
				if not survivorHumanoid or survivorHumanoid.Health <= 0 then continue end

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
		end)

		Debris:AddItem(domain, PHASE1_DURATION + 2)
	else
		self:PlayUseAnimation()
	end
end

-- ============================================================
-- CHARACTER DEFINITION
-- ============================================================
local SteadGuy: Types.Killer = Character.CreateKiller({
	Config = {
		Name = "SteadGuy",
		Quote = "I'm not here to save this realm. I'm here to fix it...",
		Render = "rbxassetid://0",
		Price = 0,

		Origin = {
			TooltipText = "Dev Character",
			Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		},

		AnimationIDs = {
			Execution = {
				Default = {
					Killer = "rbxassetid://0",
					Survivor = "rbxassetid://0",
				},
			},
		},

		-- SteadGuy's custom chase themes (replace asset IDs with real uploads).
		-- L1 = low-intensity chase, L2 = medium, L3 = high, L4 = final/extreme.
		ChaseThemes = {
			L1 = "rbxassetid://0",
			L2 = "rbxassetid://0",
			L3 = "rbxassetid://0",
			L4 = "rbxassetid://0",
		},

		-- Explicitly use the default Last Man Standing theme.
		-- Replace with a custom asset ID if SteadGuy should have his own LMS music.
		LastManStandingTheme = "rbxassetid://96287447337283",
	},

	GameplayConfig = {
		Health = 1800,
		BaseSpeed = 16,
		SprintSpeedMultiplier = 1.5,
		StaminaProperties = {
			MaxStamina = 100,
			StaminaDrain = 20,
			StaminaGain = 40,
		},

		Abilities = {
			Slash = Slash.New({
				Duration = 0.35,
				Damage = 20,
			}),

			CursedJab = Ability.New({
				Name = "Cursed Jab",
				InputName = "FirstAbility",
				Cooldown = 8,
				UseSound = "rbxassetid://131961136",
				UseAnimation = "rbxassetid://507766388",
				Behaviour = CursedJabBehaviour,
			}),

			PlasmaArc = Ability.New({
				Name = "Plasma Arc",
				InputName = "SecondAbility",
				Cooldown = 18,
				UseSound = "rbxassetid://131933925",
				UseAnimation = "rbxassetid://507770239",
				Behaviour = PlasmaArcBehaviour,
			}),

			HeatSeeker = Ability.New({
				Name = "Heat Seeker",
				InputName = "ThirdAbility",
				Cooldown = 40,
				Duration = 12,
				Behaviour = HeatSeekerBehaviour,
			}),

			DomainExpansion = Ability.New({
				Name = "Domain Expansion: Void Eradication",
				InputName = "FourthAbility",
				Cooldown = 120,
				UseSound = "rbxassetid://131933925",
				Behaviour = DomainExpansionBehaviour,
			}),
		},
	},
})

-- ============================================================
-- DESCRIPTION
-- ============================================================
local SteadNameLabel = '<font color="rgb(80, 160, 255)">SteadGuy</font>'

SteadGuy.Config.Description = {
	{
		Type = "Separator",
		Text = "GENERAL INFO",
	},
	{
		Type = "Header",
		Text = SteadGuy.Config.Name:upper(),
	},
	{
		Type = "Quote",
		Text = '"' .. SteadGuy.Config.Quote .. '"',
	},
	{
		Type = "Text",
		Text = "A former friend of Bendie. He usually supported Bendie's projects, laughed at lunch, and helped each other in class. "
			.. "Stead really liked planes, cars, welding, and boxing — and he hated Algebra I. "
			.. "But things changed. Ever heard of a curse? "
			.. SteadNameLabel
			.. " is now one. He transformed himself into a curse, wielding the Ultimate Lifeform technique. "
			.. "Cursed energy flows through him — an infinite amount of it.",
	},
	{
		Type = "Header",
		Text = "STATS",
	},
	{
		Type = "Text",
		Text = {
			"Difficulty: ★★★☆☆",
			"Health: " .. tostring(SteadGuy.GameplayConfig.Health),
			"Base Speed: " .. tostring(SteadGuy.GameplayConfig.BaseSpeed),
			"Sprint Speed: " .. tostring(
				math.round(SteadGuy.GameplayConfig.BaseSpeed * SteadGuy.GameplayConfig.SprintSpeedMultiplier * 10) / 10
			),
			"Max Stamina: " .. tostring(SteadGuy.GameplayConfig.StaminaProperties.MaxStamina),
			"Stamina Loss per second: " .. tostring(SteadGuy.GameplayConfig.StaminaProperties.StaminaDrain),
			"Stamina Gain per second: " .. tostring(SteadGuy.GameplayConfig.StaminaProperties.StaminaGain),
		},
	},
	{
		Type = "Separator",
		Text = "ABILITIES",
	},
	{
		Type = "Header",
		Text = SteadGuy.GameplayConfig.Abilities.Slash.Name:upper(),
	},
	{
		Type = "Text",
		Text = SteadNameLabel .. " performs a basic cursed-energy slash, dealing 20 damage.",
	},
	{
		Type = "Header",
		Text = SteadGuy.GameplayConfig.Abilities.CursedJab.Name:upper(),
	},
	{
		Type = "Text",
		Text = SteadNameLabel
			.. " delivers a short-range jab charged with cursed energy, dealing 20–30 damage. Cooldown: 8s.",
	},
	{
		Type = "Header",
		Text = SteadGuy.GameplayConfig.Abilities.PlasmaArc.Name:upper(),
	},
	{
		Type = "Text",
		Text = SteadNameLabel
			.. " releases a slow-moving arc of plasma energy. On hit, deals 15 damage and applies <b>Slowness II</b> for 5 seconds. Cooldown: 18s.",
	},
	{
		Type = "Header",
		Text = SteadGuy.GameplayConfig.Abilities.HeatSeeker.Name:upper(),
	},
	{
		Type = "Text",
		Text = SteadNameLabel
			.. " activates radar mode: he blinds himself but gains <b>Speed II</b> and reveals every survivor's aura for 12 seconds. Cooldown: 40s.",
	},
	{
		Type = "Header",
		Text = SteadGuy.GameplayConfig.Abilities.DomainExpansion.Name:upper(),
	},
	{
		Type = "Text",
		Text = SteadNameLabel
			.. " expands his cursed domain. For 10 seconds, all survivors are afflicted with <b>Helpless</b> and <b>Slowness III</b>. "
			.. "When the domain collapses, a lingering <b>Slowness II</b> persists for 6 more seconds. Cooldown: 120s.",
	},
}

return SteadGuy
