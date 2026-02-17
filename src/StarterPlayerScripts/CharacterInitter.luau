local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)

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
        --set attributes n shit

        if Character:GetAttribute("Role") ~= "Spectator" then
            CharacterInitter._InitializeGameCharacter(Character)
        end

        require(Character:FindFirstChild("Initter")):Init(Character)
    end)
end

function CharacterInitter._InitializeGameCharacter(Character: Model)
    if not Character:GetAttribute("CharacterName") then
        return
    end

    CharacterInitter._ResetButtonCycle()

    local Info: Types.Killer | Types.Survivor = Utils.Type.CopyTable(require(Utils.Instance.GetCharacterModule(Character:GetAttribute("Role"), Character:GetAttribute("CharacterName"), Character:GetAttribute("CharacterSkin"))))
    Info.Owner = Players.LocalPlayer

    Utils.Misc.PreloadAssets(Info.Config)

    task.defer(CharacterInitter._LoadCharacterAnimations, Character, Info)

    Character:SetAttribute("AnimationTransitionTime", Info.Config.AnimationTransitionTime)

    CharacterInitter._InitializeCharacterAbilities(Character, Info)

    if Info.OnInit then
        Info:OnInit(Character)
    end
end

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

function CharacterInitter._InitializeCharacterAbilities(Character: Model, Info: Types.Killer | Types.Survivor)
    local CharacterModule = require(Character.CharacterModule)
    CharacterModule.Module = Info

    for _, Ability: Types.Ability in Info.GameplayConfig.Abilities do
        CharacterModule.Abilities[Ability.Name] = Ability
        Ability:Init(Players.LocalPlayer, Info)
    end
end

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

function CharacterInitter._SetupStunAnimations(Character: Model, AnimationManager: any, Info: Types.Killer | Types.Survivor)
    Utils.Instance.ObserveChildren(Character.Effects, function(Effect: Instance)
        if Effect.Name ~= "Stunned" then
            return
        end

        local Duration = Effect:GetAttribute("Duration")

        local Stunned = AnimationManager.AnimationTracks.Stunned
        local StunnedLoop = AnimationManager.AnimationTracks.StunnedLoop
        local StunnedEnd = AnimationManager.AnimationTracks.StunnedEnd

        if Stunned then
            Stunned:Play(0)
        end

        if StunnedLoop then
            if Stunned then
                task.wait(Stunned.Length - 0.1)
            end

            if not StunnedEnd or not StunnedEnd.IsPlaying then
                StunnedLoop:Play(0)
            end
        end

        if StunnedEnd then
            task.delay(Duration - StunnedEnd.Length - 0.1, function()
                if StunnedLoop and StunnedLoop.IsPlaying then
                    StunnedLoop:Stop(0)
                end
                StunnedEnd:Play(0)
            end)
            return
        end

        if not StunnedLoop then
            return
        end

        task.delay(Duration, function()
            StunnedLoop:Stop(0)
        end)
    end)
end

return CharacterInitter
