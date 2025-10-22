local Customization = {

-- Wave Settings
	WaitingText = "",
	CountdownTextFormat = "Wave starting in %d",
	WaveTextFormat = "Wave %d",
	CountdownDuration = 10,
	WaveSoundId = "rbxassetid://4398694764",

-- Zombie Settings
	SpawnCap = 65,
	BaseZombies = 10,
	ZombieList = {
		{ name = "NormalZombie1", startWave = 1 },
		{ name = "NormalZombie2", startWave = 1 },
		{ name = "NormalZombie3", startWave = 1 },
		{ name = "RunnerZombie1", startWave = 3, perWave = 1 },
	}

}

return Customization