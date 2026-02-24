local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utils = require(ReplicatedStorage.Modules.Utils)

local Backpedaling = {}

function Backpedaling:Init()
    local Character = Players.LocalPlayer.Character
    local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
    local Root = Utils.Character.GetRootPart(Character)

    local SpeedManager = require(script.Parent)

    --initially set a speed factor
    SpeedManager:AddFactor("Backpedaling", 1)

    --check when the move direction for the humanoid changes
    Utils.Instance.ObserveProperty(Humanoid, "MoveDirection", function(value: Vector3)
        --compare the direction relative to the hrp's rotation and, if it's backwards, make the factor lower
        --if it's not backwards, leave it in 1 to nullify the backpedaling speed factor
        SpeedManager.Factors["Backpedaling"] = Root.CFrame:VectorToObjectSpace(value).Z > 0.1 and 0.75 or 1
    end)
end

return Backpedaling
