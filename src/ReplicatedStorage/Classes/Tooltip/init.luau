local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Sounds = require(ReplicatedStorage.Modules.Sounds)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

--- Class used to create mouse tooltips.
--- Only one can be created at a time and this class should only be used internally / in the `More Info` section for characters.
local TooltipClass = {}

local Tooltip = nil
local Prefab = Utils.Instance.AwaitChild(script, "Tooltip")

--- Creates a new Tooltip.
--- 
--- If there's an existing one, it'll just change the text if it's different.
--- 
--- If `Text` is `nil`, it'll hide the existing tooltip and destroy it.
--- 
--- Playing hover and hover stop sounds isn't needed as it's done automatically by default.
function TooltipClass.New(Text: string): Folder
    --prevent the server from using this
    if RunService:IsServer() then
        return
    end

    --if Text is nil or empty, halt
    if not Text or #Text <= 0 then
        --if a tooltip exists, unassign it as the current one and make it disappear
        if Tooltip then
            TweenService:Create(Tooltip.Title, TweenInfo.new(0.15), {
                TextSize = 0,
                TextTransparency = 1,
            }):Play()
            TweenService:Create(Tooltip.Background, TweenInfo.new(0.15), {
                Size = Utils.UDim.Zero,
                ImageTransparency = 1,
                BackgroundTransparency = 1,
            }):Play()

            Debris:AddItem(Tooltip, 0.15)
            
            Sounds.PlaySound(Sounds.CommonSounds.ButtonHoverStop, {Volume = 0.2})

            Tooltip = nil
        end

        --return nothing because there is literally nothing to return
        return
    end

    --from here we know Text is valid

    --if a tooltip already exists, just change the text
    if Tooltip then
        if Text ~= Tooltip.Title.Text then
            Tooltip.Title.Text = Text
            
            Sounds.PlaySound(Sounds.CommonSounds.ButtonHover, {Volume = 0.2})
        end

        --return the damn thing
        return Tooltip
    end

    --create the tooltip
    local NewTooltip = Prefab:Clone()
    --add its contents
    NewTooltip.Title.Text = Text
    --parent it to its gui
    NewTooltip.Parent = require(Players.LocalPlayer.PlayerScripts.UIManager).FetchScreenGui("Menus")
    --le sound
    Sounds.PlaySound(Sounds.CommonSounds.ButtonHover, {Volume = 0.2})

    --updates each item's position and size to be consistent with the current text size and mouse position
    local function UpdateMousePos()
        local MousePos = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
        NewTooltip.Title.Position = UDim2.fromOffset(MousePos.X, MousePos.Y - 30)
        NewTooltip.Background.Position = UDim2.fromOffset(MousePos.X, MousePos.Y - 30 - NewTooltip.Title.AbsoluteSize.Y + 40)
        NewTooltip.Background.Size = UDim2.fromOffset(NewTooltip.Title.AbsoluteSize.X + 64, NewTooltip.Title.AbsoluteSize.Y + 50)
    end

    --janitor instancing for easier cleanup
    local TooltipJanitor = Janitor.new()
    --link it to le tooltip
    TooltipJanitor:LinkToInstance(NewTooltip)
    --call per frame
    TooltipJanitor:Add(RunService.PreRender:Connect(function()
        --if this tooltip isn't the current one, thus is being destroyed, clean up inmediately
        if Tooltip ~= NewTooltip then
            TooltipJanitor:Cleanup()
            return
        end
        
        --update le mouse pos
        UpdateMousePos()
    end))
    --update le mouse pos in the current frame
    UpdateMousePos()

    --set the current tooltip to the new one
    Tooltip = NewTooltip

    --return the damn thing
    return NewTooltip
end

function TooltipClass.Exists(): boolean
    return Tooltip ~= nil
end

return TooltipClass
