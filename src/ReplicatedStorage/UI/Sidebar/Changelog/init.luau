local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sidebar = require(script.Parent)

local Menu = require(ReplicatedStorage.Classes.Menu)
local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)

--- The format to follow in `CurrentChangelog`'s 
type ChangelogFormat = {
    --- The version of the place containing the update.
    --- Can be found by printing `game.PlaceVersion`.
    PlaceVersion: number,
    --- The text that'll be shown in the menu's title.
    MenuTitle: string,
    --- The title of the update for the beginning of the changelog.
    UpdateTitle: string,
    --- The ID of the update's thumbnail's image.
    --- May also be a banner if you modify the UI yourself.
    UpdateThumbnailID: string,
    --- The date of the update.
    --- Can be anything, but preferably the date.
    --- Will show under the thumbnail.
    UpdateDate: string,
    --- The entries of the changelog.
    Entries: {{
        Type: "Separator" | "SectionEntry" | "Text",
        Text: string,
    }},
}

local CurrentChangelog: ChangelogFormat = {
    PlaceVersion = 0,
    MenuTitle = "Changelog",
    UpdateTitle = "GAME RELEASE",
    UpdateThumbnailID = "rbxasset://textures/ui/GuiImagePlaceholder.png",
    UpdateDate = "01/01/2099",
    Entries = {
        {
            Type = "Separator",
            Text = "Section N.º 1",
        },
        {
            Type = "SectionEntry",
            Text = "Pretty cool feature N.º 1!",
        },
        {
            Type = "SectionEntry",
            Text = "Pretty cool feature N.º 2!",
        },
        {
            Type = "Text",
            Text = "Quick note N.º 1!",
        },
        {
            Type = "SectionEntry",
            Text = "Pretty cool feature N.º 3!",
        },
        {
            Type = "Text",
            Text = "Quick note N.º 2!",
        },
        {
            Type = "Separator",
            Text = "Section N.º 2",
        },
        {
            Type = "SectionEntry",
            Text = "Pretty cool feature N.º 1!",
        },
        {
            Type = "Text",
            Text = "Quick note N.º 1!",
        },
        {
            Type = "SectionEntry",
            Text = "Pretty cool feature N.º 2!",
        },
        {
            Type = "SectionEntry",
            Text = "Pretty cool feature N.º 3!",
        },
        {
            Type = "Text",
            Text = "Quick note N.º 2!",
        },
    },
}

return Menu.New(script.Changelog, {
    OnInit = function(self: Types.Menu)
        local Content = self.UI.Content
        local Top = Content.Top
        Top.Title.Text = CurrentChangelog.UpdateTitle
        Top.Thumbnail.Image = CurrentChangelog.UpdateThumbnailID
        Top.Date.Text = CurrentChangelog.UpdateDate

        self.UI.Label.TextLabel.Text = CurrentChangelog.MenuTitle

        for order, entry in CurrentChangelog.Entries do
            local Inst = script.Prefabs[entry.Type]:Clone()
            Inst.Title.Text = entry.Text
            Inst.LayoutOrder = order
            Inst.Parent = Content
        end

        local Log = Utils.Instance.FindFirstChild(Players.LocalPlayer, "PlayerData.Misc.LastSeenLog")
        if Log.Value < CurrentChangelog.PlaceVersion and Log.Value < ReplicatedStorage.PlaceVersion.Value and CurrentChangelog.PlaceVersion <= ReplicatedStorage.PlaceVersion.Value then
            Sidebar:OpenMenu(self)
        end
    end,
})
