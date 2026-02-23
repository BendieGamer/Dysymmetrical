local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuyWindow = require(script.Parent.BuyWindow)
local Types = require(ReplicatedStorage.Classes.Types)
local Sounds = require(ReplicatedStorage.Modules.Sounds)

local ShopUtils = {}

function ShopUtils.SetupAudibleButton(Button: ImageButton, JanitorInstance: Types.Janitor?, Callback: () -> (), ...)
    local Args = {...}

    local function AddToJanitor(Connection: RBXScriptConnection)
        if JanitorInstance == nil then
            return
        end

        JanitorInstance:Add(Connection)
    end

    AddToJanitor(Button.MouseEnter:Connect(function()
        Sounds.PlaySound(Sounds.CommonSounds.ButtonHover, {Volume = 0.2})
    end))
    AddToJanitor(Button.MouseLeave:Connect(function()
        Sounds.PlaySound(Sounds.CommonSounds.ButtonHoverStop, {Volume = 0.2})
    end))

    AddToJanitor(Button.MouseButton1Click:Connect(function()
        Sounds.PlaySound(Sounds.CommonSounds.ButtonPress, {Volume = 0.8})
        Callback(table.unpack(Args))
    end))
end

function ShopUtils.CreateBuyWindow(Shop: any, Module: ModuleScript, Card: Frame)
    local Window = BuyWindow.New(Shop, Module)
    Window.Instance.Parent = Shop.UI.Parent
    Window.JanitorInstance:Add(Window.Purchased:Connect(function()
        --reload card to display it as owned
        Card.Container.Owned.BackgroundTransparency = 0.55
        Card.Container.Owned.TextLabel.TextTransparency = 0
    end), "Disconnect")
    Window.JanitorInstance:Add(Window.Removed:Connect(function()
        Shop:_ReloadPurchaseButton()

        Shop.BuyWindow = nil
    end))

    Shop.BuyWindow = Window
end

return ShopUtils
