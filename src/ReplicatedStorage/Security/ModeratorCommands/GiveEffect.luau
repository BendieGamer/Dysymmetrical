local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local CommonFunctions = RunService:IsServer() and require(ServerScriptService.System.CommonFunctions) or nil

local EffectOptions = {}
for _, effectFolder in ReplicatedStorage.Effects:GetChildren() do
    if effectFolder:IsA("ModuleScript") then
        table.insert(EffectOptions, effectFolder.Name)
    elseif effectFolder:IsA("Folder") then
        for _, sub in effectFolder:GetChildren() do
            if sub:IsA("ModuleScript") then
                table.insert(EffectOptions, sub.Name)
            end
        end
    end
end
table.sort(EffectOptions)

return {
    Name = "Give Effect",
    Type = "Executable",
    Executable = true,
    Params = {
        {
            Title = "Chosen Player",
            Type = "Player",
            Default = "...",
        },
        {
            Title = "Effect Name",
            Default = "Slowness",
            Cache = {
                Options = EffectOptions,
            },
        },
        {
            Title = "Level",
            Type = "String",
            Default = "1",
        },
        {
            Title = "Duration (seconds)",
            Type = "String",
            Default = "10",
        },
    },
    Executed = function(self, Player, EffectName, Level, Duration)
        if typeof(Player) ~= "string" then
            return
        end

        if not table.find(self.Params[2].Cache.Options, EffectName) then
            return
        end

        local LevelNum = tonumber(Level) or 1
        local DurationNum = tonumber(Duration) or 10

        local function applyToChar(char)
            local humanoid = char:FindFirstChildWhichIsA("Humanoid")
            if not humanoid then return end

            local subfolder = nil
            for _, folder in ReplicatedStorage.Effects:GetChildren() do
                if folder:IsA("Folder") and folder:FindFirstChild(EffectName) then
                    subfolder = folder.Name
                    break
                end
            end

            CommonFunctions.ApplyEffect({
                TargetHumanoid = humanoid,
                EffectSettings = {
                    Name = EffectName,
                    Level = LevelNum,
                    Duration = DurationNum,
                    Subfolder = subfolder,
                },
                OverwriteExistingEffect = true,
            })
        end

        if Player:lower() == "all" then
            for _, char in workspace.Players:GetChildren() do
                applyToChar(char)
            end
            return
        end

        local char = workspace.Players:FindFirstChild(Player)
        if char then
            applyToChar(char)
        end
    end,
}
