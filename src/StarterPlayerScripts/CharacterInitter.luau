local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utils = require(ReplicatedStorage.Modules.Utils)

local AnimLoadPrevented = {
    "IdleAnimation",
    "WalkAnimation",
    "RunAnimation",
    "Execution",
}

local CharacterInitter = {}

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
end

return CharacterInitter
