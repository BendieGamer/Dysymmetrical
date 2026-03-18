--[[

	Name: SmoothShiftLock
	Author: nekothyl
	Version: 1.4.0

--]]

--// Services
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Settings = UserSettings()
local GameSettings = Settings.GameSettings

--// Utilities
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Signal = require(ReplicatedStorage.Utils.Signal)
local Spring = require(ReplicatedStorage.Utils.Spring)

--// [ Smooth ShiftLock: ]
local SmoothShiftLock = {}

--// Instances
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

--// Configuration
local Constants = require(script:WaitForChild("Constants"))

--// [ Local Functions: ]
local Character
local HumanoidRootPart
local Humanoid

local function _refreshCharacterVariables()
	Character = LocalPlayer.Character
	HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
	Humanoid = Character:WaitForChild("Humanoid")
end

function SmoothShiftLock:Init()
	SmoothShiftLock:Start()
end

--// [ Life Cycle: ]
function SmoothShiftLock:Start()
	if RunService:IsServer() then
		return
	end
	
	local alreadyStarted = SmoothShiftLock._started
	if alreadyStarted then
		warn("[SmoothShiftLock]: Is already started")
		return
	end
	
	SmoothShiftLock._started = true
	
	--// Signals
	SmoothShiftLock.MouseLockEvent = Signal.new()
	
	--// Utilities
	SmoothShiftLock._janitor = Janitor.new()
	SmoothShiftLock._stateJanitor = Janitor.new()
	SmoothShiftLock._mouseLockJanitor = Janitor.new()
	
	SmoothShiftLock._cameraOffsetSpring = Spring.new(Vector3.new(0, 0, 0))
	SmoothShiftLock._cameraOffsetSpring.Damper = Constants.TRANSITION_SPRING_DAMPER

	--// Locals
	SmoothShiftLock.IsEnabled = false
	SmoothShiftLock.ShouldEnable = false
	SmoothShiftLock.IsAvailable = false
	SmoothShiftLock.IsMouseLocked = false

	--// [ Setup: Mouse Lock Availability ]
	GameSettings.Changed:Connect(function(property)
		if property ~= "ControlMode" and property ~= "ComputerMovementMode" then return end
		SmoothShiftLock:_updateMouseLockAvailability()
	end)

	LocalPlayer:GetPropertyChangedSignal("DevEnableMouseLock"):Connect(function()
		SmoothShiftLock:_updateMouseLockAvailability()
	end)

	LocalPlayer:GetPropertyChangedSignal("DevComputerMovementMode"):Connect(function()
		SmoothShiftLock:_updateMouseLockAvailability()
	end)
	
	SmoothShiftLock:_updateMouseLockAvailability()

	--// [ Setup: ]
	SmoothShiftLock:Enable()
	SmoothShiftLock._janitor:Add(function()
		SmoothShiftLock:Disable()
	end, true)
end

function SmoothShiftLock:Destroy()
	SmoothShiftLock._janitor:Cleanup()
	SmoothShiftLock._started = false
end

--// [ Internal Functions: State ]
function SmoothShiftLock:_updateMouseLockEnabledState()
	local isEnabled = SmoothShiftLock.ShouldEnable and SmoothShiftLock.IsAvailable
	
	if isEnabled == SmoothShiftLock.IsEnabled then return end
	SmoothShiftLock.IsEnabled = isEnabled

	--// Update enabled state
	if isEnabled then
		--// [ Setup: Character ]
		if LocalPlayer.Character then
			_refreshCharacterVariables()
		end

		SmoothShiftLock._stateJanitor:Add(LocalPlayer.CharacterAdded:Connect(function()
			_refreshCharacterVariables()
		end), true)

		--// [ Setup: Context Action ]
		ContextActionService:BindActionAtPriority(
			Constants.CONTEXT_ACTION_NAME, 
			function(actionName, inputState, inputObject)
				if inputState == Enum.UserInputState.Begin then
					SmoothShiftLock:MouseLock()
					return Enum.ContextActionResult.Sink
				end

				return Enum.ContextActionResult.Pass
			end, 
			Constants.CREATE_MOBILE_BUTTON, 
			Constants.MOUSELOCK_ACTION_PRIORITY, 
			unpack(Constants.MOUSE_LOCK_KEYBINDS)
		)
		
		SmoothShiftLock._stateJanitor:Add(function()
			ContextActionService:UnbindAction(Constants.CONTEXT_ACTION_NAME)
		end, true)
		
		SmoothShiftLock._stateJanitor:Add(function()
			SmoothShiftLock:MouseLock(false)
		end, true)

		--// [ Setup: Camera Offset ]
		SmoothShiftLock._stateJanitor:Add(RunService.RenderStepped:Connect(function()
			if Camera.CameraSubject ~= Humanoid then return end
			
			--// Camera offset
			local cameraDelta = Camera.Focus.Position - Camera.CFrame.Position
			local firstPerson = cameraDelta.Magnitude < 1
			
			if not firstPerson then	
				Camera.CFrame = Camera.CFrame * CFrame.new(SmoothShiftLock._cameraOffsetSpring.Position) 
			end
		end), true)
	else
		--// Disable
		SmoothShiftLock._stateJanitor:Cleanup()
	end
end

function SmoothShiftLock:_updateMouseLockAvailability()
	local DevAllowsMouseLock = LocalPlayer.DevEnableMouseLock
	local DevMovementModeIsScriptable = LocalPlayer.DevComputerMovementMode == Enum.DevComputerMovementMode.Scriptable
	local UserHasMouseLockModeEnabled = GameSettings.ControlMode == Enum.ControlMode.MouseLockSwitch
	local UserHasClickToMoveEnabled = GameSettings.ComputerMovementMode == Enum.ComputerMovementMode.ClickToMove
	local MouseLockAvailable = DevAllowsMouseLock and UserHasMouseLockModeEnabled and not UserHasClickToMoveEnabled and not DevMovementModeIsScriptable

	SmoothShiftLock.IsAvailable = MouseLockAvailable
	SmoothShiftLock:_updateMouseLockEnabledState()
end

--// [ External Functions: State ]
function SmoothShiftLock:Enable()
	SmoothShiftLock.ShouldEnable = true
	SmoothShiftLock:_updateMouseLockEnabledState()
end

function SmoothShiftLock:Disable()
	SmoothShiftLock.ShouldEnable = false
	SmoothShiftLock:_updateMouseLockEnabledState()
end

--// [ External Functions: Mouse Lock ]
function SmoothShiftLock:MouseLock(enable: boolean?)
	local isMouseLocked 
	if type(enable) == "boolean" then isMouseLocked = enable 
	else isMouseLocked = not SmoothShiftLock.IsMouseLocked end
	
	if isMouseLocked == SmoothShiftLock.IsMouseLocked then return end
	SmoothShiftLock.IsMouseLocked = isMouseLocked
	
	--// Update mouse lock
	if isMouseLocked then
		--// Setup
		UserInputService.MouseIcon = Constants.LOCKED_MOUSE_ICON
		
		SmoothShiftLock._cameraOffsetSpring.Speed = Constants.CAMERA_TRANSITION_IN_SPEED
		SmoothShiftLock._cameraOffsetSpring.Target = Constants.LOCKED_CAMERA_OFFSET
		
		--// Connections
		SmoothShiftLock._mouseLockJanitor:Add(RunService.RenderStepped:Connect(function(deltaTime)
			if not HumanoidRootPart or not Humanoid then return end
			
			--// Auto rotate
			Humanoid.AutoRotate = false

			--// Rotate the character
			if not Humanoid.Sit then 
				local _, y, _ = Camera.CFrame:ToOrientation()
				local finalCFrame = CFrame.new(HumanoidRootPart.Position) * CFrame.Angles(0, y, 0)

				if Constants.SMOOTH_CHARACTER_ROTATION then
					HumanoidRootPart.CFrame = HumanoidRootPart.CFrame:Lerp(finalCFrame, deltaTime * 5 * Constants.CHARACTER_ROTATION_SPEED)
				else
					HumanoidRootPart.CFrame = finalCFrame
				end
			end
			
			--// Update mouse behaviour
			if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then 
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			end
		end))
		
		--// Cleanup
		SmoothShiftLock._mouseLockJanitor:Add(function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIcon = ""

			SmoothShiftLock._cameraOffsetSpring.Speed = Constants.CAMERA_TRANSITION_OUT_SPEED
			SmoothShiftLock._cameraOffsetSpring.Target = Vector3.new(0, 0, 0)
		end, true)
		
		SmoothShiftLock._mouseLockJanitor:Add(function()
			if not Humanoid then return end
			Humanoid.AutoRotate = true
		end, true)
	else
		SmoothShiftLock._mouseLockJanitor:Cleanup()
	end
	
	SmoothShiftLock.MouseLockEvent:Fire(isMouseLocked)
end

return SmoothShiftLock