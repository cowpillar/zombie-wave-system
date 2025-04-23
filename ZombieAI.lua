local char = script.Parent
local humanoid = char:WaitForChild("Humanoid")
local hrp = char:WaitForChild("HumanoidRootPart")
local plr = game:GetService("Players"):GetPlayerFromCharacter(char)
local R6 = require(script:WaitForChild("R6"))

local idleSounds = {
	1158093080,
	1158093243,
	1158093410,
	1158093080
}

local attackSounds = {
	1158091792,
	1158091961,
	1158091668
}

local function playIdleSounds()
	task.spawn(function()
		while humanoid.Health > 0 do
			local soundId = idleSounds[math.random(1, #idleSounds)]
			local sfx = Instance.new("Sound")
			sfx.SoundId = "rbxassetid://" .. soundId
			sfx.Volume = 0.5
			sfx.Parent = hrp
			sfx:Play()
			game:GetService("Debris"):AddItem(sfx, 5)
			task.wait(math.random(2, 4))
		end
	end)
end

playIdleSounds()

local function setNetworkOwner()
	for _, bp in pairs(char:GetChildren()) do
		if bp:IsA("BasePart") and bp:CanSetNetworkOwnership() then
			bp:SetNetworkOwner(plr)
		end
	end
end

humanoid.Died:Connect(function()
	R6(char)
	setNetworkOwner()
	delay(3, function()
		char:Destroy()
	end)
end)

humanoid.WalkSpeed = 10
local ATTACK_RANGE = 2
local ATTACK_COOLDOWN = 2
local ATTACK_DAMAGE = 10
local lastAttackTime = 0

local walkAnim = Instance.new("Animation")
walkAnim.AnimationId = "http://www.roblox.com/asset/?id=180426354"
local walk = humanoid:LoadAnimation(walkAnim)
walk.Looped = true

local idleAnim = Instance.new("Animation")
idleAnim.AnimationId = "http://www.roblox.com/asset/?id=180435571"
local idle = humanoid:LoadAnimation(idleAnim)
idle.Looped = true

idle:Play()

local function findNearestPlayer()
	local players = game:GetService("Players"):GetPlayers()
	local closestPlayer = nil
	local shortestDistance = math.huge
	for _, player in ipairs(players) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character.Humanoid.Health > 0 then
			local distance = (player.Character.HumanoidRootPart.Position - hrp.Position).magnitude
			if distance < shortestDistance then
				shortestDistance = distance
				closestPlayer = player
			end
		end
	end
	return closestPlayer, shortestDistance
end

local function attackPlayer(target)
	if os.clock() - lastAttackTime < ATTACK_COOLDOWN then return end
	if target.Character and target.Character:FindFirstChild("Humanoid") then
		target.Character.Humanoid:TakeDamage(ATTACK_DAMAGE)

		local attackSound = Instance.new("Sound")
		attackSound.SoundId = "rbxassetid://" .. attackSounds[math.random(1, #attackSounds)]
		attackSound.Volume = 0.25
		attackSound.Parent = hrp
		attackSound:Play()
		game:GetService("Debris"):AddItem(attackSound, 3)
	end
	lastAttackTime = os.clock()
end

local prevPos = hrp.Position

while humanoid.Health > 0 do
	task.wait(0.1)
	local nearestPlayer, distance = findNearestPlayer()
	if nearestPlayer and nearestPlayer.Character and nearestPlayer.Character:FindFirstChild("HumanoidRootPart") then
		local targetPos = nearestPlayer.Character.HumanoidRootPart.Position
		humanoid:MoveTo(targetPos)
		if distance <= ATTACK_RANGE then
			attackPlayer(nearestPlayer)
		end
	end
	local currentPos = hrp.Position
	local moved = (currentPos - prevPos).magnitude > 0.01
	prevPos = currentPos
	if moved then
		if not walk.IsPlaying then
			idle:Stop()
			walk:Play()
		end
	else
		if not idle.IsPlaying then
			walk:Stop()
			idle:Play()
		end
	end
end
