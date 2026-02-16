local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Classes.Types)
local Network = require(ReplicatedStorage.Modules.Network)
local Sounds = require(ReplicatedStorage.Modules.Sounds)
local PlayerRespawnManager = require(script.Parent.PlayerRespawnManager)
local PlayerSprintManager = require(script.PlayerSprintManager)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

--- Manages character instance filling (e.g. assigning the `Role` attribute or creating the hitboxes) and player rig loading.
local CharacterManager = {}

function CharacterManager:Init()
    Utils.Player.ObservePlayers(function(Player: Player)
        Utils.Character.ObserveCharacter(Player, function(Character: Model)
            require(Character:FindFirstChild("Initter")):Init(Character)
        end)
    end)
end

type CharacterSettings = {
    Name: string,
    Role: "Killer" | "Survivor",
    Skin: string?,
}
function CharacterManager.SpawnAsCharacter(Player: Player, CharacterSettings: CharacterSettings): Model
    local CharacterModule = Utils.Instance.GetCharacterModule(CharacterSettings.Role, CharacterSettings.Name, CharacterSettings.Skin)
    if CharacterModule == nil then
        return PlayerRespawnManager.LoadCharacter(Player)
    end

    CharacterModule = Utils.Type.CopyTable(require(CharacterModule)) :: Types.Killer | Types.Survivor
    CharacterModule.Owner = Player

    local Character = PlayerRespawnManager.LoadCharacter(Player, {
        Role = CharacterSettings.Role,
        Name = CharacterSettings.Name,
        Skin = CharacterSettings.Skin,
        AutoSetPlayerCharacter = false,
    })

    local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
    Humanoid.MaxHealth = CharacterModule.GameplayConfig.Health
    Humanoid.Health = CharacterModule.GameplayConfig.Health
    Humanoid.JumpPower = 0
    Humanoid.JumpHeight = 0

    task.defer(function()
        if not PlayerSprintManager.ManagedPlayers[Player] then
            local Timeout = 0
            repeat
                task.wait()
                Timeout += 1
            until PlayerSprintManager.ManagedPlayers[Player] or Timeout >= 50
            if Timeout >= 50 then
                return
            end
        end

        PlayerSprintManager.ManagedPlayers[Player].SprintMultiplier = CharacterModule.GameplayConfig.SprintSpeedMultiplier
    end)

    Utils.Misc.PreloadAssets(CharacterModule.Config)

    Player.Character = Character

    local CharacterContainer = require(Character.CharacterModule)
    CharacterContainer.Module = CharacterModule

    for name, value in CharacterModule.GameplayConfig.StaminaProperties do
        Character:SetAttribute(name, value)
    end

    for Name: string, Ability: Types.Ability in CharacterModule.GameplayConfig.Abilities do
        Ability:Init(Player, CharacterModule)
        CharacterContainer.Abilities[Name] = Ability
    end

    task.defer(function()
        -- loading all execution animations
        task.defer(function()
            for rootName, _ in CharacterModule.Config.AnimationIDs do
                if not rootName:lower():find("execution") then
                    continue
                end

                module.GameplayConfig.Cache.Animations[rootName] = {}

                for name, anims in CharacterModule.Config.AnimationIDs[rootName] do
                    module.GameplayConfig.Cache.Animations[rootName][name] = {}
                    for animName, anim in anims do
                        if animName:lower() ~= "killer" then
                            continue
                        end

                        module.GameplayConfig.Cache.Animations[rootName][name][animName] = Utils.Character.LoadAnimationFromID(Character, anim)
                    end
                end
            end
        end)

        if not CharacterModule.Config.Voicelines then
            return
        end

        local Primary = Utils.Character.GetRootPart(Character)
        if not Primary then
            return
        end

        local VoicelineJanitor = Janitor.new()
        VoicelineJanitor:LinkToInstance(Character)

        if CharacterModule.Config.Voicelines.Stunned then
            Character.Effects.ChildAdded:Connect(function(newChild)
                if newChild.Name == "Stunned" then
                    Sounds.PlayVoiceline(Character, CharacterModule.Config.Voicelines.Stunned)
                end
            end)
        end

        task.defer(function()
            if not CharacterModule.Config.Voicelines.Idle then
                return
            end

            task.wait(math.random(10, 25))
            while Player.Character and Character and Player.Character == Character and Primary do
                if CharacterModule.Config.Voicelines.Idle then
                    Sounds.PlayVoiceline(Character, CharacterModule.Config.Voicelines.Idle, {
                        Priority = 0,
                    })
                end
                task.wait(math.random(10, 25))
            end
        end)

        if not CharacterModule.Config.Voicelines.LMS then
            return
        end

        VoicelineJanitor:Add(Network:SetConnection("LMSVoiceline", "BINDABLE_EVENT", function(LastMan: Player)
            local Voiceline =
                CharacterModule.Config.Voicelines.LMS[
                    LastMan:GetAttribute("CharacterSkin") and
                        LastMan:GetAttribute("CharacterSkin")..LastMan:GetAttribute("CharacterName") or
                        LastMan:GetAttribute("CharacterName")
                ]
                or CharacterModule.Config.Voicelines.LMS["Default"]
                or CharacterModule.Config.Voicelines.LMS

            Sounds.PlayVoiceline(Character, Voiceline, {
                Priority = 999,
            })
        end))
    end)

    return Character
end

return CharacterManager
