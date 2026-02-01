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

    Shop.UISize = UI.Size
    UI.Size = Utils.UDim.Zero

    local JanitorInstance = Janitor.new()
    JanitorInstance:LinkToInstance(UI)

    for _, SectionButton in UI.ShopContainer.Topbar:GetChildren() do
        if not (SectionButton:IsA("ImageButton") and SectionButton.Visible) then
            continue
        end

        ShopUtils.SetupAudibleButton(SectionButton, JanitorInstance, Shop._SwitchSection, SectionButton.Name)
    end

    ShopUtils.SetupAudibleButton(UI.SideContainer.ButtonsContainer.Purchase, JanitorInstance, function()
        if Utils.PlayerData.GetPlayerOwned(Players.LocalPlayer, `{Shop.CurSelected.Type}s.{Shop.CurSelected.Name}`) then
            return
        end

        local Module = Shop.CurSelected.Type == "Emote" and
                        Utils.Instance.GetEmoteModule(Shop.CurSelected.Name) or
                        Utils.Instance.GetCharacterModule(Shop.CurSelected.Type, Shop.CurSelected.Name)
        
        ShopUtils.CreateBuyWindow(Shop, Module, Shop.CurSelected.Card)
    end)

    Utils.Instance.ObserveProperty(UI, "Size", function(Size: UDim2)
        UI.Visible = Size ~= Utils.UDim.Zero
    end)
    
    Utils.Instance.ObserveProperty(UI.SkinsContainer, "Size", function(value: UDim2)
        UI.SkinsContainer.Label.TextLabel.Visible = value.X.Scale >= 0.05
    end)

    Utils.Instance.ObserveProperty(UI.InfoContainer, "Size", function(Size: UDim2)
        if Shop.InfoMenu.Open or Size.X.Scale >= 0.05 or #UI.InfoContainer:GetChildren() <= 0 then
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

    Shop.UI = UI

    Shop._ReloadContent(true)
end

function Shop._SwitchSection(SectionName: string)
    if not Shop.Opened or Shop.SelectedSection == SectionName then
        return
    end

    TweenService:Create(Shop.UI.SideContainer, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0, 1)}):Play()

    do
        local EmotePreviewSFX = workspace.TempObjectFolders.Sounds:FindFirstChild("EmotePreview")
        if EmotePreviewSFX then
            EmotePreviewSFX:Destroy()
        end
    end

    for _, Section in Shop.UI.ShopContainer.Content:GetChildren() do
        if not Section:IsA("ScrollingFrame") then
            continue
        end

        Section.Visible = Section.Name == SectionName
    end

    Shop.SelectedSection = SectionName
end

function Shop._ReloadPurchaseButton()
    local Label = "Purchase"
    if Utils.PlayerData.GetPlayerOwned(Players.LocalPlayer, Shop.CurSelected.Type.."s."..Shop.CurSelected.Name) then
        Label = `{Label}d`
    end

    Shop.UI.SideContainer.ButtonsContainer.Purchase.Title.Text = Label
end

function Shop._ReloadContent(CreateCards: boolean?)
    if CreateCards == nil then
        CreateCards = false
    end

    local CanMakePreviews = Shop.PreviewsEnabled and Utils.PlayerData.GetPlayerSetting(Players.LocalPlayer, "Performance.SkinPreviews")

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
                CardRenderer.SetupItemCard(Shop, Module, Type, CreateCards, LayoutOrder, CanMakePreviews)
            end
        end
    end
end

function Shop:Open(TweenDuration: number)
    if not Shop.Enabled or not Players.LocalPlayer.Character or Players.LocalPlayer.Character:GetAttribute("Role") ~= "Spectator" or not Sidebar.Enabled then
        return 0
    end

    -- Shop.ToggleSkinsMenu(false)
    -- Shop.ToggleInfoMenu(false)

    local PreviewInstances = Shop.UI.SideContainer.PreviewContainer
    PreviewInstances.Render.Image = ""
    PreviewInstances.Render.ImageTransparency = 0
    PreviewInstances.Emote.Visible = false

    Shop.UI.SideContainer.ButtonsContainer.Skins.Visible = false
    Shop.UI.SideContainer.ButtonsContainer.MoreInfo.Visible = false
    
    for _, Track in Shop.LoadedEmoteTracks do
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

    Shop.UI.SkinsContainer.Size = Utils.UDim.FullY
    Shop.UI.InfoContainer.Size = Utils.UDim.FullY
    Shop.UI.SideContainer.Size = Utils.UDim.FullY
    Shop.UI.ShopContainer.Size = UDim2.fromScale(0.7, 1)
    Shop.IsSkinMenuOpen = false

    TweenService:Create(Shop.UI, TweenInfo.new(TweenDuration, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
        Size = Utils.UDim.Full20Offset,
    }):Play()
    Shop.Opened = true

    return
end

function Shop:Close(TweenDuration: number)
    if Shop.BuyWindow then
        Shop.BuyWindow:Hide(TweenDuration <= 0)
    end

    do
        local ExistingEmotePreview = workspace.TempObjectFolders.Sounds:FindFirstChild("EmotePreview")
        if ExistingEmotePreview then
            ExistingEmotePreview:Destroy()
        end
    end

    if TweenDuration > 0 then
        TweenService:Create(Shop.UI, TweenInfo.new(TweenDuration, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
            Size = Utils.UDim.Zero,
        }):Play()
    else
        Shop.UI.Size = Utils.UDim.Zero
    end

    Shop.Opened = false
end

function Shop:Toggle(Toggle: boolean)
    if not Shop.Enabled and Toggle then
        Shop:Init()
    end

    if not Toggle and Shop.Enabled then
        if Shop.BuyWindow then
            Shop.BuyWindow:Hide(true)
        end

        do
            local ExistingEmotePreview = workspace.TempObjectFolders.Sounds:FindFirstChild("EmotePreview")
            if ExistingEmotePreview then
                ExistingEmotePreview:Destroy()
            end
        end

        Shop.LoadedItems = {
            Killers = {},
            Survivors = {},
            Emotes = {},
            Skins = {},
        }
        Shop.CurSelected = {
            Name = "",
            Type = "",
            Card = nil,
        }
        Shop.SelectedSection = "Survivors"
        Shop.UI:Destroy()
        Shop.IsSkinMenuOpen = false
    end

    Shop.Enabled = Toggle
end

function Shop.OnCharButtonPress(Module: ModuleScript, Type: "Emote" | "Survivor" | "Killer", Card: Frame)
    if not Shop.Opened then
        return
    end

    do
        local ExistingEmotePreview = workspace.TempObjectFolders.Sounds:FindFirstChild("EmotePreview")
        if ExistingEmotePreview then
            ExistingEmotePreview:Destroy()
        end
    end
    
    for _, Track in Shop.LoadedEmoteTracks do
        if Track.Animation ~= nil then
            Track.Animation:Stop(0)
            continue
        end

        for _, SubTrack in Track do
            SubTrack.Animation:Stop(0)
        end
    end

    local Info = require(Module)

    local PreviewInstances = Shop.UI.SideContainer.PreviewContainer
    PreviewInstances.Render.Image = Info.Config.Render
    PreviewInstances.Title.Text = Info.Config.Name

    Shop.CurSelected.Name = Module.Name
    Shop.CurSelected.Type = Type
    Shop.CurSelected.Card = Card

    Shop.UI.SideContainer.ButtonsContainer.CurrentItemPrice.Text = `{Info.Config.Price}$`

    Shop._ReloadPurchaseButton()

    TweenService:Create(Shop.UI.SideContainer, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
        Size = UDim2.fromScale(0.3, 1),
    }):Play()

    if Type == "Emote" then
        CardRenderer.SetupEmoteRig(Shop, Module, Card)
        return
    end

    Shop.UI.SideContainer.PreviewContainer.Emote.Visible = false
    Shop.UI.SideContainer.PreviewContainer.Render.ImageTransparency = 0
    Shop.UI.SideContainer.ButtonsContainer.MoreInfo.Visible = true
    Shop.UI.SideContainer.ButtonsContainer.Skins.Visible = true
end

return Shop
