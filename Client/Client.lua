local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("EndlessZombiesGui")
local waveLabel = mainGui:WaitForChild("WaveIndicator")

local systemFolder = ReplicatedStorage.ZombieWaveSystemV1
local eventsFolder = systemFolder.Events
local endlessEvent = eventsFolder:WaitForChild("EndlessZombiesEvent")
local statusFunction = eventsFolder:WaitForChild("EndlessZombiesStatus")

local Config = {
	WaitingText = "Waiting...",
	CountdownTextFormat = "Wave starting in %d",
	WaveTextFormat = "Wave %d",
}
do
	local modulesFolder = systemFolder:FindFirstChild("Modules") or systemFolder
	local customization = modulesFolder:FindFirstChild("Customization") or ReplicatedStorage:FindFirstChild("Customization")
	if customization and customization:IsA("ModuleScript") then
		local ok, mod = pcall(require, customization)
		if ok and type(mod) == "table" then
			if type(mod.WaitingText) == "string" then Config.WaitingText = mod.WaitingText end
			if type(mod.CountdownTextFormat) == "string" then Config.CountdownTextFormat = mod.CountdownTextFormat end
			if type(mod.WaveTextFormat) == "string" then Config.WaveTextFormat = mod.WaveTextFormat end
		end
	end
end

local showingCountdown = false

local function onEvent(action, value)
	if action == "countdown" then
		showingCountdown = true
		if value > 0 then
			waveLabel.Text = string.format(Config.CountdownTextFormat, tonumber(value) or 0)
		else
			waveLabel.Text = string.format(Config.WaveTextFormat, 1)
			showingCountdown = false
		end
	elseif action == "wave" then
		if not showingCountdown then
			waveLabel.Text = string.format(Config.WaveTextFormat, tonumber(value) or 0)
		end
	end
end

endlessEvent.OnClientEvent:Connect(onEvent)

local function initializeStatus()
	if statusFunction and statusFunction:IsA("RemoteFunction") then
		local ok, status = pcall(function()
			return statusFunction:InvokeServer()
		end)
		if ok and type(status) == "table" then
			if status.inWave and status.currentWave then
				showingCountdown = false
				waveLabel.Text = string.format(Config.WaveTextFormat, tonumber(status.currentWave) or 0)
				return
			end
		end
	end
	waveLabel.Text = Config.WaitingText
end

initializeStatus()