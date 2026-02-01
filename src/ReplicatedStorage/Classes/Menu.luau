local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Utils = require(ReplicatedStorage.Modules.Utils)
local Sidebar = require(ReplicatedStorage.UI.Sidebar)

local Menu = {}

local MetaMenu = {}
MetaMenu.__index = MetaMenu

type MenuCallbacks = {
    OnInit: (self: Menu) -> (),
    OnOpen: (self: Menu) -> (),
    OnClose: (self: Menu) -> (),
    OnToggle: (self: Menu) -> (),
}
type Menu = {
    Enabled: boolean,
    Opened: boolean,
    UI: GuiObject,
    UiPrefab: GuiObject,
    Callbacks: MenuCallbacks,
}

function Menu.New(UiPrefab: GuiObject, Callbacks: MenuCallbacks?)
    return setmetatable({
        Enabled = true,
        Opened = false,
        UiPrefab = UiPrefab,
        Callbacks = Callbacks or {},
    }, MetaMenu)
end

function MetaMenu:Init()
    if self.UI then
        self.UI.Parent = require(Players.LocalPlayer.PlayerScripts.UIManager).FetchScreenGui("Menus")
        self.UI.Size = Utils.UDim.Zero
        self.UI.Visible = false
        return
    end

    local UI = self.UiPrefab
    UI.Size = Utils.UDim.Zero
    UI.Visible = false
    UI.Parent = require(Players.LocalPlayer.PlayerScripts.UIManager).FetchScreenGui("Menus")
    self.UI = UI

    Utils.Instance.ObserveProperty(UI, "Size", function(value: UDim2)
        UI.Visible = value ~= Utils.UDim.Zero
    end)

    if self.Callbacks.OnInit then
        self.Callbacks.OnInit(self)
    end
end

function MetaMenu:Open(Time: number): any?
    if not self.Enabled or not Players.LocalPlayer.Character or Players.LocalPlayer.Character:GetAttribute("Role") ~= "Spectator" or not Sidebar.Enabled then
        return 0
    end

    TweenService:Create(self.UI, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.Full20Offset}):Play()
    self.Opened = true

    if self.Callbacks.OnOpen then
        self.Callbacks.OnOpen(self)
    end

    return
end

function MetaMenu:Close(Time: number)
    if Time > 0 then
        TweenService:Create(self.UI, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.Zero}):Play()
    else
        self.UI.Size = Utils.UDim.Zero
    end

    self.Opened = false

    if self.Callbacks.OnClose then
        self.Callbacks.OnClose(self)
    end
end

function MetaMenu:Toggle(toggle: boolean)
    if not self.Enabled and toggle then
        self:Init()
    end

    if not toggle and self.Enabled then
        self.UI.Parent = script
        self.UI.Size = Utils.UDim.Zero
    end

    self.Enabled = toggle

    if self.Callbacks.OnToggle then
        self.Callbacks.OnToggle(self)
    end
end

return Menu
