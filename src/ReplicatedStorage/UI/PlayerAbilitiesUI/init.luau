--writing this at the internship because i'm too lazy to do this from home
--man am i addicted to valorant

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Classes.Types)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local UIManager = require(script.Parent)

local PlayerAbilitiesUI = {}

type AbilityButton = {
    ModuleCode: Types.Ability,
    Keybind: TextLabel,
    Timer: TextLabel,
    Uses: TextLabel?,
    Interactor: ImageButton,
}

local AbilityGuiUtils = {
    FramePositions = {
        Slash = UDim2.fromScale(0.675, 0.9),
        FirstAbility = UDim2.fromScale(0.745, 0.9),
        SecondAbility = UDim2.fromScale(0.815, 0.9),
        ThirdAbility = UDim2.fromScale(0.885, 0.9),
        FourthAbility = UDim2.fromScale(0.605, 0.9),
    },
    LayoutOrder = {
        Slash = 1,
        FirstAbility = 2,
        SecondAbility = 3,
        ThirdAbility = 4,
        FourthAbility = 5,
    },
    Prefabs = {
        Container = script.Prefabs.CharacterAbilitiesContainer,
        AbilityContainer = script.Prefabs.AbilityContainer,
        UsesLeftText = script.Prefabs.UsesLeft,
    },
}

function PlayerAbilitiesUI.Instantiate()
    local InputManager = require(Players.LocalPlayer.PlayerScripts.InputManager)
    local Character = Players.LocalPlayer.Character

    local Container = AbilityGuiUtils.Prefabs.Container:Clone()
    Container.Name = Character:GetAttribute("CharacterName")
    Container.Parent = UIManager.FetchScreenGui("CharacterGUI")

    local AbilityButtons: {AbilityButton} = {}

    local AbilityList = require(Character.CharacterModule).Abilities
    for _, Ability: Types.Ability in AbilityList do
        --no need for passive labels
        if Ability.Passive then
            continue
        end

        table.insert(AbilityButtons, PlayerAbilitiesUI._SetupAbilityButton({
            Module = Ability,
            Parent = Container,
        }))
    end

    local JanitorInstance = Janitor.new()
    JanitorInstance:LinkToInstances(Container, Character)

    JanitorInstance:Add(InputManager.SchemeChanged:Connect(function(CurrentScheme: string)
        for _, AbilityButton: AbilityButton in AbilityButtons do
            PlayerAbilitiesUI._UpdateInputLabel(AbilityButton, InputManager, CurrentScheme)
        end
    end), "Disconnect")

    for _, AbilityButton: AbilityButton in AbilityButtons do
        PlayerAbilitiesUI._UpdateInputLabel(AbilityButton, InputManager, InputManager.CurrentControlScheme)

        if AbilityButton.Uses then
            JanitorInstance:Add(AbilityButton.ModuleCode.Signals.ChargesChanged:Connect(function(Charges: number)
                AbilityButton.Uses.Text = tostring(Charges)
            end), "Disconnect")
        end

        AbilityButton.Timer.TextTransparency = 1

        JanitorInstance:Add(AbilityButton.ModuleCode.Signals.CooldownSet:Connect(function(_Cooldown: number)
            AbilityButton.Timer.TextTransparency = 0
            
            while AbilityButton.Timer and AbilityButton.ModuleCode.CooldownTimer > 0 do
                if not AbilityButton.Timer then
                    break
                end

                AbilityButton.Timer.Text = tostring(math.ceil(AbilityButton.ModuleCode.CooldownTimer * 10) / 10)
                task.wait(0.05)
            end

            if AbilityButton.Timer then
                AbilityButton.Timer.TextTransparency = 1
            end
        end), "Disconnect")

        JanitorInstance:Add(AbilityButton.Interactor.MouseButton1Click:Connect(function()
            AbilityButton.ModuleCode:AttemptUse()
        end))
    end
end

function PlayerAbilitiesUI._SetupAbilityButton(Properties: {
    Module: Types.Ability,
    Parent: Instance,
}): AbilityButton
    local Container = AbilityGuiUtils.Prefabs.AbilityContainer:Clone()
    Container.Name = Properties.Module.Name
    Container.Position = AbilityGuiUtils.FramePositions[Properties.Module.InputName]
    Container.LayoutOrder = AbilityGuiUtils.LayoutOrder[Properties.Module.InputName]
    Container.Parent = Properties.Parent

    local RenderImage = Container.RenderImage
    RenderImage.Image = Properties.Module.RenderImage
    if Properties.Module.UICorner then
        local Corner = Instance.new("UICorner")
        Corner.CornerRadius = UDim.new(1, 0)
        Corner.Parent = RenderImage
    end

    local CooldownTimer = Container.CooldownTime
    CooldownTimer.Text = Properties.Module.Cooldown

    Container.NameLabel.Text = Properties.Module.Name

    local AbilityButton: AbilityButton = {
        ModuleCode = Properties.Module,
        Keybind = Container.Keybind,
        Timer = CooldownTimer,
        Interactor = Container.Interactor,
    }

    if Properties.Module.UseSettings.Limited then
        local UsesLeft = AbilityGuiUtils.Prefabs.UsesLeftText:Clone()
        UsesLeft.Text = Properties.Module.UseSettings.InitialUses
        UsesLeft.Parent = Container

        AbilityButton.Uses = UsesLeft
    end

    return AbilityButton
end

function PlayerAbilitiesUI._UpdateInputLabel(AbilityButton: AbilityButton, InputManager: typeof(require(game:GetService("StarterPlayer").StarterPlayerScripts.InputManager)), CurrentScheme: string)
    --touch should just hide the text
    if CurrentScheme == "Touch" then
        --never show up in my face again
        AbilityButton.Keybind.TextTransparency = 1

        return
    end

    --show the text
    AbilityButton.Keybind.TextTransparency = 0

    --get the key in inputmanager
    --if it's a controller, it has a different name
    local Path = `Default.{AbilityButton.ModuleCode.InputName}.{CurrentScheme ~= "Gamepad" and "Keyboard" or "Controller"}`
    local Key = InputManager:GetInputBinding(Path)

    --WOW THANKS DYSCARN FOR MAKING A COOL INPUT MANAGER THAT ACTUALLY WORKS AND SHOWS YOUR `preferred input device` // you're welcome Dyscarn
    --set da text
    AbilityButton.Keybind.Text = Key.KeyCode.Name
    --if it's a controller, remove the "Button" part from each input
    if CurrentScheme == "Gamepad" then
        AbilityButton.Keybind.Text = AbilityButton.Keybind.Text:gsub("Button", "")
    end
end

return PlayerAbilitiesUI
