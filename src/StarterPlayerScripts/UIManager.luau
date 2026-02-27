local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TypeUtils = require(ReplicatedStorage.Modules.Utils.TypeUtils)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

type GuiItem = {
    Name: string,
    Enabled: boolean?,
    IgnoreGuiInset: boolean?,
    ResetOnSpawn: boolean?,
    DisplayOrder: number?,
    Callback: ((Gui: ScreenGui) -> ())?,
}

local UIManager = {
    ManagedScreenGuis = {},
}
UIManager.DefaultGuiInfo = {
    {
        Name = "TemporaryUI",
        IgnoreGuiInset = true,
    },
    {
        Name = "EmotePanel",
        ResetOnSpawn = false,
    },
    {
        Name = "Time",
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
    },
    {
        Name = "PlayerVitals",
    },
    {
        Name = "Effects",
    },
    {
        Name = "RoundPlayerList",
        ResetOnSpawn = false,
    },
    {
        Name = "CharacterGUI",
    },
    {
        Name = "VideoPlayer",
        ResetOnSpawn = false,
    },
    {
        Name = "PlayerList",
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
    },
    {
        Name = "Menus",
        ResetOnSpawn = false,
    },
    {
        Name = "Sidebar",
        ResetOnSpawn = false,
    },
    {
        Name = "KillerIntros",
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
    },
    {
        Name = "MoneyXPRewards",
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
    },
    {
        Name = "RewardNotifications",
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
    },
    {
        Name = "AFKLabel",
        Enabled = false,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        Callback = function(ScreenGui: ScreenGui)
            local AFK = Instance.new("TextLabel")

            AFK.AnchorPoint = Vector2.new(0.5, 1)

            AFK.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            AFK.BackgroundTransparency = 1

            AFK.Position = UDim2.fromScale(0.5, 1)
            AFK.Size = UDim2.fromScale(0.5, 0.13)

            AFK.Text = "AFK mode is on. You won't be put in new matches while it's on. It can be turned off from the top of the settings menu."

            AFK.TextColor3 = Color3.fromRGB(255, 255, 255)
            AFK.TextTransparency = 0.6

            AFK.TextScaled = true
            AFK.TextWrapped = true

            AFK.Font = Enum.Font.Fantasy

            AFK.Parent = ScreenGui
        end,
    },
} :: {GuiItem}

function UIManager:Init()
    --disables default roblox ui
    do
        local StarterGui = game:GetService("StarterGui")

        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    end

    --creates all screenguis that aren't there yet with their own display order correspondingly
    for DisplayOrder, Gui in UIManager.DefaultGuiInfo do
        if UIManager.ManagedScreenGuis[Gui.Name] ~= nil then
            continue
        end

        Gui.DisplayOrder = DisplayOrder

        UIManager.ManagedScreenGuis[Gui.Name] = UIManager.CreateScreenGui(Gui)
    end

    --initializing all UI modules from here to keep it tidy
    for _, Module in ReplicatedStorage.UI:GetDescendants() do
        if not Module:IsA("ModuleScript") then
            continue
        end

        local Code = require(Module)
        if typeof(Code) == "table" and Code.Init and typeof(Code.Init) == "function" then
            Code:Init()
        end
    end

    --i know that if the modules are initialized here they don't have to use FetchScreenGui anymore because every ScreenGui would be there when initting
    --but i could not give less of a shit because i'm lazy to change it back and it's readable this way
    --2.0 is making me insane
    --   -dys
end

--- Directly creates a `ScreenGui` instance.
--- 
--- If it already exists, the existent one is returned.
--- 
--- Similar to `UIManager.FetchScreenGui` but takes `GuiItem` as a parameter, letting you create a `ScreenGui` from scratch with custom properties already set.
function UIManager.CreateScreenGui(Info: GuiItem): ScreenGui
    local ScreenGui = UIManager.ManagedScreenGuis[Info.Name]
    if ScreenGui then
        return ScreenGui
    end

    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = Info.Name
    if Info.Enabled ~= nil then
        ScreenGui.Enabled = Info.Enabled
    end
    if Info.IgnoreGuiInset ~= nil then
        ScreenGui.IgnoreGuiInset = Info.IgnoreGuiInset
    end
    if Info.ResetOnSpawn ~= nil then
        ScreenGui.ResetOnSpawn = Info.ResetOnSpawn
    end
    if ScreenGui.ResetOnSpawn then
        --why am I doing this instead of `ScreenGui:ClearAllChildren()`

        --because it's been proven that just redoing the ScreenGui is more performant than clearing its children
        --because it doesn't have to reparent every single child individually

        --cool sauce i love reading random stuff like this in devforum out of nowhere
        local JanitorInstance = Janitor.new()
        JanitorInstance:LinkToInstance(ScreenGui)

        JanitorInstance:Add(Players.LocalPlayer.CharacterAdded:Connect(function(_Character: Model)
            ScreenGui:Destroy()
            --reset so that `UIManager.CreateScreenGui()` doesn't return `nil`
            UIManager.ManagedScreenGuis[Info.Name] = nil
            UIManager.ManagedScreenGuis[Info.Name] = UIManager.CreateScreenGui(Info)
        end))
    end
    --ALWAYS false, or else it'll screw up the whole thing (i think)
    ScreenGui.ResetOnSpawn = false
    -- override -> order in default table -> default to last in default table
    ScreenGui.DisplayOrder = Info.DisplayOrder or table.find(UIManager.DefaultGuiInfo, Info) or TypeUtils.GetCountOfDict(UIManager.ManagedScreenGuis)
    ScreenGui.Parent = Players.LocalPlayer.PlayerGui
    if Info.Callback then
        Info.Callback(ScreenGui)
    end

    return ScreenGui
end

--- Will try to get an existing `ScreenGui` and, if it doesn't exist, it creates it with default values.
--- 
--- `UIManager.CreateScreenGui()` still does the same sanity check to return an existing `ScreenGui` with the same name,
--- but this function describes better what you're doing, so for readability it's a lot better to sue this one if you're trying to get an existing `ScreenGui`.
function UIManager.FetchScreenGui(Name: string): ScreenGui
    local Result = UIManager.ManagedScreenGuis[Name]
    if Result then
        return Result
    end

    return UIManager.CreateScreenGUI(UIManager._GetDefaultInfoByName(Name) or {Name = Name})
end

function UIManager._GetDefaultInfoByName(Name: string): GuiItem
    for _, Info: GuiItem in UIManager.DefaultGuiInfo do
        if Info.Name == Name then
            return Info
        end
    end

    return
end

return UIManager
