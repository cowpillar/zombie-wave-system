local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local systemFolder = ReplicatedStorage:WaitForChild("ZombieWaveSystemV1")
local eventsFolder = systemFolder:WaitForChild("Events")
local modulesFolder = systemFolder:WaitForChild("Modules")
local endlessEvent = eventsFolder:WaitForChild("EndlessEvent")
local statusRequest = eventsFolder:FindFirstChild("StatusRequest")
local statusResponse = eventsFolder:FindFirstChild("StatusResponse")
local customizationModuleInstance = modulesFolder:WaitForChild("Customization")
local customization = require(customizationModuleInstance)
if type(customization) ~= "table" then
	warn("[EndlessZombies] Customization module did not return a table; using defaults where possible")
	customization = {}
end

local DEFAULTS = {
	SpawnCap = 65,
	BaseZombies = 10,
	CountdownDuration = 10,
	WaveSoundId = "rbxassetid://4398694764",
}

local function normalizeWaveSoundId(v)
	if v == nil then return DEFAULTS.WaveSoundId end
	if type(v) == "number" then
		return "rbxassetid://" .. tostring(v)
	elseif type(v) == "string" then
		if v:match("^%d+$") then
			return "rbxassetid://" .. v
		else
			return v
		end
	end
	return DEFAULTS.WaveSoundId
end

local Custom = {
	SpawnCap = (type(customization.SpawnCap) == "number" and math.max(0, customization.SpawnCap)) or DEFAULTS.SpawnCap,
	BaseZombies = (type(customization.BaseZombies) == "number" and math.max(0, customization.BaseZombies)) or DEFAULTS.BaseZombies,
	CountdownDuration = (type(customization.CountdownDuration) == "number" and math.max(0, customization.CountdownDuration)) or DEFAULTS.CountdownDuration,
	WaveSoundId = normalizeWaveSoundId(customization.WaveSoundId),
}

local spawnCap = Custom.SpawnCap

local zombiesFolder = systemFolder:FindFirstChild("Zombies")
local zombieSpawnFolder = workspace:WaitForChild("ZombieSpawns")

local ZombieConfig = {}
do
	if type(customization.ZombieList) == "table" then
		for _, entry in ipairs(customization.ZombieList) do
			if type(entry) == "table" and type(entry.name) == "string" then
				local model = zombiesFolder and zombiesFolder:FindFirstChild(entry.name)
				if model then
					ZombieConfig[#ZombieConfig + 1] = {
						name = entry.name,
						model = model,
						startWave = tonumber(entry.startWave) or 1,
						perWave = tonumber(entry.perWave) or nil,
					}
				else
					warn("[EndlessZombies] Zombie model not found for ZombieList entry: " .. tostring(entry.name))
				end
			end
		end
	end
end

local ConfiguredNames = {}
for _, z in ipairs(ZombieConfig) do
	ConfiguredNames[z.name] = true
end

local Teams = game:GetService("Teams")
local aliveTeam = Teams:FindFirstChild("Alive")
local deadTeam = Teams:FindFirstChild("Dead")
wait(1)

local currentWave = 1
local inWave = false

if statusRequest and statusResponse and statusRequest:IsA("RemoteEvent") and statusResponse:IsA("RemoteEvent") then
	statusRequest.OnServerEvent:Connect(function(player)
		statusResponse:FireClient(player, {
			inWave = inWave,
			currentWave = currentWave,
		})
	end)
end

local function waveSound()
	local sound = Instance.new("Sound")
	sound.SoundId = Custom.WaveSoundId or "rbxassetid://4398694764"
	sound.Parent = workspace
	sound:Play()
	sound.Ended:Wait()
end

local function waveNumber(wave)
	endlessEvent:FireAllClients("wave", wave)
end

local function zombieSpawner()
	local spawnerList = {}
	for _, descendant in pairs(zombieSpawnFolder:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "Spawner" then
			table.insert(spawnerList, descendant)
		end
	end
	return spawnerList
end

local function countZombiesByName(name)
	local count = 0
	for _, obj in pairs(workspace:GetChildren()) do
		if obj.Name == name then
			local humanoid = obj:FindFirstChild("Humanoid")
			if humanoid and humanoid.Health > 0 then
				count += 1
			end
		end
	end
	return count
end

local function totalConfiguredZombiesCount()
	local total = 0
	for name, _ in pairs(ConfiguredNames) do
		total += countZombiesByName(name)
	end
	return total
end

local function clearAllZombies()
	for _, obj in pairs(workspace:GetChildren()) do
		if ConfiguredNames[obj.Name] then
			obj:Destroy()
		else
			if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") and obj.Name:match("Zombie") then
				if not Players:GetPlayerFromCharacter(obj) then
					obj:Destroy()
				end
			end
		end
	end
end

local function getTeamSpawnLocations(team)
	if not team then return {} end
	local spawns = {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("SpawnLocation") and d.TeamColor == team.TeamColor then
			table.insert(spawns, d)
		end
	end
	return spawns
end

local function teleportPlayersToTeamSpawns(playersToTeleport)
	local spawns = getTeamSpawnLocations(aliveTeam)
	if #spawns == 0 then return end
	for _, player in ipairs(playersToTeleport) do
		if player.Team == aliveTeam then
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local spawnLocation = spawns[math.random(#spawns)]
				hrp.CFrame = spawnLocation.CFrame + Vector3.new(0, 3, 0)
			end
		end
	end
end

local function playerDead()
	for _, player in pairs(Players:GetPlayers()) do
		if player.Team == aliveTeam then
			return false
		end
	end
	return true
end

local function setupPlayer(player)
	local function bindHumanoid(character)
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
		if not humanoid then return end
		humanoid.Died:Connect(function()
			if deadTeam then
				player.Team = deadTeam
			end
		end)
	end

	player.CharacterAdded:Connect(bindHumanoid)
	if player.Character then
		bindHumanoid(player.Character)
	end
end

for _, player in pairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(function(player)
	setupPlayer(player)
end)

while true do
	if inWave and playerDead() then
		clearAllZombies()
		currentWave = 1
		inWave = false
		for _, plr in ipairs(Players:GetPlayers()) do
			if deadTeam then
				plr.Team = deadTeam
			end
		end
		continue
	end

	if currentWave == 1 then
		local countdown = Custom.CountdownDuration
		for i = countdown, 1, -1 do
			if inWave and playerDead() then
				break
			end
			endlessEvent:FireAllClients("countdown", i)
			wait(1)
		end
		endlessEvent:FireAllClients("countdown", 0)
		-- Build list of players that are not currently Alive (to teleport only revived players)
		local toTeleport = {}
		local allPlayers = Players:GetPlayers()
		for _, player in ipairs(allPlayers) do
			if player.Team ~= aliveTeam then
				table.insert(toTeleport, player)
			end
		end
		-- Switch everyone to Alive for the wave
		for _, player in ipairs(allPlayers) do
			if aliveTeam then
				player.Team = aliveTeam
			end
		end
		teleportPlayersToTeamSpawns(toTeleport)
		inWave = true
	end

	if not inWave then
		if playerDead() then
			break
		end
		local toTeleport = {}
		local allPlayers = Players:GetPlayers()
		for _, player in ipairs(allPlayers) do
			if player.Team ~= aliveTeam then
				table.insert(toTeleport, player)
			end
		end
		for _, player in ipairs(allPlayers) do
			if aliveTeam then
				player.Team = aliveTeam
			end
		end
		teleportPlayersToTeamSpawns(toTeleport)
		inWave = true
	end
	print("=== Wave " .. currentWave .. " Starting ===")
	waveNumber(currentWave)
	waveSound()

	local totalZombiesThisWave = 0
	if Custom.BaseZombies and #ZombieConfig > 0 then
		totalZombiesThisWave = currentWave * Custom.BaseZombies
	end

	local spawnedZombies = 0
	local spawnerParts = zombieSpawner()

	while spawnedZombies < totalZombiesThisWave do
		if playerDead() then break end

		if totalConfiguredZombiesCount() >= spawnCap then
			wait(0.25)
			continue
		end

		local spawnModel = nil

		for _, z in ipairs(ZombieConfig) do
			if z.perWave and currentWave >= z.startWave then
				local quota = z.perWave
				local alive = countZombiesByName(z.name)
				if alive < quota then
					spawnModel = z.model:Clone()
					break
				end
			end
		end

		if not spawnModel then
			local eligibleNormals = {}
			for _, z in ipairs(ZombieConfig) do
				if (not z.perWave) and currentWave >= z.startWave then
					table.insert(eligibleNormals, z)
				end
			end
			if #eligibleNormals > 0 then
				local chosen = eligibleNormals[math.random(#eligibleNormals)]
				spawnModel = chosen.model:Clone()
			else
				local eligibleLimited = {}
				for _, z in ipairs(ZombieConfig) do
					if z.perWave and currentWave >= z.startWave then
						table.insert(eligibleLimited, z)
					end
				end
				if #eligibleLimited > 0 then
					local chosen = eligibleLimited[math.random(#eligibleLimited)]
					spawnModel = chosen.model:Clone()
				else
					break
				end
			end
		end

		if spawnModel then
			local humanoid = spawnModel:FindFirstChild("Humanoid")
			if humanoid then
				local bonusHealth = currentWave * 5
				humanoid.MaxHealth += bonusHealth
				humanoid.Health = humanoid.MaxHealth
			end

			local spawnPoint = spawnerParts[math.random(#spawnerParts)]
			spawnModel.Parent = workspace
			spawnModel:MoveTo(spawnPoint.Position + Vector3.new(0, 3, 0))
			spawnedZombies += 1
			print("Spawned " .. spawnedZombies .. "/" .. totalZombiesThisWave)
			wait(0.25)
		end
	end

	print("All zombies spawned.")

	local waveAborted = false
	repeat
		if playerDead() then
			clearAllZombies()
			currentWave = 1
			inWave = false
			for _, plr in ipairs(Players:GetPlayers()) do
				if deadTeam then
					plr.Team = deadTeam
				end
			end
			waveAborted = true
			break
		end

		local remaining = totalConfiguredZombiesCount()
		print("Zombies remaining: " .. remaining)
		wait(1)
	until remaining == 0

	if waveAborted then
		continue
	end

	inWave = false
	print("Wave " .. currentWave .. " cleared.\n")
	currentWave += 1
	wait(1)
end