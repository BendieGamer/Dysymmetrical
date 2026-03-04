local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(ReplicatedStorage.Classes.Types)
local Network = require(ReplicatedStorage.Modules.Network)
local Utils = require(ReplicatedStorage.Modules.Utils)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local PlayerHurtboxCreator = {}

function PlayerHurtboxCreator:Init()
    Utils.Player.ObservePlayers(function(Player: Player)
        Utils.Character.ObserveCharacter(Player, function(Character: Model, CharacterJanitor: Types.Janitor)
            --if it's a spectator, halt
            if not Character:GetAttribute("Role") or Character:GetAttribute("Role") == "Spectator" then
                return
            end

            PlayerHurtboxCreator.CreateHurtboxesForPlayer(Player, Character)
        end)
    end)
end

function PlayerHurtboxCreator.CreateHurtboxesForPlayer(Player: Player, Character: Model)
    local HRP = Utils.Character.GetRootPart(Character)
    local TargetCFrame = CFrame.new(HRP.CFrame.Position)

    -- Get character config for priority
    local hurtboxPriority = 1 -- fallback
    local charName = Character:GetAttribute("CharacterName")
    local charSkin = Character:GetAttribute("CharacterSkinName")
    local roleValue = Character:FindFirstChild("Role") and Character.Role.Value
    
    if roleValue and charName and #charName > 0 then
        local moduleInstance = Utils.Instance.GetCharacterModule(roleValue, charName, charSkin)
        if moduleInstance then
            local success, mod = pcall(require, moduleInstance)
            if success and mod.GameplayConfig and type(mod.GameplayConfig.HitboxPriority) == "number" then
                hurtboxPriority = mod.GameplayConfig.HitboxPriority
            end
        end
    end
    
    --make IDs for later hitbox display
    local ID = 0
    for _, Hitbox: BasePart in script:GetChildren() do
        if not Hitbox:IsA("BasePart") then
            continue
        end

        --make its ID unique but very very low to prevent using UniqueID because it's unnecessary info
        ID += 1

        --clone it
        local HitboxClone = Hitbox:Clone()
        HitboxClone.Transparency = 1
        HitboxClone.CFrame = TargetCFrame
		HitboxClone:SetAttribute("HitboxPriority", hurtboxPriority)
        --set its ID for later hitbox display
        HitboxClone:SetAttribute("ID", ID)
        
        --weld to HRP
        local Weld = Instance.new("Weld")
        Weld.Part0 = HRP
        Weld.Part1 = HitboxClone
        Weld.Name = HitboxClone.Name
        Weld.Parent = HRP
        
        --parent it NOW instead of BEFORE so that the client can properly get the ID attribute
        HitboxClone.Parent = Character.Hurtboxes
    end

    --setup hitbox display on client
    PlayerHurtboxCreator._SetupHurtboxViewConnections(Player, Character)
end

local Framerate = 1/15
--- Sets up all available hitboxes for the passed character.
function PlayerHurtboxCreator._SetupHurtboxViewConnections(Player: Player, Character: Model)
    local JanitorInstance = Janitor.new()
    JanitorInstance:LinkToInstance(Character)

    local Root = Utils.Character.GetRootPart(Character)

    local Elapsed = 0
    local LastPosition = Root.Position
    JanitorInstance:Add(RunService.PostSimulation:Connect(function(delta: number)
        --will wait until the 3 frames are processed
        --but only if there wasn't a frame skip because of lag
        --in which case it'll skip the check entirely and move on
        if Elapsed < Framerate then
            Elapsed += delta
            return
        end

        --subtracting to elapsed in this way just in case there is
        --for example half a frame after a small lag spike so that it can be used next check
        Elapsed -= Framerate
        if Elapsed > Framerate then
            Elapsed = 0
        end

        local CurrentPosition = Root.Position
        if math.abs((CurrentPosition - LastPosition).Magnitude) < 0.05 then
            return
        end

        LastPosition = CurrentPosition

        --sending the root's cframe directly to update the hurtboxes's cframe on the client
        --i can send the cframe because it'll still be optimized and buffered by the networking module anyways
        Network:FireClientConnection(Player, "UpdHurtboxPos", "UREMOTE_EVENT", Root.CFrame)
    end))
end

return PlayerHurtboxCreator
