local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Utils = require(ReplicatedStorage.Modules.Utils)

local DataHandler = {}

function DataHandler.SortSkins(Inventory: any)
    local Ordered = Inventory.LoadedItems.Skins

    --requiring the modules outside of the sort to save some overhead
    local Modules = {}
    for _, Skin in Ordered do
        Modules[Skin] = Utils.Instance.GetCharacterModule(Inventory.SelectedItem.Type, Inventory.SelectedItem.Name, Skin.Name)
    end

    table.sort(Ordered, function(a, b): boolean
        local ItemModules = {
            A = Modules[a],
            B = Modules[b],
        }

        return
            ItemModules.A.Config.Price == ItemModules.B.Config.Price and a.Name < b.Name
            or ItemModules.A.Config.Price < ItemModules.B.Config.Price
    end)

    local LayoutOrder = 0
    for _, Skin in Ordered do
        LayoutOrder += 1
        Skin.LayoutOrder = LayoutOrder
    end
end

local function HideEquippedLabel(card: Frame)
    if card.Container.Equipped.ImageTransparency == 1 then
        return
    end
    TweenService:Create(card.Container.Equipped, TweenInfo.new(0.2), {ImageTransparency = 1}):Play()
end
local function ShowEquippedLabel(card: Frame)
    if card.Container.Equipped.ImageTransparency == 0 then
        return
    end
    TweenService:Create(card.Container.Equipped, TweenInfo.new(0.2), {ImageTransparency = 0}):Play()
end

function DataHandler.CheckEquipLabels(Inventory: any)
    for name, Type in Inventory.LoadedItems do
        if name == "Skins" then
            continue
        end

        for _, Item in Type do
            if Item.Name == Inventory.Equipped["Equipped"..name:sub(1, #name - 1)].Value then
                ShowEquippedLabel(Item)
            else
                HideEquippedLabel(Item)
            end
        end
    end
end

return DataHandler
