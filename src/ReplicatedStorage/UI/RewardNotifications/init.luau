local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Network = require(ReplicatedStorage.Modules.Network)
local Utils = require(ReplicatedStorage.Modules.Utils)
local UIManager = require(script.Parent)

local RewardNotifications = {}

function RewardNotifications:Init()
    local Container = script.RewardNotificationContainer
    Container.Parent = UIManager.FetchScreenGui("RewardNotifications")

    local Prefab = script.RewardNotification
    local AchievementPrefab = script.AchievementNotification
    
    Network:SetConnection("RewardNotif", "REMOTE_EVENT", function(Module: ModuleScript | string, Type: number, Quoted: boolean?, Granted: boolean?)
        local IsAchievement = Type == Utils.Enum.RewardNotifications.Achievement

        local Card = (IsAchievement and AchievementPrefab or Prefab):Clone()
        local Info = IsAchievement and Utils.Instance.GetAchievementData(Module) or require(Module)

        Card.ImageContainer.Render.Image = IsAchievement and (Info.Icon or "rbxasset://textures/ui/GuiImagePlaceholder.png") or Info.Config.Render

        local Text
        if IsAchievement then
            Text = `"{Info.Title}" achievement obtained!`
        else
            Text = `{Granted and "Received" or "Bought"} "{Info.Config.Name}"`

            if Type == Utils.Enum.RewardNotifications.Character then
                Text = Text.." character"
            elseif Type == Utils.Enum.RewardNotifications.Skin then
                Text = Text.." skin"
            elseif Type == Utils.Enum.RewardNotifications.Emote then
                Text = Text.." emote"
            end
        end

        Card.TextContainer.RewardLabel.Text = Text

        local Quote = not IsAchievement and Info.Config.Quote or Info.Description
        if Quoted then
            Quote = `"{Quote}"`
        end

        Card.TextContainer.RewardQuote.Text = Quote

        Card.Size = Utils.UDim.Zero
        Card.Parent = Container
        TweenService:Create(Card, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.fromScale(1, 0.2)}):Play()
        task.wait(5)
        TweenService:Create(Card, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Size = Utils.UDim.Zero}):Play()
        task.wait(1)
        Card:Destroy()
    end)
end

return RewardNotifications
