local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local systemFolder = ReplicatedStorage.ZombieWaveSystemV1
local eventsFolder = systemFolder.Events
local modulesFolder = systemFolder.Modules
local endlessEvent = eventsFolder:WaitForChild("EndlessZombiesEvent")
local statusFunction = eventsFolder:WaitForChild("EndlessZombiesStatus")
local customizationModule = modulesFolder:WaitForChild("Customization")

local spawnCap = 65
local Custom = {
	SpawnCap = spawnCap,
	BaseZombies = 10,
	CountdownDuration = 10,
	WaveSoundId = "rbxassetid://4398694764",
}
if customizationModule and customizationModule:IsA("ModuleScript") then
	local ok, mod = pcall(require, customizationModule)
	if ok and type(mod) == "table" then
		if type(mod.SpawnCap) == "number" then Custom.SpawnCap = math.max(0, mod.SpawnCap) end
		if type(mod.BaseZombies) == "number" then Custom.BaseZombies = math.max(0, mod.BaseZombies) end
		if type(mod.CountdownDuration) == "number" then Custom.CountdownDuration = math.max(0, mod.CountdownDuration) end
		if mod.WaveSoundId ~= nil then
			if type(mod.WaveSoundId) == "number" then
				Custom.WaveSoundId = "rbxassetid://" .. tostring(mod.WaveSoundId)
			elseif type(mod.WaveSoundId) == "string" and #mod.WaveSoundId > 0 then
				if mod.WaveSoundId:match("^%d+$") then
					Custom.WaveSoundId = "rbxassetid://" .. mod.WaveSoundId
				else
					Custom.WaveSoundId = mod.WaveSoundId
				end
			end
		end
	end
end
local spawnCap = Custom.SpawnCap

local zombiesFolder = systemFolder.Zombies
local zombieSpawnFolder = workspace:WaitForChild("ZombieSpawns")

local ZombieConfig = {}
do
	local ok, mod = pcall(function() return require(customizationModule) end)
	if ok and type(mod) == "table" and type(mod.ZombieList) == "table" then
		for _, entry in ipairs(mod.ZombieList) do
			if type(entry) == "table" and type(entry.name) == "string" then
				local model = zombiesFolder:FindFirstChild(entry.name)
				if model then
					ZombieConfig[#ZombieConfig + 1] = {
						name = entry.name,
						model = model,
						startWave = tonumber(entry.startWave) or 1,
						perWave = tonumber(entry.perWave) or nil,
					}
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

statusFunction.OnServerInvoke = function(player)
	return {
		inWave = inWave,
		currentWave = currentWave,
	}
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