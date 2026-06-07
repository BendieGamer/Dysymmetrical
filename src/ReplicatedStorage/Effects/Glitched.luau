local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Effect = require(ReplicatedStorage.Classes.Effect)

-- keyed by char Model, stores the thread handle so RemoveEffect can cancel it
local dotThreads = {}

-- client-side state
local flickerConn
local fadeThread

return Effect.New({
	Name = "Glitched",
	Description = "Deals damage over time and corrupts the player's screen.",
	Duration = 10,
	ShowInGUI = true,

	ApplyEffect = function(_self, level, char, duration)
		if RunService:IsServer() then
			-- 2 damage per tick, every 1 second, for the full duration
			local tickDamage = 2 * (level or 1)
			local ticks = math.floor(duration)
			local humanoid = char:FindFirstChildWhichIsA("Humanoid")
			if not humanoid then return end

			local thread = task.spawn(function()
				for _ = 1, ticks do
					task.wait(1)
					local hum = char:FindFirstChildWhichIsA("Humanoid")
					if not hum or hum.Health <= 0 then break end
					-- Find the killer who applied the effect via the character's Role attribute
					-- Fall back to raw humanoid damage if no source player is known
					hum:TakeDamage(tickDamage)
				end
			end)
			dotThreads[char] = thread
		else
			-- visual: cyan/magenta screen flicker
			local existing = Lighting:FindFirstChild("GlitchedColorCorrection")
			if existing then existing:Destroy() end

			local cc = Instance.new("ColorCorrectionEffect")
			cc.Name = "GlitchedColorCorrection"
			cc.TintColor = Color3.fromRGB(0, 255, 200)
			cc.Brightness = 0.08
			cc.Contrast = 0.15
			cc.Saturation = -0.4
			cc.Parent = Lighting

			local flickerColors = {
				Color3.fromRGB(0, 255, 200),
				Color3.fromRGB(200, 0, 255),
				Color3.fromRGB(0, 220, 255),
				Color3.fromRGB(0, 255, 200),
			}
			local flickerIndex = 1
			local flickerAccum = 0
			flickerConn = RunService.Heartbeat:Connect(function(dt)
				flickerAccum += dt
				if flickerAccum >= 0.08 then
					flickerAccum = 0
					flickerIndex = (flickerIndex % #flickerColors) + 1
					local current = Lighting:FindFirstChild("GlitchedColorCorrection")
					if current then
						current.TintColor = flickerColors[flickerIndex]
					end
				end
			end)

			local fadeAt = math.max(duration - 1, 0.1)
			fadeThread = task.delay(fadeAt, function()
				if flickerConn then
					flickerConn:Disconnect()
					flickerConn = nil
				end
				local current = Lighting:FindFirstChild("GlitchedColorCorrection")
				if current then
					TweenService:Create(current, TweenInfo.new(1, Enum.EasingStyle.Sine), {
						Brightness = 0,
						Contrast = 0,
						Saturation = 0,
						TintColor = Color3.fromRGB(255, 255, 255),
					}):Play()
				end
			end)
		end
	end,

	RemoveEffect = function(_self, char)
		if RunService:IsServer() then
			local thread = dotThreads[char]
			if thread then
				task.cancel(thread)
				dotThreads[char] = nil
			end
		else
			if flickerConn then
				flickerConn:Disconnect()
				flickerConn = nil
			end
			if fadeThread then
				task.cancel(fadeThread)
				fadeThread = nil
			end
			local cc = Lighting:FindFirstChild("GlitchedColorCorrection")
			if cc then cc:Destroy() end
		end
	end,
})
