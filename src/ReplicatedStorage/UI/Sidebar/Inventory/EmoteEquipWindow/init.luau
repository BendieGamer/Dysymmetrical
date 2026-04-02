local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local InventoryUtils = require(script.Parent.InventoryUtils)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Network = require(ReplicatedStorage.Modules.Network)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Signal = require(ReplicatedStorage.Utils.Signal)

local EmoteEquipWindow = {}
EmoteEquipWindow.__index = EmoteEquipWindow

function EmoteEquipWindow.New(Slot: number, Parent: Instance)
    --define all vars
    local self = setmetatable({
        Instance = script.EmoteEquipWindow:Clone(),
        Connections = {},
        Janitor = Janitor.new(),
        Equipped = Signal.new(),
        Removed = Signal.new(),
    }, EmoteEquipWindow)
    self.Instance.Parent = Parent

    --getting all owned emotes for the list
    local EmotesToInstantiate = {}
    for _, Emote in Utils.PlayerData.GetPlayerOwned(Players.LocalPlayer, "Emotes"):GetChildren() do
        table.insert(EmotesToInstantiate, Emote.Name)
    end
    --sorting in alphabetical order
    table.sort(EmotesToInstantiate, function(a: string, b: string): boolean
        return a < b
    end)

    --instantiate all buttons
    for _, Emote in EmotesToInstantiate do
        local EmoteInfo = require(Utils.Instance.GetEmoteModule(Emote))
        local Button = script.EmoteButton:Clone()
        Button.Name = Emote
        Button.Render.Image = EmoteInfo.Config.Render
        Button.NameLabel.Text = EmoteInfo.Config.Name

        --set up for equipping
        InventoryUtils.SetupAudibleButton(Button, self.Janitor, function()
            --EquipEmote returns a bool indicating if it was successful or not
            self.Equipped:Fire(Network:FireServerConnection("EquipEmote", "REMOTE_FUNCTION", Slot, Emote))
            self:Hide()
        end)

        --parent
        Button.Parent = self.Instance.Content
    end

    --setting up buttons
    InventoryUtils.SetupAudibleButton(self.Instance.Cancel, self.Janitor, self.Hide, self)
    InventoryUtils.SetupAudibleButton(self.Instance.Unequip, self.Janitor, function()
        self.Equipped:Fire(Network:FireServerConnection("EquipEmote", "REMOTE_FUNCTION", Slot))
        self:Hide()
    end)
    
    --show it
    self:Show()
    --return da thing
    return self
end

function EmoteEquipWindow:Show()
    TweenService:Create(self.Instance, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.855, 0.962)}):Play()
end

function EmoteEquipWindow:Hide(instant: boolean?)
    if instant == nil then
        instant = false
    end
    --fire the removed signal and disconnect everything from them
    self.Removed:Fire()
    self.Removed:DisconnectAll()
    self.Equipped:DisconnectAll()
    --clean up
    self.Janitor:Destroy()
    --tween if it's not instant
    --if it is, just hide
    if not instant then
        TweenService:Create(self.Instance, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.Zero}):Play()
    else
        self.Instance.Size = Utils.UDim.Zero
    end
    --destroy the instance later
    Utils.Instance.AddToDebris(self.Instance, 0.5)
end

return EmoteEquipWindow
