local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utils = require(ReplicatedStorage.Modules.Utils)

return if RunService:IsServer() then {} else require(Utils.Instance.AwaitChild(Players.LocalPlayer.PlayerScripts, "UIManager"))