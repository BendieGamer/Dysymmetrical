local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Utils = require(ReplicatedStorage.Modules.Utils)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local SlowOnFall = {}

function SlowOnFall:Init()
    local Character = Players.LocalPlayer.Character
    if Character:GetAttribute("Role") == "Killer" then
        return
    end
    
    local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
    local Root = Utils.Character.GetRootPart(Character)

    local thread

    local SpeedManager = require(script.Parent)

    local JanitorInstance = Janitor.new()
    JanitorInstance:LinkToInstance(Character)

    JanitorInstance:Add(Humanoid.StateChanged:Connect(function(_old: Enum.HumanoidStateType, new: Enum.HumanoidStateType)
        if new ~= Enum.HumanoidStateType.Landed then
            return
        end

        --don't apply another slow on fall if there is already one happening (will try to rework this in the future)
        if thread then
            return
        end
        
        --getting fall speed
        local Vel = math.abs(Root.AssemblyLinearVelocity.Y)
        --crazy calculations
        local Mult = 40 / Vel / 1.5
        local Recovery = Vel / 40 * 0.25
        --add the speed factor
        SpeedManager:AddFactor("FallSlowness", Mult)
        --thread thing
        thread = task.defer(function()
            local elapsed = 0
            local alpha = 0
            --tweening the value to 1
            repeat
                alpha = math.clamp(elapsed / Recovery, 0, 1)
                SpeedManager.Factors.FallSlowness = math.lerp(Mult, 1, TweenService:GetValue(alpha, Enum.EasingStyle.Circular, Enum.EasingDirection.In))
                elapsed += task.wait()
            until alpha == 1 or not Humanoid or not SpeedManager.Factors.FallSlowness
            --remove the factor
            SpeedManager:RemoveFactor("FallSlowness")
        end)
    end))
end

return SlowOnFall
