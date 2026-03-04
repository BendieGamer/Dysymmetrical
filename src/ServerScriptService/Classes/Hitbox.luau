local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GlobalTimeManager = require(ServerScriptService.Managers.GlobalTimeManager)
local ServerUtils = require(ServerScriptService.ServerUtils)
local Types = require(ReplicatedStorage.Classes.Types)
local Network = require(ReplicatedStorage.Modules.Network)
local Sounds = require(ReplicatedStorage.Modules.Sounds)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local Hitbox = {}

local FallbackSettings: Types.HitboxSettings = {
    Size = Vector3.new(4, 7, 4),
    CFrameOffset = CFrame.new(),
    Damage = 20,
    Time = 0.2,
    Knockback = 0,
    HitMultiple = false,
    PredictVelocity = true,
    ExecuteOnKill = false,
    IsProjectile = false,
    FriendlyFire = false,
    Reason = "Generic Hit",
    Shape = Enum.PartType.Block,
    MinBlockingWallHeight = 3,
    IgnoreWalls = false,
    EffectsToApply = {},
    Connections = {},
}

local MetaHitbox = {}
MetaHitbox.__index = MetaHitbox

--- Creates a new hitbox, assigning it to a specific player.
function Hitbox.New(Source: Player, Config: Types.HitboxSettings): Types.HitboxDetails
    if not Source then
        warn(`[Hitbox.New()] Hitboxes must have a Player owner!\n{debug.traceback()}`)
        return
    end
    
    local Char = Source.Character
    local Root = Utils.Character.GetRootPart(Char)
    if not Root then
        warn(`[Hitbox.New()] A hitbox's source character must have a root part assigned to it!\n{debug.traceback()}`)
        return
    end

    --writing default values if they're missing
    Utils.Type.DeepTableWrite(Config, FallbackSettings)

    local IntersectFilter = OverlapParams.new()
    IntersectFilter.FilterType = Enum.RaycastFilterType.Exclude
    IntersectFilter.FilterDescendantsInstances = {Char}
    IntersectFilter.CollisionGroup = "Attackable"

    local RayParams = RaycastParams.new()
    RayParams.FilterType = Enum.RaycastFilterType.Exclude
    RayParams.FilterDescendantsInstances = {Char}

    local SourceEffects: Folder = Char.Effects

    local self: Types.HitboxDetails = setmetatable({
        HumanoidsHit = {},
        Creator = Source,
        Damage = Config.Damage,
        TimePast = 0,
        Cancelled = false,
        IsProjectile = Config.IsProjectile,
        Callbacks = Config.Connections,
        _Janitor = Janitor.new(),
    }, MetaHitbox)
    self._Janitor:LinkToInstances(Char, Root)

    self._Janitor:Add(SourceEffects.ChildAdded:Connect(function(Effect: Instance)
        if Effect.Name ~= "Stunned" then
            return
        end

        self:Cancel()
    end))

    local function CanContinue()
        return not self.Cancelled and self.TimePast < Config.Time and (Config.HitMultiple or (#self.HumanoidsHit <= 0))
    end

    task.spawn(function()
        if SourceEffects:FindFirstChild("Stunned") then
            return
        end

        local DetectionPart = Hitbox._CreateDetectionPart(Source, Config)

        while CanContinue() do
            local CurrentDetPart = DetectionPart:Clone()

            for _, Name in {"Size", "Shape"} do
                if CurrentDetPart[Name] ~= Config[Name] then
                    CurrentDetPart[Name] = Config[Name]
                end
            end

            --if there's a specific cframe set in the config,
                --execute it if it's a function
                --just fetch it if not
            --if not, just get the root's cframe
            --then mult by the offset
            --HACK: ts ugly
            CurrentDetPart.CFrame = (Config.CFrame and (typeof(Config.CFrame) == "function" and Config.CFrame() or Config.CFrame) or Root.CFrame) * Config.CFrameOffset
            CurrentDetPart.Parent = workspace.Hitboxes

            Debris:AddItem(CurrentDetPart, 0.75)

            Hitbox._CompensatePingIfApplicable(Source, Config, Root, CurrentDetPart)

            local Damaged = Hitbox._GetDamaged(CurrentDetPart, IntersectFilter)
            local Hit = self:_GetActuallyHitHumanoids(Config, Damaged)

            CurrentDetPart.Color = #Hit > 0 and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)

            self:_DamageHumanoids(Hit, CurrentDetPart, Config)

            self.TimePast += task.wait(1/40)
        end

        self:_RunCallback("Ended")
    end)

    return self
end

function MetaHitbox:_GetActuallyHitHumanoids(Config: Types.HitboxSettings, Damaged: {BasePart}): {Humanoid}
    local Hit: {Humanoid} = {}

    for _, Part in Damaged do
        local Humanoid: Humanoid = Utils.Character.FindHumanoidInModel(Part)
        if not Humanoid or table.find(self.HumanoidsHit, Humanoid) then
            continue
        end

        local Target = Humanoid.Parent

        --if:
            --the hum's alive
            --it's not invincible
            --it's not being executed (death)
            --friendly fire is active in the hitbox or workspace or if it's a different role from the source
        if not (
            Humanoid.Health > 0
            and not Target:GetAttribute("Invincible")
            and not Target:GetAttribute("Executing")
            and (
                workspace:GetAttribute("FriendlyFire")
                or Config.FriendlyFire
                or Target:GetAttribute("Role") ~= self.Creator.Character:GetAttribute("Role")
            )
        ) then
            continue
        end

        if not Config.IgnoreWalls and Hitbox._CheckForWall(self.Creator.Character, Target, Config) then
            continue
        end

        table.insert(self.HumanoidsHit, Humanoid)
        table.insert(Hit, Humanoid)
    end

    return Hit
end

function MetaHitbox:Cancel()
    if self.Cancelled then
        return
    end

    self.Cancelled = true
    self._Janitor:Cleanup()
    for _, Conn in self.Connections do
        Conn:Disconnect()
    end
end

function MetaHitbox:_RunCallback(ID: string, ...)
    if not (self.Callbacks and self.Callbacks[ID]) then
        return
    end

    self.Callbacks[ID](...)
end

function MetaHitbox:_DamageHumanoids(Hit: {Humanoid}, DetectionPart: BasePart, Config: Types.HitboxSettings)
    for Index, Humanoid in Hit do
        self:_RunCallback("PreHit", Config, Humanoid, Index == 1)

        local Target = Humanoid.Parent
        local TargetRoot = Utils.Character.GetRootPart(Target)

        if not TargetRoot then
            continue
        end

        Target:SetAttribute("TimesHit", (Target:GetAttribute("TimesHit") or 0) + 1)

        local HasResistance, ResistanceLevel = Utils.Character.CheckPlayerEffect(Target, "Resistance")

        local Damage = Config.Damage
        if HasResistance then
            Damage *= 1 - ResistanceLevel / 5
        end

        if Target:GetAttribute("CharacterName") ~= nil then
            local CharModule = require(Target.CharacterModule).Module
            if CharModule and CharModule.OnHit ~= nil and CharModule:OnHit(self, Damage) then
                continue
            end
        end

        self:_RunCallback("Hit", Config, Humanoid, Index == 1)

        if Target:FindFirstChild("Killer") then
            Target.Killer.Value = self.Creator
        end

        if self:_ExecuteIfApplicable(self.Creator.Character, Target, Damage, Humanoid) then
            return
        end

        ServerUtils.Character.DamagePlayer({
            SourcePlayer = self.Creator,
            TargetHumanoid = Humanoid,
            Damage = Damage,
            Reason = Config.Reason,
            KnockbackDirection = DetectionPart.CFrame.LookVector,
            KnockbackMagnitude = Config.Knockback,
        })

        if Config.EffectsToApply then
            for _, Effect in Config.EffectsToApply do
                ServerUtils.Character.ApplyEffect({
                    TargetHumanoid = Humanoid,
                    EffectSettings = {
                        Name = Effect.Name,
                        Level = Effect.Level,
                        Duration = Effect.Duration,
                        Subfolder = Effect.Subfolder,
                    },
                    OverwriteExistingEffect = Effect.OverwriteExisting,
                })
            end
        end

        self:_RunCallback("PostHit", Config, Humanoid, Index == 1)
    end
end

function MetaHitbox:_ExecuteIfApplicable(Config: Types.HitboxSettings, SourceCharacter: Model, TargetCharacter: Model, Damage: number, TargetHumanoid: Humanoid): boolean
    if not (TargetHumanoid.Health > 0 and TargetHumanoid.Health - Damage <= 0) then
        return false
    end

    local Module: Types.Killer = require(Utils.Instance.GetCharacterModule(SourceCharacter:GetAttribute("Role"), SourceCharacter:GetAttribute("CharacterName"), SourceCharacter:GetAttribute("CharacterSkin")))

    local KilledSurvivor = {
        Name = TargetCharacter:GetAttribute("CharacterName"),
        Skin = TargetCharacter:GetAttribute("CharacterSkin"),
    }

    if Module.Config.Voicelines.Kill then
        local Voiceline =
            (KilledSurvivor.Skin and
                Module.Config.Voicelines.Kill[KilledSurvivor.Skin..KilledSurvivor.Name] or
                Module.Config.Voicelines.Kill[KilledSurvivor.Name])
            or Module.Config.Voicelines.Kill.Default

        if Voiceline then
            Sounds.PlayVoiceline(SourceCharacter, Voiceline)
        end
    end

    if not (SourceCharacter:GetAttribute("Role") == "Killer" and Config.ExecuteOnKill and TargetCharacter:GetAttribute("ExecutionsDisabled")) then
        return false
    end

    local AvailableExecutionAnims = Module.Config.AnimationIDs[Config.ExecutionAnimation or "Execution"]

    if not AvailableExecutionAnims then
        return false
    end
    
    local ExecutionAnim =
        (KilledSurvivor.Skin and
            AvailableExecutionAnims[KilledSurvivor.Skin..KilledSurvivor.Name] or
            AvailableExecutionAnims[KilledSurvivor.Name])
        or AvailableExecutionAnims.Default
    
    if not ExecutionAnim then
        return false
    end

    task.defer(function()
        self:_Execute(Config, ExecutionAnim, SourceCharacter, TargetCharacter, KilledSurvivor)
    end)

    return true
end

function MetaHitbox:_Execute(Config: Types.HitboxSettings, ExecutionAnim: {Killer: string, Survivor: string}, SourceCharacter: Model, TargetCharacter: Model, KilledSurvivor: {any})
    SourceCharacter:GetAttribute("Executing", true)
    SourceCharacter:GetAttribute("Invincible", true)
    TargetCharacter:GetAttribute("Executing", true)

    --reward granting and networking
    task.spawn(function()
        ServerUtils.Player.GrantRewardToPlayer(self.Creator, {
            Money = 20,
            EXP = 60,
            Reason = "killing a Survivor"
        })
        ServerUtils.PlayerData.UpdatePlayerStat(self.Creator, "KillerStats.Kills", 1)

        GlobalTimeManager.SetTime(GlobalTimeManager.Time + 35)

        local TargetPlayer = Players:GetPlayerFromCharacter(TargetCharacter)
        if not TargetPlayer then
            return
        end

        Network:FireClientConnection(self.Creator, "KilledPlayer", "REMOTE_EVENT", TargetPlayer)
        Network:FireConnection("KilledPlayer", self.Creator, TargetPlayer)
    end)

    TargetCharacter.Effects:ClearAllChildren()

    local SourceRoot = Utils.Character.GetRootPart(SourceCharacter)
    local TargetRoot = Utils.Character.GetRootPart(TargetCharacter)

    SourceRoot.Anchored = true
    TargetRoot.Anchored = true

    local RuntimeKillerModule: Types.Killer = require(SourceCharacter.CharacterModule).Module
    local KillerExecutionAnimations = RuntimeKillerModule.GameplayConfig.Cache.Animations[Config.ExecutionAnimation or "Execution"]
    local KillerAnimation = 
        ((KilledSurvivor.Skin and
            KillerExecutionAnimations[KilledSurvivor.Skin..KilledSurvivor.Name] or
            KillerExecutionAnimations[KilledSurvivor.Name])
        or KillerExecutionAnimations.Default
    ).Killer

    local SurvivorAnim = Utils.Character.LoadAnimationFromID(TargetCharacter, ExecutionAnim.Survivor, true)

    SourceCharacter:PivotTo(CFrame.new(SourceRoot.CFrame, TargetRoot.Position))
    TargetCharacter:PivotTo(SourceRoot.CFrame * (RuntimeKillerModule.Config.ExecutionSurvivorCFrameOffset or CFrame.new(0, 0, -3)) * CFrame.fromEulerAngles(0, math.rad(180), 0))

    --exec sound
    task.defer(function()
        if not RuntimeKillerModule.Config.Sounds.Execution then
            return
        end

        local ExecutionSound =
            (KilledSurvivor.Skin and
                RuntimeKillerModule.Config.Sounds.Execution[KilledSurvivor.Skin..KilledSurvivor.Name] or
                RuntimeKillerModule.Config.Sounds.Execution[KilledSurvivor.Name])
            or RuntimeKillerModule.Config.Sounds.Execution.Default
        
        if ExecutionSound then
            Sounds.PlaySound(ExecutionSound, {
                Parent = SourceRoot
            })
        end
    end)

    --cleanup
    task.delay(KillerAnimation.Length, function()
        if SourceCharacter then
            SourceCharacter:SetAttribute("Invincible", false)
            SourceCharacter:SetAttribute("Executing", false)
        end
        if SourceRoot then
            SourceRoot.Anchored = false
        end
        if TargetRoot then 
            TargetRoot.Anchored = false
        end
        local TargetHumanoid = Utils.Character.FindHumanoidInModel(TargetCharacter)
        if TargetHumanoid then
            TargetHumanoid.Health = 0
        end
    end)

    KillerAnimation:Play(0)
    SurvivorAnim:Play(0)

    if RuntimeKillerModule.OnExecution then
        RuntimeKillerModule:OnExecution(TargetCharacter, Config.ExecutionAnimation or "Execution")
    end
end

function Hitbox._CreateDetectionPart(Source: Player, Config: Types.HitboxSettings): Part
    local Part = Instance.new("Part")
    Part.Name = Source.Name.."Hitbox"
    Part.Material = Enum.Material.ForceField
    Part.Transparency = 1
    Part.CanCollide = false
    Part.CanQuery = false
    Part.CanTouch = false
    Part.CastShadow = false
    Part.Anchored = true
    Part.Size = Config.Size
    Part.Shape = Config.Shape

    return Part
end

function Hitbox._CompensatePingIfApplicable(Source: Player, Config: Types.HitboxSettings, Root: BasePart, DetectionPart: Part)
    if not (Config.PredictVelocity and not Config.IsProjectile) then
        return
    end

    local PingDiff = 6.5 - math.clamp(Source:GetNetworkPing(), 0, 3)
    local Offset = DetectionPart.CFrame:VectorToObjectSpace(Root.AssemblyLinearVelocity) / PingDiff
    DetectionPart.CFrame *= CFrame.new(Offset)
end

function Hitbox._GetDamaged(DetectionPart: Part, Params: OverlapParams): {BasePart}
    local Damaged = {}
    for _, Part in workspace:GetPartsInPart(DetectionPart, Params) do
        if not Part:GetAttribute("HitboxPriority") then
            continue
        end

        table.insert(Damaged, Part)
    end

    table.sort(Damaged, function(a: BasePart, b: BasePart)
        return a:GetAttribute("HitboxPriority") > b:GetAttribute("HitboxPriority")
    end)

    return Damaged
end

function Hitbox._CheckForWall(SourceCharacter: Model, TargetCharacter: Model, Config: Types.HitboxSettings): boolean
    local SourceRoot = Utils.Character.GetRootPart(SourceCharacter)
    local TargetRoot = Utils.Character.GetRootPart(TargetCharacter)

    if not SourceRoot or not TargetRoot then
        return true
    end

    local MinimumHeight = Config.MinBlockingWallHeight

    local Params = RaycastParams.new()
    Params.FilterType = Enum.RaycastFilterType.Exclude
    Params.FilterDescendantsInstances = {SourceCharacter, TargetCharacter}

    for Index = -1, 1 do
        local Offset = Index * 2

        local Origin = SourceRoot.Position + Vector3.yAxis * Offset
        local Target = TargetRoot.Position + Vector3.yAxis * Offset
        local Cast = workspace:Raycast(Origin, Target - Origin, Params)

        if Cast
            and Cast.Instance
            and Cast.Instance.Transparency < 1
            and not Cast.Instance:GetAttribute("Hitbox")
            and Cast.Normal.Y < 0.5
            and Cast.Instance.Size.Y >= MinimumHeight
        then
            local Obstacle = Utils.Character.FindHumanoidInModel(Cast.Instance)
            if Obstacle then
                continue
            end
            return true
        end
    end

    return false
end

return {
    New = Hitbox.New,
}
