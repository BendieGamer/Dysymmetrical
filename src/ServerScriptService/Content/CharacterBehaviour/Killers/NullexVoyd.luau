local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Types = require(ReplicatedStorage.Classes.Types)
local Sounds = require(ReplicatedStorage.Modules.Sounds)

local NullexVoyd = {}

--you may also do `function NullexVoyd:DataAnchorBehaviour()` but you get autocompletion this way instead
function NullexVoyd.DataAnchorBehaviour(self: Types.Ability)
    if self.Setup then
        self.OwnerProperties.Character:PivotTo(self.PositionInfo)
    
        if self.TeleporterInstance then
            self.TeleporterInstance:Destroy()
        end
    
        self.PositionInfo = nil
        self.Setup = false
    else
        self.Setup = true
    
        self:AddConnection(task.delay(0.75, function()
            self.DevicePosition = self.OwnerProperties.Character.HumanoidRootPart.Position - Vector3.new(0, 3 * self.OwnerProperties.Character:GetScale(), 0)
            Sounds.PlaySound(self.PlaceSound, {
                Position = self.DevicePosition,
                RollOffMaxDistance = 35,
                RollOffMinDistance = 12,
                Name = self.Name,
                SoundGroup = SoundService.SoundGroups.Master.SFX,
            })
        end))
        self:AddConnection(task.delay(0.917, function()
            local TpInstance = self.CharModule.Config.TeleporterPrefab:Clone()
            TpInstance:PivotTo(CFrame.new(self.DevicePosition))
            TpInstance.Parent = workspace.Map.InGame
            self.PositionInfo = self.OwnerProperties.Character:GetPivot()
            self.TeleporterInstance = TpInstance
        end))
    end
end

return NullexVoyd
