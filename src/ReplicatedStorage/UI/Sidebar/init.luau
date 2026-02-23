local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local UIManager = require(script.Parent)
local Sounds = require(ReplicatedStorage.Modules.Sounds)
local Utils = require(ReplicatedStorage.Modules.Utils)

local Sidebar = {
    Enabled = true,
    ToggleDuration = 0.5,
    Menus = {},
}

type Button = {
    Render: string,
    Type: "Button" | "SmallButton",
    InvertedRender: string?,
    LayoutOrder: number,
    CloseOnOtherOpen: boolean,
    CloseOthersOnOpen: boolean,
    RelativePath: string?,
}

local Menus: {[string]: Button} = {
    Shop = {
        Render = "rbxassetid://140391842164127",
        Type = "Button",
        InvertedRender = "rbxassetid://106935872381429",
        LayoutOrder = 0,
        CloseOnOtherOpen = true,
        CloseOthersOnOpen = true,
        RelativePath = "Collections.Shop",
    },
    Stats = {
        Render = "rbxassetid://130488549713780",
        Type = "Button",
        InvertedRender = "rbxassetid://72911514685580",
        LayoutOrder = 3,
        CloseOnOtherOpen = true,
        CloseOthersOnOpen = true,
    },
    Credits = {
        Render = "rbxassetid://82434587437333",
        Type = "SmallButton",
        InvertedRender = "rbxassetid://113410904986274",
        LayoutOrder = 6,
        CloseOnOtherOpen = true,
        CloseOthersOnOpen = true,
    },
    Rules = {
        Render = "rbxassetid://83147016587963",
        Type = "SmallButton",
        InvertedRender = "rbxassetid://90249013398230",
        LayoutOrder = 7,
        CloseOnOtherOpen = true,
        CloseOthersOnOpen = true,
    },
    Changelog = {
        Render = "rbxassetid://82434587437333",
        Type = "SmallButton",
        InvertedRender = "rbxassetid://113410904986274",
        LayoutOrder = 8,
        CloseOnOtherOpen = true,
        CloseOthersOnOpen = true,
    },
}

local function TweenInverted(BarButton, Inverted: boolean)
    for _, Child in BarButton:GetChildren() do
        if #Child:GetChildren() > 0 then
            TweenInverted(Child, Inverted)
        end

        if Child:IsA("TextLabel") then
            local Value = Inverted and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
            
            TweenService:Create(Child, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                TextColor3 = Value,
            }):Play()

            continue
        end

        if not (Child:IsA("ImageLabel") or Child:IsA("ImageButton")) then
            continue
        end

        local Value = not Inverted and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        local Transp = 0

        if Child.Name:lower():find("inverted") then
            Transp = Inverted and 0 or 1
        elseif Child.Parent.Name ~= "Holder" then
            continue
        end

        TweenService:Create(Child, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            ImageTransparency = Transp,
            BackgroundColor3 = Value,
        }):Play()
    end
end

function Sidebar.Toggle(visible: boolean)
    Sidebar.UI.Visible = visible
    Sidebar.Enabled = visible

    for _, Menu in Sidebar.Menus do
        if not Menu.Button then
            continue
        end

        TweenInverted(Menu.Button, false)
    end
end

function Sidebar.CloseAll(Remaining: any)
    for _, menu in Sidebar.Menus do
        if menu == Remaining or not menu.Opened or not menu.CloseOnOtherOpen then
            continue
        end

        menu:Close(Sidebar.ToggleDuration)

        if not menu.Button then
            continue
        end

        TweenInverted(menu.Button, false)
    end
end

function Sidebar.OpenMenu(Menu)
    Sounds.PlaySound(Sounds.CommonSounds.ButtonPress, {Volume = 0.8})

    if not Menu.Opened then
        if Menu:Open(Sidebar.ToggleDuration) ~= nil then
            return
        end
        if Menu.Button then
            TweenInverted(Menu.Button, true)
        end

        if Menu.CloseOthersOnOpen then
            Sidebar.CloseAll(Menu)
        end

        return
    end

    Menu:Close(Sidebar.ToggleDuration)
    if Menu.Button then
        TweenInverted(Menu.Button, false)
    end
end

function Sidebar:Init()
    local UI = script.SidebarUI.Sidebar:Clone()
    UI.Parent = UIManager.FetchScreenGui("Sidebar")

    do
        local MoneyLabel = UI.Money.CurrentBalance
        local Cash = Utils.PlayerData.GetPlayerStat(Players.LocalPlayer, "Currency.Money", false)
        Utils.Instance.ObserveProperty(Cash, "Value", function(Value: number)
            MoneyLabel.Text = `{tostring(Value)}$`
        end)
    end

    for Name: string, Button: Button in Menus do
        local BarButton = script.SidebarUI[Button.Type]:Clone()
        BarButton.Name = Name
        BarButton.Icon.Image = Button.Render
        BarButton.Button.Image = Button.Render
        BarButton.InvertedIcon.Image = Button.InvertedRender or BarButton.InvertedIcon.Image
        BarButton.Inverted.Image = Button.InvertedRender or BarButton.Inverted.Image
        BarButton.Title.Holder.Label.Text = Name
        BarButton.LayoutOrder = Button.LayoutOrder

        local Menu = require(Button.RelativePath ~= nil and Utils.Instance.FindFirstChild(script, Button.RelativePath) or script:FindFirstChild(Name))
        Menu.CloseOnOtherOpen = Button.CloseOnOtherOpen
        Menu.CloseOthersOnOpen = Button.CloseOthersOnOpen

        BarButton.Button.MouseButton1Click:Connect(function()
            Sidebar.OpenMenu(Menu)
        end)

        Menu.Button = BarButton

        Sidebar.Menus[Name] = Menu
        BarButton.Parent = UI.Buttons

        local OriginalSize = BarButton.Size
        local HoverSize = UDim2.fromScale(OriginalSize.X.Scale * 1.2, OriginalSize.Y.Scale * 1.2)

        local OriginalYLabelBound = BarButton.Title.Holder.Label.AbsoluteSize.Y
        BarButton.MouseEnter:Connect(function()
            if BarButton.Title.Holder.Position.X.Scale <= 0 and BarButton.Title.Holder.Position.X.Offset <= 0 then
                OriginalYLabelBound = BarButton.Title.Holder.Label.AbsoluteSize.Y
                OriginalSize = BarButton.Size
                HoverSize = UDim2.fromScale(OriginalSize.X.Scale * 1.2, OriginalSize.Y.Scale * 1.2)
            end

            Sounds.PlaySound(Sounds.CommonSounds.ButtonHover, {Volume = 0.2})
            TweenService:Create(BarButton, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = HoverSize}):Play()
            -- Why does `TextLabel.AutomaticSize` not fucking work with `TextLabel.TextScaled`? No idea! I'm mentally insane! :D
            -- `TextLabel.TextSize` doesn't either. What world are we living in?
            -- 
            -- reading this 2 months later makes me realize i was a dumbass -Dys XX/01/2026
            -- what the fuck is my thought process when coding??????? -Dys 02/02/2026
            local Size = TextService:GetTextSize(BarButton.Title.Holder.Label.Text, OriginalYLabelBound, BarButton.Title.Holder.Label.Font, BarButton.Title.Holder.Label.AbsoluteSize)
            TweenService:Create(BarButton.Title.Holder, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.15, Size.X + 56, 0.5, 0)
            }):Play()
        end)
        BarButton.MouseLeave:Connect(function()
            Sounds.PlaySound(Sounds.CommonSounds.ButtonHoverStop, {Volume = 0.2})

            TweenService:Create(BarButton, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = OriginalSize}):Play()
            TweenService:Create(BarButton.Title.Holder, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 0, 0.5, 0)
            }):Play()
        end)

        Utils.Character.ObserveCharacter(Players.LocalPlayer, function(char: Model)
            if Menu.Toggle == nil then
                return
            end
            Menu:Toggle(char:GetAttribute("Role") == "Spectator")
        end)
    end
end

return Sidebar
