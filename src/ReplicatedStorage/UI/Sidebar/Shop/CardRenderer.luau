local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Tooltip = require(ReplicatedStorage.Classes.Tooltip)
local Sounds = require(ReplicatedStorage.Modules.Sounds)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local Templates = script.Parent.Templates

local CardRenderer = {}

function CardRenderer.SetupItemCard(Shop: any, Module: ModuleScript, Type: "Emote" | "Survivor" | "Killer", CreateCard: boolean, LayoutOrder: number, CanMakePreviews: boolean)
    if Module:HasTag("Unpurchasable") then
        return
    end

    local Parent = Shop.UI.ShopContainer.Content[`{Type}s`]
    local Name = Module.Name

    if not CreateCard then
        local ExistingCard = Parent:FindFirstChild(Name)
        if ExistingCard then
            ExistingCard.LayoutOrder = LayoutOrder
        end
        return
    end

    if Shop.LoadedItems[`{Type}s`][Name] then
        return
    end

    local Info = require(Module)

    local Card = Templates.CardTemplate:Clone()
    local Container = Card.Container

    Card.Name = Name
    Card.LayoutOrder = LayoutOrder
    Card.Parent = Shop.UI.ShopContainer.Content[`{Type}s`]

    Container.Title.Text = Info.Config.Name or Name
    Container.CharacterRender.Image = Info.Config.Render or ""
    Container.Price.Text = Info.Config.Price > 0 and `{Info.Config.Price}$` or "FREE"

    if Info.Config.CardFrame then
        for PropertyName, PropertyValue in Info.Config.CardFrame do
            Container.Outline[PropertyName] = PropertyValue or Container.Outline[PropertyName]
        end
    end

    local Preview = Container.Preview.ViewportFrame

    if CanMakePreviews and Type ~= "Emote" then
        task.defer(function()
            local Model = Utils.Instance.FindFirstChild(ReplicatedStorage.Assets.Characters, `{Type}s.{Name}`)
            if not Model then
                return
            end

            local Camera = Instance.new("Camera")
            Camera.FieldOfView = 10
            Camera.Parent = Preview
            local WorldModel = Instance.new("WorldModel")
            WorldModel.Parent = Camera
            Preview.CurrentCamera = Camera

            Model = Model:Clone()
            if not Model:FindFirstChildWhichIsA("Animator", true) then
                Instance.new("Animator").Parent = Model:FindFirstChildWhichIsA("Humanoid", true)
            end
            Utils.Character.GetRootPart(Model).Anchored = true
            --math.pi is the equivalent in radians to 180 degrees
            Model:PivotTo(CFrame.new(0, 10000, 0) * CFrame.Angles(0, math.pi, 0))

            Camera.CFrame = CFrame.new(0, 10000, 6 * Model:GetExtentsSize().Y)

            local Cache = Shop.UI.ShopContainer.Content.PreviewCache
            Model.Parent = Cache

            Utils.Character.LoadAnimationFromID(Model, Info.Config.AnimationIDs.PreviewAnimation or Info.Config.AnimationIDs.IdleAnimation, false):Play(0)

            Utils.Instance.ObserveProperty(Preview, "ImageTransparency", function(Transparency: number)
                if Transparency < 1 then
                    if Model.Parent ~= WorldModel then
                        Model.Parent = WorldModel
                    end
                    return
                end

                if Model.Parent ~= Cache then
                    Model.Parent = Cache
                end
            end)
        end)
    end

    if Utils.PlayerData.GetPlayerOwned(Players.LocalPlayer, `{Type}s.{Name}`) then
        Container.Owned.BackgroundTransparency = 0.55
        Container.Owned.TextLabel.TextTransparency = 0
    end

    Shop.LoadedItems[`{Type}s`][Name] = Card

    local ContainerJanitor = Janitor.new()
    ContainerJanitor:LinkToInstance(Container)

    ContainerJanitor:Add(Container.Interact.MouseEnter:Connect(function()
        TweenService:Create(Container, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            Size = UDim2.fromScale(1.065, 1.065),
        }):Play()
        Sounds.PlaySound(Sounds.CommonSounds.ButtonHover, {Volume = 0.2})

        if not CanMakePreviews or Type == "Emote" then
            return
        end

        TweenService:Create(Preview, TweenInfo.new(0.25), {
            ImageTransparency = 0
        }):Play()
        TweenService:Create(Preview.Parent, TweenInfo.new(0.25), {
            BackgroundTransparency = 0
        }):Play()
    end))
    ContainerJanitor:Add(Container.Interact.MouseLeave:Connect(function()
        TweenService:Create(Container, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            Size = UDim2.fromScale(1, 1),
        }):Play()
        Sounds.PlaySound(Sounds.CommonSounds.ButtonHoverStop, {Volume = 0.2})

        if not CanMakePreviews or Type == "Emote" then
            return
        end

        TweenService:Create(Preview, TweenInfo.new(0.25), {
            ImageTransparency = 1
        }):Play()
        TweenService:Create(Preview.Parent, TweenInfo.new(0.25), {
            BackgroundTransparency = 1
        }):Play()
    end))
    ContainerJanitor:Add(Container.Interact.MouseButton1Click:Connect(function()
        if Shop.IsSkinMenuOpen then
            return
        end

        Sounds.PlaySound(Sounds.CommonSounds.ButtonPress, {Volume = 0.8})
        Shop:OnCharButtonPress(Module, Type, Card)
    end))

    if not (Info.Config.Origin and Info.Config.Origin.Icon) then
        Container.Origin.Visible = false

        return
    end

    Container.Origin.Visible = true
    Container.Origin.Image = Info.Config.Origin.Icon

    ContainerJanitor:Add(Container.Origin.MouseEnter:Connect(function()
        if Info.Config.Origin.TooltipText == nil then
            return
        end

        Tooltip.New(Info.Config.Origin.TooltipText)
    end))
    ContainerJanitor:Add(Container.Origin.MouseLeave:Connect(function()
        if Info.Config.Origin.TooltipText == nil then
            return
        end

        Tooltip.New()
    end))
end

function CardRenderer.SetupEmoteRig(Shop: any, Module: ModuleScript, Card: Frame)
    Shop.UI.SideContainer.PreviewContainer.Emote.Visible = true
    Shop.UI.SideContainer.PreviewContainer.Render.ImageTransparency = 1
    Shop.UI.SideContainer.ButtonsContainer.MoreInfo.Visible = false
    Shop.UI.SideContainer.ButtonsContainer.Skins.Visible = false

    local Info = require(Module)

    local AnimTrack = Shop.LoadedEmoteTracks[Module.Name]
    if not AnimTrack then
        local AnimIDs = Info.AnimationIds
        if typeof(AnimIDs) == "string" then
            Shop.LoadedEmoteTracks[Module.Name] = {
                Animation = Utils.Character.LoadAnimationFromID(Shop.UI.SideContainer.PreviewContainer.Emote.EmotePreview.Rig, AnimIDs),
                Sound = nil,
            }
        else
            Shop.LoadedEmoteTracks[Module.Name] = {}

            for _, ID: string in AnimIDs do
                Shop.LoadedEmoteTracks[Module.Name][ID] = {
                    Animation = Utils.Character.LoadAnimationFromID(Shop.UI.SideContainer.PreviewContainer.Emote.EmotePreview.Rig, ID),
                    Sound = nil,
                }
            end
        end

        if Info.SoundIds then
            if typeof(Info.SoundIds) == "string" then
                if typeof(AnimIDs) == "string" then
                    Shop.LoadedEmoteTracks[Module.Name].Sound = Info.SoundIds
                else
                    for _, id in AnimIDs do
                        Shop.LoadedEmoteTracks[Module.Name][id].Sound = Info.SoundIds
                    end
                end
            else
                for animId, id in Info.SoundIds do
                    Shop.LoadedEmoteTracks[Module.Name][animId].Sound = id
                end
            end
        end

        AnimTrack = Shop.LoadedEmoteTracks[Module.Name]
    end

    if not AnimTrack.Animation then
        local Selected = AnimTrack[math.random(1, #AnimTrack)]
        Selected.Animation:Play(0)
        Sounds.PlaySound(Selected.Sound, {Name = "EmotePreview"})
    else
        AnimTrack.Animation:Play(0)
        Sounds.PlaySound(AnimTrack.Sound, {Name = "EmotePreview"})
    end
end

return CardRenderer
