--TODO: comment this whole thingamagic

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterManager = require(ServerScriptService.Managers.PlayerManager.CharacterManager)
local PlayerRespawnManager = require(ServerScriptService.Managers.PlayerManager.PlayerRespawnManager)
local ServerUtils = require(ServerScriptService.ServerUtils)
local Types = require(ReplicatedStorage.Classes.Types)
local Network = require(ReplicatedStorage.Modules.Network)
local Sounds = require(ReplicatedStorage.Modules.Sounds)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local GlobalTimeManager = require(script.Parent.GlobalTimeManager)
local MapManager = require(script.Parent.MapManager)

local RoundInfo: Configuration = ReplicatedStorage.RoundInfo

local RoundManager = {
    Utils = {},
    Threads = {},
    PlayerConnections = {},
    CurrentRound = {
        InitialPlayers = {},
        RemainingPlayers = {},
        Killers = {
            -- {
            --     Player = nil,
            --     Character = nil,
            -- },
        },
        KillerIndex = {},
        StartedLMS = false,
    },
    StopLoop = false,
    CanSpawnKiller = true,
    CanInitLMS = true,
    _Janitor = Janitor.new(),
}

function RoundManager:Init()
    GlobalTimeManager.OnTimerEnd = RoundManager.StartRound
end

function RoundManager.StartRound()
    local LoadedPlayers = Utils.Player.GetLoadedPlayers(false)
    Utils.Player.Fade(LoadedPlayers, "In", 0.6, true)

    Utils.Type.ShuffleTable(LoadedPlayers)
    RoundManager.CurrentRound.InitialPlayers = LoadedPlayers

    table.sort(LoadedPlayers, function(a: Player, b: Player)
        return Utils.PlayerData.GetPlayerStat(a, "General.Malice") > Utils.PlayerData.GetPlayerStat(b, "General.Malice")
    end)

    MapManager.InstantiateMap()

    for KillerIndex = 1, workspace:GetAttribute("KillersAllowed") or 1 do
        RoundManager.CurrentRound.Killers[KillerIndex] = {
            Player = LoadedPlayers[KillerIndex],
            -- Character = nil,
        }
        RoundManager.CurrentRound.KillerIndex[LoadedPlayers[KillerIndex]] = KillerIndex
    end

    for Index, Player: Player in LoadedPlayers do
        local IsKiller = Index <= (workspace:GetAttribute("KillersAllowed") or 1)
        RoundManager.Utils.SetupPlayer(Player, IsKiller and Index or nil)

        if RoundManager.CanSpawnKiller and IsKiller then
            return
        end

        RoundManager.CurrentRound.RemainingPlayers[Player.UserId] = Player
    end

    if RoundManager.CanSpawnKiller then
        for Index = #RoundManager.CurrentRound.RemainingPlayers, 1, -1 do
            if not table.find(RoundManager.CurrentRound.Killers, RoundManager.CurrentRound.RemainingPlayers[Index]) then
                continue
            end

            table.remove(RoundManager.CurrentRound.RemainingPlayers, Index)
        end
    end
    
    RoundInfo:SetAttribute("State", "InRound")

    GlobalTimeManager.SetTime(GlobalTimeManager.Config.RoundTime)
    GlobalTimeManager.OnTimerEnd = RoundManager.EndRound
    workspace:SetAttribute("LMS", false)

    task.defer(function()
        while task.wait(1) do
            if RoundManager.StopLoop then
                RoundManager.StopLoop = false
                break
            end

            RoundManager.Utils.CheckForKillerWin()
        end
    end)

    RoundManager.PlayIntro()
end

function RoundManager.PlayIntro()
    if not RoundManager.CanSpawnKiller then
        Utils.Player.Fade(RoundManager.CurrentRound.InitialPlayers, "Out", 0.6, false)
    end

    RoundManager.Threads.IntroEndingThread = RoundManager._Janitor:Add(task.delay(3, function()
        GlobalTimeManager.CanDecreaseTime = true
        for _, Player: Player in RoundManager.CurrentRound.InitialPlayers do
            Utils.Character.GetRootPart(Player).Anchored = false
        end
    end), true)
end

function RoundManager.InitLMS(LastMan: Player)
    if not RoundManager.CanInitLMS or
        RoundManager.CurrentRound.StartedLMS or
        not RoundManager.CurrentRound.Killers[1] or
        not RoundManager.CurrentRound.Killers[1].Character then
        
        return
    end

    RoundManager.CurrentRound.StartedLMS = true
    workspace:SetAttribute("LMS", true)

    for _, Killer in RoundManager.CurrentRound.Killers do
        Utils.Player.RevealPlayerAuraTo(Killer.Player, LastMan)
        Utils.Player.RevealPlayerAuraTo(LastMan, Killer.Player)
    end

    GlobalTimeManager.SetTime(GlobalTimeManager.Config.DefaultLMSTime) --TODO: custom LMS time depending on character interactions

    Network:FireConnection("LMS", LastMan)
    
    local KillerCharacter: Model = RoundManager.CurrentRound.Killers[1].Character
    local Mod = require(Utils.Instance.GetCharacterModule("Killer", KillerCharacter:GetAttribute("CharacterName"), KillerCharacter:GetAttribute("CharacterSkin")))
    local SpecialLMS = Mod.Config.SpecialLastManStandings[LastMan.Character:GetAttribute("CharacterName")]

    local Theme = SpecialLMS and (SpecialLMS[LastMan.Character:GetAttribute("CharacterSkin")] or SpecialLMS.Default or Mod.Config.LastManStandingTheme) or Mod.Config.LastManStandingTheme
    Sounds.PlayTheme(Theme, {Name = "LMS", Priority = 999999, TweenTime = 0, Volume = 1, TimePosition = 0})
end

function RoundManager.EndRound(Winners: Types.Role?)
    Winners = Winners or "Survivor"

    RoundManager.StopLoop = true
    RoundManager._Janitor:Cleanup()
    table.clear(RoundManager.Threads)
    table.clear(RoundManager.PlayerConnections)
    
    Sounds.StopTheme("LMS", 0)

    workspace:SetAttribute("LMS", false)
    
    if Winners == "Killer" then
        for _, Killer in RoundManager.CurrentRound.Killers do
            ServerUtils.PlayerData.UpdatePlayerStat(Killer.Player, "KillerStats.KillerWins", 1)
            ServerUtils.Player.GrantRewardToPlayer(Killer.Player, {Money = 120, EXP = 180, Reason = "winning a match as Killer"})
        end
        Utils.Misc.Print("Killers win!")
    elseif Winners == "Survivor" then
        for _, Killer in RoundManager.CurrentRound.Killers do
            ServerUtils.PlayerData.UpdatePlayerStat(Killer.Player, "KillerStats.KillerLosses", 1)
        end
        for _, Survivor in RoundManager.CurrentRound.RemainingPlayers do
            ServerUtils.PlayerData.UpdatePlayerStat(Survivor, "SurvivorStats.SurvivorWins", 1)
            ServerUtils.Player.GrantRewardToPlayer(Survivor, {Money = 70, EXP = 110, Reason = "winning a match as Survivor"})
        end

        Utils.Misc.Print("Survivors win!")
    else
        Utils.Misc.Print("No one won! (somehow)")
    end

    local LoadedPlayers = Utils.Player.GetLoadedPlayers()

    Utils.Player.Fade(LoadedPlayers, "In", 0.7, true)
    
    for _, Player in RoundManager.CurrentRound.InitialPlayers do
        if Player.Character and Player.Character:GetAttribute("Role") ~= "Spectator" then
            PlayerRespawnManager.LoadCharacter(Player)
        end
    end

    RoundManager.CurrentRound = {
        Killers = {},
        KillerIndex = {},
        InitialPlayers = {},
        RemainingPlayers = {},
        StartedLMS = false,
    }

    task.defer(MapManager.DestroyCurrentMap)

    RoundInfo:SetAttribute("State", "Lobby")

    Utils.Player.Fade(LoadedPlayers, "Out", 0.7, true)

    GlobalTimeManager.OnTimerEnd = RoundManager.StartRound
    GlobalTimeManager.CanDecreaseTime = true
end

function RoundManager.Utils.CheckForKillerWin()
    local Count = Utils.Character.GetCharactersWithRoles(false)

    local Survivors = #Count.Survivor

    if RoundManager.CanSpawnKiller then
        if #Count.Killer <= 0 then
            RoundManager.EndRound("Survivor")
        elseif Survivors == 1 then
            RoundManager.InitLMS(Players:GetPlayerFromCharacter(Count.Survivor[1]))
        elseif #RoundManager.CurrentRound.InitialPlayers > 1 and Survivors <= 0 then
            RoundManager.EndRound("Killer")
        end
    elseif Survivors <= 0 then
        RoundManager.EndRound("Killer")
    end
end

function RoundManager.Utils.GetPlayerEquippedCharacterModule(Player: Player, Role: Types.Role): ModuleScript
    local EquippedCharacter = Utils.PlayerData.GetPlayerEquipped(Player, Role)
    local EquippedSkin = Utils.PlayerData.GetPlayerEquipped(Player, "Skins."..EquippedCharacter)

    return Utils.Instance.GetCharacterModule(Role, EquippedCharacter, EquippedSkin)
end

function RoundManager.Utils.SetupPlayer(Player: Player, KillerIndex: number?)
    local Char

    if KillerIndex and RoundManager.CanSpawnKiller then
        Utils.PlayerData.GetPlayerStat(Player, "General.Malice", false).Value = 1

        Char = CharacterManager.LoadEquippedCharacter(Player, "Killer")

        RoundManager.PlayerConnections[Player.UserId] = {
            RoundManager._Janitor:Add(Player.CharacterRemoving:Connect(function()
                RoundManager._OnPlayerDeath(Player, true)
            end)),
            RoundManager._Janitor:Add(Char:FindFirstChildWhichIsA("Humanoid").Died:Connect(function()
                RoundManager._OnPlayerDeath(Player, true)
            end)),
        }

        RoundManager.CurrentRound.Killers[KillerIndex].Character = Char
    else
        ServerUtils.PlayerData.UpdatePlayerStat(Player, "General.Malice", 1)

        Char = CharacterManager.LoadEquippedCharacter(Player, "Survivor")

        RoundManager.PlayerConnections[Player.UserId] = {
            RoundManager._Janitor:Add(Player.CharacterRemoving:Connect(function()
                RoundManager._OnPlayerDeath(Player)
            end)),
            RoundManager._Janitor:Add(Char:FindFirstChildWhichIsA("Humanoid").Died:Connect(function()
                ServerUtils.PlayerData.UpdatePlayerStat(Player, "SurvivorStats.SurvivorLosses", 1)
                RoundManager._OnPlayerDeath(Player)
            end)),
        }
    end

    task.wait()
    Utils.Character.GetRootPart(Char).Anchored = true
end

function RoundManager._OnPlayerDeath(Dead: Player, WasKiller: boolean?)
    if WasKiller == nil then
        WasKiller = false
    end

    for _, Connection in RoundManager.PlayerConnections[Dead.UserId] do
        Connection:Disconnect()
    end
    RoundManager.PlayerConnections[Dead.UserId] = nil

    if WasKiller then
        ServerUtils.PlayerData.UpdatePlayerStat(Dead, "KillerStats.KillerLosses", 1)
        table.remove(RoundManager.CurrentRound.Killers[RoundManager.CurrentRound.KillerIndex[Dead]])

        RoundManager.CurrentRound.KillerIndex[Dead] = nil
        table.clear(RoundManager.CurrentRound.KillerIndex)

        table.sort(RoundManager.CurrentRound.Killers)
        for Index, Killer in RoundManager.CurrentRound.Killers do
            RoundManager.CurrentRound.KillerIndex[Killer.Player] = Index
        end
    else
        RoundManager.CurrentRound.RemainingPlayers[Dead.UserId] = nil
    end

    RoundManager.Utils.CheckForKillerWin()
end

return RoundManager
