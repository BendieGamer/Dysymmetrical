local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Tooltip = require(ReplicatedStorage.Classes.Tooltip)
local Types = require(ReplicatedStorage.Classes.Types)
local Sounds = require(ReplicatedStorage.Modules.Sounds)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local Templates = script.Parent.Templates

local CardRenderer = {}

function CardRenderer.SetupItemCard(Inventory: any, Module: ModuleScript, Type: "Emote" | Types.Role, CreateCard: boolean, LayoutOrder: number, CanMakePreviews: boolean)
    if Module:HasTag("Unpurchasable") then
        return
    end

    local Parent = Inventory.UI.ShopContainer.Content[`{Type}s`]
    local Name = Module.Name

    if not CreateCard then
        local ExistingCard = Parent:FindFirstChild(Name)
        if ExistingCard then
            ExistingCard.LayoutOrder = LayoutOrder
        end
        return
    end

    if Inventory.LoadedItems[`{Type}s`][Name] then
        return
    end

    local Info = require(Module)

    local Card = Templates.CardTemplate:Clone()
    local Container = Card.Container

    Card.Name = Name
    Card.LayoutOrder = LayoutOrder
    Card.Parent = Inventory.UI.ShopContainer.Content[`{Type}s`]

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

            local Cache = Inventory.UI.ShopContainer.Content.PreviewCache
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
        if Inventory.IsSkinMenuOpen then
            return
        end

        Sounds.PlaySound(Sounds.CommonSounds.ButtonPress, {Volume = 0.8})
        Inventory:OnCharButtonPress(Module, Type)
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

return CardRenderer
