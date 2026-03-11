local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Utils = require(ReplicatedStorage.Modules.Utils)
local Types = require(script.Parent.Types)

local Effect = {}

function Effect.GetDefaultSettings(): Types.Effect
    return {
        Name = "Effect",
        Description = "Does something",
        Duration = 1,
        Level = 1,

        TimeLeft = 1,
        ShowInGUI = true,
    }
end

function Effect.New(Props: Types.Effect): Types.Effect
    Props = Props or {}
    local Final = Effect.GetDefaultSettings()

    return Utils.Type.DeepTableOverwrite(Final, Props)
end

return Effect
