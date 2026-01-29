local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Network = require(ReplicatedStorage.Modules.Network)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Signal = require(ReplicatedStorage.Utils.Signal)

local BuyWindow = {}
BuyWindow.__index = BuyWindow

function BuyWindow.New(Shop, Module: ModuleScript, Parent: Frame, Card: Frame)
    local self = setmetatable({
        Checking = false,
        Instance = script:FindFirstChild("Window"):Clone(),
        JanitorInstance = Janitor.new(),
        Removed = Signal.new(),
        Purchased = Signal.new(),
    }, BuyWindow)

    --link janitor to ui and add signals to it to clean up later
    self.JanitorInstance:LinkToInstance(self.Instance)
    self.JanitorInstance:Add(self.Removed, "DisconnectAll")
    self.JanitorInstance:Add(self.Purchased, "DisconnectAll")

    --try to fetch item info
    local ItemInfo = require(Module)
    --set label for when the window shows up
    self.Instance.PriceTag.Text = `Purchase {ItemInfo.Config.Name} for {ItemInfo.Config.Price > 0 and `{ItemInfo.Config.Price}$` or "FREE"}?`
    self.Instance.Parent = Parent
    --hide at first
    self.Instance.Size = Utils.UDim.Zero

    --purchasing
    self.JanitorInstance:Add(self.Instance.Buy.Button.MouseButton1Click:Connect(function()
        --if it's already checking, halt
        if self.Checking then
            return
        end
        --already checking
        self.Checking = true
        --visual cue
        self.Instance.Buy.TextLabel.Text = "..."

        --fetch item purchase
        local Bought = Network:FireServerConnection("BuyItem", "REMOTE_FUNCTION", Module)

        --if it was successfully bought, 
        if Bought then
            --visual cue
            self.Instance.Buy.TextLabel.Text = "Purchased!"
            --reload card to display it as owned
            Card.Container.Owned.BackgroundTransparency = 0.55
            Card.Container.Owned.TextLabel.TextTransparency = 0
            --fire signal
            self.Purchased:Fire()
            --hide after a bit
            self.JanitorInstance:Add(task.delay(0.75, function()
                self:Hide()
            end), true)
        else
            --visual cue to indicate poorness
            self.Instance.Buy.TextLabel.Text = "you're too poor. sorry, but numbers speak for you."
            self.Checking = false
        end
    end))
    --cancelling
    self.JanitorInstance:Add(self.Instance.Cancel.Button.MouseButton1Click:Connect(function()
        --if it's checking, halt to prevent interruptions
        if self.Checking then
            return
        end
        --hide
        self:Hide()
    end))
    --show directly on init
    self:Show()

    return self
end

function BuyWindow:Show()
    --literally just show
    TweenService:Create(self.Instance, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = UDim2.fromScale(0.253, 0.202)}):Play()
end

function BuyWindow:Hide(Instant: boolean?)
    --fire signal
    self.Removed:Fire()
    --clean up the window
    self.JanitorInstance:Cleanup()

    --if it's instant, hide it directly
    --if not, tween it
    if Instant ~= true then
        TweenService:Create(self.Instance, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.Zero}):Play()
    else
        self.Instance.Size = Utils.UDim.Zero
    end

    --add the instance to debris just in case
    Debris:AddItem(self.Instance, 0.5)
end

return BuyWindow
