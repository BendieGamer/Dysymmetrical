local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Achievements = require(ReplicatedStorage.Content.Achievements)
local Network = require(ReplicatedStorage.Modules.Network)
local InstanceUtils = require(script.Parent.InstanceUtils)
local TypeUtils = require(script.Parent.TypeUtils)

local PlayerDataUtils = {}

--- Yields code execution until a `Player`'s PlayerData is correctly loaded.
--- 
--- Won't yield if it's already loaded.
function PlayerDataUtils.AwaitSaveLoad(Player: Player)
    --check if it's already loaded, and halt if so
    if Player:GetAttribute("SaveLoaded") == true then
        return
    end

    --wait for the attribute to change
    Player:GetAttributeChangedSignal("SaveLoaded"):Wait()

    --just in case it wasn't assigned before, thus it's false, wait until it's true
    while Player:GetAttribute("SaveLoaded") ~= true do
        task.wait(0.1)
    end
end

--- Retrieves a player's equipped item of a type through a string path.
--- Also works for emotes.
--- If `value` is false, it'll return the `StringValue` object instead of the value itself.
function PlayerDataUtils.GetPlayerEquipped(Player: Player, path: string, value: boolean?): StringValue | string
    if value == nil then
        value = true
    end

    PlayerDataUtils.AwaitSaveLoad(Player)

    local splitPath = TypeUtils.SplitStringPath(path)
    local Equipped = PlayerDataUtils.GetSpecificObject(Player, "Equipped")
    if #splitPath == 1 then
        local Child = Equipped:FindFirstChild(splitPath[1])
        return value and Child.Value or Child
    else
        local Child = Equipped
        for _, step in splitPath do
            if not Child then
                warn("[Utils:GetPlayerEquipped()] Child \""..step.."\" not found! Returning nil!")
                -- actually returning nil but preventing selene from crying
                return Child
            end

            if Child.Name == "Skins" then
                Child = Child:FindFirstChild(step)

                if not Child then
                    if RunService:IsServer() then
                        Child = PlayerDataUtils.CreateMissingSkinValue(Player, step)
                    else
                        Child = Network:FireServerConnection("CreateMissingSkinValue", "REMOTE_FUNCTION", step)
                    end
                end

                continue
            end
            
            Child = Child:FindFirstChild(step)
        end
        return value and Child.Value or Child
    end
end

--- Retrieves a player's purchased item of a type through a string path.
--- 
--- Also works for emotes.
--- 
--- If `value` is false, it'll return the `StringValue` object instead of the value itself.
function PlayerDataUtils.GetPlayerOwned(Player: Player, path: string, value: boolean?): StringValue | string
    if value == nil then
        value = true
    end

    PlayerDataUtils.AwaitSaveLoad(Player)

    local Child = PlayerDataUtils.GetSpecificObject(Player, `Purchased.{path}`)
    return value and (Child and Child.Value or false) or Child
end

--- Retrieves a player's stat through a string path.
--- 
--- If `value` is false, it'll return the `ValueBase` object instead of the value itself to modify it or to get a property from it (e.g. attributes).
function PlayerDataUtils.GetPlayerStat(Player: Player, path: string, value: boolean?): ValueBase | any
    if value == nil then
        value = true
    end

    PlayerDataUtils.AwaitSaveLoad(Player)

    local Stat = PlayerDataUtils.GetSpecificObject(Player, `Stats.{path}`)
    return value and Stat.Value or Stat
end

--- Retrieves a player's setting value through a string path.
function PlayerDataUtils.GetPlayerSetting(Player: Player, path: string): any
    PlayerDataUtils.AwaitSaveLoad(Player)

    local splitPath = TypeUtils.SplitStringPath(path)
    local PlayerSettings = InstanceUtils.FindFirstChild(Player, "PlayerData.Settings")
    if #splitPath == 1 then
        return PlayerSettings:FindFirstChild(splitPath[1]).Value
    else
        local Setting = PlayerSettings
        for _, step in splitPath do
            if not Setting then
                warn("[Utils:GetPlayerSetting()] Child \""..step.."\" not found! Returning nil!")
                return
            end
            Setting = Setting:FindFirstChild(step)
        end
        return Setting.Value
    end
end

--- INTERNAL | SERVER FUNCTION: Used to create a character's equipped skin value for a player if it's missing.
function PlayerDataUtils.CreateMissingSkinValue(SourcePlayer: Player, name: string): StringValue
    PlayerDataUtils.AwaitSaveLoad(SourcePlayer)

    if not RunService:IsServer() then
        return InstanceUtils.FindFirstChild(SourcePlayer, "PlayerData.Equipped.Skins."..name) :: StringValue | any
    end

    local EquippedSkins = InstanceUtils.FindFirstChild(SourcePlayer, "PlayerData.Equipped.Skins")
    local SkinValue = EquippedSkins:FindFirstChild(name)
    if SkinValue then
        return SkinValue
    end

    SkinValue = Instance.new("StringValue")
    SkinValue.Name = name
    SkinValue.Value = ""
    SkinValue.Parent = EquippedSkins

    return SkinValue
end

--- INTERNAL | SERVER FUNCTION: Used to create a character's purchased skins folder for a player if it's missing.
function PlayerDataUtils.CreateMissingPurchasedSkinValue(SourcePlayer: Player, name: string): Folder
    PlayerDataUtils.AwaitSaveLoad(SourcePlayer)

    if not RunService:IsServer() then
        return InstanceUtils.FindFirstChild(SourcePlayer, "PlayerData.Purchased.Skins."..name) :: Folder | any
    end

    local PurchasedSkins = InstanceUtils.FindFirstChild(SourcePlayer, "PlayerData.Purchased.Skins")
    local SkinFolder = InstanceUtils.FindFirstChild(PurchasedSkins, name)
    if SkinFolder then
        return SkinFolder
    end

    SkinFolder = Instance.new("Folder")
    SkinFolder.Name = name
    SkinFolder.Parent = PurchasedSkins

    return SkinFolder
end

--- Retrieves an achievement's `ValueBase` from a player.
function PlayerDataUtils.GetAchievementObject(SourcePlayer: Player, path: string): NumberValue | BoolValue
    PlayerDataUtils.AwaitSaveLoad(SourcePlayer)

    local AchievementFolder = PlayerDataUtils.GetSpecificObject(SourcePlayer, "Achievements")
    local AchievementObject = InstanceUtils.FindFirstChild(AchievementFolder, path)
    
    if not AchievementObject then
        local steps = TypeUtils.SplitStringPath(path)
        local Achievement = Achievements[steps[1]].Achievements[steps[2]]
        if not Achievement then
            return nil :: any
        end

        if Achievement.Requirement then
            AchievementObject = Instance.new("NumberValue")
            AchievementObject.Value = 0
        else
            AchievementObject = Instance.new("BoolValue")
            AchievementObject = false
        end
        AchievementObject.Name = steps[2]
        AchievementObject.Parent = AchievementFolder:FindFirstChild(steps[1])
    end

    return AchievementObject
end

--- Similar to `Utils.Instance.AwaitChild()` but only for a player's `PlayerData` folder.
--- 
--- This method is mainly used for readability.
function PlayerDataUtils.GetSpecificObject(Player: Player, Path: string): ValueBase
    --wait for the save to load
    PlayerDataUtils.AwaitSaveLoad(Player)
    --get the data folder
    local PlayerData = Player:FindFirstChild("PlayerData")
    --find the object inside
    return InstanceUtils.FindFirstChild(PlayerData, Path)
end

return PlayerDataUtils
