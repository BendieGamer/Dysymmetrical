local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Network = require(ReplicatedStorage.Modules.Network)
local Sounds = require(ReplicatedStorage.Modules.Sounds)
local Utils = require(ReplicatedStorage.Modules.Utils)

-- The Bool script holds the ImageLabel prefab we reuse for consistent styling.
local BoolScript = Utils.Instance.FindFirstChild(script.Parent, "Bool")
local BasePrefab = BoolScript:FindFirstChildWhichIsA("ImageLabel")

local ExecutableCommand = {}

local function buildDropdown(param, parent)
    local options = param.Cache.Options
    local default = options[1] or "..."

    -- container sized like a normal TextBox row
    local holder = Instance.new("Frame")
    holder.Name = param.Title
    holder.Size = UDim2.new(1, 0, 0, 26)
    holder.BackgroundTransparency = 1
    holder.ClipsDescendants = false

    -- copy style from the Execute button that already exists in the prefab
    local selected = Instance.new("TextButton")
    selected.Name = "Selected"
    selected.Size = UDim2.fromScale(1, 1)
    selected.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    selected.BorderSizePixel = 0
    selected.TextColor3 = Color3.fromRGB(220, 220, 220)
    selected.Font = Enum.Font.Bodoni
    selected.TextSize = 13
    selected.Text = default
    selected.TextXAlignment = Enum.TextXAlignment.Left
    selected.AutoButtonColor = false
    local selCorner = Instance.new("UICorner")
    selCorner.CornerRadius = UDim.new(0, 4)
    selCorner.Parent = selected
    local selPad = Instance.new("UIPadding")
    selPad.PaddingLeft = UDim.new(0, 8)
    selPad.Parent = selected
    selected.Parent = holder

    local ROW_H = 24
    local visibleRows = math.min(#options, 6)

    local list = Instance.new("Frame")
    list.Name = "List"
    list.Size = UDim2.new(1, 0, 0, visibleRows * ROW_H)
    list.Position = UDim2.new(0, 0, 1, 2)
    list.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    list.BorderSizePixel = 0
    list.Visible = false
    list.ZIndex = 20
    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 4)
    listCorner.Parent = list
    list.Parent = holder

    local function makeOption(optName, index, listParent)
        local btn = Instance.new("TextButton")
        btn.Name = optName
        btn.Size = UDim2.new(1, 0, 0, ROW_H)
        btn.Position = UDim2.new(0, 0, 0, (index - 1) * ROW_H)
        btn.BackgroundTransparency = 1
        btn.TextColor3 = Color3.fromRGB(220, 220, 220)
        btn.Font = Enum.Font.Bodoni
        btn.TextSize = 13
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Text = "  " .. optName
        btn.ZIndex = 21
        btn.AutoButtonColor = false
        btn.MouseEnter:Connect(function()
            btn.BackgroundTransparency = 0.7
            btn.BackgroundColor3 = Color3.fromRGB(80, 80, 200)
        end)
        btn.MouseLeave:Connect(function()
            btn.BackgroundTransparency = 1
        end)
        btn.MouseButton1Click:Connect(function()
            selected.Text = optName
            list.Visible = false
        end)
        btn.Parent = listParent
    end

    if #options > 6 then
        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.fromScale(1, 1)
        scroll.CanvasSize = UDim2.new(0, 0, 0, #options * ROW_H)
        scroll.BackgroundTransparency = 1
        scroll.ScrollBarThickness = 4
        scroll.BorderSizePixel = 0
        scroll.ZIndex = 21
        scroll.Parent = list
        for i, opt in options do
            makeOption(opt, i, scroll)
        end
    else
        for i, opt in options do
            makeOption(opt, i, list)
        end
    end

    selected.MouseButton1Click:Connect(function()
        list.Visible = not list.Visible
    end)

    UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 and list.Visible then
            -- small delay so the option click registers first
            task.defer(function() list.Visible = false end)
        end
    end)

    holder.Parent = parent
    return function() return selected.Text end
end

local function buildTextInput(param, parent)
    local box = Instance.new("TextBox")
    box.Name = param.Title
    box.Size = UDim2.new(1, 0, 0, 26)
    box.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    box.BorderSizePixel = 0
    box.TextColor3 = Color3.fromRGB(220, 220, 220)
    box.PlaceholderColor3 = Color3.fromRGB(130, 130, 130)
    box.PlaceholderText = param.Default or ""
    box.Text = ""
    box.Font = Enum.Font.Bodoni
    box.TextSize = 13
    box.ClearTextOnFocus = false
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = box
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 8)
    pad.Parent = box
    box.Parent = parent
    return function() return box.Text ~= "" and box.Text or (param.Default ~= "..." and param.Default or "") end
end

function ExecutableCommand.New(CommandModule, UI)
    local Config = require(CommandModule)

    local CommandFrame = BasePrefab:Clone()
    CommandFrame.Parent = UI.Content

    CommandFrame.Label.Text = Config.Name

    local valueLabel = CommandFrame:FindFirstChild("Value")
    if valueLabel then
        valueLabel.Visible = false
    end

    local LABEL_H = CommandFrame.Label.Size.Y.Offset
    local PAD = 6
    local ROW_H = 26
    local TITLE_H = 18

    local getters = {}

    if #Config.Params > 0 then
        local extraH = #Config.Params * (TITLE_H + ROW_H + PAD) + PAD
        CommandFrame.Size = UDim2.new(
            CommandFrame.Size.X.Scale, CommandFrame.Size.X.Offset,
            0, CommandFrame.Size.Y.Offset + extraH
        )

        local exec = CommandFrame:FindFirstChild("Execute")
        if exec then
            exec.Position = UDim2.new(
                exec.Position.X.Scale, exec.Position.X.Offset,
                0, exec.Position.Y.Offset + extraH
            )
        end

        local insertY = LABEL_H + PAD

        for i, param in Config.Params do
            local titleLbl = Instance.new("TextLabel")
            titleLbl.Name = param.Title .. "_Title"
            titleLbl.Size = UDim2.new(1, -16, 0, TITLE_H)
            titleLbl.Position = UDim2.new(0, 8, 0, insertY)
            titleLbl.BackgroundTransparency = 1
            titleLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
            titleLbl.Font = Enum.Font.Bodoni
            titleLbl.TextSize = 12
            titleLbl.TextXAlignment = Enum.TextXAlignment.Left
            titleLbl.Text = param.Title
            titleLbl.Parent = CommandFrame
            insertY = insertY + TITLE_H

            local inputHolder = Instance.new("Frame")
            inputHolder.Name = param.Title .. "_Input"
            inputHolder.Size = UDim2.new(1, -16, 0, ROW_H)
            inputHolder.Position = UDim2.new(0, 8, 0, insertY)
            inputHolder.BackgroundTransparency = 1
            inputHolder.ClipsDescendants = false
            inputHolder.Parent = CommandFrame

            if param.Cache and param.Cache.Options then
                getters[i] = buildDropdown(param, inputHolder)
            else
                getters[i] = buildTextInput(param, inputHolder)
            end

            insertY = insertY + ROW_H + PAD
        end
    end

    -- Wire Execute button
    local execBtn = CommandFrame:FindFirstChild("Execute")
    if execBtn then
        execBtn.MouseEnter:Connect(function()
            Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHover, {Volume = 0.2})
        end)
        execBtn.MouseLeave:Connect(function()
            Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonHoverStop, {Volume = 0.2})
        end)
        execBtn.MouseButton1Click:Connect(function()
            Sounds.PlaySound(Sounds.CommonlyUsedSounds.ButtonPress, {Volume = 0.8})
            local args = {}
            for i = 1, #getters do
                table.insert(args, getters[i]())
            end
            Network:FireServerConnection("ExecuteCommand", "REMOTE_FUNCTION", CommandModule.Name, table.unpack(args))
        end)
    end

    return CommandFrame
end

return ExecutableCommand
