local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mainGui = playerGui:WaitForChild("EndlessZombiesGui")
local waveLabel = mainGui:WaitForChild("WaveIndicator")

local systemFolder = ReplicatedStorage:WaitForChild("ZombieWaveSystemV1")
local eventsFolder = systemFolder:WaitForChild("Events")
local endlessEvent = eventsFolder:WaitForChild("EndlessEvent")
local statusRequest = eventsFolder:FindFirstChild("StatusRequest")
local statusResponse = eventsFolder:FindFirstChild("StatusResponse")

local Config = {
	WaitingText = "Waiting...",
	CountdownTextFormat = "Wave starting in %d",
	WaveTextFormat = "Wave %d",
}
do
	local modulesFolder = systemFolder:FindFirstChild("Modules") or systemFolder
	local customizationModule = modulesFolder:FindFirstChild("Customization") or ReplicatedStorage:FindFirstChild("Customization")
	local customization = nil
	if customizationModule and customizationModule:IsA("ModuleScript") then
		customization = require(customizationModule)
		if type(customization) ~= "table" then
			warn("[EndlessZombies][Client] Customization module did not return a table; using defaults")
			customization = nil
		end
	end
	if customization then
		if type(customization.WaitingText) == "string" then Config.WaitingText = customization.WaitingText end
		if type(customization.CountdownTextFormat) == "string" then Config.CountdownTextFormat = customization.CountdownTextFormat end
		if type(customization.WaveTextFormat) == "string" then Config.WaveTextFormat = customization.WaveTextFormat end
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
	if statusRequest and statusResponse and statusRequest:IsA("RemoteEvent") and statusResponse:IsA("RemoteEvent") then
		local received = false
		local status = nil
		local conn
		conn = statusResponse.OnClientEvent:Connect(function(data)
			status = data
			received = true
			conn:Disconnect()
		end)
		statusRequest:FireServer()
		local timeout = 0
		while not received and timeout < 2 do
			wait(0.05)
			timeout = timeout + 0.05
		end
		if received and type(status) == "table" and status.inWave and status.currentWave then
			showingCountdown = false
			waveLabel.Text = string.format(Config.WaveTextFormat, tonumber(status.currentWave) or 0)
			return
		end
	end
	waveLabel.Text = Config.WaitingText
end

initializeStatus()