local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local EffectDisplay = {}

function EffectDisplay:Init()
    local Prefab = script.StatusContainer

    Utils.Character.ObserveCharacter(Players.LocalPlayer, function(Character: Model)
        --NOTE: remove this sanity check if you want lol
        if Character:GetAttribute("Role") == "Spectator" then
            return
        end

        self:_SetupUI(Character, Prefab:Clone())
    end)
end

function EffectDisplay:_SetupUI(Character: Model, UI: Frame)
    local JanitorInstance: Types.Effect = Janitor.new()
    JanitorInstance:LinkToInstances(Character, UI)

    UI.Parent = require(script.Parent).FetchScreenGui("Effects")

    local EffectManager = require(Character.PlayerAttributeScripts.EffectManager)
    
    local ManagedEffects: {[string]: Frame} = {}
    JanitorInstance:Add(RunService.PreRender:Connect(function(_delta: number)
        local Effects: {[string]: Types.Effect} = EffectManager.Effects
	
	    for name: string, effect: Types.Effect in Effects do
	    	if not effect.ShowInGUI then continue end
	    	local Display = ManagedEffects[name]
	    	if not Display then
	    		Display = script.EffectObject:Clone()
	    		Display.Name = name
	    		Display.Title.Text = effect.Name
                if effect.Level > 1 then
                    local RomanLevel = Utils.Math.IntToRoman(effect.Level)
                    Display.Title.Text = Display.Title.Text.." "..RomanLevel
                end
                ManagedEffects[name] = Display
	    		Display.Parent = UI
	    	end
	    	Display.Timer.Text = Utils.Math.ConvertToMinSec(effect.TimeLeft + 1)
	    end
    
	    for name, display in ManagedEffects do
	    	if display:IsA("Frame") and not Effects[display.Name] then
	    		display:Destroy()
                ManagedEffects[name] = nil
	    	end
	    end
    end))
end

return EffectDisplay
