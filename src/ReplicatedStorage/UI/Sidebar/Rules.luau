local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Menu = require(ReplicatedStorage.Classes.Menu)

local Ruleset: {{
        Type: "Separator" | "SectionEntry" | "Text",
        Text: string,
    }} = {
    {
        Type = "Separator",
        Text = "Rule section N.º 1",
    },
    {
        Type = "SectionEntry",
        Text = "Pretty cool rule N.º 1!",
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
        Text = "Pretty cool rule N.º 3!",
    },
    {
        Type = "Text",
        Text = "Quick note N.º 2!",
    },
    {
        Type = "Separator",
        Text = "Rule section N.º 2",
    },
    {
        Type = "SectionEntry",
        Text = "Pretty cool rule N.º 1!",
    },
    {
        Type = "Text",
        Text = "Quick note N.º 1!",
    },
    {
        Type = "SectionEntry",
        Text = "Pretty cool rule N.º 2!",
    },
    {
        Type = "SectionEntry",
        Text = "Pretty cool rule N.º 3!",
    },
    {
        Type = "Text",
        Text = "Quick note N.º 2!",
    },
}

return Menu.New(script.Rules, {
    OnInit = function(self)
        for order, entry in Ruleset do
            local Inst = script.Prefabs[entry.Type]:Clone()
            Inst.Title.Text = entry.Text
            Inst.LayoutOrder = order
            Inst.Parent = self.UI.Content
        end
    end,
})
