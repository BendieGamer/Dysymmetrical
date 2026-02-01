local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Sidebar = require(script.Parent)
local Utils = require(ReplicatedStorage.Modules.Utils)
local UIManager = require(Players.LocalPlayer.PlayerScripts.UIManager)

local Stats = {
    Enabled = true,
    Opened = false,
}

function Stats:Init()
    if Stats.UI then
        Stats.UI.Parent = UIManager.FetchScreenGui("Menus")
        Stats.UI.Size = Utils.UDim.Zero
        Stats.UI.Visible = false
        return
    end

    local UI = script.Stats
    UI.Size = Utils.UDim.Zero
    UI.Visible = false
    UI.Parent = UIManager.FetchScreenGui("Menus")
    Stats.UI = UI
    local Content = UI.StatsContainer.Content

    local CurrentLayoutOrder = 0
    
    local Folders = Utils.PlayerData.GetSpecificObject(Players.LocalPlayer, "Stats"):GetChildren()

    table.sort(Folders, function(a, b)
        return a:GetAttribute("LayoutOrder") < b:GetAttribute("LayoutOrder")
    end)

    for _, StatFolder in ipairs(Folders) do
        CurrentLayoutOrder += 1

        local Section = script.Prefabs.Section:Clone()
        Section.Name = StatFolder.Name
        Section.TextLabel.Text = StatFolder:GetAttribute("DisplayTitle")
        Section.LayoutOrder = CurrentLayoutOrder

        local StatsInSection = StatFolder:GetChildren()

        table.sort(StatsInSection, function(a, b)
            return a:GetAttribute("LayoutOrder") < b:GetAttribute("LayoutOrder")
        end)

        for _, StatValue in ipairs(StatsInSection) do
            CurrentLayoutOrder += 1
            
            local Stat = script.Prefabs.Stat:Clone()
            Stat.Name = StatValue.Name

            local DisplayTitle = StatValue:GetAttribute("DisplayTitle")

            if StatValue:GetAttribute("PostDisplayTitle") ~= nil then
                DisplayTitle = DisplayTitle.." ("..StatValue:GetAttribute("PostDisplayTitle")..")"
            end

            Stat.Text = DisplayTitle..": "

            local FormatTime = StatValue:GetAttribute("FormatTime")
            if FormatTime == true then
                Stat.Text = Stat.Text..Utils.Math.ConvertToDHMS(StatValue.Value)
            else
                Stat.Text = Stat.Text..tostring(StatValue.Value)
            end

            Stat.LayoutOrder = CurrentLayoutOrder

            StatValue.Changed:Connect(function(value)
                Stat.Text = DisplayTitle..": "

                local RealValue = FormatTime == true and Utils.Math.ConvertToDHMS(value) or tostring(value)
                Stat.Text = Stat.Text..RealValue
            end)

            Stat.Parent = Content
        end
        
        Section.Parent = Content
    end

    Utils.Instance.ObserveProperty(UI, "Size", function(value: UDim2)
        UI.Visible = value ~= Utils.UDim.Zero
    end)
end

function Stats.Open(Time: number)
    if not Stats.Enabled or not Players.LocalPlayer.Character or Players.LocalPlayer.Character:GetAttribute("Role") ~= "Spectator" or not Sidebar.Enabled then
        return "Prevented"
    end

    TweenService:Create(Stats.UI, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.Full20Offset}):Play()
    Stats.Opened = true
    return
end

function Stats.Close(Time: number)
    if Time > 0 then
        TweenService:Create(Stats.UI, TweenInfo.new(Time, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = Utils.UDim.Zero}):Play()
    else
        Stats.UI.Size = Utils.UDim.Zero
    end
    Stats.Opened = false
end

function Stats.Toggle(toggle: boolean)
    if not Stats.Enabled and toggle then
        Stats:Init()
    end

    if not toggle and Stats.Enabled then
        Stats.UI.Parent = script
        Stats.UI.Size = Utils.UDim.Zero
    end

    Stats.Enabled = toggle
end

return Stats
