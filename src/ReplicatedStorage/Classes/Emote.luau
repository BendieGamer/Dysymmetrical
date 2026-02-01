local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local rand = Random.new()

local Network = require(ReplicatedStorage.Modules.Network)
local Sounds = require(ReplicatedStorage.Modules.Sounds)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Types = require(script.Parent.Types)
local PlayerSpeedManager = RunService:IsServer() and require(game:GetService("ServerScriptService").Managers.PlayerManager.CharacterManager.PlayerSpeedManager) or nil

local Emote = {}
Emote.__index = Emote

function Emote.GetDefaultSettings(): Types.Emote
    return setmetatable({
        Config = {
            Name = "Emote",
            Quote = "\"hey guys what's up dys here\"",
            Author = "idk lol",
            Render = "rbxasset://textures/ui/GuiImagePlaceholder.png",
            Price = 300,
        },

        AnimationIds = {},
        SoundIds = {},
        SpeedMultiplier = 0,
        BaseBehaviourAllowed = true,

        AnimationTracks = {},
        OnStop = nil,

        HumanoidRootPart = nil,
        TurnToMoveDirection = nil,

        TrackPlaying = nil,
    }, Emote)
end

--- ## DEPRECATED: use `Emote.GetDefaultSettings()` instead.
--- 
--- Emote preset for customization.
@deprecated
function Emote.GetDefaultEmoteSettings(): Types.Emote
    return Emote.GetDefaultSettings()
end

--- Creates an emote with the settings specified in `Props`.
--- 
--- Every property that has to be there has a fallback, so not all properties have to be written there if the default values are fine.
function Emote.New(Props: Types.Emote): Types.Emote
    Props = Props or {}

    return Utils.Type.DeepTableOverwrite(Emote.GetDefaultSettings(), Props)
end

--- ## DEPRECATED: use `Emote.New()` instead.
--- Creates an emote with the settings specified in `Props`.
--- 
--- Every property that has to be there has a fallback, so not all properties have to be written there if the default values are fine.
@deprecated
function Emote.CreateEmote(Props: Types.Emote): Types.Emote
    return Emote.New()
end

function Emote:Init(player: Player)
    --common variable definitions
    self.Owner = player
    self.Janitor = Janitor.new()
    self.Janitor:LinkToInstance(self.Owner.Character)

    self.HumanoidRootPart = Utils.Character.GetRootPart(self.Owner)

    --yippee split code in ReplicatedStorage i love it
    if RunService:IsServer() then
        --useful for readability and NOTHING ELSE. 
        local function CheckRequestParams(Player: Player, EmoteName: string)
            return Player == self.Owner and EmoteName == self.Config.Name
        end

        --i just noticed that forsaken uses a whole data array to store everything from a player and get the index of it instead of checking it for everyone.
        --it makes more sense.
        self:AddConnection(Network:SetConnection("PlayEmote", "REMOTE_EVENT", function(plr: Player, emoteName: string, soundId: string)
            --if the player or the emote name isn't the same as in self, or if the player is already emoting, halt
            if not (CheckRequestParams(plr, emoteName) and self.Owner.Character:GetAttribute("Emoting") ~= true) then
                return
            end

            --if there's a soundid available, play it
            if soundId and #soundId > 0 then
                Sounds.PlaySound(soundId, {Name = "Emote", Parent = Utils.Character.GetRootPart(self.Owner), Looped = true})
            end

            --set to emoting
            self.Owner.Character:SetAttribute("Emoting", true)
            --add whatever speed factor the emote has
            PlayerSpeedManager.AddSpeedFactor(player, "Emoting", self.SpeedMultiplier)

            --fire the client to play the anim n stuff
            Network:FireClientConnection(plr, "PlayEmote", "REMOTE_EVENT", emoteName)

            --execute behaviour if applicable
            if self.Behaviour then
                self:Behaviour(self.Owner.Character)
            end
        end))
        self:AddConnection(Network:SetConnection("StopEmote", "REMOTE_EVENT", function(plr: Player, emoteName: string)
            --if the player or the emote name isn't the same as in self, or if the player isn't emoting, halt
            if not (CheckRequestParams(plr, emoteName) and self.Owner.Character == true) then
                return
            end

            --removing existing emote using `do ... end` to limit the scope of the variables used here
            do
                local HRP = Utils.Character.GetRootPart(self.Owner)
                local ExistingEmote = HRP and HRP:FindFirstChild("Emote")
                
                if ExistingEmote then
                    ExistingEmote:Destroy()
                end
            end
            --set to not emoting
            self.Owner.Character:SetAttribute("Emoting", false)
            --remove whatever speed factor the emote had
            PlayerSpeedManager.RemoveSpeedFactor(player, "Emoting")

            --fire the client to stop the anim n stuff
            Network:FireClientConnection(plr, "StopEmote", "REMOTE_EVENT", emoteName)
            
            --execute behaviour if applicable
            if self.OnStop then
                self:OnStop(self.Owner.Character)
            end
        end))

        --halt before the server executes client code
        return
    end

    --preload all rbxassetids in the emote
    Utils.Misc.PreloadAssets({self.Config.Render, self.AnimationIds, self.SoundIds})

    --if AnimationIds is a string, load it directly
    --if not, it's guessed to be a table, so iterate over every string in the table and load each one
    if typeof(self.AnimationIds) == "string" then
        self.AnimationTracks[self.AnimationIds] = {
            Animation = Utils.Character.LoadAnimationFromID(self.Owner.Character, self.AnimationIds),
            -- Sound = nil,
        }
    else
        for _, id: string in self.AnimationIds do
            self.AnimationTracks[id] = {
                Animation = Utils.Character.LoadAnimationFromID(self.Owner.Character, id),
                -- Sound = nil,
            }
        end
    end

    --get turn to move direction here since it's client only and it may be used to lock the head while emoting
    self.TurnToMoveDirection = require(Players.LocalPlayer.PlayerScripts.Visual.TurnToMoveDirection)

    --if there are sounds, do the same as with animations
    if self.SoundIds then
        if typeof(self.SoundIds) == "string" then
            if typeof(self.AnimationIds) == "string" then
                self.AnimationTracks[self.AnimationIds].Sound = self.SoundIds
            else
                for _, id in self.AnimationIds do
                    self.AnimationTracks[id].Sound = self.SoundIds
                end
            end
        else
            for animId, id in self.SoundIds do
                self.AnimationTracks[animId].Sound = id
            end
        end
    end

    --setup connections from the server to play emote animations n stuff
    self:AddConnection(Network:SetConnection("PlayEmote", "REMOTE_EVENT", function(emoteName: string)
        --if the emote to play isn't this one, halt
        if self.Config.Name ~= emoteName then
            return
        end
        
        --if the emote is already playing, halt
        if self.TrackPlaying and self.TrackPlaying.Animation.IsPlaying then
            return
        end

        --play the emote
        self.TrackPlaying.Animation:Play(0)
        --prevent head turning
        self.TurnToMoveDirection:AddHeadPreventionFactor("Emoting")

        --execute behaviour if applicable
        if self.Behaviour then
            self:Behaviour(self.Owner.Character)
        end
    end))

    --same with stopping
    self:AddConnection(Network:SetConnection("StopEmote", "REMOTE_EVENT", function(emoteName: string)
        --if the emote to play isn't this one, or there is no track playing, or if the track playing doesn't have an animation, halt
        if not (emoteName == self.Config.Name and self.TrackPlaying and self.TrackPlaying.Animation) then
            return
        end

        --stop the animation
        self.TrackPlaying.Animation:Stop(0)
        
        --allow for head turning again
        self.TurnToMoveDirection:RemoveHeadPreventionFactor("Emoting")

        --remove TrackPlaying
        self.TrackPlaying = nil

        --execute behaviour if applicable
        if self.OnStop then
            self:OnStop(self.Owner.Character)
        end
    end))
end

function Emote:BaseBehaviour()
    --there's only really base behaviour for client so yuh
    if RunService:IsServer() then
        return
    end

    --if base behaviour isn't allowed, halt
    if not self.BaseBehaviourAllowed then
        return
    end
    
    --if the nanimation is playing, halt
    if self.TrackPlaying and self.TrackPlaying.Animation.IsPlaying then
        return
    end

    --play an animation
    --if AnimationIds was a string, play it directly
    --if not, play one of the available animations
    if typeof(self.AnimationIds) == "string" then
        self.TrackPlaying = self.AnimationTracks[self.AnimationIds]
    else
        local AsTable = Utils.Type.DictToTable(self.AnimationTracks)
        self.TrackPlaying = AsTable[rand:NextInteger(1, #AsTable)]
    end

    --fire to the server so that the server knows what emote is about to play and execute behaviour based on it
    Network:FireServerConnection("PlayEmote", "REMOTE_EVENT", self.Config.Name, self.TrackPlaying.Sound)
end

function Emote:AddConnection<T>(Connection: T & (RBXScriptConnection | thread)): T & (RBXScriptConnection | thread)
    self.Janitor:Add(Connection,
        if typeof(Connection) == "thread" then
            true
        else
            nil
    )

    return Connection
end

return Emote
