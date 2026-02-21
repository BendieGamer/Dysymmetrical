local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Modules.Network)
local Utils = require(ReplicatedStorage.Modules.Utils)

local ShopManager = {}

function ShopManager:Init()
    Network:SetConnection("BuyShopItem", "REMOTE_FUNCTION", ShopManager._RequestPurchase)
end

function ShopManager._RequestPurchase(Player: Player, Module: ModuleScript, Quotation: boolean?): boolean
    --defaults
    if Quotation == nil then
        Quotation = true
    end

    --get da money
    local Money = Utils.PlayerData.GetPlayerStat(Player, "Currency.Money", false)

    --get da price
    local Price = require(Module).Config.Price
    --if the player is poor, halt
    if Price > Money.Value then
        return false
    end

    --take the money (taxes included)
    Money.Value -= Price
    --increase the player's net worth so that they feel rich
    Utils.PlayerData.GetPlayerStat(Player, "Currency.NetWorth", false).Value -= Price

    --create the product on the spot
    local Product = Instance.new("IntValue")
    Product.Name = Module.Name
    Product.Value = 0

    --get the type of product
    local ProductType = Utils.Instance.GetTypeOfItemModule(Module)
    --fallback to the pocket in the "pockets based on product types" list
    local Parent = Utils.PlayerData.GetSpecificObject(Player, `Purchased.{ProductType}s`)
    --if it's a skin, manually look for the player's skin pocket for the specific character the skin is for
    if ProductType == "Skin" then
        Parent = Parent:FindFirstChild(Module.Parent.Name) or Utils.PlayerData.CreateMissingPurchasedSkinValue(Player, Module.Parent.Name)
    end

    --put the product automatically in the player's pocket
    Product.Parent = Parent

    --tell the player "yo you got yo stuff cuh, see it!"
    Network:FireClientConnection(Player, "RewardNotif", "REMOTE_EVENT", Module, Utils.Enum.RewardNotifications[ProductType], true)

    --confirm the purchase
    return true
end

return ShopManager
