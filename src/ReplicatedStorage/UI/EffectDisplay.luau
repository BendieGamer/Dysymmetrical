local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)
local EffectDisplay = {}

function EffectDisplay:Init()
    -- local Prefab = script.StatusContainer

    Utils.Character.ObserveCharacter(Players.LocalPlayer, function(Character: Model, CharacterJanitor: Types.Janitor)
        --NOTE: remove this sanity check if you want lol
        if Character:GetAttribute("Role") == "Spectator" then
            return
        end

        -- self:_SetupUI(Character, Prefab:Clone(), CharacterJanitor)
    end)
end

function EffectDisplay:_SetupUI(Character: Model, UI: Frame, JanitorInstance: Types.Janitor)
    
end

return EffectDisplay
