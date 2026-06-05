local DEBUG = false

local function debugPrint(...)
	if DEBUG then
		print("[DEBUG]", ...)
	end
end

debugPrint("[XxNamedzxX] FILE LOADING - DEBUG ENABLED!")
debugPrint("XxNamedzxX character file loading...")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ServerScriptService = game:GetService("ServerScriptService")

local Types = require(ReplicatedStorage.Classes.Types)
local Character = require(ReplicatedStorage.Classes.Character)
local Ability = require(ReplicatedStorage.Classes.Ability)
local Utils = require(ReplicatedStorage.Modules.Utils)
local CommonFunctions = nil
pcall(function()
	CommonFunctions = RunService:IsServer()
			and require(
				ServerScriptService:FindFirstChild("System")
					and ServerScriptService.System:FindFirstChild("CommonFunctions")
			)
		or nil
end)

debugPrint("XxNamedzxX dependencies loaded, creating character...")
local MINIGAME_REWARD = 2
local MIN_SKATE_METER_TO_START = 3
local SEQUENCE_MINIGAME_TIME = 3
local DOT_MINIGAME_TIME = 4
local MINIGAME_TIMEOUT = 4
local DEFAULT_WALK_SPEED = 16
local SKATEBOARD_SPEED = 30
local SKATE_ANIMATION_ID = "rbxassetid://131034297401435"
local STARTING_SKATE_METER = 10

-- Helper functions
local function setModelTransparency(model, transparency)
	if model and model:IsA("Model") then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = transparency
			end
		end
	end
end

local function setAccessoryTransparency(character, accessoryName, transparency)
	local accessory = character and character:FindFirstChild(accessoryName)
	if not accessory then
		return
	end
	if accessory:IsA("Model") then
		setModelTransparency(accessory, transparency)
	elseif accessory:IsA("BasePart") then
		accessory.Transparency = transparency
	end
end

local function getSkateboardVisual(character)
	return character and character:FindFirstChild("Skateboard")
end

-- Clone Skateboard from ServerStorage (like BloodRose does), falling back to ReplicatedStorage
local function cloneSkateboardFromServerStorage(): Model?
	print("[XxNamedzxX] cloneSkateboardFromServerStorage() CALLED")
	local serverStorage = game:GetService("ServerStorage")
	local replicatedStorage = game:GetService("ReplicatedStorage")

	-- First try ServerStorage
	print("[XxNamedzxX] Checking ServerStorage for Skateboard...")
	print("[XxNamedzxX] ServerStorage children:", serverStorage:GetChildren())
	local serverSkateboard = serverStorage:FindFirstChild("Skateboard")
	print("[XxNamedzxX] ServerStorage Skateboard found:", serverSkateboard)
	if serverSkateboard and serverSkateboard:IsA("Model") then
		print("[XxNamedzxX] SUCCESS: Cloning Skateboard from ServerStorage")
		return serverSkateboard:Clone()
	end

	-- Fall back to ReplicatedStorage
	print("[XxNamedzxX] Checking ReplicatedStorage for Skateboard...")
	print("[XxNamedzxX] ReplicatedStorage children:", replicatedStorage:GetChildren())
	local repSkateboard = replicatedStorage:FindFirstChild("Skateboard")
	print("[XxNamedzxX] ReplicatedStorage Skateboard found:", repSkateboard)
	if repSkateboard and repSkateboard:IsA("Model") then
		print("[XxNamedzxX] SUCCESS: Cloning Skateboard from ReplicatedStorage (fallback)")
		return repSkateboard:Clone()
	end

	warn("[XxNamedzxX] FAIL: Skateboard not found in ServerStorage or ReplicatedStorage!")
	return nil
end

-- Minigame functions (Finished)
local function createMinigameGui(playerGui, titleText)
	local existingGui = playerGui:FindFirstChild("SlopeTrickMinigame")
	if existingGui then
		existingGui:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SlopeTrickMinigame"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local background = Instance.new("Frame")
	background.Size = UDim2.fromOffset(400, 220)
	background.Position = UDim2.new(0.5, -200, 0.5, -110)
	background.BackgroundColor3 = Color3.new(0, 0, 0)
	background.BackgroundTransparency = 0.3
	background.BorderSizePixel = 2
	background.BorderColor3 = Color3.new(1, 1, 1)
	background.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.fromOffset(0, 10)
	title.BackgroundTransparency = 1
	title.Text = titleText
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Font = Enum.Font.SourceSansBold
	title.Parent = background

	local instructionLabel = Instance.new("TextLabel")
	instructionLabel.Size = UDim2.new(1, -20, 0, 30)
	instructionLabel.Position = UDim2.fromOffset(10, 45)
	instructionLabel.BackgroundTransparency = 1
	instructionLabel.TextColor3 = Color3.new(0.8, 0.9, 1)
	instructionLabel.TextScaled = true
	instructionLabel.Font = Enum.Font.SourceSans
	instructionLabel.Parent = background

	local contentFrame = Instance.new("Frame")
	contentFrame.Size = UDim2.new(1, -20, 1, -120)
	contentFrame.Position = UDim2.fromOffset(10, 80)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = background

	local timerDisplay = Instance.new("TextLabel")
	timerDisplay.Size = UDim2.new(1, 0, 0, 30)
	timerDisplay.Position = UDim2.new(0, 0, 1, -35)
	timerDisplay.BackgroundTransparency = 1
	timerDisplay.TextColor3 = Color3.new(1, 0.5, 0)
	timerDisplay.TextScaled = true
	timerDisplay.Font = Enum.Font.SourceSansBold
	timerDisplay.Parent = background

	return screenGui, background, instructionLabel, contentFrame, timerDisplay
end

local function finishMinigame(meterSystem, skateboard, success, gameType)
	if skateboard then
		setModelTransparency(skateboard, 1)
	end
	if success then
		meterSystem.addMeter(MINIGAME_REWARD)
		debugPrint(string.format("%s minigame completed successfully!", gameType))
		debugPrint(
			string.format("Skate meter after minigame: %.1f/%.1f", meterSystem.getMeter(), meterSystem.getMaxMeter())
		)
	else
		debugPrint(string.format("%s minigame failed!", gameType))
	end
end

local function startSequenceMinigame(meterSystem, skateboard)
	debugPrint("Starting sequence minigame")
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui, _, instructionLabel, contentFrame, timerDisplay =
		createMinigameGui(playerGui, "SLOPE TRICK - SEQUENCE")
	instructionLabel.Text = "Press the keys in order before time runs out."

	local keys = { "W", "A", "S", "D", "Space" }
	local keySequence = {}
	for i = 1, 5 do
		keySequence[i] = keys[math.random(1, #keys)]
	end

	local keyDisplay = Instance.new("TextLabel")
	keyDisplay.Size = UDim2.fromScale(1, 1)
	keyDisplay.BackgroundTransparency = 1
	keyDisplay.TextColor3 = Color3.new(1, 1, 0)
	keyDisplay.TextScaled = true
	keyDisplay.Font = Enum.Font.SourceSansBold
	keyDisplay.Parent = contentFrame

	local function updateSequenceText(currentKeyIndex)
		if currentKeyIndex > #keySequence then
			keyDisplay.Text = "TRICK LANDED!"
			return
		end
		local displayParts = {}
		for index, key in ipairs(keySequence) do
			if index < currentKeyIndex then
				table.insert(displayParts, "[" .. key .. "]")
			elseif index == currentKeyIndex then
				table.insert(displayParts, ">" .. key .. "<")
			else
				table.insert(displayParts, key)
			end
		end
		keyDisplay.Text = table.concat(displayParts, " → ")
	end
	updateSequenceText(1)

	local currentKeyIndex = 1
	local timeRemaining = SEQUENCE_MINIGAME_TIME
	local minigameActive = true
	local success = false
	local cleanedUp = false

	local timer_conn
	timer_conn = RunService.Heartbeat:Connect(function(deltaTime)
		if not minigameActive then
			if timer_conn then
				timer_conn:Disconnect()
			end
			return
		end
		timeRemaining -= deltaTime
		timerDisplay.Text = string.format("Time: %.1f", math.max(0, timeRemaining))
		if timeRemaining <= 0 then
			minigameActive = false
		end
	end)

-- Helper to convert KeyCode to input key string
	local function keyCodeToInputKey(keyCode)
		if keyCode == Enum.KeyCode.W or keyCode == Enum.KeyCode.DPadUp then
			return "W"
		elseif keyCode == Enum.KeyCode.A or keyCode == Enum.KeyCode.DPadLeft then
			return "A"
		elseif keyCode == Enum.KeyCode.S or keyCode == Enum.KeyCode.DPadDown then
			return "S"
		elseif keyCode == Enum.KeyCode.D or keyCode == Enum.KeyCode.DPadRight then
			return "D"
		elseif keyCode == Enum.KeyCode.Space or keyCode == Enum.KeyCode.ButtonA or keyCode == Enum.KeyCode.ButtonX then
			return "Space"
		end
		return nil
	end

	local input_conn
	input_conn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not minigameActive or gameProcessed then
			return
		end

		local inputKey = keyCodeToInputKey(input.KeyCode)

		if inputKey and inputKey == keySequence[currentKeyIndex] then
			currentKeyIndex += 1
			updateSequenceText(currentKeyIndex)
			if currentKeyIndex > #keySequence then
				success = true
				minigameActive = false
			end
		end
	end)

	local function cleanup()
		if cleanedUp then
			return
		end
		cleanedUp = true
		if timer_conn then
			timer_conn:Disconnect()
		end
		if input_conn then
			input_conn:Disconnect()
		end
		screenGui:Destroy()
		finishMinigame(meterSystem, skateboard, success, "Sequence")
	end

	task.delay(MINIGAME_TIMEOUT, cleanup)

	local cleanup_conn
	cleanup_conn = RunService.Heartbeat:Connect(function()
		if not minigameActive then
			if cleanup_conn then
				cleanup_conn:Disconnect()
			end
			cleanup()
		end
	end)
end

local function startDotClickMinigame(meterSystem, skateboard)
	debugPrint("Starting dot click minigame")
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui, _, instructionLabel, contentFrame, timerDisplay =
		createMinigameGui(playerGui, "SLOPE TRICK - DOT RUSH")
	instructionLabel.Text = "Click every dot before time runs out."

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, 0, 0, 28)
	statusLabel.Position = UDim2.new(0, 0, 0, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextColor3 = Color3.new(1, 1, 0)
	statusLabel.TextScaled = true
	statusLabel.Font = Enum.Font.SourceSansBold
	statusLabel.Parent = contentFrame

	local dotContainer = Instance.new("Frame")
	dotContainer.Size = UDim2.new(1, 0, 1, -30)
	dotContainer.Position = UDim2.fromOffset(0, 30)
	dotContainer.BackgroundTransparency = 1
	dotContainer.ClipsDescendants = true
	dotContainer.Parent = contentFrame

	local dotCount = 5
	local dotsRemaining = dotCount
	local timeRemaining = DOT_MINIGAME_TIME
	local minigameActive = true
	local success = false
	local cleanedUp = false

	local function updateStatus()
		statusLabel.Text = string.format("Dots Left: %d", dotsRemaining)
	end

	updateStatus()

	for index = 1, dotCount do
		local dotButton = Instance.new("TextButton")
		dotButton.Name = "Dot" .. index
		dotButton.Size = UDim2.fromOffset(32, 32)
		dotButton.AnchorPoint = Vector2.new(0.5, 0.5)
		dotButton.Position = UDim2.fromScale(math.random(15, 85) / 100, math.random(20, 80) / 100)
		dotButton.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
		dotButton.BorderSizePixel = 0
		dotButton.Text = ""
		dotButton.AutoButtonColor = true
		dotButton.Parent = dotContainer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = dotButton

		dotButton.MouseButton1Click:Connect(function()
			if not minigameActive or not dotButton.Parent then
				return
			end
			dotButton:Destroy()
			dotsRemaining -= 1
			updateStatus()
			if dotsRemaining <= 0 then
				success = true
				minigameActive = false
				statusLabel.Text = "ALL DOTS CLEARED!"
			end
		end)
	end

	local timer_conn
	timer_conn = RunService.Heartbeat:Connect(function(deltaTime)
		if not minigameActive then
			if timer_conn then
				timer_conn:Disconnect()
			end
			return
		end
		timeRemaining -= deltaTime
		timerDisplay.Text = string.format("Time: %.1f", math.max(0, timeRemaining))
		if timeRemaining <= 0 then
			minigameActive = false
		end
	end)

	local function cleanup()
		if cleanedUp then
			return
		end
		cleanedUp = true
		if timer_conn then
			timer_conn:Disconnect()
		end
		screenGui:Destroy()
		finishMinigame(meterSystem, skateboard, success, "Dot Click")
	end

task.delay(4.5, cleanup)

	local cleanup_conn
	cleanup_conn = RunService.Heartbeat:Connect(function()
		if not minigameActive then
			if cleanup_conn then
				cleanup_conn:Disconnect()
			end
			cleanup()
		end
	end)
end

local function startSlopeTrickMinigame(meterSystem, skateboard)
	-- Mobile/touch devices use dot-click minigame (more touch-friendly)
	-- Keyboard/console devices random between both
	local isMobile = UserInputService.TouchEnabled
	if isMobile then
		startDotClickMinigame(meterSystem, skateboard)
	else
		local minigameRoll = math.random(1, 2)
		if minigameRoll == 1 then
			startSequenceMinigame(meterSystem, skateboard)
		else
			startDotClickMinigame(meterSystem, skateboard)
		end
	end
end

local function createMeterDisplay(player)
	debugPrint("Creating meter display for player:", player.Name)
	local playerGui = player:WaitForChild("PlayerGui")
	local existingDisplay = playerGui:FindFirstChild("SkateMeterDisplay")
	if existingDisplay then
		existingDisplay:Destroy()
	end

	local meterGui = Instance.new("ScreenGui")
	meterGui.Name = "SkateMeterDisplay"
	meterGui.ResetOnSpawn = false
	meterGui.Parent = playerGui

	local meterFrame = Instance.new("Frame")
	meterFrame.Name = "Container"
	meterFrame.Size = UDim2.fromOffset(255, 46)
	meterFrame.Position = UDim2.fromOffset(10, 10)
	meterFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	meterFrame.BackgroundTransparency = 0.3
	meterFrame.BorderSizePixel = 2
	meterFrame.BorderColor3 = Color3.new(1, 1, 1)
	meterFrame.Parent = meterGui

	local meterText = Instance.new("TextLabel")
	meterText.Name = "MeterText"
	meterText.Size = UDim2.new(1, -10, 1, 0)
	meterText.Position = UDim2.fromOffset(5, 0)
	meterText.BackgroundTransparency = 1
	meterText.TextColor3 = Color3.new(1, 1, 1)
	meterText.TextScaled = true
	meterText.Font = Enum.Font.SourceSansBold
	meterText.Parent = meterFrame

	local function getCurrentValues(plr)
		local playerChar = plr.Character
		if playerChar then
			return playerChar:GetAttribute("XxNamedzxX_SkateMeter") or 0,
				playerChar:GetAttribute("XxNamedzxX_IsSkating") or false
		end
		return 0, false
	end

	local heartbeatConn = RunService.Heartbeat:Connect(function()
		local currentMeter, isSkating = getCurrentValues(player)
		local maxMeter = 10
		local statusText = isSkating and " [SKATING]" or " [READY]"
		meterText.Text = string.format("Skate Meter: %.1f / %.1f%s", currentMeter, maxMeter, statusText)
		meterText.TextColor3 = isSkating and Color3.new(0, 1, 0) or Color3.new(1, 1, 1)
		meterFrame.BackgroundColor3 = isSkating and Color3.new(0, 0.5, 0) or Color3.new(0, 0, 0)
	end)
	return meterGui, heartbeatConn
end

local function initializeMeterSystem(self, character)
	debugPrint("Initializing meter system for character:", character and character.Name or "nil")
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not hrp then
		debugPrint("No humanoid or root part found, aborting meter system")
		return
	end

	local skateMeter = character:GetAttribute("XxNamedzxX_SkateMeter") or STARTING_SKATE_METER
	local maxSkateMeter = 10
	local isSkating = character:GetAttribute("XxNamedzxX_IsSkating") or false
	local previousHealth = humanoid.Health
	local meterChanged = Instance.new("BindableEvent")
	local isSkatingChanged = Instance.new("BindableEvent")
	self._meterSystemCharacter = character

	local drainConnection, stopSkating

	local function fireMeterChanged()
		meterChanged:Fire(skateMeter, maxSkateMeter, isSkating)
	end

	-- Initialize character attribute with current meter value
	character:SetAttribute("XxNamedzxX_SkateMeter", skateMeter)

	function stopSkating(reason)
		if not isSkating then
			return
		end
		debugPrint("stopSkating called:", reason)
		isSkating = false
		if self._meterSystemCharacter then
			self._meterSystemCharacter:SetAttribute("XxNamedzxX_IsSkating", false)
			self._meterSystemCharacter:SetAttribute("XxNamedzxX_SkateMeter", skateMeter)
		end

		if drainConnection and drainConnection.Connected then
			drainConnection:Disconnect()
			drainConnection = nil
		end

		local currentHumanoid = character:FindFirstChildOfClass("Humanoid")
		if currentHumanoid then
			currentHumanoid.AutoRotate = true
			currentHumanoid.WalkSpeed = DEFAULT_WALK_SPEED
		end
		setAccessoryTransparency(character, "Skateboard", 1)
		isSkatingChanged:Fire(false)
		fireMeterChanged()
	end

	local function startAutoForwardMovement()
		local hum = character:FindFirstChildOfClass("Humanoid")
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not hum or not rootPart then
			return
		end

		hum.AutoRotate = false

		local initialLook = (rootPart.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
		local travelDirection = initialLook
		-- Character faces right of travel (sideways skater stance, right side forward)
		local function getRightFacing(dir)
			return CFrame.lookAt(Vector3.zero, Vector3.new(dir.Z, 0, -dir.X))
		end
		local currentFacingCFrame = getRightFacing(travelDirection)

		local connection
		connection = RunService.Heartbeat:Connect(function(deltaTime)
			if not isSkating or skateMeter <= 0 then
				hum.AutoRotate = true
				if connection then
					connection:Disconnect()
				end
				stopSkating("Stopped")
				return
			end

			local currentRoot = character:FindFirstChild("HumanoidRootPart")
			local currentHumanoid = character:FindFirstChildOfClass("Humanoid")
			if not currentRoot or not currentHumanoid then
				return
			end

			-- Steer from WASD (MoveDirection is already world-space from camera)
			local worldInput = Vector3.new(currentHumanoid.MoveDirection.X, 0, currentHumanoid.MoveDirection.Z)
			if worldInput.Magnitude > 0.1 then
				-- Smoothly interpolate travel direction for gradual turning
				travelDirection = travelDirection:Lerp(worldInput.Unit, math.min(4 * deltaTime, 1))
				if travelDirection.Magnitude > 0.001 then
					travelDirection = travelDirection.Unit
				end
			end

			-- Smoothly rotate facing to stay right of travel direction
			local targetFacing = getRightFacing(travelDirection)
			currentFacingCFrame = currentFacingCFrame:Lerp(targetFacing, math.min(4 * deltaTime, 1))

			local speed = SKATEBOARD_SPEED
			local moveDistance = speed * deltaTime

			-- Raycast down to find ground level
			local rayDown = workspace:Raycast(currentRoot.Position + Vector3.new(0, 0.5, 0), Vector3.new(0, -8, 0))
			local targetY = rayDown and rayDown.Position.Y + 2.5 or currentRoot.Position.Y

			-- Lerp directly to ground height — no spring, no velocity, no bounce
			local newY = currentRoot.Position.Y + (targetY - currentRoot.Position.Y) * math.min(20 * deltaTime, 1)

			local newPosition = Vector3.new(
				currentRoot.Position.X + travelDirection.X * moveDistance,
				newY,
				currentRoot.Position.Z + travelDirection.Z * moveDistance
			)

			-- Check collision in movement direction
			local raycastParams = RaycastParams.new()
			raycastParams.FilterDescendantsInstances = { workspace.Map.InGame }
			raycastParams.FilterType = Enum.RaycastFilterType.Include
			local rayResult = workspace:Raycast(currentRoot.Position, travelDirection * moveDistance, raycastParams)
			if rayResult then
				stopSkating("Map collision")
				return
			end

			-- Apply smoothly interpolated facing with new position
			currentRoot.CFrame = currentFacingCFrame + newPosition

			-- Snap the skateboard under the root, flat on ground, aligned with travel
			local skateboardModel = character:FindFirstChild("Skateboard")
			if skateboardModel then
				local boardPos = newPosition + Vector3.new(0, -2.5, 0)
				-- Rotate 90° on X to lay the board flat (tip was facing sky = front axis is up)
				local boardCFrame = CFrame.lookAt(boardPos, boardPos + travelDirection, Vector3.new(0, 1, 0))
					* CFrame.Angles(math.rad(90), 0, 0)
				if skateboardModel:IsA("Model") then
					skateboardModel:PivotTo(boardCFrame)
				elseif skateboardModel:IsA("BasePart") then
					skateboardModel.CFrame = boardCFrame
				end
			end

			debugPrint(string.format("Skate CFrame move: %.1f dt, meter=%.1f", moveDistance, skateMeter))
		end)
	end

	local function startDrain()
		if drainConnection and drainConnection.Connected then
			return
		end
		drainConnection = RunService.Heartbeat:Connect(function(deltaTime)
			if isSkating and humanoid and humanoid.Health > 0 then
				local previousMeter = skateMeter
				skateMeter = math.max(0, skateMeter - deltaTime)
				self._meterSystemCharacter:SetAttribute("XxNamedzxX_SkateMeter", skateMeter)
				if skateMeter ~= previousMeter then
					fireMeterChanged()
				end
				if skateMeter <= 0 then
					stopSkating("Meter depleted")
				end
			end
		end)
		debugPrint("drainConnection started")
	end

	-- Removed natural regen - only minigames refill meter

	-- Health monitoring
	humanoid.HealthChanged:Connect(function(health)
		if health < previousHealth and isSkating then
			stopSkating("Took damage")
		end
		previousHealth = health
	end)

	-- No regen on init

	return {
		addMeter = function(amount)
			local previousMeter = skateMeter
			skateMeter = math.clamp(skateMeter + amount, 0, maxSkateMeter)
			self._meterSystemCharacter:SetAttribute("XxNamedzxX_SkateMeter", skateMeter)
			if skateMeter ~= previousMeter then
				fireMeterChanged()
			end
		end,
		getMeter = function()
			return skateMeter
		end,
		getMaxMeter = function()
			return maxSkateMeter
		end,
		setSkating = function(skating)
			-- Sync skateMeter from attribute in case it was updated elsewhere
			local attributeMeter = self._meterSystemCharacter:GetAttribute("XxNamedzxX_SkateMeter") or 0
			if attributeMeter ~= skateMeter then
				skateMeter = attributeMeter
			end

			if skating and skateMeter < MIN_SKATE_METER_TO_START then
				debugPrint("Cannot skate: insufficient meter", skateMeter)
				return
			end
			local wasSkating = isSkating
			isSkating = skating
			self._meterSystemCharacter:SetAttribute("XxNamedzxX_IsSkating", isSkating)
			if isSkating then
				startDrain()
				local hum = character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.WalkSpeed = SKATEBOARD_SPEED
				end
				setAccessoryTransparency(character, "Skateboard", 0)
				startAutoForwardMovement()
			else
				if drainConnection and drainConnection.Connected then
					drainConnection:Disconnect()
					drainConnection = nil
				end
				local hum = character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.WalkSpeed = DEFAULT_WALK_SPEED
					hum.AutoRotate = true
				end
				setAccessoryTransparency(character, "Skateboard", 1)
			end
			if wasSkating ~= isSkating then
				isSkatingChanged:Fire(isSkating)
			end
			fireMeterChanged()
		end,
		isSkating = function()
			return isSkating
		end,
		meterChanged = meterChanged.Event,
		isSkatingChanged = isSkatingChanged.Event,
	}
end

-- WeakTable to cache meter systems per character (auto-cleans when character is destroyed)
local MeterSystemCache = setmetatable({}, { __mode = "k" })

local function ensureMeterSystem(self)
	-- Use LocalPlayer on client, self.Owner on server
	local player = RunService:IsServer() and self.Owner or Players.LocalPlayer
	local character = player and player.Character
	if not character then
		return nil
	end

	-- Check if we already have a meter system for this character
	if MeterSystemCache[character] then
		return MeterSystemCache[character]
	end

	local meterSystem = initializeMeterSystem(self, character)
	if meterSystem then
		MeterSystemCache[character] = meterSystem
	end
	return meterSystem
end

local function SlopeTrickBehaviour(self)
	debugPrint("Slope Trick ability triggered!")
	local player = Players.LocalPlayer
	local character = player.Character
	local brokenBoard = character and character:GetAttribute("XxNamedzxX_HasBrokenBoard") or false
	local isBlocking = character and character:GetAttribute("XxNamedzxX_IsBlocking") or false
	if brokenBoard or isBlocking then
		return
	end
	if not RunService:IsServer() then
		if not character then
			return
		end

		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end

		local meterSystem = ensureMeterSystem(self)
		if not meterSystem then
			return
		end

		local skateboard = getSkateboardVisual(character)
		if skateboard then
			setModelTransparency(skateboard, 0)
		end

		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = { character }
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude

		local downRay = workspace:Raycast(hrp.Position, Vector3.new(0, -5, 0), raycastParams)
		if downRay then
			local part = downRay.Instance
			local normal = downRay.Normal
			local isOnWedge = part and part:IsA("BasePart") and part.Shape == Enum.PartType.Wedge
			local slope = isOnWedge or math.abs(normal.Y) < 0.85
			if slope then
				startSlopeTrickMinigame(meterSystem, skateboard)
			else
				if skateboard then
					setModelTransparency(skateboard, 1)
				end
			end
		else
			if skateboard then
				setModelTransparency(skateboard, 1)
			end
		end
	end
end

local function SkateboardBehaviour(self)
	print("[SkateboardBehaviour] FUNCTION CALLED!")
	debugPrint("Skateboard ability triggered!")
	
	-- CLIENT SIDE: Handle UI and meter system
	if not RunService:IsServer() then
		print("[SkateboardBehaviour] CLIENT SIDE")
		local player = Players.LocalPlayer
		if not player then
			print("[SkateboardBehaviour] No local player!")
			return
		end
		local character = player.Character
		if not character then
			print("[SkateboardBehaviour] No character!")
			return
		end
		print("[SkateboardBehaviour] Character found:", character.Name)
		
		local brokenBoard = character:GetAttribute("XxNamedzxX_HasBrokenBoard") or false
		local isBlocking = character:GetAttribute("XxNamedzxX_IsBlocking") or false
		print(string.format("[SkateboardBehaviour] brokenBoard=%s, isBlocking=%s", tostring(brokenBoard), tostring(isBlocking)))
		if brokenBoard or isBlocking then
			print("[SkateboardBehaviour] Blocked or broken, returning")
			return
		end

		local meterSystem = ensureMeterSystem(self)
		if not meterSystem then
			print("[SkateboardBehaviour] WARNING: meterSystem is nil!")
			return
		end
		print("[SkateboardBehaviour] Meter system obtained")

		local attributeMeter = character:GetAttribute("XxNamedzxX_SkateMeter") or 0
		print(string.format("[SkateboardBehaviour] Meter: %.1f / %.1f", attributeMeter, MIN_SKATE_METER_TO_START))
		debugPrint(string.format("Skateboard - Meter from attribute: %.1f", attributeMeter))

		if attributeMeter < MIN_SKATE_METER_TO_START then
			print("[SkateboardBehaviour] Not enough meter, showing toast")
			local playerGui = Players.LocalPlayer.PlayerGui
			local toast = Instance.new("ScreenGui")
			toast.Name = "LowMeterToast"
			toast.Parent = playerGui
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromOffset(300, 50)
			label.Position = UDim2.new(0.5, -150, 0.3, 0)
			label.BackgroundColor3 = Color3.new(1, 0, 0)
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextScaled = true
			label.Text =
				string.format("Not enough skate meter! Need %.1f, have %.1f", MIN_SKATE_METER_TO_START, attributeMeter)
			label.Parent = toast
			game:GetService("Debris"):AddItem(toast, 2)
			return
		end

		local skateboard = getSkateboardVisual(character)
		if skateboard then
			setModelTransparency(skateboard, 0)
		end

		print("[SkateboardBehaviour] Activating skating!")
		meterSystem.setSkating(true)
		character:SetAttribute("XxNamedzxX_SkateMeter", meterSystem.getMeter())
		print("Skateboarding activated!")
		
		local track = self.UseAnimationTrack
		if track then
			track.Priority = Enum.AnimationPriority.Action
			track:Play(0.2)
		end

		local _conn = meterSystem.isSkatingChanged:Connect(function()
			if not meterSystem.isSkating() then
				if track then
					track:Stop(0.2)
				end
				if skateboard then
					setModelTransparency(skateboard, 1)
				end
			end
		end)
		print("[SkateboardBehaviour] CLIENT DONE")
		return
	end
	
	-- SERVER SIDE: Grant EXP when skating activates
	print("[SkateboardBehaviour] SERVER SIDE")
	local owner = self.Owner
	if not owner then
		print("[SkateboardBehaviour] ERROR: No owner on server!")
		return
	end
	print("[SkateboardBehaviour] Owner:", owner.Name)
	local character = owner.Character
	if not character then
		print("[SkateboardBehaviour] No character on server!")
		return
	end
	
	local brokenBoard = character:GetAttribute("XxNamedzxX_HasBrokenBoard") or false
	local isBlocking = character:GetAttribute("XxNamedzxX_IsBlocking") or false
	if brokenBoard or isBlocking then
		return
	end
	
	-- Grant EXP on server when ability is used (character has enough meter)
	local attributeMeter = character:GetAttribute("XxNamedzxX_SkateMeter") or 0
	print(string.format("[SkateboardBehaviour] Server meter: %.1f", attributeMeter))
	if attributeMeter >= MIN_SKATE_METER_TO_START then
		print("[SkateboardBehaviour] GRANTING EXP!")
		if CommonFunctions then
			CommonFunctions.GrantRewardToPlayer(owner, { EXP = 10, Reason = "skateboarding as Namedz" })
			print("[SkateboardBehaviour] EXP granted!")
		else
			print("[SkateboardBehaviour] ERROR: CommonFunctions is nil on server!")
		end
	end
	print("[SkateboardBehaviour] SERVER DONE")
end

local function SkateboardBlockBehaviour(self)
	debugPrint("Skateboard block ability called!")
	if RunService:IsServer() then
		local player = self.Owner
		if not player then
			debugPrint("Block: No owner")
			return
		end
		local character = player.Character
		if not character then
			debugPrint("Block: No character")
			return
		end

		local brokenBoard = character:GetAttribute("XxNamedzxX_HasBrokenBoard") or false
		local isBlocking = character:GetAttribute("XxNamedzxX_IsBlocking") or false
		debugPrint(string.format("Block: brokenBoard=%s, isBlocking=%s", tostring(brokenBoard), tostring(isBlocking)))
		if brokenBoard or isBlocking then
			debugPrint("Block: Already blocked or board broken")
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			debugPrint("Block: No humanoid")
			return
		end

		debugPrint(
			string.format(
				"Skateboard block activated on SERVER! Health: %d, MaxHealth: %d",
				humanoid.Health,
				humanoid.MaxHealth
			)
		)
		character:SetAttribute("XxNamedzxX_IsBlocking", true)

		if CommonFunctions then
			CommonFunctions.ApplyEffect({
				TargetHumanoid = humanoid,
				EffectSettings = {
					Name = "Resistance",
					Level = 1,
					Duration = 3,
				},
			})
			debugPrint("Resistance effect applied to character during block")
		else
			debugPrint("CommonFunctions not available, skipping resistance effect")
		end

		local blockDuration = 3
		local blockActive = true
		local healthBeforeBlock = humanoid.Health
		debugPrint(string.format("Stored health before block: %d", healthBeforeBlock))

		local healthConn
		healthConn = humanoid.HealthChanged:Connect(function(health)
			debugPrint(
				string.format(
					"Health changed event: new=%d, old=%d, blockActive=%s",
					health,
					healthBeforeBlock,
					tostring(blockActive)
				)
			)
			if blockActive and health < healthBeforeBlock then
				debugPrint("XxNamedzxX took damage while blocking! Breaking board...")
				blockActive = false
				character:SetAttribute("XxNamedzxX_HasBrokenBoard", true)
				character:SetAttribute("XxNamedzxX_IsBlocking", false)
				if healthConn and healthConn.Connected then
					healthConn:Disconnect()
				end
			end
		end)

		task.delay(blockDuration, function()
			debugPrint(string.format("Block timeout - blockActive=%s", tostring(blockActive)))
			if blockActive then
				character:SetAttribute("XxNamedzxX_IsBlocking", false)
				debugPrint("Skateboard block ended on server - no hit detected.")
			end
			if healthConn and healthConn.Connected then
				healthConn:Disconnect()
			end
		end)

		return
	end

	local player = Players.LocalPlayer
	local character = player.Character
	if not character then
		debugPrint("Client block: No character found")
		return
	end

	local brokenBoard = character:GetAttribute("XxNamedzxX_HasBrokenBoard") or false
	local isBlocking = character:GetAttribute("XxNamedzxX_IsBlocking") or false
	debugPrint(
		string.format("Client block: brokenBoard=%s, isBlocking=%s", tostring(brokenBoard), tostring(isBlocking))
	)
	if brokenBoard or isBlocking then
		debugPrint("Client block: Already in a state, returning")
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		debugPrint("Client block: No humanoid found")
		return
	end

	debugPrint("Client block: Setting isBlocking attribute to true")
	character:SetAttribute("XxNamedzxX_IsBlocking", true)
	local skateboard = getSkateboardVisual(character)
	if skateboard then
		setModelTransparency(skateboard, 0)
	end

	local blockDuration = 3
	local blockActive = true

	local _brokenBoardConn = character:GetAttributeChangedSignal("XxNamedzxX_HasBrokenBoard"):Connect(function()
		if character:GetAttribute("XxNamedzxX_HasBrokenBoard") then
			debugPrint("Client: Board broken detected via attribute change")
			blockActive = false
			if skateboard then
				setModelTransparency(skateboard, 1)
			end
			print("Skateboard broken by hit! Bonk enabled.")
		end
	end)

	local _isBlockingConn = character:GetAttributeChangedSignal("XxNamedzxX_IsBlocking"):Connect(function()
		if not character:GetAttribute("XxNamedzxX_IsBlocking") then
			debugPrint("Client: Blocking ended via attribute change")
			blockActive = false
			if skateboard then
				setModelTransparency(skateboard, 1)
			end
		end
	end)

	task.delay(blockDuration, function()
		if blockActive then
			character:SetAttribute("XxNamedzxX_IsBlocking", false)
			if skateboard then
				setModelTransparency(skateboard, 1)
			end
			print("Skateboard block ended - no hit taken.")
		end
	end)

	print("Skateboard block activated! Blocking for up to 3 seconds...")
end

local function SkateboardBonkBehaviour(self)
	if not RunService:IsServer() then
		local player = Players.LocalPlayer
		local character = player.Character
		if not character then
			return
		end

		local brokenBoard = character:GetAttribute("XxNamedzxX_HasBrokenBoard") or false
		if not brokenBoard then
			return
		end

		debugPrint("Skateboard Bonk activated on CLIENT!")
		local board = character:FindFirstChild("BrokenBoard") or getSkateboardVisual(character)
		if board then
			if board:IsA("Model") then
				setModelTransparency(board, 0)
			elseif board:IsA("BasePart") then
				board.Transparency = 0
			end
			task.delay(0.8, function()
				if board:IsA("Model") then
					setModelTransparency(board, 1)
				elseif board:IsA("BasePart") then
					board.Transparency = 1
				end
			end)
		end
	else
		local character = self.Owner and self.Owner.Character
		if not character then
			return
		end
		local brokenBoard = character:GetAttribute("XxNamedzxX_HasBrokenBoard") or false
		if not brokenBoard then
			return
		end

		debugPrint("Skateboard Bonk activated on SERVER!")
		require(ReplicatedStorage.Classes.Hitbox).New(self.Owner, {
			CFrameOffset = CFrame.new(0, 0, -3),
			Size = Vector3.new(4, 4, 4),
			Time = 0.3,
			Damage = 0.1, -- Minimal damage to ensure hitbox registers, actual damage is negligible
			Reason = "Skateboard Bonk",
			ExecuteOnKill = false,
			EffectsToApply = {
				{
					Name = "Stunned",
					Subfolder = "KillerSpecific",
					Duration = 4,
					Level = 1,
					OverwriteExisting = true,
				},
			},
			Connections = {
				PostHit = function(_, targetHumanoid, isFirstHit)
					if isFirstHit and targetHumanoid then
						debugPrint(
							"Skateboard Bonk HIT! Stunning",
							targetHumanoid.Parent and targetHumanoid.Parent.Name or "unknown"
						)
					end
				end,
			},
		})
	end
end

debugPrint("Creating XxNamedzxX character instance...")
local Namedz: Types.Survivor = Character.CreateSurvivor({
	Config = {
		Name = "XxNamedzxX",
		Quote = "Itz skating tiem!",
		Render = "rbxassetid://134924431710405",
	},

	GameplayConfig = {
		Abilities = {
			SlopeTrick = Ability.New({
				Name = "Slope Trick",
				InputName = "FirstAbility",
				Cooldown = 10,
				EXP = 10,
				Behaviour = SlopeTrickBehaviour,
				UseConditions = function(self)
					local character = self.Owner and self.Owner.Character
					if not character then
						return false
					end
					local brokenBoard = character:GetAttribute("XxNamedzxX_HasBrokenBoard") or false
					local isBlocking = character:GetAttribute("XxNamedzxX_IsBlocking") or false
					return not brokenBoard and not isBlocking
				end,
				-- LockWatcher: directly reads LocalPlayer.Character attributes for the GUI overlay.
				-- Avoids the self.Owner chain which may not be reliable during polling.
				LockWatcher = function(_self)
					local character = Players.LocalPlayer.Character
					if not character then
						return false
					end
					local brokenBoard = character:GetAttribute("XxNamedzxX_HasBrokenBoard") or false
					local isBlocking = character:GetAttribute("XxNamedzxX_IsBlocking") or false
					return brokenBoard or isBlocking
				end,
			}),

Skateboard = Ability.New({
				Name = "Skateboard",
				InputName = "SecondAbility",
				Cooldown = 15,
				UseAnimation = SKATE_ANIMATION_ID,
				PlayUseAnimationOnUse = false,
				EXP = 0, -- No EXP on use, only when skating actually activates
				Behaviour = SkateboardBehaviour,
				UseConditions = function(self)
					local character = self.Owner and self.Owner.Character
					if not character then
						return false
					end
					local brokenBoard = character:GetAttribute("XxNamedzxX_HasBrokenBoard") or false
					local isBlocking = character:GetAttribute("XxNamedzxX_IsBlocking") or false
					return not brokenBoard and not isBlocking
				end,
				LockWatcher = function(_self)
					local character = Players.LocalPlayer.Character
					if not character then
						return false
					end
					local brokenBoard = character:GetAttribute("XxNamedzxX_HasBrokenBoard") or false
					local isBlocking = character:GetAttribute("XxNamedzxX_IsBlocking") or false
					return brokenBoard or isBlocking
				end,
			}),

			SkateboardBlock = Ability.New({
				Name = "Skateboard Block",
				InputName = "ThirdAbility",
				Cooldown = 20,
				Duration = 3,
				DisableOtherAbilitiesOnPerform = false,
				EXP = 12,
				Behaviour = SkateboardBlockBehaviour,
				UseConditions = function(self)
					local character = self.Owner and self.Owner.Character
					if not character then
						return false
					end
					local brokenBoard = character:GetAttribute("XxNamedzxX_HasBrokenBoard") or false
					local isBlocking = character:GetAttribute("XxNamedzxX_IsBlocking") or false
					return not brokenBoard and not isBlocking
				end,
				LockWatcher = function(_self)
					local character = Players.LocalPlayer.Character
					if not character then
						return false
					end
					local brokenBoard = character:GetAttribute("XxNamedzxX_HasBrokenBoard") or false
					local isBlocking = character:GetAttribute("XxNamedzxX_IsBlocking") or false
					return brokenBoard or isBlocking
				end,
			}),

			SkateboardBonk = Ability.New({
				Name = "Skateboard Bonk",
				InputName = "FourthAbility",
				Cooldown = 20,
				EXP = 15,
				Behaviour = SkateboardBonkBehaviour,
				UseConditions = function(self)
					local character = self.Owner and self.Owner.Character
					if not character then
						return false
					end
					local brokenBoard = character:GetAttribute("XxNamedzxX_HasBrokenBoard") or false
					local isBlocking = character:GetAttribute("XxNamedzxX_IsBlocking") or false
					return brokenBoard and not isBlocking
				end,
				-- SkateboardBonk is locked when the board is NOT broken (it only unlocks after break)
				LockWatcher = function(_self)
					local character = Players.LocalPlayer.Character
					if not character then
						return true
					end
					local brokenBoard = character:GetAttribute("XxNamedzxX_HasBrokenBoard") or false
					return not brokenBoard
				end,
			}),
		},
	},
	OnHit = function(_self, _hitbox, _damage)
		debugPrint("OnHit triggered for XxNamedzxX!")
	end,
	OnDamage = function(self)
		local character = self.Owner and self.Owner.Character
		if not character then
			return
		end

		local isBlocking = character:GetAttribute("XxNamedzxX_IsBlocking") or false
		if isBlocking then
			debugPrint("OnDamage: Block active, preventing damage and breaking board!")
			character:SetAttribute("XxNamedzxX_HasBrokenBoard", true)
			character:SetAttribute("XxNamedzxX_IsBlocking", false)
			return "Ignored" -- Prevent damage from being applied
		end
	end,
OnInit = function(self)
		local character = self.Owner and self.Owner.Character
		if not character then
			return
		end

		-- Set CharacterName attribute on SERVER so hitbox can find it
		character:SetAttribute("CharacterName", "XxNamedzxX")

		-- Initialize skate meter on BOTH server and client
		-- This ensures server knows about the meter value when granting EXP
		if not character:GetAttribute("XxNamedzxX_SkateMeter") then
			character:SetAttribute("XxNamedzxX_SkateMeter", STARTING_SKATE_METER)
		end
		if not character:GetAttribute("XxNamedzxX_IsSkating") then
			character:SetAttribute("XxNamedzxX_IsSkating", false)
		end
		if not character:GetAttribute("XxNamedzxX_HasBrokenBoard") then
			character:SetAttribute("XxNamedzxX_HasBrokenBoard", false)
		end
		if not character:GetAttribute("XxNamedzxX_IsBlocking") then
			character:SetAttribute("XxNamedzxX_IsBlocking", false)
		end
		print("[OnInit] Server initialized meter:", character:GetAttribute("XxNamedzxX_SkateMeter"))

if not RunService:IsServer() then
			debugPrint("OnSpawn called for XxNamedzxX")
			character:SetAttribute(
				"XxNamedzxX_SkateMeter",
				character:GetAttribute("XxNamedzxX_SkateMeter") or STARTING_SKATE_METER
			)
			character:SetAttribute("XxNamedzxX_IsSkating", character:GetAttribute("XxNamedzxX_IsSkating") or false)
			character:SetAttribute(
				"XxNamedzxX_HasBrokenBoard",
				character:GetAttribute("XxNamedzxX_HasBrokenBoard") or false
			)
			character:SetAttribute("XxNamedzxX_IsBlocking", character:GetAttribute("XxNamedzxX_IsBlocking") or false)
			debugPrint("Character found, default attributes set:", character:GetAttribute("XxNamedzxX_SkateMeter"))

			local player = Players.LocalPlayer
			local meterGui, heartbeatConn = createMeterDisplay(player)
			self.MeterGui = meterGui
			self.MeterConnection = heartbeatConn
			debugPrint("Skate meter GUI created")

-- Skateboard should already be present from server-side spawn (cloned from ServerStorage)
			-- Just verify it exists and hide it if present
			local skateboard = getSkateboardVisual(character)
			if skateboard then
				debugPrint("Skateboard found in character, hiding it")
				setModelTransparency(skateboard, 1)
			else
				debugPrint("WARNING: Skateboard not found in character! Server should add it.")
			end

			local brokenBoard = character:FindFirstChild("BrokenBoard")
			if brokenBoard then
				if brokenBoard:IsA("Model") then
					setModelTransparency(brokenBoard, 1)
				elseif brokenBoard:IsA("BasePart") then
					brokenBoard.Transparency = 1
				end
			end

			local function cleanupMeterGui()
				if self.MeterGui then
					self.MeterGui:Destroy()
					self.MeterGui = nil
				end
				if self.MeterConnection then
					self.MeterConnection:Disconnect()
					self.MeterConnection = nil
				end
				debugPrint("Skate meter GUI cleaned up")
			end

			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Died:Connect(cleanupMeterGui)
			end

			-- Also clean up when the round ends (RoundState flips to "Lobby")
			local roundState = ReplicatedStorage:FindFirstChild("RoundInfo")
				and ReplicatedStorage.RoundInfo:FindFirstChild("CurrentState")
			if roundState then
				roundState.Changed:Connect(function(newState)
					if newState == "Lobby" then
						cleanupMeterGui()
					end
				end)
			end

			-- Killer Detection Passive: Hear the killer from farther away
			local killerDetectionConnection
			killerDetectionConnection = RunService.Heartbeat:Connect(function()
				if not character or not character.Parent then
					if killerDetectionConnection then
						killerDetectionConnection:Disconnect()
					end
					return
				end

				local characterRoot = character:FindFirstChild("HumanoidRootPart")
				if not characterRoot then
					return
				end

				local killerCharacters = {}
				for _, plr in ipairs(Players:GetPlayers()) do
					if plr ~= player and plr.Character then
						local role = plr.Character:FindFirstChild("Role")
						if role and role.Value == "Killer" then
							table.insert(killerCharacters, plr.Character)
						end
					end
				end

				if #killerCharacters > 0 then
					local nearestKiller = nil
					local nearestDistance = math.huge

					for _, killerChar in ipairs(killerCharacters) do
						local killerRoot = killerChar:FindFirstChild("HumanoidRootPart")
						if killerRoot then
							local distance = (killerRoot.Position - characterRoot.Position).Magnitude
							if distance < nearestDistance then
								nearestDistance = distance
								nearestKiller = killerChar
							end
						end
					end

					-- Alert at 80 studs (farther than normal vision)
					if nearestKiller and nearestDistance < 80 then
						local killerName = nearestKiller:GetAttribute("CharacterName") or nearestKiller.Name
						character:SetAttribute("XxNamedzxX_DetectedKiller", killerName)
						character:SetAttribute("XxNamedzxX_KillerDistance", nearestDistance)
						debugPrint(
							string.format("Namedz Passive: Detected %s at %.1f studs away", killerName, nearestDistance)
						)
					else
						if character:GetAttribute("XxNamedzxX_DetectedKiller") then
							debugPrint("Namedz Passive: Lost killer detection")
						end
						character:SetAttribute("XxNamedzxX_DetectedKiller", nil)
						character:SetAttribute("XxNamedzxX_KillerDistance", nil)
					end
				end
			end)
		end
	end,
})

local NamedzNameLabel = '<font color="rgb(255, 200, 50)">XxNamedzxX</font>'

Namedz.Config.Description = {
	{
		Type = "Separator",
		Text = "GENERAL INFO",
	},
	{
		Type = "Header",
		Text = Namedz.Config.Name:upper(),
	},
	{
		Type = "Quote",
		Text = '"' .. Namedz.Config.Quote .. '"',
	},
	{
		Type = "Text",
		Text = NamedzNameLabel
			.. ", the skating protagonist of the Namedz Archive channel, rolls into danger with a board under his feet and chaos in his heart. "
			.. "He lives for the grind, literally. Whether he's pulling tricks on a slope or blocking a killer's strike with his skate board, "
			.. NamedzNameLabel
			.. " uses momentum, improvisation, and a broken plank to keep himself alive.",
	},
	{
		Type = "Separator",
		Text = "ABILITIES",
	},
	{
		Type = "Header",
		Text = Namedz.GameplayConfig.Abilities.SlopeTrick.Name:upper(),
	},
	{
		Type = "Text",
		Text = "While standing on a slope, "
			.. NamedzNameLabel
			.. " can attempt a trick — either a <b>key sequence</b> or a <b>dot-clicking minigame</b>. "
			.. "Completing it fills the <b>Skate Meter</b> by 5. Cooldown: <b>10s</b>.",
	},
	{
		Type = "Header",
		Text = Namedz.GameplayConfig.Abilities.Skateboard.Name:upper(),
	},
	{
		Type = "Text",
		Text = NamedzNameLabel
			.. " hops on his skateboard and rockets forward at high speed, draining the <b>Skate Meter</b> over time. "
			.. "Requires at least <b>3 meter</b> to activate. Taking damage stops the ride. Cooldown: <b>15s</b>.",
	},
	{
		Type = "Header",
		Text = Namedz.GameplayConfig.Abilities.SkateboardBlock.Name:upper(),
	},
	{
		Type = "Text",
		Text = NamedzNameLabel
			.. " raises his board to block incoming hits for up to <b>3 seconds</b>, gaining <b>Resistance</b> for the duration. "
			.. "If struck while blocking, the board <b>breaks</b> — disabling Skateboard and Slope Trick, "
			.. "but unlocking <b>Skateboard Bonk</b> and absorbing the hit entirely. Cooldown: <b>20s</b>.",
	},
	{
		Type = "Header",
		Text = Namedz.GameplayConfig.Abilities.SkateboardBonk.Name:upper(),
	},
	{
		Type = "Text",
		Text = "Only available after the board is broken. "
			.. NamedzNameLabel
			.. " swings the broken shard at the killer. On hit, the killer is <b>Stunned for 4 seconds</b>. Cooldown: <b>20s</b>.",
	},
	{
		Type = "Header",
		Text = "PASSIVE — KILLER RADAR",
	},
	{
		Type = "Text",
		Text = NamedzNameLabel
			.. " can sense the killer's presence from up to <b>80 studs away</b> — further than normal. "
			.. "When the killer is within range, he's alerted to their location and approximate distance.",
	},
}

debugPrint("XxNamedzxX character created successfully!")
return Namedz
