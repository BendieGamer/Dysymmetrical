local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Menu = require(ReplicatedStorage.Classes.Menu)
local Utils = require(ReplicatedStorage.Modules.Utils)

local Inventory = Menu.New(script.InventoryUI, {

})
Utils.Type.DeepTableWrite(Inventory, {
    IsSkinMenuOpen = false,
    IsInfoMenuOpen = false,
    LoadedItems = {
        Killers = {},
        Survivors = {},
        Emotes = {},
        Skins = {},
    },
    CurSelected = {
        Name = "",
        Type = "",
    },
    SelectedSection = "Survivors",
    Equipped = {
        EquippedKiller = Utils.PlayerData.GetPlayerEquipped(Players.LocalPlayer, "Killer", false),
        EquippedSurvivor = Utils.PlayerData.GetPlayerEquipped(Players.LocalPlayer, "Survivor", false),
    },

    PreviewsEnabled = true,
})

return Inventory
