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
    --- Table for utility functions used in this manager.
    Utils = {},
    --- Thread table just in case you want to make global server threads that get cancelled if the round ends.
    Threads = {},
    --- Death connections per player. Managed by `RoundManager._Janitor`.
    PlayerConnections = {},
    --- Info for the current round.
    CurrentRound = {
        --- All of the *accepted* (alive and dead) players in the current round.
        InitialPlayers = {},
        --- All of the *alive* survivors in the current round.
        RemainingPlayers = {},
        --- All of the *alive* killers in the current round.
        Killers = {
            -- {
            --     Player = nil,
            --     Character = nil,
            -- },
        },
        --- Lookup table for killers in `RoundManager.CurrentRounds.Killers`.
        KillerIndex = {},
        --- Info variable to know if LMS has started without having to access attributes every time.
        StartedLMS = false,
    },
    --- If `true`, will stop the current round's check loop.
    StopLoop = false,
    --- If `false`, no killers will be allowed to spawn.
    CanSpawnKiller = true,
    --- If `false`, LMS will never be activated.
    CanInitLMS = true,
    --- This manager's connection manager.
    _Janitor = Janitor.new(),
}

function RoundManager:Init()
    --just start with starting a round
    GlobalTimeManager.OnTimerEnd = RoundManager.StartRound
end

--- Starts a round.
function RoundManager.StartRound()
    --get all loaded players and give them a (yielding) fade
    local LoadedPlayers = Utils.Player.GetLoadedPlayers(false)
    Utils.Player.Fade(LoadedPlayers, "In", 0.6, true)

    --set le table
    RoundManager.CurrentRound.InitialPlayers = LoadedPlayers

    --sort all loaded players by descending malice
    table.sort(LoadedPlayers, function(a: Player, b: Player)
        return Utils.PlayerData.GetPlayerStat(a, "General.Malice") > Utils.PlayerData.GetPlayerStat(b, "General.Malice")
    end)

    --instantiate le map
    MapManager.InstantiateMap()

    --get the amount of killers allowed
    local KillersAllowed = workspace:GetAttribute("KillersAllowed") or 1

    --spawn all possible killers based on the allowed amount
    for KillerIndex = 1, KillersAllowed do
        --set its table
        RoundManager.CurrentRound.Killers[KillerIndex] = {
            Player = LoadedPlayers[KillerIndex],
            -- Character = nil,
        }
        --also add it to the index lookup table
        RoundManager.CurrentRound.KillerIndex[LoadedPlayers[KillerIndex]] = KillerIndex
    end

    --set up every player's character
    for Index, Player: Player in LoadedPlayers do
        --check if it's a killer if its index is in the killer range
        local IsKiller = Index <= KillersAllowed
        --set the thing up
        RoundManager.Utils.SetupPlayer(Player, IsKiller and Index or nil)

        --if it's a survivor, add it to the remaining players table
        if RoundManager.CanSpawnKiller and IsKiller then
            continue
        end

        table.insert(RoundManager.CurrentRound.RemainingPlayers, Player)
    end

    --if killers can spawn, remove all killers from the remaining survivors table if it ever happens
    if RoundManager.CanSpawnKiller then
        for Index = #RoundManager.CurrentRound.RemainingPlayers, 1, -1 do
            if not table.find(RoundManager.CurrentRound.Killers, RoundManager.CurrentRound.RemainingPlayers[Index]) then
                continue
            end

            table.remove(RoundManager.CurrentRound.RemainingPlayers, Index)
        end
    end
    
    --set da state
    RoundInfo:SetAttribute("State", "InRound")

    --set the time and final callback
    GlobalTimeManager.SetTime(GlobalTimeManager.Config.RoundTime)
    GlobalTimeManager.OnTimerEnd = RoundManager.EndRound
    --JUST IN CASE SOMEONE DOES SOMETHING STUPID ENOUGH TO SET THIS TO TRUE IN THE LOBBY.
    workspace:SetAttribute("LMS", false)

    --check for killer win every second
    task.defer(function()
        while not RoundManager.StopLoop and task.wait(1) do
            RoundManager.Utils.CheckForKillerWin()
        end
    end)

    --play le intro and unanchor all players
    RoundManager.PlayIntro()
end

--- Plays the round intro based on the available killers.
function RoundManager.PlayIntro()
    --will uncomment when intros are implemented
    --if a killer can't be spawned, just fade out as usual
    -- if not RoundManager.CanSpawnKiller then
        Utils.Player.Fade(RoundManager.CurrentRound.InitialPlayers, "Out", 0.6, false)
    -- end

    --after 3 seconds, players will all get unanchored
    RoundManager.Threads.IntroEndingThread = RoundManager._Janitor:Add(task.delay(3, function()
        GlobalTimeManager.CanDecreaseTime = true
        for _, Player: Player in RoundManager.CurrentRound.InitialPlayers do
            Utils.Character.GetRootPart(Player).Anchored = false
        end
    end), true)
end

--- Starts the LMS sequence of the current round.
function RoundManager.InitLMS(LastMan: Player)
    --if it's impossible, halt
    if not RoundManager.CanInitLMS or
        RoundManager.CurrentRound.StartedLMS or
        not RoundManager.CurrentRound.Killers[1] or
        not RoundManager.CurrentRound.Killers[1].Character then
        
        return
    end

    --set le vars
    RoundManager.CurrentRound.StartedLMS = true
    workspace:SetAttribute("LMS", true)

    --reveal all auras to each other
    for _, Killer in RoundManager.CurrentRound.Killers do
        Utils.Player.RevealPlayerAuraTo(Killer.Player, LastMan)
        Utils.Player.RevealPlayerAuraTo(LastMan, Killer.Player)
    end

    --set the lms time
    GlobalTimeManager.SetTime(GlobalTimeManager.Config.DefaultLMSTime) --TODO: custom LMS time depending on character interactions

    --fire the lms
    Network:FireConnection("LMS", LastMan)
    
    --gets the top priority killer (based on the one that had the most malice at the beginning of the round)
    local KillerCharacter: Model = RoundManager.CurrentRound.Killers[1].Character
    --gets its module
    local Mod = require(Utils.Instance.GetCharacterModule("Killer", KillerCharacter:GetAttribute("CharacterName"), KillerCharacter:GetAttribute("CharacterSkin")))
    --checks if it has special lms interaction themes
    local SpecialLMS = Mod.Config.SpecialLastManStandings[LastMan.Character:GetAttribute("CharacterName")]

    --if there are special lms:
        --try to get one for the skin of the last survivor
        --if there isn't any, just get the default for its character (applied to every skin as well)
        --if there isn't any either, fall back to the default lms set in the killer
    --if not, fall back to the default lms theme set in the killer
    --there'll always be one unless stated so so it's fine
    local Theme = SpecialLMS and (SpecialLMS[LastMan.Character:GetAttribute("CharacterSkin")] or SpecialLMS.Default or Mod.Config.LastManStandingTheme) or Mod.Config.LastManStandingTheme
    --play the lms on server with max priority and without tweening
    Sounds.PlayTheme(Theme, {Name = "LMS", Priority = 999999, TweenTime = 0, Volume = 1, TimePosition = 0})
end

--- Ends the current round and gives rewards to the winner(s).
function RoundManager.EndRound(Winners: Types.Role?)
    --defaults
    Winners = Winners or "Survivor"

    --stop le loop
    RoundManager.StopLoop = true
    --clean up all connections and threads
    RoundManager._Janitor:Cleanup()
    --clear their tables just in case
    table.clear(RoundManager.Threads)
    table.clear(RoundManager.PlayerConnections)
    
    --stop the lms if it's playing
    Sounds.StopTheme("LMS", 0)
    --disable lms
    workspace:SetAttribute("LMS", false)
    
    --killer win
    if Winners == "Killer" then
        --update wins and grant rewards to each alive killer
        for _, Killer in RoundManager.CurrentRound.Killers do
            ServerUtils.PlayerData.UpdatePlayerStat(Killer.Player, "KillerStats.KillerWins", 1)
            ServerUtils.Player.GrantRewardToPlayer(Killer.Player, {Money = 120, EXP = 180, Reason = "winning a match as Killer"})
        end
        --tracing is cool!
        Utils.Misc.Print("Killers win!")
    --survivor win
    elseif Winners == "Survivor" then
        --update losses for each alive killer
        for _, Killer in RoundManager.CurrentRound.Killers do
            ServerUtils.PlayerData.UpdatePlayerStat(Killer.Player, "KillerStats.KillerLosses", 1)
        end
        --update wins and grant rewards to each alive survivor
        for _, Survivor in RoundManager.CurrentRound.RemainingPlayers do
            ServerUtils.PlayerData.UpdatePlayerStat(Survivor, "SurvivorStats.SurvivorWins", 1)
            ServerUtils.Player.GrantRewardToPlayer(Survivor, {Money = 70, EXP = 110, Reason = "winning a match as Survivor"})
        end

        --i fucking despise tracing
        Utils.Misc.Print("Survivors win!")
    --"impossible" scenario
    else
        Utils.Misc.Print("No one won! (somehow)")
    end

    --do fade to all players
    local LoadedPlayers = Utils.Player.GetLoadedPlayers()

    Utils.Player.Fade(LoadedPlayers, "In", 0.7, true)
    
    --respawn all players in the round if they aren't already a spectator
    for _, Player in RoundManager.CurrentRound.InitialPlayers do
        if Player.Character and Player.Character:GetAttribute("Role") ~= "Spectator" then
            PlayerRespawnManager.LoadCharacter(Player)
        end
    end

    --reset the round table
    RoundManager.CurrentRound = {
        Killers = {},
        KillerIndex = {},
        InitialPlayers = {},
        RemainingPlayers = {},
        StartedLMS = false,
    }

    --destroy le map
    task.defer(MapManager.DestroyCurrentMap)

    --set lobby state
    RoundInfo:SetAttribute("State", "Lobby")
    
    --TODO: outros

    --fade out (temp)
    Utils.Player.Fade(LoadedPlayers, "Out", 0.7, true)

    --reset time manager as well
    GlobalTimeManager.OnTimerEnd = RoundManager.StartRound
    GlobalTimeManager.CanDecreaseTime = true
end

--- Counts the amount of characters left for each role and executes a corresponding callback.
--- 
--- This manages starting LMS and round endings, also determining who wins.
function RoundManager.Utils.CheckForKillerWin()
    --get how many players of each role there are
    local Count = Utils.Character.GetCharactersWithRoles(false)

    --cache
    local Survivors = #Count.Survivor

    --do the normal count if killer spawning is allowed
    if RoundManager.CanSpawnKiller then
        --if there are no killers, make the survivors win
        if #Count.Killer <= 0 then
            RoundManager.EndRound("Survivor")
        --if there's 1 survivor and 1 killer, start lms
        elseif Survivors == 1 then
            RoundManager.InitLMS(Players:GetPlayerFromCharacter(Count.Survivor[1]))
        --if there are still killers, and there are no survivors, make the killers win
        --this only applies if there were any survivors at the beginning of the match
        --if there were no survivors, it means that we're testing rounds with killers only, so we shouldn't end the round
        elseif #RoundManager.CurrentRound.InitialPlayers > 1 and Survivors <= 0 then
            RoundManager.EndRound("Killer")
        end
    --if killer spawning isn't allowed, end the round when there are no survivors left
    elseif Survivors <= 0 then
        RoundManager.EndRound("Killer")
    end
end

--- Gets a player's equipped character with its skin.
--- 
--- I'd place this in `Utils.Player` or `Utils.Instance` but it'd make a cyclic module dependency, and since it's only used here, we'll just place it here.
function RoundManager.Utils.GetPlayerEquippedCharacterModule(Player: Player, Role: Types.Role): ModuleScript
    local EquippedCharacter = Utils.PlayerData.GetPlayerEquipped(Player, Role)
    local EquippedSkin = Utils.PlayerData.GetPlayerEquipped(Player, "Skins."..EquippedCharacter)

    return Utils.Instance.GetCharacterModule(Role, EquippedCharacter, EquippedSkin)
end

--- Sets up a player's character and connections for the current round.
--- 
--- If `KillerIndex` is `nil`, the player will be treated as a survivor.
function RoundManager.Utils.SetupPlayer(Player: Player, KillerIndex: number?)
    local Char

    --killer setup
    if KillerIndex and RoundManager.CanSpawnKiller then
        --resets malice
        Utils.PlayerData.GetPlayerStat(Player, "General.Malice", false).Value = 1

        --loads the character itself
        Char = CharacterManager.LoadEquippedCharacter(Player, "Killer")

        --checks for death to call `RoundManager._OnPlayerDeath()`
        RoundManager.PlayerConnections[Player.UserId] = {
            RoundManager._Janitor:Add(Player.CharacterRemoving:Connect(function()
                RoundManager._OnPlayerDeath(Player, true)
            end)),
            RoundManager._Janitor:Add(Char:FindFirstChildWhichIsA("Humanoid").Died:Connect(function()
                RoundManager._OnPlayerDeath(Player, true)
            end)),
        }

        --adds to killer table
        RoundManager.CurrentRound.Killers[KillerIndex].Character = Char
    else
        --increases malice
        ServerUtils.PlayerData.UpdatePlayerStat(Player, "General.Malice", 1)

        --loads the character itself
        Char = CharacterManager.LoadEquippedCharacter(Player, "Survivor")

        --checks for death to call `RoundManager._OnPlayerDeath()`
        RoundManager.PlayerConnections[Player.UserId] = {
            RoundManager._Janitor:Add(Player.CharacterRemoving:Connect(function()
                RoundManager._OnPlayerDeath(Player)
            end)),
            RoundManager._Janitor:Add(Char:FindFirstChildWhichIsA("Humanoid").Died:Connect(function()
                --also automatically updates losses
                ServerUtils.PlayerData.UpdatePlayerStat(Player, "SurvivorStats.SurvivorLosses", 1)
                RoundManager._OnPlayerDeath(Player)
            end)),
        }
    end

    --anchors at first
    task.wait()
    Utils.Character.GetRootPart(Char).Anchored = true
end

--- Internal callback for when a player dies.
--- 
--- Cleans up a player's connections, gives corresponding stats, and executes `RoundManager.Utils.CheckForKillerWin()`.
function RoundManager._OnPlayerDeath(Dead: Player, WasKiller: boolean?)
    --defaults
    if WasKiller == nil then
        WasKiller = false
    end

    --disconnects all connections from the player
    for _, Connection in RoundManager.PlayerConnections[Dead.UserId] do
        Connection:Disconnect()
    end
    --removes its table
    RoundManager.PlayerConnections[Dead.UserId] = nil

    --if it was a killer, do:
    if WasKiller then
        --update losses and remove the killer from the table
        ServerUtils.PlayerData.UpdatePlayerStat(Dead, "KillerStats.KillerLosses", 1)
        table.remove(RoundManager.CurrentRound.Killers[RoundManager.CurrentRound.KillerIndex[Dead]])

        --clear the killer index table
        table.clear(RoundManager.CurrentRound.KillerIndex)

        --sort all killers
        table.sort(RoundManager.CurrentRound.Killers)
        --repopulate KillerIndex
        for Index, Killer in RoundManager.CurrentRound.Killers do
            RoundManager.CurrentRound.KillerIndex[Killer.Player] = Index
        end
    --if not, just remove it from remaining
    else
        RoundManager.CurrentRound.RemainingPlayers[Dead.UserId] = nil
    end

    --yeah
    RoundManager.Utils.CheckForKillerWin()
end

return RoundManager
