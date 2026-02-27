local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Menu = require(ReplicatedStorage.Classes.Menu)

type Credit = {
    Render: string,
    DisplayName: string,
    Username: string,
    Description: string,
}
local Credits: {{ Name: string, Credits: {Credit} }} = {
    {
        Name = "Dysymmetrical",
        Credits = {
            {
                Render = "rbxassetid://112215528635901",
                DisplayName = "Dyscarn",
                Username = "@LrgeAlvaro8882",
                Description = "Made the engine used in this game: Dysymmetrical.",
            },
            {
                Render = "",
                DisplayName = "heromax149807",
                Username = "@heromax149807",
                Description = "Made the original engine art like the sidebar icons, the buttons, etc.",
            },
        },
    },
}

return Menu.New(script.Credits, {
    OnInit = function(self)
        local LO = 0
        for _, CreditsSection: {Name: string, Credits: {Credit}} in Credits do
            LO += 1

            local SectionPrefab = script.Prefabs.Section:Clone()
            SectionPrefab.Name = CreditsSection.Name.."Section"
            SectionPrefab.SectionName.Text = CreditsSection.Name
            SectionPrefab.LayoutOrder = LO
            SectionPrefab.Parent = self.UI.Content

            for _, Credit: Credit in CreditsSection.Credits do
                LO += 1

                local CreditPrefab = script.Prefabs.Credit:Clone()
                CreditPrefab.Name = Credit.Username.."Credit"
                CreditPrefab.DisplayName.Text = Credit.DisplayName
                CreditPrefab.Username.Text = Credit.Username
                CreditPrefab.Portrait.Image = Credit.Render or "rbxasset://textures/ui/GuiImagePlaceholder.png"
                CreditPrefab.Description.Text = Credit.Description

                CreditPrefab.LayoutOrder = LO
                CreditPrefab.Parent = self.UI.Content
            end
        end
    end,
})
