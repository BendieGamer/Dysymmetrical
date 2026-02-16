local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Menu = require(ReplicatedStorage.Classes.Menu)
local Utils = require(ReplicatedStorage.Modules.Utils)

return Menu.New(script.Stats, {
    OnInit = function(self)
        local Content = self.UI.StatsContainer.Content

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
    end,
})
