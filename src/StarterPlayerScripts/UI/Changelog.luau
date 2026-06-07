local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SideBar = require(script.Parent.SideBar)
local Utils = require(ReplicatedStorage.Modules.Utils)

local LocalPlayer = Players.LocalPlayer

local Changelog = {
    Enabled = true,
    UIInstance = nil,
    Opened = false,
}

--- The format to follow in `CurrentChangelog`'s 
type ChangelogFormat = {
    --- The version of the place containing the update.
    --- Can be found by printing `game.PlaceVersion`.
    PlaceVersion: number,
    --- The text that'll be shown in the menu's title.
    MenuTitle: string,
    --- The title of the update for the beginning of the changelog.
    UpdateTitle: string,
    --- The ID of the update's thumbnail's image.
    --- May also be a banner if you modify the UI yourself.
    UpdateThumbnailID: string,
    --- The date of the update.
    --- Can be anything, but preferably the date.
    --- Will show under the thumbnail.
    UpdateDate: string,
    --- The entries of the changelog.
    Entries: {{
        Type: "Separator" | "SectionEntry" | "Text",
        Text: string,
    }},
}
local CurrentChangelog: ChangelogFormat = {
    PlaceVersion = 0,
    MenuTitle = "Changelog",
    UpdateTitle = "BIT UPDATE",
    UpdateThumbnailID = "rbxasset://textures/ui/GuiImagePlaceholder.png",
    UpdateDate = "06/07/2026",
    Entries = {
        {
            Type = "Separator",
            Text = "NEW CHARACTER",
        },
        {
            Type = "SectionEntry",
            Text = "Added BIT_09 as a new Killer character.",
        },
        {
            Type = "Separator",
            Text = "BIT_09 — ABILITIES",
        },
        {
            Type = "SectionEntry",
            Text = "Swing — Quick melee attack dealing 10–15 damage.",
        },
        {
            Type = "SectionEntry",
            Text = "Charge — Dash in movement direction, dealing 20 damage on hit. Missing slows BIT briefly.",
        },
        {
            Type = "SectionEntry",
            Text = "BIT Summon — Spawns a clone that chases survivors. Touching a survivor deals 15 damage, applies Glitched (10s) and Slowness (5s), then the clone is destroyed. Up to 3 active clones. Click a highlighted clone to teleport to it and trigger a domain explosion.",
        },
        {
            Type = "SectionEntry",
            Text = "Digital EYE — Reveals every survivor's aura for 10 seconds.",
        },
        {
            Type = "SectionEntry",
            Text = "STATE EDIT — Inflicts a random debuff (Blindness, Disoriented, Helpless, or Slowness) on a random survivor for 10 seconds.",
        },
        {
            Type = "Separator",
            Text = "BIT_09 — PASSIVE",
        },
        {
            Type = "SectionEntry",
            Text = "Corruption Cascade — Killing a survivor inverts the nearest remaining survivor's controls for 10 seconds.",
        },
        {
            Type = "Separator",
            Text = "NEW EFFECT",
        },
        {
            Type = "SectionEntry",
            Text = "Glitched — Deals 2 damage per second for the effect's duration and corrupts the screen with a cyan/magenta flicker.",
        },
        {
            Type = "Separator",
            Text = "BUG FIXES",
        },
        {
            Type = "SectionEntry",
            Text = "Fixed AntiFly false positives kicking players on elevated map spawn platforms.",
        },
        {
            Type = "SectionEntry",
            Text = "Fixed EXP grant crash when rewarding players (wrong key name in internal call).",
        },
    },
}

local PrefabFolder = Utils.Instance.FindFirstChild(script, "Prefabs")
local Prefabs = {
    Separator = Utils.Instance.FindFirstChild(PrefabFolder, "Separator"),
    SectionEntry = Utils.Instance.FindFirstChild(PrefabFolder, "SectionEntry"),
    Text = Utils.Instance.FindFirstChild(PrefabFolder, "PlainText"),
}

local UIParent = Utils.Instance.FindFirstChild(LocalPlayer.PlayerGui, "Menus")
function Changelog:Init()
    if Changelog.UIInstance then
        Changelog.UIInstance.Parent = UIParent
        Changelog.UIInstance.Size = Utils.UDim.Zero
        Changelog.UIInstance.Visible = false
        return
    end

    local UI = Utils.Instance.FindFirstChild(script, "Changelog")
    UI.Size = Utils.UDim.Zero
    UI.Visible = false
    Changelog.UIInstance = UI
    UI.Parent = UIParent

    local Content = UI.Content
    local Top = Content.Top
    Top.Title.Text = CurrentChangelog.UpdateTitle
    Top.Thumbnail.Image = CurrentChangelog.UpdateThumbnailID
    Top.Date.Text = CurrentChangelog.UpdateDate

    UI.Label.TextLabel.Text = CurrentChangelog.MenuTitle

    Utils.Instance.ObserveProperty(Changelog.UIInstance, "Size", function(value: UDim2)
        Changelog.UIInstance.Visible = value ~= Utils.UDim.Zero
    end)

    for order, entry in CurrentChangelog.Entries do
        local Inst = Prefabs[entry.Type]:Clone()
        Inst.Title.Text = entry.Text
        Inst.Title.TextSize = 12
        Inst.LayoutOrder = order
        Inst.Parent = Content
    end

    local Log = Utils.Instance.FindFirstChild(LocalPlayer, "PlayerData.Misc.LastSeenLog")
    if Log.Value < CurrentChangelog.PlaceVersion and Log.Value < ReplicatedStorage.PlaceVersion.Value and CurrentChangelog.PlaceVersion <= ReplicatedStorage.PlaceVersion.Value then
        SideBar.OpenMenu(Changelog)
    end
end

function Changelog.Open(Time: number)
    if not Changelog.Enabled or not LocalPlayer.Character.Role or LocalPlayer.Character.Role.Value ~= "Spectator" or not SideBar.Enabled then
        return "Prevented"
    end

    if Time > 0 then
        TweenService:Create(Changelog.UIInstance, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.4, 0.7)}):Play()
    else
        Changelog.UIInstance.Size = UDim2.fromScale(0.4, 0.7)
    end
    Changelog.Opened = true

    return
end

function Changelog.Close(Time: number)
    if Time > 0 then
        TweenService:Create(Changelog.UIInstance, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.Zero}):Play()
    else
        Changelog.UIInstance.Size = Utils.UDim.Zero
    end
    Changelog.Opened = false
end

function Changelog.Toggle(toggle: boolean)
    if not Changelog.Enabled and toggle then
        Changelog:Init()
    end
    if not toggle and Changelog.Enabled then
        Changelog.UIInstance.Parent = script
        Changelog.UIInstance.Size = Utils.UDim.Zero
    end
    Changelog.Enabled = toggle
end

return Changelog
