local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CardRenderer = require(script.CardRenderer)
local DataHandler = require(script.DataHandler)
local Sidebar = require(script.Parent)
local UIManager = require(script.Parent.Parent)
local ShopUtils = require(script.ShopUtils)

local Utils = require(ReplicatedStorage.Modules.Utils)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local Shop = {
    Opened = false,
    Enabled = true,
    IsSkinMenuOpen = false,
    InfoMenu = {
        Open = false,
        Target = "",
    },
    LoadedItems = {
        Killers = {},
        Survivors = {},
        Emotes = {},
        Skins = {},
    },
    CurSelected = {
        Name = "",
        Type = "",
        -- Card = nil,
    },
    SelectedSection = "Survivors",
    -- BuyWindow = nil,

    -- UI = nil,

    LoadedEmoteTracks = {},

    PreviewsEnabled = true,
}

function Shop:Init()
    local UI = script.ShopUI:Clone()
    UI.Visible = false
    UI.Parent = UIManager.FetchScreenGui("Menus")

    self.UISize = UI.Size
    UI.Size = Utils.UDim.Zero

    local JanitorInstance = Janitor.new()
    JanitorInstance:LinkToInstance(UI)

    for _, SectionButton in UI.ShopContainer.Topbar:GetChildren() do
        if not (SectionButton:IsA("ImageButton") and SectionButton.Visible) then
            continue
        end

        ShopUtils.SetupAudibleButton(SectionButton, JanitorInstance, self._SwitchSection, self, SectionButton.Name)
    end

    ShopUtils.SetupAudibleButton(UI.SideContainer.ButtonsContainer.Purchase, JanitorInstance, function()
        if Utils.PlayerData.GetPlayerOwned(Players.LocalPlayer, `{self.CurSelected.Type}s.{self.CurSelected.Name}`) then
            return
        end

        local Module = self.CurSelected.Type == "Emote" and
                        Utils.Instance.GetEmoteModule(self.CurSelected.Name) or
                        Utils.Instance.GetCharacterModule(self.CurSelected.Type, self.CurSelected.Name)
        
        ShopUtils.CreateBuyWindow(self, Module, self.CurSelected.Card)
    end)

    Utils.Instance.ObserveProperty(UI, "Size", function(Size: UDim2)
        UI.Visible = Size ~= Utils.UDim.Zero
    end)
    
    Utils.Instance.ObserveProperty(UI.SkinsContainer, "Size", function(value: UDim2)
        UI.SkinsContainer.Label.TextLabel.Visible = value.X.Scale >= 0.05
    end)

    Utils.Instance.ObserveProperty(UI.InfoContainer, "Size", function(Size: UDim2)
        if self.InfoMenu.Open or Size.X.Scale >= 0.05 or #UI.InfoContainer:GetChildren() <= 0 then
            return
        end

        local Children = UI.InfoContainer:GetChildren()

        if #Children <= 0 then
            return
        end

        for _, Child in Children do
            if Child:IsA("UIComponent") then
                continue
            end

            Child:Destroy()
        end
    end)

    self.UI = UI

    self:_ReloadContent(true)
end

function Shop:_SwitchSection(SectionName: string)
    if not self.Opened or self.SelectedSection == SectionName then
        return
    end

    TweenService:Create(self.UI.SideContainer, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0, 1)}):Play()

    do
        local EmotePreviewSFX = workspace.TempObjectFolders.Sounds:FindFirstChild("EmotePreview")
        if EmotePreviewSFX then
            EmotePreviewSFX:Destroy()
        end
    end

    for _, Section in self.UI.ShopContainer.Content:GetChildren() do
        if not Section:IsA("ScrollingFrame") then
            continue
        end

        Section.Visible = Section.Name == SectionName
    end

    self.SelectedSection = SectionName
end

function Shop:_ReloadPurchaseButton()
    local Label = "Purchase"
    if Utils.PlayerData.GetPlayerOwned(Players.LocalPlayer, self.CurSelected.Type.."s."..Shop.CurSelected.Name) then
        Label = `{Label}d`
    end

    self.UI.SideContainer.ButtonsContainer.Purchase.Title.Text = Label
end

function Shop:_ReloadContent(CreateCards: boolean?)
    if CreateCards == nil then
        CreateCards = false
    end

    local CanMakePreviews = self.PreviewsEnabled and Utils.PlayerData.GetPlayerSetting(Players.LocalPlayer, "Performance.SkinPreviews")

    for _, Type in {
        "Emote",
        "Killer",
        "Survivor",
    } do
        local Items = DataHandler.GetSortedItems(Type)

        for _, Section in ipairs({
            "Owned",
            "Unowned",
        }) do
            for LayoutOrder, Module in ipairs(Items[Section]) do
                CardRenderer.SetupItemCard(self, Module, Type, CreateCards, LayoutOrder, CanMakePreviews)
            end
        end
    end
end

function Shop:Open(TweenDuration: number)
    if not self.Enabled or not Players.LocalPlayer.Character or Players.LocalPlayer.Character:GetAttribute("Role") ~= "Spectator" or not Sidebar.Enabled then
        return 0
    end

    -- self.ToggleSkinsMenu(false)
    -- self.ToggleInfoMenu(false)

    local PreviewInstances = self.UI.SideContainer.PreviewContainer
    PreviewInstances.Render.Image = ""
    PreviewInstances.Render.ImageTransparency = 0
    PreviewInstances.Emote.Visible = false

    self.UI.SideContainer.ButtonsContainer.Skins.Visible = false
    self.UI.SideContainer.ButtonsContainer.MoreInfo.Visible = false
    
    for _, Track in self.LoadedEmoteTracks do
        if Track.Animation ~= nil then
            Track.Animation:Stop(0)
            continue
        end

        for _, SubTrack in Track do
            SubTrack.Animation:Stop(0)
        end
    end

    do
        local ExistingEmotePreview = workspace.TempObjectFolders.Sounds:FindFirstChild("EmotePreview")
        if ExistingEmotePreview then
            ExistingEmotePreview:Destroy()
        end
    end

    self.UI.SkinsContainer.Size = Utils.UDim.FullY
    self.UI.InfoContainer.Size = Utils.UDim.FullY
    self.UI.SideContainer.Size = Utils.UDim.FullY
    self.UI.ShopContainer.Size = UDim2.fromScale(0.7, 1)
    self.IsSkinMenuOpen = false

    TweenService:Create(self.UI, TweenInfo.new(TweenDuration, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
        Size = Utils.UDim.Full20Offset,
    }):Play()
    self.Opened = true

    return
end

function Shop:Close(TweenDuration: number)
    if self.BuyWindow then
        self.BuyWindow:Hide(TweenDuration <= 0)
    end

    do
        local ExistingEmotePreview = workspace.TempObjectFolders.Sounds:FindFirstChild("EmotePreview")
        if ExistingEmotePreview then
            ExistingEmotePreview:Destroy()
        end
    end

    if TweenDuration > 0 then
        TweenService:Create(self.UI, TweenInfo.new(TweenDuration, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
            Size = Utils.UDim.Zero,
        }):Play()
    else
        self.UI.Size = Utils.UDim.Zero
    end

    self.Opened = false
end

function Shop:Toggle(Toggle: boolean)
    if not self.Enabled and Toggle then
        self:Init()
    end

    if not Toggle and self.Enabled then
        if self.BuyWindow then
            self.BuyWindow:Hide(true)
        end

        do
            local ExistingEmotePreview = workspace.TempObjectFolders.Sounds:FindFirstChild("EmotePreview")
            if ExistingEmotePreview then
                ExistingEmotePreview:Destroy()
            end
        end

        self.LoadedItems = {
            Killers = {},
            Survivors = {},
            Emotes = {},
            Skins = {},
        }
        self.CurSelected = {
            Name = "",
            Type = "",
            Card = nil,
        }
        self.SelectedSection = "Survivors"
        self.UI:Destroy()
        self.IsSkinMenuOpen = false
    end

    Shop.Enabled = Toggle
end

function Shop:OnCharButtonPress(Module: ModuleScript, Type: "Emote" | "Survivor" | "Killer", Card: Frame)
    if not self.Opened then
        return
    end

    do
        local ExistingEmotePreview = workspace.TempObjectFolders.Sounds:FindFirstChild("EmotePreview")
        if ExistingEmotePreview then
            ExistingEmotePreview:Destroy()
        end
    end
    
    for _, Track in self.LoadedEmoteTracks do
        if Track.Animation ~= nil then
            Track.Animation:Stop(0)
            continue
        end

        for _, SubTrack in Track do
            SubTrack.Animation:Stop(0)
        end
    end

    local Info = require(Module)

    local PreviewInstances = self.UI.SideContainer.PreviewContainer
    PreviewInstances.Render.Image = Info.Config.Render
    PreviewInstances.Title.Text = Info.Config.Name

    self.CurSelected.Name = Module.Name
    self.CurSelected.Type = Type
    self.CurSelected.Card = Card

    self.UI.SideContainer.ButtonsContainer.CurrentItemPrice.Text = `{Info.Config.Price}$`

    self:_ReloadPurchaseButton()

    TweenService:Create(self.UI.SideContainer, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(0.3, 1),
    }):Play()

    if Type == "Emote" then
        CardRenderer.SetupEmoteRig(self, Module, Card)
        return
    end

    self.UI.SideContainer.PreviewContainer.Emote.Visible = false
    self.UI.SideContainer.PreviewContainer.Render.ImageTransparency = 0
    self.UI.SideContainer.ButtonsContainer.MoreInfo.Visible = true
    self.UI.SideContainer.ButtonsContainer.Skins.Visible = true
end

return Shop
