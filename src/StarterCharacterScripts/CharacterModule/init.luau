local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Classes.Types)

return {
    Module = nil :: Types.Killer | Types.Survivor | any, --this will eventually be the character's actual module containing info and stuff
    Abilities = {} :: {[string]: Types.Ability}, --this is a shortcut to `Character.GameplayConfig.Abilities` in the current character
}
