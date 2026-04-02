local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Classes.Types)
local Network = require(ReplicatedStorage.Modules.Network)
local Sounds = require(ReplicatedStorage.Modules.Sounds)
local PlayerRespawnManager = require(script.Parent.PlayerRespawnManager)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

--- Manages character instance filling (e.g. assigning the `Role` attribute or creating the hurtboxes) and player rig loading.
local CharacterManager = {}

function CharacterManager:Init()
    Utils.Player.ObservePlayers(function(Player: Player)
        Utils.Character.ObserveCharacter(Player, function(Character: Model)
            require(Character:FindFirstChild("Initter")):Init(Character)
        end)
    end)
end

--- Character spawn parameters for `CharacterManager.SpawnAsCharacter()`.
type CharacterSettings = {
    --- The name of the character to spawn as.
    Name: string,
    --- The role of the character to spawn as (usually `"Killer"` or `"Survivor"`).
    Role: Types.Role,
    --- The skin of the character to spawn as. If blank / `nil` / not found, it'll fall back to the character's default.
    Skin: string?,
    --- If specified, the resultant character will be pivoted to this CFrame.
    TargetCFrame: CFrame?,
}
--- Spawns a player as a specific character.
--- 
--- This includes the character model and all of its abilities, voicelines, etc.
function CharacterManager.SpawnAsCharacter(Player: Player, CharacterSettings: CharacterSettings): Model
    --tries to get the character's module and falls back to loading normally if it doesn't exist
    local CharacterModule = Utils.Instance.GetCharacterModule(CharacterSettings.Role, CharacterSettings.Name, CharacterSettings.Skin)
    if CharacterModule == nil then
        return PlayerRespawnManager.LoadCharacter(Player)
    end

    --makes a new copy of the character's module for usage and gives it to the player
    CharacterModule = Utils.Type.CopyTable(require(CharacterModule)) :: Types.Killer | Types.Survivor
    CharacterModule.Owner = Player

    --actually respawns the player as the character's model but prevents automatically setting it to set up everything before `Player.CharacterAdded` fires
    local Character = PlayerRespawnManager.LoadCharacter(Player, {
        Role = CharacterSettings.Role,
        Name = CharacterSettings.Name,
        Skin = CharacterSettings.Skin,
        AutoSetPlayerCharacter = false,
        TargetCFrame = CharacterSettings.TargetCFrame,
    })

    --sets the humanoid's properties
    local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
    Humanoid.MaxHealth = CharacterModule.GameplayConfig.Health
    Humanoid.Health = CharacterModule.GameplayConfig.Health
    Humanoid.JumpPower = 0
    Humanoid.JumpHeight = 0

    --preload all sounds and animations
    Utils.Misc.PreloadAssets(CharacterModule.Config)

    --finally set the player's character
    Player.Character = Character

    --sets the character's module in its own module for easier access outside
    local CharacterContainer = require(Character.CharacterModule)
    CharacterContainer.Module = CharacterModule

    --sets all stamina attributes
    for name, value in CharacterModule.GameplayConfig.StaminaProperties do
        Character:SetAttribute(name, value)
    end

    --inits all abilities and adds them to the character's module
    for Name: string, Ability: Types.Ability in CharacterModule.GameplayConfig.Abilities do
        Ability:Init(Player, CharacterModule)
        CharacterContainer.Abilities[Name] = Ability
    end

    --misc
    task.defer(function()
        --loading all execution animations
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

        --the rest is voiceline stuff
        if not CharacterModule.Config.Voicelines then
            return
        end

        --get the root part to play voicelines in
        local Primary = Utils.Character.GetRootPart(Character)
        if not Primary then
            return
        end

        --create le janitor for voicelines
        local VoicelineJanitor = Janitor.new()
        VoicelineJanitor:LinkToInstance(Character)

        --when the character gets the Stunned effect, play the voiceline
        if CharacterModule.Config.Voicelines.Stunned then
            Character.Effects.ChildAdded:Connect(function(newChild)
                if newChild.Name ~= "Stunned" then
                    return
                end

                Sounds.PlayVoiceline(Character, CharacterModule.Config.Voicelines.Stunned)
            end)
        end

        --idle voiceline loop
        task.defer(function()
            if not CharacterModule.Config.Voicelines.Idle then
                return
            end

            --create the loop while the character exists
            while Player.Character and Character and Player.Character == Character and Primary and task.wait(math.random(10, 25)) do
                if CharacterModule.Config.Voicelines.Idle then
                    Sounds.PlayVoiceline(Character, CharacterModule.Config.Voicelines.Idle, {
                        Priority = 0,
                    })
                end
            end
        end)

        --remaining is lms so just make a sanity check directly
        if not CharacterModule.Config.Voicelines.LMS then
            return
        end

        --lms voiceline is played through a bindable event on the server
        VoicelineJanitor:Add(Network:SetConnection("LMS", "BINDABLE_EVENT", function(LastMan: Player)
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

    if CharacterModule.OnServerInit then
        CharacterModule:OnServerInit(Character)
	end

    return Character
end

--- Loads a player's equipped character.
--- 
--- Also includes skins if they're equipped.
function CharacterManager.LoadEquippedCharacter(Player: Player, Role: Types.Role, TargetCFrame: CFrame?): Model
    --get the equipped values
    local EquippedCharacter = Utils.PlayerData.GetPlayerEquipped(Player, Role)
    local EquippedSkin = Utils.PlayerData.GetPlayerEquipped(Player, `Skins.{EquippedCharacter}`)

    --return the result character
    return CharacterManager.SpawnAsCharacter(Player, {
        Name = EquippedCharacter,
        Role = Role,
        Skin = EquippedSkin,
        TargetCFrame = TargetCFrame,
    })
end

return CharacterManager
