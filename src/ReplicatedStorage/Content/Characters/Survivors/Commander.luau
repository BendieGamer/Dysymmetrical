local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Character = require(ReplicatedStorage.Classes.Character)
local Ability = require(ReplicatedStorage.Classes.Ability)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)

local ServerBehaviour = RunService:IsServer() and require(game:GetService("ServerScriptService").Content.CharacterBehaviour.Survivors.Commander) or {}

local function JusticeExtraInit(self: Types.Ability)
    self.JusticeModel = Utils.Instance.AwaitChild(self.OwnerProperties.Character, "Deagle")
end

local Commander: Types.Survivor = Character.New("Survivor", {
    Config = {
        Name = "Commander",
        Quote = "*pyro noises*",
        Render = "rbxassetid://108440668883002",

        Origin = {
            TooltipText = "Originates from Project Terminus!",
            Icon = "rbxasset://textures/ui/GuiImagePlaceholder.png",
        },
    },

    GameplayConfig = {
        Abilities = {
            BodyArmor = Ability.New({
                Name = "Body Armor",
                -- Description = "Every time Commander gets damaged, he receives Resistance V for 1 second, acting as invincibility frames.",
                Passive = true,
            }),

            Blindside = Ability.New({
                Name = "Blindside",

                ThrowDelay = 1,
                TriggerDelay = 3.5,
                FlashTime = 3.5,
                FlashRadius = 6,
                ThrowForce = 60,

                -- Description = "Commander picks up a flashbang grenade and throws it after 3.5 seconds, triggering it after 3.5 seconds and flashing the killer for 3.5 seconds if they're in a 6 stud radius.",

                Cooldown = 30,
                InputName = "FirstAbility",
                Duration = 2,

                ServerBehaviour = ServerBehaviour.BlindsideBehaviour,
            }),

            Reload = Ability.New({
                Name = "Reload",
                Duration = 5,
                Cooldown = 40,
                InputName = "SecondAbility",
                SlownessLevel = 3,
                -- Description = "Commander reloads his gun. He takes 5 seconds to do so and gets Slowness III while reloading.",
                ServerBehaviour = ServerBehaviour.ReloadBehaviour,
            }),

            Justice = Ability.New({
                Name = "Justice",
                Description = "Commander pulls out a gun and shoots forward while in low speed. Does 50 damage to the killer and stuns them for 4.2 seconds.",
                UseAnimation = "",
                ShotSound = "",
                Cooldown = 45,
                InputName = "ThirdAbility",
                Duration = 1/22 * 3,
                HitboxLength = 45,
                Damage = 50,
                StunTime = 4.2,

                UseSettings = {
                    InitialUses = 0,
                    Limited = true,
                },

                ExtraInit = JusticeExtraInit,

                ServerBehaviour = ServerBehaviour.JusticeBehaviour,
            }),
        },
    },

    OnHit = ServerBehaviour.OnHit,
})

Commander.Config.Description = {
    {
        Type = "Separator",
        Text = "GENERAL INFO",
    },
    {
        Type = "Header",
        Text = Commander.Config.Name:upper(),
    },
    {
        Type = "Quote",
        Text = "\""..Commander.Config.Quote.."\""
    },
    {
        Type = "Text",
        Text = "Initially a simple soldier that managed to turn the military upside-down with his leadership. "
            .."After some altercations in a company he got hired in as a guard against anomalies, he managed to survive a fatal accident and become one of the peak soldiers in the army. "
            .."He's been intensely trained for years and has experience with handguns and flash grenades, using them as efficiently as possible and purchasing the tools with most quality.",
    },
    {
        Type = "Header",
        Text = "STATS",
    },
    {
        Type = "Text",
        Text = {
            "Difficulty: ★★★☆☆",
            -- "Difficulty: 6 7",
            "Health: "..tostring(Commander.GameplayConfig.Health),
            "Base Speed: "..tostring(Commander.GameplayConfig.BaseSpeed),
            "Sprint Speed: "..tostring(math.round(Commander.GameplayConfig.BaseSpeed * Commander.GameplayConfig.SprintSpeedMultiplier * 10) / 10),
            "Max Stamina: "..tostring(Commander.GameplayConfig.StaminaProperties.MaxStamina),
            "Stamina Loss per second: "..tostring(Commander.GameplayConfig.StaminaProperties.StaminaDrain),
            "Stamina Gain per second: "..tostring(Commander.GameplayConfig.StaminaProperties.StaminaGain),
        },
    },
    {
        Type = "Separator",
        Text = "PASSIVES",
    },
    {
        Type = "Header",
        Text = Commander.GameplayConfig.Abilities.BodyArmor.Name:upper(),
    },
    {
        Type = "Quote",
        Text = "\"Diamond armor, full set!\" -Minecraft Steve",
    },
    {
        Type = "Text",
        Text = "Every time Commander gets hit, he gets <b>Resistance V</b> for 1 second, acting as invincibility frames.",
        Image = "http://www.roblox.com/asset/?id=113412520",
    },
    {
        Type = "Separator",
        Text = "ABILITIES",
    },
    {
        Type = "Header",
        Text = Commander.GameplayConfig.Abilities.Blindside.Name:upper(),
    },
    {
        Type = "Text",
        Text = "Commander picks up a flashbang grenade and throws it after "..tostring(Commander.GameplayConfig.Abilities.Blindside.ThrowDelay)..
            " seconds, triggering it after "..tostring(Commander.GameplayConfig.Abilities.Blindside.TriggerDelay)..
            " seconds and inflicting the killer <b>Blindness</b> for "..tostring(Commander.GameplayConfig.Abilities.Blindside.FlashTime)..
            " seconds if they're in a "..tostring(Commander.GameplayConfig.Abilities.Blindside.FlashRadius)..
            " stud radius.",
    },
    {
        Type = "Header",
        Text = Commander.GameplayConfig.Abilities.Reload.Name:upper(),
    },
    {
        Type = "Text",
        Text = "Commander reloads his gun, getting <b>Slowness "..Utils.Math.IntToRoman(Commander.GameplayConfig.Abilities.Reload.SlownessLevel)..
            "</b> for "..tostring(Commander.GameplayConfig.Abilities.Reload.Duration).." seconds.",
    },
    {
        Type = "Header",
        Text = Commander.GameplayConfig.Abilities.Justice.Name:upper(),
    },
    {
        Type = "Text",
        Text = {
            "Commander shoots forward "
            ..tostring(Commander.GameplayConfig.Abilities.Justice.HitboxLength).." studs. If it hits the killer, they get stunned for "
            ..tostring(Commander.GameplayConfig.Abilities.Justice.StunTime).." seconds and receive "
            ..tostring(Commander.GameplayConfig.Abilities.Justice.Damage).." damage.",
            "This ability's charge is obtained through <b>Reload</b>."
        },
    },
}

return Commander
