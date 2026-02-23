local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local Hitbox = RunService:IsServer() and require(ServerScriptService.Classes.Hitbox) or nil
local PlayerSpeedManager = require(ServerScriptService.Managers.PlayerManager.CharacterManager.PlayerSpeedManager)
local ServerUtils = require(ServerScriptService.ServerUtils)
local Types = require(ReplicatedStorage.Classes.Types)
local Sounds = require(ReplicatedStorage.Modules.Sounds)

local Commander = {}

function Commander.BlindsideBehaviour(self: Types.Ability)
    local AnimatedGrenade = self.OwnerProperties.Character:FindFirstChild("Grenade")
    AnimatedGrenade.Transparency = 0

    self:AddConnection(task.delay(self.ThrowDelay, function()
        local FunctionalGrenade = AnimatedGrenade:Clone()
        local Joint = FunctionalGrenade:FindFirstChildWhichIsA("JointInstance")
        if Joint then
            Joint:Destroy()
        end
        FunctionalGrenade.Name = "ActiveFlashGrenade"
        FunctionalGrenade.CanCollide = true
        FunctionalGrenade.CollisionGroup = "Items"
        FunctionalGrenade.AssemblyLinearVelocity = (self.OwnerProperties.Character.HumanoidRootPart.CFrame.LookVector + Vector3.new(0, 0.5, 0)) * self.ThrowForce
        FunctionalGrenade.Parent = workspace:FindFirstChild("Map") and workspace.Map.InGame or workspace.TempObjectFolders

        AnimatedGrenade.Transparency = 1
    
        self:AddConnection(task.delay(self.TriggerDelay, function()
            task.spawn(function()
                Hitbox.New(self.Owner, {
                    CFrame = CFrame.new(FunctionalGrenade.Position),
                    Size = Vector3.new(35, 35, 35),
                    Damage = 0,
                    Time = 1/40 * 3,
                    Shape = Enum.PartType.Ball,
                    EffectsToApply = {
                        {
                            Name = "Blindness",
                            Duration = 4,
                            Level = 1,
                        },
                    },
                    Connections = {
                        PostHit = function(Config: Types.HitboxSettings, Hum: Humanoid)
                            ServerUtils.Player.GrantRewardToPlayer(self.Owner, {Money = 10, EXP = 20, Reason = "blinding the killer with Blindside"})
                        end,
                    }
                })
            end)
        
            local Light = FunctionalGrenade:FindFirstChildWhichIsA("PointLight")
            Light.Enabled = true
            TweenService:Create(Light, TweenInfo.new(0.1), {Brightness = 0}):Play()
        
            FunctionalGrenade:FindFirstChildWhichIsA("ParticleEmitter"):Emit(80)
        
            self:AddConnection(task.delay(0.1, function()
                FunctionalGrenade.Transparency = 1
                Light.Enabled = false
            
                Debris:AddItem(FunctionalGrenade, 8)
            end))
        end))
    end))
end

function Commander.ReloadBehaviour(self: Types.Ability)
    self:AddConnection(task.delay(self.Duration, function()
        self.CharacterModule.GameplayConfig.Abilities.Justice:ChangeAbilityCharges("Set", 1)
    end))

    -- ServerUtils.Character.ApplyEffect({
    --     TargetHumanoid = self.OwnerProperties.Humanoid,
    --     EffectSettings = {
    --         Name = "Slowness",
    --         Level = 3,
    --         Duration = 5,
    --     },
    -- })
end

function Commander.JusticeBehaviour(self: Types.Ability)
    --Shot Sound & Hitbox
    self:AddConnection(task.delay(1.17, function()
        task.spawn(function()
            Hitbox.New(self.Owner, {
                CFrameOffset = CFrame.new(0, 0, -(self.HitboxLength / 2)),
                Size = Vector3.new(3, 1.5, self.HitboxLength),
                Time = self.Duration,
                Reason = "The Gun Shot",
                Damage = self.Damage,
                EffectsToApply = {
                    {
                        Name = "Stunned",
                        Level = 1,
                        Duration = self.StunTime,
                        Subfolder = "KillerSpecific"
                    },
                },
                Connections = {
                    PostHit = function(Config: Types.HitboxSettings, Hum: Humanoid)
                        ServerUtils.Player.GrantRewardToPlayer(self.Owner, {Money = 6, EXP = 14, Reason = "stunning the killer with Justice"})
                    end,
                }
            })
        end)
    
        local FirePart = self.JusticeModel.FirePart
        FirePart.Burst:Emit(4)
        FirePart.Front:Emit(12)
        FirePart.Smoke:Emit(8)
        FirePart.Flash:Emit(3)
        Sounds.PlaySound(self.ShotSound, {Volume = 2}, {
            Position = FirePart.Position,
        })
    end))

    --Hide
    self:AddConnection(task.delay(2, function()
        for _, Part in self.JusticeModel:GetDescendants() do
            if Part:IsA("BasePart") then
                Part.Transparency = 1
            end
        end
    end))

    task.spawn(function()
        PlayerSpeedManager.AddFactor(self.Owner, self.Name, 0.3)
        self:AddConnection(task.delay(self.UseAnimationTrack and self.UseAnimationTrack.Length or self.Duration, function()
            PlayerSpeedManager.RemoveFactor(self.Owner, self.Name)
        end))
    end)

    --Show
    for _, Part in self.JusticeModel:GetDescendants() do
        if Part:IsA("BasePart") and not Part:HasTag("Transparent") then
            Part.Transparency = 0
        end
    end
end

function Commander.OnHit(self: Types.Ability, _hitbox: Types.HitboxDetails, _damage: number)
    -- ServerUtils.Character.ApplyEffect({
    --     TargetHumanoid = self.OwnerProperties.Humanoid,
    --     EffectSettings = {
    --         Name = "Resistance",
    --         Level = 5,
    --         Duration = 1,
    --     },
    -- })
end

return Commander
