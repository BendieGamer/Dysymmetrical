local LoadingGui = script:WaitForChild("LoadingGui")
local Main = LoadingGui:WaitForChild("LoadingScreen"):WaitForChild("Main")
local Percent = Main:WaitForChild("Percent")
local AmountTxt = Main:WaitForChild("Amount")
local CurrentlyInitting = Main:WaitForChild("CurrentlyInitting")
local Skip = Main:WaitForChild("Skip")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

LoadingGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

while not game:IsLoaded() do
    task.wait()
end

task.wait(1)

local assets = {}
local loadedAssets = {}
local function addAssetsToLoad(assetList)
    for _, asset in assetList do
        table.insert(assets, asset)
    end
end
addAssetsToLoad(workspace:GetDescendants())
addAssetsToLoad(ReplicatedStorage:GetDescendants())
addAssetsToLoad(game:GetService("StarterPlayer"):GetDescendants())
addAssetsToLoad(StarterGui:GetDescendants())

local assetAmount = #assets
local loaded = false
function updateProgress()
    if not loaded then
        Percent.Text = tostring(math.floor(#loadedAssets / assetAmount * 100 - 1)).."%"
        AmountTxt.Text = "("..tostring(#loadedAssets - 1).."/"..tostring(assetAmount)..")"
    end
end

local ContentProvider = game:GetService("ContentProvider")
for index, asset in assets do
    task.delay(index / (assetAmount / 0.75), function()
        ContentProvider:PreloadAsync({
            asset
        })
        table.insert(loadedAssets, asset)
        updateProgress()
    end)
end

local TweenService = game:GetService("TweenService")

local function Finish()
    local Utils = require(ReplicatedStorage.Modules.Utils)
    if not game:GetService("RunService"):IsStudio() then
        --don't remove this or you'll get in trouble! salutations! (unless you mention the engine in the game's description or idfk where)
        print(Utils.Credits)
    end
    
    task.spawn(function()
        require(ReplicatedStorage.Modules.Network):FireServerConnection("PlayerLoad", "REMOTE_EVENT")
    end)

    loaded = true

    Percent.Text = "100%"
    AmountTxt.Text = "("..tostring(assetAmount).."/"..tostring(assetAmount)..")"

    TweenService:Create(CurrentlyInitting, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        TextTransparency = 1
    }):Play()
    TweenService:Create(Percent.UIStroke, TweenInfo.new(0.666), {
        Transparency = 1
    }):Play()
    TweenService:Create(Percent.UIStroke, TweenInfo.new(2), {
        Thickness = 20
    }):Play()
    TweenService:Create(AmountTxt.UIStroke, TweenInfo.new(0.666), {
        Transparency = 1
    }):Play()
    TweenService:Create(AmountTxt.UIStroke, TweenInfo.new(2), {
        Thickness = 20
    }):Play()
    TweenService:Create(Skip, TweenInfo.new(0.666), {
        TextTransparency = 1
    }):Play()
    task.wait(1)
    TweenService:Create(Percent, TweenInfo.new(1, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        TextTransparency = 1
    }):Play()
    TweenService:Create(AmountTxt, TweenInfo.new(1, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        TextTransparency = 1
    }):Play()
    task.wait(0.5)
    TweenService:Create(Main, TweenInfo.new(0.75), {
        BackgroundTransparency = 1
    }):Play()

    Utils.Instance.AddToDebris(LoadingGui, 0.8)
    StarterGui:SetCore("ResetButtonCallback", true)

    task.wait(0.8)

    workspace:SetAttribute("ClientLoaded", true)
end

task.delay(10, function()
    if not loaded then
        Skip.Visible = true
        TweenService:Create(Skip, TweenInfo.new(1), {
            TextTransparency = 0
        }):Play()
        Skip.MouseButton1Click:Once(function()
            loaded = true
            Finish()
        end)
    end
end)

while #loadedAssets < #assets - 100 and not loaded do
    task.wait()
end

local function InitScripts(module: ModuleScript)
    local ModuleCode = require(module)
    task.spawn(function()
        ModuleCode:Init()
    end)

    while not ModuleCode.Loaded do
        if ModuleCode.CurrentlyInitting then
            CurrentlyInitting.Text = "Initializing "..ModuleCode.CurrentlyInitting.."..."
        else
            CurrentlyInitting.Text = ""
        end
        task.wait()
    end
end

InitScripts(ReplicatedStorage.Initter)
InitScripts(Players.LocalPlayer.PlayerScripts.Initter)

while not workspace:GetAttribute("ServerLoaded") do
    task.wait()
end

if loaded then return end

Finish()
