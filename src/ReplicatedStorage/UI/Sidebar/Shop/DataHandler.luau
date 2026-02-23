local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Classes.Types)
local Utils = require(ReplicatedStorage.Modules.Utils)

local DataHandler = {}

function DataHandler.GetSortedItems(Type: "Emote" | Types.Role): {
    Owned: {[number]: ModuleScript},
    Unowned: {[number]: ModuleScript},
}
    local ItemTable = {
        Owned = {},
        Unowned = {},
    }

    local TargetFolder = ReplicatedStorage.Content
    if Type ~= "Emote" then
        TargetFolder = TargetFolder.Characters
    end

    for _, Module in TargetFolder[`{Type}s`]:GetChildren() do
        local IsItemOwned = Utils.PlayerData.GetPlayerOwned(Players.LocalPlayer, `{Type}s.{Module.Name}`)
        table.insert(ItemTable[IsItemOwned and "Owned" or "Unowned"], Module)
    end

    for _, Table in ItemTable do
        table.sort(Table, function(a: ModuleScript, b: ModuleScript)
            do
                --if a isn't a module, prioritize b
                local IsFirstItemModule = a:IsA("ModuleScript")
                if not IsFirstItemModule or b:IsA("ModuleScript") then
                    --if b isn't a module instead, prioritize a
                    return IsFirstItemModule
                end
            end

            --require le modules
            local A = require(a)
            local B = require(b)
            
            do
                --if a doesn't have a price tag, prioritize b
                local FirstItemPriceTagExistent = Utils.Type.SafeTableIndex(A, "Config.Price") ~= nil
                if not FirstItemPriceTagExistent or Utils.Type.SafeTableIndex(B, "Config.Price") == nil then
                    --if b doesn't have a price tag instead, prioritize a
                    return FirstItemPriceTagExistent
                end
            end

            return
                --if they're the same price, go for alphabetical order
                if A.Config.Price == B.Config.Price then
                    a.Name < b.Name
                --if not, put the lowest price one first to show the most expensive ones at the bottom
                else
                    A.Config.Price < B.Config.Price
        end)
    end

    return ItemTable
end

return DataHandler
