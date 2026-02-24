local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)
local PlayerAbilitiesUI = require(ReplicatedStorage.UI.PlayerAbilitiesUI)

local AnimLoadPrevented = {
    IdleAnimation = true, --doing it like this to not use `table.find()` and save a bit in overhead
    WalkAnimation = true,
    RunAnimation = true,
    Execution = true,
}

local CharacterInitter = {
    -- ResetButtonThread = nil,
}

function CharacterInitter:Init()
    Utils.Character.ObserveCharacter(Players.LocalPlayer, function(Character: Model)
        CharacterInitter._InitializeGameCharacter(Character)

        --init all character scripts themselves
        require(Character:FindFirstChild("Initter")):Init(Character)
    end)
end

function CharacterInitter._InitializeGameCharacter(Character: Model)
    if Character:GetAttribute("Role") == "Spectator" or not Character:GetAttribute("CharacterName") then
        return
    end

    --disable the reset button
    CharacterInitter._ResetButtonCycle()

    --make a new char table for this character
    local Info: Types.Killer | Types.Survivor = Utils.Type.CopyTable(require(Utils.Instance.GetCharacterModule(Character:GetAttribute("Role"), Character:GetAttribute("CharacterName"), Character:GetAttribute("CharacterSkin"))))
    Info.Owner = Players.LocalPlayer

    --preload le stuff
    Utils.Misc.PreloadAssets(Info.Config)

    --load all animations in a deferred thread
    task.defer(CharacterInitter._LoadCharacterAnimations, Character, Info)

    --set up sprint multiplier
    require(Character.CharacterModule.Sprinting).SprintMultiplier = Info.GameplayConfig.SprintSpeedMultiplier

    --set the anim transition time
    Character:SetAttribute("AnimationTransitionTime", Info.Config.AnimationTransitionTime)

    --init all char abilities
    CharacterInitter._InitializeCharacterAbilities(Character, Info)

    --oninit callback
    if Info.OnInit then
        Info:OnInit(Character)
    end
end

--- Disables the reset button for 5 seconds.
--- 
--- If called while waiting, the 5 second counter will reset and take another 5 seconds.
function CharacterInitter._ResetButtonCycle()
    if CharacterInitter.ResetButtonThread then
        task.cancel(CharacterInitter.ResetButtonThread)
        CharacterInitter.ResetButtonThread = nil
    end

    StarterGui:SetCore("ResetButtonCallback", false)
    CharacterInitter.ResetButtonThread = task.delay(5, function()
        StarterGui:SetCore("ResetButtonCallback", true)
    end)
end

--- Initializes a character's abilities if the table for it is provided.
function CharacterInitter._InitializeCharacterAbilities(Character: Model, Info: Types.Killer | Types.Survivor)
    local CharacterModule = require(Character.CharacterModule)
    CharacterModule.Module = Info

    for _, Ability: Types.Ability in Info.GameplayConfig.Abilities do
        CharacterModule.Abilities[Ability.Name] = Ability
        Ability:Init(Players.LocalPlayer, Info)
    end

    --init le ui
    PlayerAbilitiesUI.Instantiate()
end

--- Loads all animations from a character module onto a character's model.
--- 
--- Also calls `CharacterInitter._SetupStunAnimations()` at the end.
function CharacterInitter._LoadCharacterAnimations(Character: Model, Info: Types.Killer | Types.Survivor)
    local AnimationManager = require(Character:FindFirstChild("AnimationManager"))
    AnimationManager:LoadAnimation("Idle", Info.Config.AnimationIDs.IdleAnimation)
    AnimationManager:LoadAnimation("Walk", Info.Config.AnimationIDs.WalkAnimation)
    AnimationManager:LoadAnimation("Sprint", Info.Config.AnimationIDs.RunAnimation)

    for name: string, animation: string in Info.Config.AnimationIDs do
        if AnimLoadPrevented[name] or name:lower():find("execution") then
            continue
        end

        Info.GameplayConfig.Cache.Animations[name] = AnimationManager:LoadAnimation(name, animation)
    end

    CharacterInitter._SetupStunAnimations(Character, AnimationManager, Info)
end

--- Sets up stun animations to play automatically.
function CharacterInitter._SetupStunAnimations(Character: Model, AnimationManager: any, Info: Types.Killer | Types.Survivor)
    Utils.Instance.ObserveChildren(Character.Effects, function(Effect: Instance)
        if Effect.Name ~= "Stunned" then
            return
        end

        --gets the duration of the stun
        local Duration = Effect:GetAttribute("Duration")

        --gets all animations
        local Stunned = AnimationManager.AnimationTracks.Stunned
        local StunnedLoop = AnimationManager.AnimationTracks.StunnedLoop
        local StunnedEnd = AnimationManager.AnimationTracks.StunnedEnd

        --plays the stun
        if Stunned then
            Stunned:Play(0)
        end

        --if there is a stun loop, play it after the stun animation
        if StunnedLoop then
            if Stunned then
                task.wait(Stunned.Length - 0.1)
            end

            if not StunnedEnd or not StunnedEnd.IsPlaying then
                StunnedLoop:Play(0)
            end
        end

        --if there's an ending animation, play it before the stun ends
        if StunnedEnd then
            task.delay(Duration - StunnedEnd.Length - 0.1, function()
                if StunnedLoop and StunnedLoop.IsPlaying then
                    StunnedLoop:Stop(0)
                end
                StunnedEnd:Play(0)
            end)
            return
        end

        --if the stun loop is there, wait until the end to stop it
        if not StunnedLoop then
            return
        end

        task.delay(Duration, function()
            StunnedLoop:Stop(0)
        end)
    end)
end

return CharacterInitter
