local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local TimeManager = RunService:IsServer() and require(ServerScriptService.Managers.TimeManager) or nil

local RoundState: StringValue = ReplicatedStorage.RoundInfo.CurrentState

return {
    Name = "Skip Intermission",
    Type = "Executable",
    Executable = true,
    Params = {},
    Executed = function(self)
        if RoundState.Value ~= "Lobby" then
            return
        end

        TimeManager.CanDecreaseTime = false
        TimeManager.SetTime(0)
        TimeManager.OnTimerEnd()
    end,
}
