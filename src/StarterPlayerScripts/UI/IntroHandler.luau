local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Utils = require(ReplicatedStorage.Modules.Utils)
local KillerIntro = require(ReplicatedStorage.Classes.KillerIntro)
local PlayerUtils = require(ReplicatedStorage.Modules.Utils.PlayerUtils)

local IntroFolder = ReplicatedStorage.Assets.KillerIntros
local function GetIntroModule(name: string, skin: string?)
	local Intro

	if skin ~= nil and #skin > 0 then
		Intro = IntroFolder.Skins:FindFirstChild(name)
		if Intro then
			Intro = Intro:FindFirstChild(skin)
		end
	end

	if not Intro then
		Intro = IntroFolder:FindFirstChild(name)
	end

	return Intro
end

local function WaitForFade(timeout)
    local t = 0
    local limit = timeout or 5
    while (not PlayerUtils.FadeFrame or not PlayerUtils.FadeFrame.Parent) and t < limit do
        t = t + task.wait()
    end
    return PlayerUtils.FadeFrame and PlayerUtils.FadeFrame.Parent ~= nil
end

local IntroContainer = Utils.Instance.FindFirstChild(Players.LocalPlayer.PlayerGui, "KillerIntros")
local ToastPrefab = GetIntroModule("KillerNameToast")

return {
    Init = function(_)
        local KillerPlayerNames = {}
		local CurrentIntro

        local function SetupCharacter(Char: Model)
            if not workspace:GetAttribute("ClientLoaded") then
                return
            end

            local Role = Char:WaitForChild("Role", 10)
            if not Role then
                return
            end
            if Role.Value ~= "Killer" then
                return
            end

            local KillerName = Char:GetAttribute("CharacterName")
            local KillerSkin = Char:GetAttribute("CharacterSkinName")

            --TODO: multi-killer toast support
            KillerPlayerNames[1] = Char.Name

		    if Utils.PlayerData.GetPlayerSetting(Players.LocalPlayer, "Miscellaneous.DisableKillerIntros") then
		    	task.spawn(require(ToastPrefab), IntroContainer, KillerPlayerNames)
		    	WaitForFade()
		    	Utils.Player.Fade(Players.LocalPlayer, "Out", 0.6)
		    	return
		    end

		    local IntroInfo: KillerIntro.IntroSettings = {
		    	KillerName = KillerName,
		    	SkinName = KillerSkin,
		    	PlayerName = KillerPlayerNames[1],
		    }

            task.delay(7.5, function()
                table.clear(KillerPlayerNames)
            end)

		    local Intro2D = GetIntroModule(KillerName, KillerSkin)

		    local Intro
			if Intro2D then
				Intro = KillerIntro.New2DIntro(IntroInfo, Intro2D)
			else
				local Module = Utils.Instance.GetCharacterModule("Killer", KillerName, KillerSkin)
				if Module then
					Module = require(Module)
					if Module.Config.AnimationIDs["KillerRig"] and Module.Config.AnimationIDs["CameraRig"] then
						Intro = KillerIntro.New3DIntro(IntroInfo)
					end
				end
			end

			if not Intro then
		    	task.spawn(require(ToastPrefab), IntroContainer, KillerPlayerNames)
		    	WaitForFade()
		    	Utils.Player.Fade(Players.LocalPlayer, "Out", 0.6)
				return
			end

			if CurrentIntro then
				CurrentIntro:Destroy()
				CurrentIntro = nil
			end
			CurrentIntro = Intro

		    local initOk, initErr = pcall(Intro.Init, Intro)
		    if not initOk then
		    	warn("[IntroHandler] Intro:Init() failed:", initErr)
		    	task.spawn(require(ToastPrefab), IntroContainer, KillerPlayerNames)
		    	WaitForFade()
		    	Utils.Player.Fade(Players.LocalPlayer, "Out", 0.6)
		    	return
		    end

		    task.spawn(require(ToastPrefab), IntroContainer, KillerPlayerNames)

		    WaitForFade()
		    Utils.Player.Fade(Players.LocalPlayer, "Out", 0.6)

		    local playOk, playErr = pcall(Intro.Play, Intro)
		    if not playOk then
		    	warn("[IntroHandler] Intro:Play() failed:", playErr)
		    end
		    task.wait(2.5)

		    Utils.Player.Fade(Players.LocalPlayer, "In", 0.6, true)
		    Intro:Destroy()
		    Utils.Player.Fade(Players.LocalPlayer, "Out", 0.6)
        end

		Utils.Player.ObservePlayers(function(plr, playerJanitor)
			local function onCharacterAdded(char)
				task.defer(SetupCharacter, char)
			end
			playerJanitor:Add(plr.CharacterAdded:Connect(onCharacterAdded))
			if plr.Character then
				task.spawn(onCharacterAdded, plr.Character)
			end
		end)
    end,
}
