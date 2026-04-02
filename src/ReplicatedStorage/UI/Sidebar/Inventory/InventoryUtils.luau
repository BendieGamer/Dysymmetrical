local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataHandler = require(script.Parent.DataHandler)
local Types = require(ReplicatedStorage.Classes.Types)
local Network = require(ReplicatedStorage.Modules.Network)
local Sounds = require(ReplicatedStorage.Modules.Sounds)

local InventoryUtils = {}

function InventoryUtils.SetupAudibleButton(Button: ImageButton, JanitorInstance: Types.Janitor?, Callback: () -> (), ...)
    local Args = {...}

    local function AddToJanitor(Connection: RBXScriptConnection)
        if JanitorInstance == nil then
            return
        end

        JanitorInstance:Add(Connection)
    end

    AddToJanitor(Button.MouseEnter:Connect(function()
        Sounds.PlaySound(Sounds.CommonSounds.ButtonHover, {Volume = 0.2})
    end))
    AddToJanitor(Button.MouseLeave:Connect(function()
        Sounds.PlaySound(Sounds.CommonSounds.ButtonHoverStop, {Volume = 0.2})
    end))

    AddToJanitor(Button.MouseButton1Click:Connect(function()
        Sounds.PlaySound(Sounds.CommonSounds.ButtonPress, {Volume = 0.8})
        Callback(table.unpack(Args))
    end))
end

function InventoryUtils.EquipItem(Inventory: any, EquipButton: Frame)
    -- Sounds.PlaySound(Sounds.CommonSounds.ButtonPress, {Volume = 0.8})
    if not Inventory.Opened or Inventory.Equipped["Equipped"..Inventory.SelectedItem.Type].Value == Inventory.SelectedItem.Name then
        return
    end

    local LastEquipped = Inventory.Equipped["Equipped"..Inventory.SelectedItem.Type].Value

    EquipButton.Title.Text = "Equipped"

    Network:FireServerConnection("EquipItem", "REMOTE_EVENT", Inventory.SelectedItem.Name, Inventory.SelectedItem.Type)

    if Inventory.Equipped["Equipped"..Inventory.SelectedItem.Type].Value == LastEquipped then
        Inventory.Equipped["Equipped"..Inventory.SelectedItem.Type].Changed:Wait()
    end

    DataHandler.CheckEquipLabels(Inventory)
end

return InventoryUtils
