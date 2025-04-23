local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
wait(5)

local zombieVariants = {
	ReplicatedStorage:WaitForChild("NormalZombie1"),
	ReplicatedStorage:WaitForChild("NormalZombie2"),
	ReplicatedStorage:WaitForChild("NormalZombie3")
}
local runnerZombie = ReplicatedStorage:WaitForChild("RunnerZombie1")
local zombieSpawnFolder = workspace:WaitForChild("ZombieSpawns")

local spawnCap = 10
local currentWave = 1

local function waveSound()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://4398694764"
	sound.Parent = workspace
	sound:Play()
	sound.Ended:Wait()
end

local function waveNumber(wave)
	for _, player in pairs(Players:GetPlayers()) do
		local mainGui = player.PlayerGui and player.PlayerGui.EndlessZombiesGui
		local waveLabel = mainGui and mainGui.WaveIndicator
		if waveLabel then
			waveLabel.Text = "Wave " .. wave
		end
	end
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

local function zombieNormalCount()
	local count = 0
	for _, obj in pairs(workspace:GetChildren()) do
		local humanoid = obj:FindFirstChild("Humanoid")
		if humanoid and humanoid.Health > 0 and obj.Name:match("Zombie") then
			count += 1
		end
	end
	return count
end

local function zombieRunnerCount()
	local count = 0
	for _, obj in pairs(workspace:GetChildren()) do
		local humanoid = obj:FindFirstChild("Humanoid")
		if obj.Name == "RunnerZombie1" and humanoid and humanoid.Health > 0 then
			count += 1
		end
	end
	return count
end

while true do
	print("=== Wave " .. currentWave .. " Starting ===")
	waveNumber(currentWave)
	waveSound()

	local totalZombiesThisWave = currentWave * 10
	local spawnedZombies = 0
	local spawnedRunners = 0
	local runnerTarget = currentWave >= 3 and 5 or 0
	local spawnerParts = zombieSpawner()

	while spawnedZombies < totalZombiesThisWave do
		if zombieNormalCount() >= spawnCap then
			wait(0.25)
			continue
		end

		local zombie
		if currentWave >= 3 and zombieRunnerCount() < runnerTarget and spawnedRunners < totalZombiesThisWave then
			zombie = runnerZombie:Clone()
			spawnedRunners += 1
		else
			zombie = zombieVariants[math.random(#zombieVariants)]:Clone()
			local humanoid = zombie:FindFirstChild("Humanoid")
			if humanoid then
				local bonusHealth = currentWave * 5
				humanoid.MaxHealth += bonusHealth
				humanoid.Health = humanoid.MaxHealth
			end
		end

		local spawnPoint = spawnerParts[math.random(#spawnerParts)]
		zombie.Parent = workspace
		zombie:MoveTo(spawnPoint.Position + Vector3.new(0, 3, 0))
		spawnedZombies += 1
		print("Spawned " .. spawnedZombies .. "/" .. totalZombiesThisWave)
		wait(0.25)
	end

	print("All zombies spawned.")

	repeat
		local remaining = zombieNormalCount()
		print("Zombies remaining: " .. remaining)
		wait(1)
	until remaining == 0

	print("Wave " .. currentWave .. " cleared.\n")
	currentWave += 1
	wait(5)
end