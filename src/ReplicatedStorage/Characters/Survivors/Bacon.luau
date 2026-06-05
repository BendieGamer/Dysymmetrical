local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Types = require(ReplicatedStorage.Classes.Types)

local Character = require(ReplicatedStorage.Classes.Character)
local Ability = require(ReplicatedStorage.Classes.Ability)
local Hitbox = require(ReplicatedStorage.Classes.Hitbox)
local RoundManager = RunService:IsServer() and require(game:GetService("ServerScriptService").Managers.RoundManager) or nil
local Utils = require(ReplicatedStorage.Modules.Utils)

local function FlashlightBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    task.spawn(function()
        Hitbox.New(self.Owner, {
            CFrameOffset = CFrame.new(),
            Size = Vector3.new(self.FlashRadius * 2, self.FlashRadius * 2, self.FlashRadius * 2),
            Time = 0.25,
            Shape = Enum.PartType.Ball,
            Damage = 0,
            EffectsToApply = {
                {
                    Name = "Blindness",
                    Duration = self.BlindDuration,
                    Level = 1,
                },
            },
        })
    end)
end

local function KillerSightBehaviour(self: Types.Ability)
    if not RunService:IsServer() then
        return
    end

    local baconPlayer = self.Owner
    for _, killerData in ipairs(RoundManager.CurrentRound.Killers or {}) do
        if killerData.Player and killerData.Player ~= baconPlayer then
            Utils.Player.RevealPlayerAuraTo(baconPlayer, killerData.Player, self.HighlightDuration)
        end
    end
end

local Bacon: Types.Survivor = Character.CreateSurvivor({
    Config = {
        Name = "Bacon Hair",
        Quote = "Im a bacon",
        Render = "rbxassetid://90863791545676",
    },

    GameplayConfig = {
        Abilities = {
            Flashlight = Ability.New({
                Name = "Flashlight",
                InputName = "FirstAbility",
                Cooldown = 20,
                Duration = 0.25,
                FlashRadius = 12,
                BlindDuration = 3,
                Behaviour = FlashlightBehaviour,
            }),

            KillerSight = Ability.New({
                Name = "Killer Highlight",
                Description = "Reveal the killer to Bacon with a glowing aura.",
                InputName = "SecondAbility",
                Cooldown = 60,
                Duration = 0.25,
                HighlightDuration = 10,
                Behaviour = KillerSightBehaviour,
            }),
        }
    }
})
Bacon.Config.Description = {
    {
        Type = "Separator",
        Text = "GENERAL INFO",
    },
    {
        Type = "Header",
        Text =  Bacon.Config.Name:upper(),
    },
    {
        Type = "Quote",
        Text = "\""..Bacon.Config.Quote.."\""
    },
}
return Bacon