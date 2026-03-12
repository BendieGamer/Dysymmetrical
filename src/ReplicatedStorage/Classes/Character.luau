local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utils = require(ReplicatedStorage.Modules.Utils)
local Types = require(script.Parent.Types)

local Character = {
    AutoLoadedAnims = {
        "Idle",
        "Walk",
        "Run",
        "Stunned",
        "StunnedEnd",
        "Preview",
        "Slash",
        "KillerRig",
        "CameraRig",
        "Execution",
    }
}

--- Survivor preset for customization.
function Character.GetDefaultSurvivorSettings(): Types.Survivor
    return {
        Owner = nil,
        Config = {
            Name = "Survivor",
            Description = {
                {
                    Type = "Text",
                    Text = "PLACEHOLDER",
                },
            },
            Quote = "hello",

            Price = 0,
            Render = "",

            AnimationIDs = {
                IdleAnimation = "rbxassetid://128254839975087",
                WalkAnimation = "rbxassetid://95139037304316",
                RunAnimation = "rbxassetid://84289923509689",
            },

            AnimationTransitionTime = 0.3,

            Voicelines = {},

            Sounds = {},
        },

        GameplayConfig = {
            Health = 100,
            BaseSpeed = 10.5,
            SprintSpeedMultiplier = 26 / 10.5,
            StaminaProperties = {
                MaxStamina = 100,
                StaminaDrain = 10,
                StaminaGain = 20,
            },

            Abilities = {},
            Cache = {
                Animations = {},
            },
        },
    }
end

--- Killer preset for customization.
function Character.GetDefaultKillerSettings(): Types.Killer
    return {
        Owner = nil,
        Config = {
            Name = "Killer",
            Description = {
                {
                    Type = "Text",
                    Text = "PLACEHOLDER",
                },
            },
            Quote = "hello",

            Price = 0,
            Render = "",

            LastManStandingTheme = "rbxassetid://125799740823318",
            SpecialLastManStandings = {},

            AnimationIDs = {
                IdleAnimation = "rbxassetid://138818467051890",
                WalkAnimation = "rbxassetid://96779101755387",
                RunAnimation = "rbxassetid://139221510401164",
            },

            AnimationTransitionTime = 0.3,

            Voicelines = {},

            ChaseThemes = {
                L1 = "rbxassetid://101608255438688",
                L2 = "rbxassetid://122380833390973",
                L3 = "rbxassetid://78435073515542",
                L4 = "rbxassetid://100400124559989",
            },

            Sounds = {},
        },

        GameplayConfig = {
            Health = 1200,
            BaseSpeed = 10.5,
            SprintSpeedMultiplier = 26 / 10.5,
            StaminaProperties = {
                MaxStamina = 110,
                StaminaDrain = 10.5,
                StaminaGain = 21,
            },

            Abilities = {},
            Cache = {
                Animations = {},
            },
        },
    }
end

type New = (
    ((Type: "Killer", CharacterName: string, Props: Types.Killer) -> Types.Killer) &
    ((Type: "Survivor", CharacterName: string, Props: Types.Survivor) -> Types.Survivor)
)
--[=[
    Creates a character / skin with the settings specified in `Props`.

    This function, if put in a local variable, SHOULD have type checking to specify if you want a killer or a survivor for proper autocompletion.

    With this I mean like so:

    ```lua
    local KillerExample: Types.Killer = Character.New("Killer", {...})
    ```

    **Quick note: not every property has to be there, every crucial property has a default value as a fallback.**
    
    You may also create skins by defining `RootCharacterName` as a 3rd parameter.

    This way, if it's defined, it'll treat this as a skin and, if it isn't, as a unique character.

    ```lua
    local SkinExample: Types.Killer = Character.New("Killer", {...}, "NullexVoyd")
    ```
]=]
function Character.New(Type: Types.Role, Props: Types.Killer | Types.Survivor, RootCharacterName: string?): Types.Killer | Types.Survivor
    --prevent errors from not defining Props
    Props = Props or {}
    --try to get the func based off of the given role
    local Func = Character[`GetDefault{Type}Settings`]
    --if the role doesn't have its own func, halt
    --TODO: unify default settings as well
    if not Func then
        return
    end

    --check if it's supposed to be a skin and, if it is, try to get the root character module
    local Final
    if RootCharacterName ~= nil then
        Final = Utils.Instance.GetCharacterModule(Type, RootCharacterName)
    end
    
    --if there's an available module to base a skin off of, use it; if not, just get the default settings
    Final = Final ~= nil and Utils.Type.CopyTable(require(Final)) or Func()

    --apply Props to whatever properties we already have in Final
    Utils.Type.DeepTableOverwrite(Final, Props)

    --return the damn thing
    return Final
end
Character.New = Character.New :: New

--- **DEPRECATED:** Use `Character.New()` instead.
@deprecated
function Character.CreateKiller(Props: Types.Killer): Types.Killer
    return Character.New("Killer", Props)
end

--- **DEPRECATED:** Use `Character.New()` instead.
@deprecated
function Character.CreateSurvivor(Props: Types.Survivor): Types.Survivor
    return Character.New("Survivor", Props)
end

--- **DEPRECATED:** Use `Character.New()` instead.
@deprecated
function Character.CreateSkin(Type: Types.Role, CharacterName: string, Props: Types.Survivor | Types.Killer): Types.Survivor | Types.Killer
    return Character.New(Type, Props, CharacterName)
end

return Character
