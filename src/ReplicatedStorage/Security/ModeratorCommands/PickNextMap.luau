local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local MapManager = RunService:IsServer() and require(ServerScriptService.Managers.MapManager) or nil

local MapOptions = {}
if RunService:IsServer() then
    for _, map in ServerStorage.Maps:GetChildren() do
        if map:IsA("Folder") or map:IsA("Model") then
            table.insert(MapOptions, map.Name)
        end
    end
    table.sort(MapOptions)
end

return {
    Name = "Pick Next Map",
    Type = "Executable",
    Executable = true,
    Params = {
        {
            Title = "Map Name",
            Default = "...",
            Cache = {
                Options = MapOptions,
            },
        },
    },
    Executed = function(self, MapName)
        if typeof(MapName) ~= "string" then
            return
        end

        local TargetMap = ServerStorage.Maps:FindFirstChild(MapName)
        if not TargetMap then
            return
        end

        -- Override LastMap so GetRandomMap() will pick this one (or set it directly)
        -- We force the next map by temporarily replacing MapPrefabs with just the chosen map
        local OriginalPrefabs = MapManager.MapPrefabs
        MapManager.MapPrefabs = { TargetMap }
        MapManager.CanRepeatMap = true

        -- Restore after one round starts (hook into GetRandomMap result)
        local originalGetRandom = MapManager.GetRandomMap
        MapManager.GetRandomMap = function(...)
            local result = originalGetRandom(...)
            MapManager.MapPrefabs = OriginalPrefabs
            MapManager.GetRandomMap = originalGetRandom
            return result
        end
    end,
}
