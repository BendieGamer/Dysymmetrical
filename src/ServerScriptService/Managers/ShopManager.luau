local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Network = require(ReplicatedStorage.Modules.Network)
local ShopManager = {}

function ShopManager:Init()
    Network:SetConnection("BuyShopItem", "REMOTE_EVENT", function(Player: Player, Module: ModuleScript, Quotation: boolean?): boolean
        if Quotation == nil then
            Quotation = true
        end

        
    end)
end

return ShopManager
