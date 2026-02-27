local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Lighting = require(ReplicatedStorage.Modules.Lighting)
local Sounds = require(ReplicatedStorage.Modules.Sounds)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local MapManager = {
    --- If `false`, no maps can show up twice in a row.
    RepeatedMaps = false,
    -- CurrentMap = nil,
    -- LastMap = nil,
    -- Prefabs = nil,
}

local Rand = Random.new()

function MapManager:Init()
    MapManager.Prefabs = ServerStorage.Assets.Maps:GetChildren()

    --check for every map to see if it's a wrong type
    for Index = #MapManager.Prefabs, 1, -1 do
        local Map = MapManager.Prefabs[Index]

        if not Map:IsA("Folder") and not Map:IsA("Model") then
            table.remove(MapManager.Prefabs, Index)
        end
    end
end

--- Instantiates and initializes a random map from the pool based on `MapManager.RepeatedMaps` and parents it to `workspace`.
function MapManager.InstantiateMap(): Model | Folder
    local SelectedMap = MapManager._GetMap()
    MapManager.LastMap = SelectedMap

    SelectedMap = SelectedMap:Clone()
    SelectedMap.Name = "Map"
    MapManager.CurrentMap = SelectedMap

    --check for mandatory folders that aren't there
    if not SelectedMap:FindFirstChild("InGame") then
        local InGame = Instance.new("Folder")
        InGame.Name = "InGame"
        InGame.Parent = SelectedMap
    end
    
    if not SelectedMap:FindFirstChild("Items") then
        local Items = Instance.new("Folder")
        Items.Name = "Items"
        Items.Parent = SelectedMap
    end

    if not SelectedMap:FindFirstChild("PermAbilities") then
        local PermAbilities = Instance.new("Folder")
        PermAbilities.Name = "PermAbilities"
        PermAbilities.Parent = SelectedMap
    end

    local Map = SelectedMap:FindFirstChild("Map")

    --TODO: item spawning

    --spawning was odd in 1.0 and now it's easier
    local SpawnPoints = Map:FindFirstChild("SpawnPoints")
    local AvailableLayouts = SpawnPoints:GetChildren()
    if #AvailableLayouts > 1 then
        local Chosen = AvailableLayouts[Rand:NextInteger(1, #AvailableLayouts)]
        for _, Layout in AvailableLayouts do
            if Layout == Chosen then
                continue
            end

            Layout:Destroy()
        end
    end

    --config currently only has ambience themes, so do that
    local Config = Map:FindFirstChild("Config")
    if Config and Config:IsA("ModuleScript") then
        Config = require(Config)
        if Config.Ambience then
            local Props = Config.AmbienceProperties or {}
            Props.Priority = Props.Priority or 0.5
            Props.Name = "MapAmbience"
            Sounds.PlayTheme(Config.Ambience, Props)
        end
    end

    --cleanups are cool
    local MapJanitor = Janitor.new()
    MapJanitor:LinkToInstance(SelectedMap)
    MapJanitor:Add(function()
        Sounds.StopTheme("MapAmbience")
    end, true)

    --lighting
    do
        local LightingConfig = SelectedMap:FindFirstChild("Lighting")
        if LightingConfig then
            Lighting.SetCustomLighting(LightingConfig)
        end
    end

    --behaviour
    do
        local Behaviour = SelectedMap:FindFirstChild("Behaviour")
        if Behaviour and Behaviour:IsA("ModuleScript") then
            Behaviour = require(Behaviour)
            if Behaviour.Init and typeof(Behaviour.Init) == "function" then
                Behaviour:Init(MapJanitor)
            end
        end
    end

    --reparent finally
    SelectedMap.Parent = workspace
    
    return SelectedMap
end

--- Destroys the manager's current map if it exists.
function MapManager.DestroyCurrentMap()
    if not MapManager.CurrentMap then
        return
    end

    --destroy le thing
    MapManager.CurrentMap:Destroy()
    MapManager.CurrentMap = nil
    --reset lighting
    Lighting.SetDefaultLighting()
end

--- Gets a random map prefab from the pool based on `MapManager.RepeatedMaps`.
function MapManager._GetMap(): Model | Folder
    --if maps can be repeated, just do nothing
    if MapManager.RepeatedMaps or #MapManager.Prefabs < 2 then
        return MapManager._GetRandomMap()
    end

    --get a rand map
    local SelectedMap = MapManager._GetRandomMap()
    --if it's the same as the last one, keep getting a random map until it's different
    while SelectedMap == MapManager.LastMap do
        SelectedMap = MapManager._GetRandomMap()
    end
    --return da thing
    return SelectedMap
end

--- Gets a random map prefab from the pool.
--- 
--- It differs with `MapManager._GetMap()` in that it doesn't take `MapManager.RepeatedMaps` into account.
function MapManager._GetRandomMap(): Model | Folder
    --self explanatory
    return MapManager.Prefabs[Rand:NextInteger(1, #MapManager.Prefabs)]
end

return MapManager
