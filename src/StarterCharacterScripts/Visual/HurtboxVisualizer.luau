local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(ReplicatedStorage.Classes.Types)
local Network = require(ReplicatedStorage.Modules.Network)
local Utils = require(ReplicatedStorage.Modules.Utils)

return {
    Init = function(_)
        local Character: Model = Players.LocalPlayer.Character
        local HurtboxFolder: Folder = Character.Hurtboxes

        --necessary tables
        local GhostHurtboxes: {[number]: BasePart} = {}
        local TargetCFrame: CFrame = Utils.Character.GetRootPart(Character).CFrame

        --creating the janitor by conveniently using `Utils.Instance.ObserveChildren()`, which is bound to HurtboxFolder
        local JanitorInstance: Types.Janitor = Utils.Instance.ObserveChildren(HurtboxFolder, function(Child: Instance)
            --safety check
            if not Child:IsA("BasePart") then
                return
            end

            --if there is no ID available, halt
            local ID = Child:GetAttribute("ID")
            if ID == nil then
                return
            end

            --create its dupe with its supposed transparency
            local Ghost = Child:Clone()
            Ghost.Parent = HurtboxFolder
            Ghost.Name = Ghost.Name.."Ghost"
            Ghost.Transparency = Ghost:GetAttribute("VisibleTransparency") or 0.75
            --IMPORTANTLY anchor it or it will fall to oblivion
            Ghost.Anchored = true
            --add it to the ghost table for the render loop
            GhostHurtboxes[ID] = Ghost
        end)
        --use the same janitor for removing stuffs
        JanitorInstance:Add(HurtboxFolder.ChildRemoved:Connect(function(Child: Instance)
            --safety check
            if not Child:IsA("BasePart") then
                return
            end

            --if there is no ID available, halt
            local ID = Child:GetAttribute("ID")
            if ID == nil then
                return
            end
            
            --remove stuff from tables to clean up
            if GhostHurtboxes[ID] then
                GhostHurtboxes[ID]:Destroy()
            end
            GhostHurtboxes[ID] = nil
        end))
        
        --use the same janitor again to add the network connection
        JanitorInstance:Add(Network:SetConnection("UpdHurtboxPos", "UREMOTE_EVENT", function(_TargetCFrame: CFrame)
            TargetCFrame = _TargetCFrame
        end))

        --use the same janitor yet again to add the render loop
        JanitorInstance:Add(RunService.PreRender:Connect(function(delta: number)
            for _, Ghost in GhostHurtboxes do
                Ghost.CFrame = Ghost.CFrame:Lerp(TargetCFrame, delta * 20)
                -- Ghost.CFrame = TargetCFrame
            end
        end))
    end,
}