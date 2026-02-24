local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Utils = require(ReplicatedStorage.Modules.Utils)
local Janitor = require(ReplicatedStorage.Packages.Janitor)

local Sprinting = {
    AttemptingSprint = false,
    PressingSprintWhileRecovering = false,
    Recovering = false,
    Exhausted = false,
    Stamina = 100,
    TweenSpeed = true,
    SpeedApplied = false,
    SprintMultiplier = 2.66666,
    CanGainStamina = true,
    RecoverDelay = 0.75,
    RecoverExhaustionDelay = 2,
}

function Sprinting:Init()
    local Character = Players.LocalPlayer.Character

    local Root = Utils.Character.GetRootPart(Character)
    local Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
    local Role = Character:GetAttribute("Role")

    self.Character = Character

    local SpeedManager = require(Character.PlayerAttributeManagers.SpeedManager)
    local FOVManager = require(Character.PlayerAttributeManagers.FOVManager)
    local InputManager = require(Players.LocalPlayer.PlayerScripts.InputManager)

    SpeedManager:AddFactor("Sprint", 1)
    FOVManager:AddFactor("Sprint", 1)

    local CharacterJanitor = Janitor.new()
    CharacterJanitor:LinkToInstance(Character)

    local function SetAttributeSafely(Name: string, Value: any)
        if Character:GetAttribute(Name) ~= Value then
            Character:SetAttribute(Name, Value)
        end
    end

    CharacterJanitor:Add(RunService.PreSimulation:Connect(function(delta: number)
        local DirectionOfMovement = Root.CFrame:VectorToObjectSpace(Root.AssemblyLinearVelocity)
        local HumanoidDirectionOfMovement = Vector3.new(Humanoid.MoveDirection.X, 0, Humanoid.MoveDirection.Z)
        local Moving = not Root.Anchored and Humanoid.WalkSpeed > 0 and DirectionOfMovement.Magnitude > 0.1 and HumanoidDirectionOfMovement.Magnitude > 0
        
        if Moving and self.AttemptingSprint and not self.Exhausted and not self.PressingSprintWhileRecovering and SpeedManager.LastMultiplier >= 0.65 and SpeedManager.CanSprint then
            self.SpeedApplied = true

            if self.RecoveryThread then
                task.cancel(self.RecoveryThread)
            end

            --killer's stamina should only deplete when other survivors are close
            --using `playersFolder` is fine since spectators will be around 1000 studs away in the lobby
            if Role == "Killer" then
                local found = false
                for _, otherChar in workspace.Players:GetChildren() do
                    if otherChar == Character then
                        continue
                    end

                    local charHRP = Utils.Character.GetRootPart(otherChar)
                    if not charHRP then
                        continue
                    end
                    
                    if otherChar:GetAttribute("Role") ~= "Survivor" then
                        continue
                    end

                    if (charHRP.Position - Root.Position).Magnitude <= 110 then
                        found = true
                        break
                    end
                end
                
                if found then
                    self:_DrainStamina(delta)
                elseif self.CanGainStamina then
                    self:_GainStaminaLegally(delta)
                end
            else
                self:_DrainStamina(delta)
            end

            if self.Stamina <= 0 then
                self:_Stop(true)
            end
            
            FOVManager.Factors["Sprint"] = 1.2

        else

            if self.SpeedApplied then
                self:_Stop(false)
                self.SpeedApplied = false
            end

            if self.CanGainStamina then
                self:_GainStaminaLegally(delta)
            end

            FOVManager.Factors["Sprint"] = 1

        end

        if self.TweenSpeed then
            local ValueToTweenTo = self.SpeedApplied and self.SprintMultiplier or 1
            
            SpeedManager.Factors["Sprint"] = math.lerp(SpeedManager.Factors["Sprint"], ValueToTweenTo, delta * 5.5)
        else
            SpeedManager.Factors["Sprint"] = self.SpeedApplied and self.SprintMultiplier or 1
        end

        SetAttributeSafely("Stamina", self.Stamina)
        SetAttributeSafely("Sprinting", self.SpeedApplied)
    end))

    local InputAction = InputManager:GetInputAction("Default.Sprint")

    local function ToggleSprintPress(Pressed: boolean)
        self.AttemptingSprint = Pressed
        self.PressingSprintWhileRecovering = self.Exhausted and Pressed
    end

    CharacterJanitor:Add(InputAction.Pressed:Connect(function()
        ToggleSprintPress(true)
    end))
    CharacterJanitor:Add(InputAction.Released:Connect(function()
        ToggleSprintPress(false)
    end))

    CharacterJanitor:Add(function()
        if self.RecoveryThread and coroutine.running() ~= self.RecoveryThread then
            task.cancel(self.RecoveryThread)
        end
    end, true)
end

function Sprinting:_Stop(StopExhausted: boolean)
	self.Recovering = true

	if StopExhausted then
		self.Stamina = 0
		self.PressingSprintWhileRecovering = true
		self.Exhausted = true
		task.delay(self.RecoverExhaustionDelay, function()
			self.Recovering = false
			self.Exhausted = false
		end)
	else
		self.RecoveryThread = task.delay(self.RecoverDelay, function()
			self.Recovering = false
		end)
	end
end

function Sprinting:_DrainStamina(delta: number)
	self.Stamina -= self.Character:GetAttribute("StaminaDrain") * delta
end

function Sprinting:_GainStaminaLegally(delta: number)
	if not self.Recovering and not self.Exhausted and self.Stamina <= self.Character:GetAttribute("MaxStamina") then
		self.Stamina = math.clamp(self.Stamina + self.Character:GetAttribute("StaminaGain") * delta, 0, self.Character:GetAttribute("MaxStamina") :: any)
	end
end

return Sprinting
