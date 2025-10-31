local replicatedStorage = game:GetService("ReplicatedStorage")
local players = game:GetService("Players")

local runService = game:GetService("RunService")
local physicsService = game:GetService("PhysicsService")

local modules = replicatedStorage.Storage.Modules 
local Utility = require(modules.Utility)

local weldBallEvent = replicatedStorage.Storage.Remotes:WaitForChild('CaptureBall')
local ShootEvent = replicatedStorage.Storage.Remotes:WaitForChild("ShootEvent")

local ball = workspace:FindFirstChild("SoccerBall") --// THIS IS THE SOCCER BALL OF THE GAME

local BALL_GROUP = "Ball"
local PLAYER_GROUP = "Player"

physicsService:RegisterCollisionGroup(BALL_GROUP)
physicsService:RegisterCollisionGroup(PLAYER_GROUP)
physicsService:CollisionGroupSetCollidable(BALL_GROUP, PLAYER_GROUP, false)

ball.CollisionGroup = BALL_GROUP

local attachment = Instance.new("Attachment")
attachment.Parent = ball

local vectorForce = Instance.new("VectorForce")
vectorForce.Attachment0 = attachment

vectorForce.Force = Vector3.new(0, ball.AssemblyMass * 98.1, 0)
vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World

vectorForce.ApplyAtCenterOfMass = true
vectorForce.Parent = ball

ball.CustomPhysicalProperties = PhysicalProperties.new(
	1,    --// Density
	2,    --// Friction (HIGHER = more grip)
	.5,  --// Elasticity (LOWER = less bounce)
	1,
	1
)

local currentOwner : Player,weld

local proximity = 5 
local playerData = require(modules.PlayerHandler)

local function ballPossessionCheck(player : Player)
	return player:GetAttribute("Ball_Owner")
end

local function ballProximityCheck(player : Player, ball : BasePart, radius : number)
	
	if player:GetAttribute("Idle") then
		return
	end
	
	local character = player.Character
	
	if not character then
		return
	end
	
	local HRP : BasePart = character.HumanoidRootPart
	
	local playerPos = HRP:GetPivot().Position
	local ballPos = ball.Position
	
	return (playerPos-ballPos).Magnitude<=radius
	
end

local formerOwner
local function updateBallOwnership(player)
	
	if player then
		
		if currentOwner and players:IsAncestorOf(currentOwner) then

			currentOwner:SetAttribute("Ball_Owner",false)
			formerOwner = currentOwner

		end
		currentOwner = player
		
		ball.Attachment.Trail.Enabled = false
		player:SetAttribute("Ball_Owner",true)

		local character = player.Character
		
		local HRP = character.HumanoidRootPart
		
		if character:GetAttribute("PerfectSlide") then
			
			--Utility.Emit({Attachment = replicatedStorage.Assets.Effects.DribbleEffects.Attachment2,Lifetime = 2,Parent = character.Torso})
			
			
			Utility.Emit({Attachment = replicatedStorage.Storage.Assets.Effects.DribbleEffects.Attachment,Lifetime = 2,Parent = character.Torso})

			local getupAnim : AnimationTrack = character.Humanoid.Animator:LoadAnimation(replicatedStorage.Storage.Assets.Animations.General.SlideGetup)

			getupAnim.Priority = Enum.AnimationPriority.Action3
			getupAnim:Play()

			getupAnim:AdjustSpeed(1.4)
		end
		
		ball.Parent = character
		
		Utility.emitNoAttachment(replicatedStorage.Storage.Assets.Effects.BallGlow,1,HRP)
		
		Utility.Highlight({Adornee = character,Color = Color3.fromRGB(255, 255, 255),outlineColor = Color3.fromRGB(255, 255, 255),lineTrans = 0,fillTrans = .3,Duration = .5})
		
		ball:SetNetworkOwner(player)
		ball.Massless = true

		ball.CanCollide = false
		ball.CanTouch = false

		if weld then
			weld:Destroy()
		end

		weld = Instance.new("Motor6D")
		weld.Name = "BallMotor6D"

		weld.Part0 = HRP
		weld.Part1 = ball

		weld.Parent = ball
		weld.C0 = CFrame.new(0,-2.5,-1.5)

		--print(`The football is now in the possession of {player}!`)
		
		
	else --// RESET THE BALL
		
		if currentOwner then
			formerOwner = currentOwner
			formerOwner:SetAttribute("Ball_Owner",false)
		end
		
		currentOwner = nil
		
		ball.Attachment.Trail.Enabled = true
		ball.Highlight.Enabled = true
		
		ball.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		
		ball.Massless = true
		ball.CanCollide = true
		
		ball.CanTouch = true
		ball.Parent = workspace
		
		local motor6D = ball:FindFirstChild("BallMotor6D")
		--game:GetService("Debris"):AddItem(motor6D,0)
		if motor6D then
			motor6D:Destroy()
		end 
		
		--print("Separated!")
		
	end
	
	shared.currentBallOwner = currentOwner

	shared.formerBallOwner = formerOwner
	
end
local function ballWeld(player : Player,sliding : boolean)
	
	local inPossession = ballPossessionCheck(player)
	if not inPossession then

		if ball.Parent ~= workspace and not sliding and not player.Character.Humanoid.Jump then --// Jump check to allow the player to headbutt the ball instead of taking ownership of it on contact
			return
		end

		if not sliding then
			
			--print("Not a slide tackle")
			
			local ballIsCloseBy = ballProximityCheck(player,ball,proximity)
			
			if ballIsCloseBy then

				updateBallOwnership(player)

			end
			
		else --// If the enemy took the ball via a slide tackle steal
	
			updateBallOwnership(player,currentOwner)
			
		end

	end

	return currentOwner
		
end

--weldBallEvent.OnServerEvent:Connect(ballWeld)

local playerBallConnections = {} --// Store the Heartbeat connection for each player
local ballBlacklist = {} --// Blacklist certain players from the ball proximity check for a certain amount of time

local function onCharacterAdded(character)
	
	local player = players:GetPlayerFromCharacter(character)
	local humanoid : Humanoid = character.Humanoid
	
	local heartBeat = runService.Heartbeat:Connect(function()
		if not ballBlacklist[player.UserId] then
			ballWeld(player)
		end
	end)
	
	playerBallConnections[player.UserId] = heartBeat
	
	humanoid.Died:Once(function()
		local data = playerBallConnections[player.UserId]
		if data then
			
			data:Disconnect()
			data = nil
			
		end
	end)
	
	for _,member in pairs(character:GetDescendants()) do
		
		if member:IsA("BasePart") then
			member.CollisionGroup = PLAYER_GROUP
		end
		
	end
	
end
local function onPlayerAdded(plr : Player)
	
	--ballBlacklist[plr.UserId] = nil
	
	plr.CharacterAdded:Connect(onCharacterAdded)
end

local function onPlayerRemoving(plr)
	
	if playerBallConnections[plr.UserId] then
		
		playerBallConnections[plr.UserId]:Disconnect()
		playerBallConnections[plr.UserId] = nil
		
	end
	
	if currentOwner == plr then
		
		updateBallOwnership() --// RESET THE BALL TO ITS ORIGINAL STATE
		
	end
end

local function blacklistPlayerFromBallOwnership(player : Player,timeoutDuration : number) 
	
	--timeoutDuration = timeoutDuration or error("No debounce duration given. Bakayaro...")
	
	ballBlacklist[player.UserId] = true
	
	if timeoutDuration then
		
		task.delay(timeoutDuration,function() --// Delay the reset time so that the ball doesn't instantly return to the player
			ballBlacklist[player.UserId] = nil
		end)
		
	end
	
end


local function makeBallIntangible(timeoutDuration: number)
	
	for _,player in pairs(players:GetPlayers()) do
		
		local userId = player.UserId
		ballBlacklist[userId] = true

		task.delay(timeoutDuration,function() --// Delay the reset time so that the ball doesn't instantly return to the player
			ballBlacklist[userId] = nil
		end)

	end
	
end

shared.undoBlacklist = function(player : Player)
	ballBlacklist[player.UserId] = nil
end

players.PlayerAdded:Connect(onPlayerAdded); players.PlayerRemoving:Connect(onPlayerRemoving)

shared.captureBall = ballWeld

shared.updateBallOwnership = updateBallOwnership

shared.ballBlacklist = ballBlacklist

shared.blacklistPlayerFromBallOwnership = blacklistPlayerFromBallOwnership;-- shared.undoBlacklist = undoBlacklist

shared.currentBallOwner = currentOwner

shared.formerBallOwner = formerOwner

shared.makeBallIntangible = makeBallIntangible