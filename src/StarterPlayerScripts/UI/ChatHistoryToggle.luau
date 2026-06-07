local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local Utils = require(ReplicatedStorage.Modules.Utils)

repeat
	local success = pcall(function()
		StarterGui:SetCore("ResetButtonCallback", false)
	end)
	task.wait()
until success --this means that it has initialized

return {
    Init = function(_)
        Utils.Character.ObserveCharacter(Players.LocalPlayer, function(Char: Model)
            local Role = Char:FindFirstChild("Role") or Char:WaitForChild("Role", 5)
            local IsSpectator = not Role or Role.Value == "Spectator"
            TextChatService:FindFirstChildWhichIsA("ChatWindowConfiguration").Enabled = IsSpectator
            StarterGui:SetCore("ResetButtonCallback", IsSpectator)
        end)
    end,
}