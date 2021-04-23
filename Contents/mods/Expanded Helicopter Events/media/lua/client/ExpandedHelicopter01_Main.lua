--GLOBAL_VARIABLES
MAX_XY = 15000
MIN_XY = 2500
ALL_HELICOPTERS = {}

---@class eHelicopter
eHelicopter = {}

---@field presetProgression table Table of presetIDs and corresponding % preset is switched to (compared to Days/CuttOffDay)
eHelicopter.presetProgression = nil

---@field frequencyFactor number This is multiplied against the min/max day range; less than 1 results in higher frequency, more than 1 results in less frequency
eHelicopter.frequencyFactor = 1

---@field startDayMinMax table two numbers: min and max start day can be
eHelicopter.startDayMinMax = {0,1}

---@field cutOffDay number event cut-off day after apocalypse start, NOT game start
eHelicopter.cutOffDay = 30

---@field speed number
eHelicopter.speed = 0.25

---@field topSpeedFactor number speed x this = top "speed"
eHelicopter.topSpeedFactor = 3

---@field flightSound string sound to loop during flight
eHelicopter.flightSound = "eHelicopter"

---@field flightVolume number
eHelicopter.flightVolume = 50

---@field fireSound table sounds for firing
eHelicopter.fireSound = {"eHeli_fire_single","eHeli_fire_loop"}

---@field fireImpacts table sounds for fire impact
eHelicopter.fireImpacts = {"eHeli_fire_impact1", "eHeli_fire_impact2", "eHeli_fire_impact3",  "eHeli_fire_impact4", "eHeli_fire_impact5"}

---@field hostilePreference string
---set to 'nil' for *any*, 'false' for *none*, otherwise has to be 'IsoPlayer' or 'IsoZombie'
eHelicopter.hostilePreference = "IsoZombie"

---@field attackDelay number delay in milliseconds between attacks
eHelicopter.attackDelay = 105

---@field attackScope number number of rows from "center" IsoGridSquare out
--- **area formula:** ((Scope*2)+1) ^2
---
--- scope:⠀0=1x1;⠀1=3x3;⠀2=5x5;⠀3=7x7;⠀4=9x9
eHelicopter.attackScope = 1

---@field attackSpread number number of rows made of "scopes" from center-scope out
---**formula for ScopeSpread area:**
---
---((Scope * 2)+1) * ((Spread * 2)+1) ^2
---
--- **Examples:**
---
---⠀  ⠀*scope* 🡇
--- -----------------------------------
--- *spread*⠀🡆 ⠀ | 00 | 01 | 02 | 03 |
--- -----------------------------------
--- ⠀  ⠀⠀⠀ ⠀| 00 | 01 | 09 | 25 | 49 |
--- -----------------------------------
--- ⠀  ⠀⠀⠀ ⠀| 01 | 09 | 81 | 225 | 441 |
--- -----------------------------------
--- ⠀  ⠀⠀⠀⠀  | 02 | 25 | 225 | 625 | 1225 |
--- -----------------------------------
--- ⠀  ⠀⠀⠀  ⠀| 03 | 49 | 441 | 1225 | 2401 |
--- -----------------------------------
eHelicopter.attackSpread = 2

--UNDER THE HOOD STUFF
---@field ID number
eHelicopter.ID = 0
---@field height number
eHelicopter.height = 20
---@field state string
eHelicopter.state = nil
---@field rotorEmitter FMODSoundEmitter | BaseSoundEmitter
eHelicopter.rotorEmitter = nil
---@field timeUntilCanAnnounce number
eHelicopter.timeUntilCanAnnounce = -1
---@field announcerVoice string
eHelicopter.announcerVoice = nil
---@field preflightDistance number
eHelicopter.preflightDistance = nil
---@field announceEmitter FMODSoundEmitter | BaseSoundEmitter
eHelicopter.announceEmitter = nil
---@field target IsoObject
eHelicopter.target = nil
---@field attackDistance number
eHelicopter.attackDistance = nil
---@field targetPosition Vector3 "position" of target, pair of coordinates which can utilize Vector3 math
eHelicopter.targetPosition = nil
---@field lastMovement Vector3 consider this to be velocity (direction/angle and speed/step-size)
eHelicopter.lastMovement = nil
---@field currentPosition Vector3 consider this a pair of coordinates which can utilize Vector3 math
eHelicopter.currentPosition = nil
---@field lastAttackTime number
eHelicopter.lastAttackTime = -1
---@field hostilesToFireOnIndex number
eHelicopter.hostilesToFireOnIndex = 0
---@field hostilesToFireOn table
eHelicopter.hostilesToFireOn = {}


---Preset list, only include variables being changed.
eHelicopter_PRESETS = {
	["increasingly_hostile"] = {presetProgression = {["patrol_only"] = 0, ["attack_only_undead"] = 0.15, ["attack_only_all"] = 0.75}},

	["jet"] = {frequencyFactor = 0.33, speed = 3, flightVolume = 25, flightSound = "eJetFlight", hostilePreference = false, announcerVoice = false},
	["news_chopper"] = {frequencyFactor = 2, speed = 0.2, topSpeedFactor = 5, hostilePreference = false, announcerVoice = false, cutOffDay = 15},
	["patrol_only"] = {hostilePreference = false},
	["attack_only_undead"] = {announcerVoice = false},
	["attack_only_all"] = {announcerVoice = false, hostilePreference = nil},
}


---@param ID string
function eHelicopter:loadPreset(ID)

	if not ID then
		return
	end

	local preset = eHelicopter_PRESETS[ID]

	if not preset then
		return
	end

	local pp = preset.presetProgression
	if pp then
		local DaysSinceApoc = getGameTime():getModData()["DaysBeforeApoc"]+getGameTime():getNightsSurvived()
		local DaysOverCutOff = DaysSinceApoc/(preset.cutOffDay or eHelicopter.cutOffDay)
		local presetIDTmp
		--run through presetProgression list
		for pID,pCutOff in pairs(pp) do
			--if progression % is less than DaysOverCutOff
			if pCutOff <= DaysOverCutOff then
				--if there is no stored % or progression % > stored %
				if (not presetIDTmp) or (presetIDTmp and (pCutOff > pp[presetIDTmp])) then
					--store qualifying choice
					presetIDTmp = pID
				end
			end
		end
		if presetIDTmp then
			--replace original preset with qualifying preset
			preset = eHelicopter_PRESETS[presetIDTmp]
		end
	end

	--local reportPreset = "loading preset: "..ID.."  vars:"
	for var,value in pairs(preset) do
		--reportPreset = reportPreset.." -"..var.." = "..tostring(value)
		self[var] = value
	end
	--print(reportPreset)
end


---Do not call this function directly for new helicopters; use: getFreeHelicopter instead
function eHelicopter:new()

	local o = {}
	setmetatable(o, self)
	self.__index = self
	table.insert(ALL_HELICOPTERS, o)
	o.ID = #ALL_HELICOPTERS

	return o
end


---returns first "unLaunched" helicopter found in ALL_HELICOPTERS -OR- creates a new instance
function getFreeHelicopter(preset)
	---@type eHelicopter heli
	local heli
	for _,h in ipairs(ALL_HELICOPTERS) do
		if h.state == "unLaunched" then
			heli = h
			break
		end
	end

	if not heli then
		heli = eHelicopter:new()
	end
	
	if preset then
		heli:loadPreset(preset)
	end
	
	return heli
end


---These is the equivalent of getters for Vector3
--tostring output of a Vector3: "Vector2 (X: %f, Y: %f) (L: %f, D:%f)"
---@param ShmectorTree Vector3
---@return float x of ShmectorTree
function Vector3GetX(ShmectorTree)
	return string.match(tostring(ShmectorTree), "%(X%: (.-)%, Y%: ")
end


---@param ShmectorTree Vector3
---@return float y of ShmectorTree
function Vector3GetY(ShmectorTree)
	return string.match(tostring(ShmectorTree), "%, Y%: (.-)%) %(")
end


---Initialize Position
---@param targetedPlayer IsoMovingObject | IsoPlayer | IsoGameCharacter
---@param randomEdge boolean true = uses random edge, false = prefers closer edge
function eHelicopter:initPos(targetedPlayer, randomEdge)

	--player's location
	local tpX = targetedPlayer:getX()
	local tpY = targetedPlayer:getY()

	--assign a random spawn point for the helicopter within a radius from the player
	--these values are being clamped to not go passed MIN_XY/MAX edges
	local offset = 500
	local initX = ZombRand(math.max(MIN_XY, tpX-offset), math.min(MAX_XY, tpX+offset))
	local initY = ZombRand(math.max(MIN_XY, tpY-offset), math.min(MAX_XY, tpY+offset))

	if not self.currentPosition then
		self.currentPosition = Vector3.new()
	end

	if randomEdge then
		
		local initPosXY = {initX, initY}
		local randEdge = {MIN_XY, MAX_XY}
		
		--randEdge stops being a list and becomes a random part of itself
		randEdge = randEdge[ZombRand(1,#randEdge)]
		
		--this takes either initX/initY (within initPosXY) and makes it either MIN_XY/MAX (randEdge)
		initPosXY[ZombRand(1, #initPosXY)] = randEdge
		
		self.currentPosition:set(initPosXY[1], initPosXY[2], self.height)
		
		return
	end
	
	--Looks for the closest edge to initX and initY to modify it to be along either MIN_XY/MAX_XY
	--differences between initX and MIN_XY/MAX_XY edge values
	local xDiffToMin = math.abs(initX-MIN_XY)
	local xDiffToMax = math.abs(initX-MAX_XY)
	local yDiffToMin = math.abs(initY-MIN_XY)
	local yDiffToMax = math.abs(initY-MAX_XY)
	--this list uses x/yDifftoMin/Max's values as keys storing their respective corresponding edges
	local xyDiffCorrespondingEdge = {[xDiffToMin]=MIN_XY, [xDiffToMax]=MAX_XY, [yDiffToMin]=MIN_XY, [yDiffToMax]=MAX_XY}
	--get the smallest of the four differences
	local smallestDiff = math.min(xDiffToMin,xDiffToMax,yDiffToMin,yDiffToMax)
	
	--if the smallest is a X local var then set initX to the closer edge
	if (smallestDiff == xDiffToMin) or (smallestDiff == xDiffToMax) then
		initX = xyDiffCorrespondingEdge[smallestDiff]
	else
		--otherwise, set initY to the closer edge
		initY = xyDiffCorrespondingEdge[smallestDiff]
	end

	self.currentPosition:set(initX, initY, self.height)
end


---@return int, int, int XYZ of eHelicopter
function eHelicopter:getXYZAsInt()
	local ehX = math.floor(Vector3GetX(self.currentPosition) + 0.5)
	local ehY = math.floor(Vector3GetY(self.currentPosition) + 0.5)
	local ehZ = self.height

	return ehX, ehY, ehZ
end


---@return IsoGridSquare of eHelicopter
function eHelicopter:getIsoGridSquare()
	local ehX, ehY, _ = self:getXYZAsInt()

	return getSquare(ehX, ehY, 0)
end


---@return boolean
function eHelicopter:isInBounds()
	local h_x, h_y, _ = self:getXYZAsInt()

	if h_x <= MAX_XY and h_x >= MIN_XY and h_y <= MAX_XY and h_y >= MIN_XY then
		return true
	end

	return false
end


---@return number
function eHelicopter:getDistanceToTarget()

	local a = Vector3GetX(self.targetPosition) - Vector3GetX(self.currentPosition)
	local b = Vector3GetY(self.targetPosition) - Vector3GetY(self.currentPosition)

	return math.sqrt((a*a)+(b*b))
end


---@param movement Vector3
---@return Vector3
function eHelicopter:dampen(movement)
	--finds the fraction of distance to target and preflight distance to target
	local distanceCompare = self:getDistanceToTarget() / self.preflightDistance
	--clamp with a max of self.topSpeedFactor and min of 0.1 (10%) is applied to the fraction 
	local dampenFactor = math.max(self.topSpeedFactor, math.min(0.1, distanceCompare))
	--this will slow-down/speed-up eHelicopter the closer/farther it is to the target
	local x_movement = Vector3GetX(movement) * dampenFactor
	local y_movement = Vector3GetY(movement) * dampenFactor

	return movement:set(x_movement,y_movement,self.height)
end


---Sets targetPosition (Vector3) to match target (IsoObject)
function eHelicopter:setTargetPos()
	if not self.target then
		return
	end
	local tx, ty, tz = self.target:getX(), self.target:getY(), self.height

	if not self.targetPosition then
		self.targetPosition = Vector3.new(tx, ty, tz)
	else
		self.targetPosition:set(tx, ty, tz)
	end
	
end


---Aim eHelicopter at it's defined target
---@return Vector3
function eHelicopter:aimAtTarget()

	self:setTargetPos()

	local movement_x = Vector3GetX(self.targetPosition) - Vector3GetX(self.currentPosition)
	local movement_y = Vector3GetY(self.targetPosition) - Vector3GetY(self.currentPosition)

	--difference between target's and current's x/y
	---@type Vector3 local_movement
	local local_movement = Vector3.new(movement_x,movement_y,0)
	--normalize (shrink) the difference
	local_movement:normalize()
	--multiply the difference based on speed
	local_movement:setLength(self.speed)

	return local_movement
end


---@param re_aim boolean recalculate angle to target
---@param dampen boolean adjust speed based on distance to target
function eHelicopter:move(re_aim, dampen)

	---@type Vector3
	local velocity

	if not self.lastMovement then
		re_aim = true
	end

	if re_aim then
		velocity = self:aimAtTarget()

		if not self.lastMovement then
			self.lastMovement = Vector3.new(velocity)
		else
			self.lastMovement:set(velocity)
		end

	else
		velocity = self.lastMovement:clone()
	end

	if dampen then
		velocity = self:dampen(velocity)
	end

	local heliVolume = self.flightVolume
	local timeStamp = getTimestampMs()

	if (self.timeUntilCanAnnounce < timeStamp) and (self.lastAttackTime < timeStamp) and (#self.hostilesToFireOn <= 0) then
		heliVolume = heliVolume+20
		self:announce()
	end

	if self.hostilePreference then
		self:lookForHostiles(self.hostilePreference)
	end

	--if there's not that many targets
	if #self.hostilesToFireOn < 5 then
		--account for sped up time
		local timeSpeed = getGameSpeed()
		local v_x = Vector3GetX(self.currentPosition)+(Vector3GetX(velocity)*timeSpeed)
		local v_y = Vector3GetY(self.currentPosition)+(Vector3GetY(velocity)*timeSpeed)

		--The actual movement occurs here when the modified `velocity` is added to `self.currentPosition`
		self.currentPosition:set(v_x, v_y, self.height)
		--Move emitter to position
		self.rotorEmitter:setPos(v_x,v_y,self.height)
		--virtual sound event to attract zombies
		addSound(nil, v_x, v_y, 0, heliVolume*5, heliVolume)
	end

	--self:Report(re_aim, dampen)
end


---@param targetedPlayer IsoMovingObject | IsoPlayer | IsoGameCharacter random player if blank
function eHelicopter:launch(targetedPlayer)

	if not targetedPlayer then
		--the -1 is to offset playerIDs starting at 0
		local weightPlayersList = {}
		local numActivePlayers = getNumActivePlayers()-1

		for i=0, numActivePlayers do
			---@type IsoGameCharacter p
			local p = getSpecificPlayer(i)

			table.insert(weightPlayersList, p)

			local zone = p:getCurrentZone():getType()
			if zone and (zone ~= "Forest" and zone ~= "DeepForest") then
				table.insert(weightPlayersList, p)
				table.insert(weightPlayersList, p)
			end
		end

		targetedPlayer = weightPlayersList[ZombRand(1, #weightPlayersList)]
	end

	self.target = targetedPlayer
	self:setTargetPos()
	self:initPos(self.target)
	self.preflightDistance = self:getDistanceToTarget()
	self.rotorEmitter = getWorld():getFreeEmitter()

	local ehX, ehY, ehZ = self:getXYZAsInt()

	self.rotorEmitter:playSound(self.flightSound, ehX, ehY, ehZ)

	if self.announcerVoice ~= false then
		self:chooseVoice(self.announcerVoice)
	end
	self.state = "gotoTarget"
end


function eHelicopter:update()

	--threshold for reaching player should be self.speed * getGameSpeed
	if (self.state == "gotoTarget") and (self:getDistanceToTarget() <= ((self.topSpeedFactor*self.speed)*tonumber(getGameSpeed()))) then
		print("HELI: "..self.ID.." FLEW OVER TARGET".." (x:"..Vector3GetX(self.currentPosition)..", y:"..Vector3GetY(self.currentPosition)..")")
		self.state = "goHome"
		self.target = getSquare(self.target:getX(),self.target:getY(),0)
		self:setTargetPos()
	end

	local lockOn = true
	if self.state == "goHome" then
		lockOn = false
	end

	self:move(lockOn, true)

	if not self:isInBounds() then
		self:unlaunch()
	end
end


function updateAllHelicopters()
	for key,_ in ipairs(ALL_HELICOPTERS) do
		---@type eHelicopter heli
		local heli = ALL_HELICOPTERS[key]

		if heli.state ~= "unLaunched" then
			heli:update()
		end
	end
end


function eHelicopter:unlaunch()
	print("HELI: "..self.ID.." UN-LAUNCH".." (x:"..Vector3GetX(self.currentPosition)..", y:"..Vector3GetY(self.currentPosition)..")")
	self.state = "unLaunched"
	self.rotorEmitter:stopAll()
end

Events.OnTick.Add(updateAllHelicopters)
