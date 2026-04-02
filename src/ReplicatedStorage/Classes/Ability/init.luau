local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Network = require(ReplicatedStorage.Modules.Network)
local Sounds = require(ReplicatedStorage.Modules.Sounds)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Types = require(script.Parent.Types)
local Signal = require(ReplicatedStorage.Utils.Signal)

local Ability = {}

local MetaAbility = {}
MetaAbility.__index = MetaAbility

--- Returns a table with all of the default values of an ability, having `Ability.MetaAbility` as a metatable,
--- which contains common functions like `Ability:Init()` and such.
function Ability.GetDefaultSettings(): Types.Ability
    return setmetatable({
        Name = "Ability",
        RenderImage = "rbxassetid://9759886280",
        UICorner = true,
        Passive = false,

        -- OnServerInit = nil,
        -- OnClientInit = nil,
        -- OnServerRemove = nil,
        -- OnClientRemove = nil,

        StunnableConnections = {},

        ClientPrediction = false,

        InputName = "FirstAbility",
        -- Behaviour = nil,

        UseAnimation = "",
        -- UseAnimationTrack = nil,
        PlayUseAnimationOnUse = true,
        UseAnimationTransitionTime = 0.1,

        Cooldown = 5,
        CooldownTimer = 0,
        OnCooldown = false,
        AutomaticCooldown = true,
        
        Duration = 0.4,

        DisableOtherAbilitiesOnPerform = true,
        DisableSlashOnPerform = true,

        UsesLeft = 1,

        UseSettings = {
            Limited = false,
            InitialUses = 5,
        },

        Signals = {
            ChargesChanged = Signal.new(),
            Used = Signal.new(),
            CooldownSet = Signal.new(),
        },
    }, MetaAbility)
end

--- ## DEPRECATED: Use `Ability.GetDefaultSettings()` instead.
--- Ability preset for customization.
@deprecated
function Ability.GetDefaultAbilitySettings(): Types.Ability
    return Ability.GetDefaultSettings()
end

--- Returns a table with all of the default values of a *passive* ability, having `Ability.MetaAbility` as a metatable,
--- which contains common functions like `Ability:Init()` and such.
function Ability.GetDefaultPassiveSettings(): Types.Ability
    return setmetatable(Utils.Type.DeepTableOverwrite({
        Passive = true,

        Init = function(self: Types.Ability, plr: Player, charModule: Types.Killer | Types.Survivor)
            --setting important variables right on init
            self.Owner = plr
            self.CharacterModule = charModule
            self.UsesLeft = self.UseSettings.InitialUses

            --making the janitor and linking it to the owner's current character so when it gets destroyed, it cleans everything
            self.Janitor = Janitor.new()
            self.Janitor:LinkToInstance(self.Owner.Character)

            --clearing ability stuff to dispose of this code when the player gets readded
            self.Janitor:Add(self)

            if RunService:IsServer() then
                --is this exploitable? yes.
                --do i give a fuck? no.
                --thanks byfron.

                self.OwnerProperties = {
                    Character = self.Owner.Character,
                    Humanoid = self.Owner.Character:FindFirstChildWhichIsA("Humanoid"),
                    HRP = Utils.Character.GetRootPart(self.Owner),
                }

                --executes any extra initialization code that the ability might need
                if self.OnServerInit then
                    self:OnServerInit()
                end

                return
            end

            self.OwnerProperties = {
                Character = self.Owner.Character,
                Humanoid = self.Owner.Character:FindFirstChildWhichIsA("Humanoid"),
                HRP = Utils.Character.GetRootPart(self.Owner),
                InputManager = require(self.Owner.PlayerScripts.InputManager),
                FOVManager = require(self.Owner.Character.PlayerAttributeManagers.FOVManager),
                EffectManager = require(self.Owner.Character.PlayerAttributeManagers.EffectManager),
                -- EmoteManager = require(self.Owner.Character.Miscellaneous.EmoteManager),
                TurnToMoveDirection = require(self.Owner.PlayerScripts.Visual.TurnToMoveDirection),
                SpeedManager = require(self.Owner.Character.PlayerAttributeManagers.SpeedManager),
                Sprinting = require(self.Owner.Character.CharacterModule.Sprinting),
            }

            --executes any extra initialization code that the ability might need
            if self.OnClientInit then
                self:OnClientInit()
            end
        end,
        ReloadAnimation = function(self: Types.Ability, id: string)
            warn("Ability \""..self.Name.."\" is a Passive, so no use animation can be assigned to it!")
        end,
        PlayUseAnimation = function(self: Types.Ability)
            warn("Ability \""..self.Name.."\" is a Passive, so no use animation is available!")
        end,
        AttemptUse = function(self: Types.Ability)
            warn("Ability \""..self.Name.."\" is a Passive, so it can't be used through input!")
        end,
        ChangeAbilityCharges = function(self: Types.Ability, _Type: "Add" | "Set" | "Take", _amount: number)
            warn("Ability \""..self.Name.."\" is a Passive, so charges aren't applied!")
        end,

        PlayUseAnimationOnUse = false,

        Cooldown = 0,

        CanUse = function(_self: Types.Ability): boolean
            return true
        end,

        Duration = 0,

        DisableOtherAbilitiesOnPerform = false,
        DisableSlashOnPerform = false,

        Signals = {},
    }, Ability.GetDefaultSettings()), MetaAbility)
end

--- ## DEPRECATED: use `Ability.GetDefaultPassiveSettings()` instead.
@deprecated
function Ability.GetDefaultPassiveAbilitySettings(): Types.Ability
    return Ability.GetDefaultPassiveSettings()
end

--- Creates an ability with the settings specified in `Props`.
--- Every property that has to be there has a fallback, so not all properties have to be written there if the default values are fine.
function Ability.New(Props: Types.Ability): Types.Ability
    Props = Props or {}

    return Utils.Type.DeepTableOverwrite(
        Props.Passive and
            Ability.GetDefaultPassiveSettings() or
            Ability.GetDefaultSettings(),

        Props
    )
end

--- ## DEPRECATED: use `Ability.New()` instead.
--- Creates an ability with the settings specified in `Props`.
--- Every property that has to be there has a fallback, so not all properties have to be written there if the default values are fine.
@deprecated
function Ability.CreateAbility(Props: Types.Ability): Types.Ability
    return Ability.New(Props)
end

function MetaAbility.Init(self: Types.Ability, Player: Player, CharacterInfo: Types.Killer | Types.Survivor)
    self.Owner = Player
    self.CharacterModule = CharacterInfo
    self.UsesLeft = self.UseSettings.InitialUses

    self.Janitor = Janitor.new()
    self.Janitor:LinkToInstance(Player.Character)

    self.Janitor:Add(self)

    task.defer(function()
        local Effects = Player.Character:FindFirstChild("Effects")
        if not Effects then
            return
        end

        self:AddConnection(Effects.ChildAdded:Connect(function(NewChild: Instance)
            if NewChild.Name ~= "Stunned" then
                return
            end

            for _, Connection in self.StunnableConnections do
                if typeof(Connection) == "thread" then
                    if coroutine.running() == Connection then
                        continue
                    end

                    task.cancel(Connection)

                    continue
                end

                Connection:Disconnect()
            end
        end))
    end)
    
    if RunService:IsServer() then
        self.OwnerProperties = {
            Character = self.Owner.Character,
            Humanoid = self.Owner.Character:FindFirstChildWhichIsA("Humanoid"),
            HRP = Utils.Character.GetRootPart(self.Owner),
        }

        self:AddConnection(Network:SetConnection("UseAbility", "REMOTE_EVENT", function(_player: Player, _abilityName: string)
            self:Use()
        end, function(player: Player, abilityName: string): boolean
            local IsCorrect = not (player ~= self.Owner or abilityName ~= self.Name)
            if not IsCorrect then
                return false
            end

            if not self:CanUse() then
                if self.ClientPrediction then
                    Network:FireClientConnection(self.Owner, "UseAbility", "REMOTE_EVENT", self.Name)
                end

                return false
            end

            return true
        end))

        if self.OnServerInit then
            self:OnServerInit()
        end
    else
        self.OwnerProperties = {
            Character = self.Owner.Character,
            Humanoid = self.Owner.Character:FindFirstChildWhichIsA("Humanoid"),
            HRP = Utils.Character.GetRootPart(self.Owner),
            InputManager = require(self.Owner.PlayerScripts.InputManager),
            FOVManager = require(self.Owner.Character.PlayerAttributeManagers.FOVManager),
            EffectManager = require(self.Owner.Character.PlayerAttributeManagers.EffectManager),
            -- EmoteManager = require(self.Owner.Character.Miscellaneous.EmoteManager),
            TurnToMoveDirection = require(self.Owner.PlayerScripts.Visual.TurnToMoveDirection),
            AnimationManager = require(self.Owner.Character.AnimationManager),
            SpeedManager = require(self.Owner.Character.PlayerAttributeManagers.SpeedManager),
            Sprinting = require(self.Owner.Character.CharacterModule.Sprinting),
        }

        do
            local InputAction = self.Owner.PlayerScripts.InputManager.InputActions.Default:FindFirstChild(self.InputName)
            if InputAction then
                self:AddConnection(InputAction.Pressed:Connect(function()
                    self:AttemptUse()
                end))
            end
		end

        if self.UseAnimation ~= nil and #self.UseAnimation > 0 then
            self:ReloadAnimation(self.UseAnimation)
        end

        self:AddConnection(Network:SetConnection("ChangeAbilityCharges", "REMOTE_EVENT", function(_abilityName: string, Type: "Set" | "Add" | "Take", amount: number)
            self:ChangeAbilityCharges(Type, amount)
        end, function(abilityName: string): boolean
            return abilityName == self.Name
        end))

        self:AddConnection(Network:SetConnection("UseAbility", "REMOTE_EVENT", function(_abilityName: string, UnpredictedCooldown: number?)
            if self.ClientPrediction then
                if UnpredictedCooldown ~= nil then
                    self:SetOnCooldown(UnpredictedCooldown)
                elseif self.PredictionJanitor then
                    self.PredictionJanitor:Cleanup()

                    self:SetOnCooldown(0)
                    self:EnableAllAbilities()

                    self.UseAnimationTrack:Stop(self.UseAnimationTransitionTime)
                    self.OwnerProperties.TurnToMoveDirection:RemoveHeadPreventionFactor(self.Name)
                end

                return
            end

            self:Use()
        end, function(abilityName: string)
            return abilityName == self.Name
		end))

        if self.OnClientInit then
            self:OnClientInit()
        end
	end
end

function MetaAbility.ReloadAnimation(self: Types.Ability, id: string)
    local AnimName = self.Name:gsub(" ", "").."Use"
    self.CharacterModule.GameplayConfig.Cache.Animations[AnimName] = self.OwnerProperties.AnimationManager ~= nil and
        self.OwnerProperties.AnimationManager:LoadAnimation(AnimName, id, false) or
        Utils.Character.LoadAnimationFromID(self.OwnerProperties.Character, id, false)
    self.UseAnimationTrack = self.CharacterModule.GameplayConfig.Cache.Animations[AnimName]
end

function MetaAbility.PlayUseAnimation(self: Types.Ability): thread
    if not self.UseAnimationTrack then
        return
    end

    self.UseAnimationTrack:Play(self.UseAnimationTransitionTime)
    self.OwnerProperties.TurnToMoveDirection:AddHeadPreventionFactor(self.Name)
    return self:AddConnection(task.delay(self.UseAnimationTrack.Length - (1/20 * 2), function()
        self.UseAnimationTrack:Stop(self.UseAnimationTransitionTime)
        self.OwnerProperties.TurnToMoveDirection:RemoveHeadPreventionFactor(self.Name)
    end))
end

function MetaAbility.Destroy(self: Types.Ability)
    if self.OnRemove then
        self:OnRemove()
    end
    if RunService:IsServer() then
        if self.OnServerRemove then
            self:OnServerRemove()
        end
    elseif self.OnClientRemove then
        self:OnClientRemove()
    end

    for _, signal in self.Signals do
        signal:DisconnectAll()
    end

    self.CooldownTimer = 0
    self.OnCooldown = false
end

function MetaAbility.AttemptUse(self: Types.Ability)
    if RunService:IsServer() then
        return
    end

    --NOTE: this is handled this way (by making separate cooldowns in both server and client) so that it's possible to prevent network calls if it's impossible to use the ability in client
    if self:CanUse() then
        Network:FireServerConnection("UseAbility", "REMOTE_EVENT", self.Name) --i know this is insecure but sue me lol
        if self.ClientPrediction then
            self:Use()
        end
    end
end

function MetaAbility.Use(self: Types.Ability)
    if RunService:IsServer() then
        task.defer(function()
            if self.CharacterModule.Config.Voicelines and self.CharacterModule.Config.Voicelines[self.Name] then
                Sounds.PlayVoiceline(self.Owner.Character, self.CharacterModule.Config.Voicelines[self.Name])
            end
        end)

        --cooldown stuffs
        if self.AutomaticCooldown then
            self:SetOnCooldown()
        end

        --decreasing uses left if it's supposed to be limited
        if self.UseSettings.Limited then
            task.spawn(function()
                self:ChangeAbilityCharges("Set", self.UsesLeft - 1)
            end)
        end

        --signal thing
        self.Signals.Used:Fire()
        --send the real server cooldown if client prediction is enabled to set the cooldown back to the real server cooldown instead of a fake client cooldown to prevent false positives
        Network:FireClientConnection(self.Owner, "UseAbility", "REMOTE_EVENT", self.Name, self.ClientPrediction and self.Cooldown or nil)

        if self.ServerBehaviour then
            self:ServerBehaviour()
        end
        
        return
    end

    if self.ClientPrediction and not self.PredictionJanitor then
        self.PredictionJanitor = Janitor.new()
        self.PredictionJanitor:LinkToInstance(self.OwnerProperties.Character)
    end

    --disables ability keys for preventing the usage of a different ability while using it
    if self.DisableOtherAbilitiesOnPerform then
        local EnableThread = self:DisableAllAbilities()
        if self.ClientPrediction then
            self.PredictionJanitor:Add(EnableThread, true)
        end
    end

    --cooldown stuffs
    if self.AutomaticCooldown then
        self:SetOnCooldown()
    end
    --plays any existant use animation
    task.defer(function()
        if self.PlayUseAnimationOnUse then
            local AnimThread = self:PlayUseAnimation()
            if self.ClientPrediction then
                self.PredictionJanitor:Add(AnimThread, true)
            end
        end
    end)
    --signal thing
    self.Signals.Used:Fire()
    --ability stuffs
    if self.ClientBehaviour then
        self:ClientBehaviour()
    end
end

function MetaAbility.ChangeAbilityCharges(self: Types.Ability, Type: "Add" | "Set" | "Take", amount: number)
    if Type == "Set" then
        self.UsesLeft = amount
    elseif Type == "Add" then
        self.UsesLeft += amount
    elseif Type == "Take" then
        self.UsesLeft -= amount
    end

    self.Signals.ChargesChanged:Fire(amount)
    if RunService:IsServer() then
        Network:FireClientConnection(self.Owner, "ChangeAbilityCharges", "REMOTE_EVENT", self.Name, Type, amount)
    end
end
        
function MetaAbility.DisableAllAbilities(self: Types.Ability, Duration: number?, DisableSlash: boolean?): thread?
    if RunService:IsServer() then
        return
    end
    
    Duration = Duration or self.Duration
    if DisableSlash == nil then
        DisableSlash = self.DisableSlashOnPerform
    end
    for _, input in self.Owner.PlayerScripts.InputManager.InputActions.Default:GetChildren() do
        if input.Name:lower():find("ability") or (input.Name:lower():find("slash") and DisableSlash) then
            input.Enabled = false
        end
    end
    if Duration then
        return self:AddConnection(task.delay(Duration, function()
            self:EnableAllAbilities()
        end))
    end

    return
end

function MetaAbility.EnableAllAbilities(self: Types.Ability)
    if RunService:IsServer() then
        return
    end

    for _, input in self.Owner.PlayerScripts.InputManager.InputActions.Default:GetChildren() do
        if input.Name:lower():find("ability") or input.Name:lower():find("slash") then
            input.Enabled = true
        end
    end
end

function MetaAbility.SetOnCooldown(self: Types.Ability, duration: number?)
    if not workspace:GetAttribute("CooldownsEnabled") then
        return
    end

    duration = duration or self.Cooldown

    --set le timer if it's already on cooldown
    if self.OnCooldown then
        self.CooldownTimer = duration
        return
    end

    --prop setting
    self.OnCooldown = true
    self.CooldownTimer = duration

    if RunService:IsServer() then
        --reset the delay counter
        if self._cooldownTask then
            task.cancel(self._cooldownTask)
            self._cooldownTask = nil
        end
        --doing cooldowns this way removes the ability to read cooldown amounts on server, might work on it later
        self._cooldownTask = self:AddConnection(task.delay(duration, function()
            self.CooldownTimer = 0
            self.OnCooldown = false
        end))
    else
        task.spawn(function()
            --this is still network stability dependant in the way that you may have to wait 0.1s more for the ability to not be on cooldown
            --because e.g. if it waits 0.19s because of framerate or anything it will reduce 0.1s and wait another 0.1s
            --but the change is so little i can't care enough to change it back
            while self.CooldownTimer > 0 do
                -- gets the amount the client waits
                local WaitAmount = task.wait(0.1)
                -- floors that onto how much it's been waiting to e.g. drain 0.1s if it waits 0.12s and 0.2s if it waits more than 0.21s
                WaitAmount = math.floor(WaitAmount * 10) / 10
                -- reduces cooldown timer
                self.CooldownTimer -= WaitAmount
            end
            --reset stuffs
            self.CooldownTimer = 0
            self.OnCooldown = false
        end)
    end

    self.Signals.CooldownSet:Fire(duration)
end

function MetaAbility.AddConnection<T>(self: Types.Ability, Connection: T & (RBXScriptConnection | thread)): T & (RBXScriptConnection | thread)
    self.Janitor:Add(Connection,
        if typeof(Connection) == "thread" then
            true
        else
            "Disconnect"
    )

    return Connection
end

function MetaAbility.AddStunnableConnection<T>(self: Types.Ability, Connection: T & (RBXScriptConnection | thread)): T & (RBXScriptConnection | thread)
    self:AddConnection(Connection)
    table.insert(self.StunnableConnections, Connection)

    return Connection
end

function MetaAbility.CanUse(self: Types.Ability): boolean
    --if it's limited then it should have to have enough uses left
    local EnoughUses = true
    if workspace:GetAttribute("ChargesEnabled") and self.UseSettings.Limited then
        EnoughUses = self.UsesLeft > 0
    end

    --if the ability is on cooldown or not
    local OnCooldown = false
    if workspace:GetAttribute("CooldownsEnabled") and self.OnCooldown then
        OnCooldown = true
    end

    --if the player isn't stunned, thus can be conscious AND has hope (hopes and dreams. UNDERTALE REFERENCE????)
    local EffectPrevention = false
    if RunService:IsServer() then
        if self.Owner.Character.Effects:FindFirstChild("Stunned") or self.Owner.Character.Effects:FindFirstChild("Helpless") then
            EffectPrevention = true
        end
    elseif self.OwnerProperties.EffectManager ~= nil then
        if self.OwnerProperties.EffectManager.Effects["Stunned"] or self.OwnerProperties.EffectManager.Effects["Helpless"] then
            EffectPrevention = true
        end
    end

    --if the player isn't emoting
    local Emoting
    if RunService:IsServer() then
        Emoting = self.OwnerProperties.Character:GetAttribute("Emoting") == true
    elseif self.OwnerProperties.EmoteManager ~= nil then
        Emoting = self.OwnerProperties.EmoteManager.CurrentlyPlayingEmote ~= nil
    end

    return EnoughUses
        and not OnCooldown --if the ability isn't on cooldown
        and self.OwnerProperties.Humanoid.Health > 0 --if the player's alive
        and not self.OwnerProperties.HRP.Anchored --if the player isn't restrained by initial round setup
        and not self.Owner.Character:GetAttribute("Executing") --if the player isn't being executed
        and not Emoting --if the player isn't emoting
        and not EffectPrevention --if the player isn't stunned and doesn't have helpless
        and self:UsePredicate() --any extra conditions added by the ability's definition in `Ability:UsePredicate()`
end

function MetaAbility.UsePredicate(self: Types.Ability): boolean
    return true
end

return Ability
