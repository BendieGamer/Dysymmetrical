local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Network = require(ReplicatedStorage.Modules.Network)

local LevelUpToast = {}

local TOAST_DURATION = 5
local TWEEN_IN = 0.45
local TWEEN_OUT = 0.35

local function makeToast(renderImage: string, prevLevel: number, currentLevel: number): Frame
	local toast = Instance.new("Frame")
	toast.Name = "LevelUpToast"
	toast.Size = UDim2.fromOffset(260, 76)
	toast.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	toast.BorderSizePixel = 0
	toast.ClipsDescendants = true
	toast.LayoutOrder = 1

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = toast

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 180, 255)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.3
	stroke.Parent = toast

	-- Character render on the left
	local render = Instance.new("ImageLabel")
	render.Name = "Render"
	render.Size = UDim2.fromOffset(64, 64)
	render.Position = UDim2.fromOffset(6, 6)
	render.BackgroundTransparency = 1
	render.Image = renderImage or ""
	render.ScaleType = Enum.ScaleType.Fit
	render.Parent = toast

	-- Text stack on the right
	local textFrame = Instance.new("Frame")
	textFrame.Name = "TextFrame"
	textFrame.Size = UDim2.new(1, -78, 1, -12)
	textFrame.Position = UDim2.fromOffset(76, 6)
	textFrame.BackgroundTransparency = 1
	textFrame.Parent = toast

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = textFrame

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 18)
	header.BackgroundTransparency = 1
	header.Text = "LEVEL UP!"
	header.TextColor3 = Color3.fromRGB(80, 200, 255)
	header.TextStrokeTransparency = 0.6
	header.Font = Enum.Font.GothamBold
	header.TextSize = 14
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.LayoutOrder = 1
	header.Parent = textFrame

	local levelLine = Instance.new("TextLabel")
	levelLine.Name = "LevelLine"
	levelLine.Size = UDim2.new(1, 0, 0, 26)
	levelLine.BackgroundTransparency = 1
	levelLine.RichText = true
	levelLine.Text = string.format(
		'<font color="rgb(160,160,160)">%d</font>  <font color="rgb(80,200,255)">&#x2192;</font>  <font color="rgb(255,255,255)" weight="bold">%d</font>',
		prevLevel,
		currentLevel
	)
	levelLine.Font = Enum.Font.Gotham
	levelLine.TextSize = 20
	levelLine.TextXAlignment = Enum.TextXAlignment.Left
	levelLine.LayoutOrder = 2
	levelLine.Parent = textFrame

	return toast
end

function LevelUpToast:Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Container anchored top-right, stacks toasts downward
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LevelUpToasts"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = false
	screenGui.Parent = playerGui

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.fromOffset(270, 600)
	container.Position = UDim2.new(1, -280, 0, 16)
	container.BackgroundTransparency = 1
	container.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Parent = container

	Network:SetConnection("LevelUp", "REMOTE_EVENT", function(renderImage: string, prevLevel: number, currentLevel: number)
		local toast = makeToast(renderImage, prevLevel, currentLevel)
		toast.Size = UDim2.fromOffset(0, 76)
		toast.Parent = container

		TweenService:Create(toast, TweenInfo.new(TWEEN_IN, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(260, 76),
		}):Play()

		task.wait(TOAST_DURATION)

		TweenService:Create(toast, TweenInfo.new(TWEEN_OUT, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
			Size = UDim2.fromOffset(0, 76),
		}):Play()

		task.wait(TWEEN_OUT + 0.05)
		toast:Destroy()
	end)
end

return LevelUpToast
