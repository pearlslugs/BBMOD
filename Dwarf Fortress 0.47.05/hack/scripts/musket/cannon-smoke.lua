--[[cannon-smoke]]
--allows a workshop to function as a pseudo siege engine cannon
--author zaporozhets
--based on scripts by Roses, expwnent and Fleeting Frames
--thanks and credits for researching completion_timer and many other great suggestions, bugfixes and improvements to Grimlocke
--CANNON to the right of them! CANNON to the left of them!

local eventful = require 'plugins.eventful'
eventful.enableEvent(eventful.eventType.JOB_INITIATED, 0)
eventful.enableEvent(eventful.eventType.JOB_COMPLETED, 0)

local maxrange = 200 --maximum range of cannon (in tiles)
local minrange = 5 --minimum range of cannon (in tiles)
local max_hitrate = 100 --TODO: account for firer siege operation skill (skill number 48) skill levels are 0-20(+? (normalize in case)). dfhack.units.getEffectiveSkill(firer, 48)
local velocity = 20000 --cannonball velocity
local rotationMult = 0.1 --cannon rotation speed multiplier, lower is faster
local loadMult = 0.3 --cannon load speed multiplier

gasSpread = 20 --distance (in tiles) gas will attempt to spread output_items
gasDensity = 5000 --amount of gas produced by gas cannisters

eventful.onProjItemCheckMovement.cannon = function(projectile)
	if projectile.distance_flown == 1 then
		cannonSmoke(projectile, 5, 10)
	elseif projectile.distance_flown == 2 then
		cannonSmoke(projectile, 5, 25)
	elseif projectile.distance_flown <= 7 then
		cannonSmoke(projectile, 5,  25)
	end
end

eventful.onProjItemCheckImpact.cannon = function(projectile)
	if projectile.item:getSubtype() ~= -1 and dfhack.items.getSubtypeDef(projectile.item:getType(),projectile.item:getSubtype()).id == "ITEM_TRAPCOMP_EXPLOSIVESHELL" then
		cannonSmoke(projectile, 6, 50)
	elseif projectile.item:getSubtype() ~= -1 and dfhack.items.getSubtypeDef(projectile.item:getType(),projectile.item:getSubtype()).id == "ITEM_TRAPCOMP_GASSHELL" then
		cannonSmoke(projectile, 10, 5000)
	end
end

eventful.onJobInitiated.cannon = function(job)
	if string.find(job.reaction_name, "GUN_") then
		modifyJob(job)
	end
end

function modifyJob(job) --modifies job once it's started, otherwise waits for job start and checks again
	if #job.general_refs > 1 then
		local firer = df.unit.find(job.general_refs[1].unit_id)
		makeFearless(firer, true) --only cowards flee
	end
	if job.completion_timer ~= -1 then
		if job.reaction_name == "GUN_ROTATE_CANNON_R" or job.reaction_name == "GUN_ROTATE_CANNON_L" then
			job.completion_timer = math.floor(job.completion_timer * rotationMult) --0.2
		elseif job.reaction_name == "GUN_LOAD_CANNON" then
			job.completion_timer = math.floor(job.completion_timer * loadMult) --0.5
		elseif job.reaction_name == "GUN_FIRE_CANNON" or job.reaction_name == "GUN_TEST_FIRE_CANNON" then
			local firer = df.unit.find(job.general_refs[1].unit_id)
			local cannon = df.building.find(job.general_refs[0].building_id)
			local loadedItems = cannonIsLoaded(firer, cannon)
			if loadedItems then 
				waitForTarget(job, firer, cannon, loadedItems)
			else --not loaded
				job.completion_timer = 0
			end
		end
	else
		dfhack.timeout(50, "ticks", function() modifyJob(job) end)
	end
end

function makeFearless(firer, mode)
	if mode == true then
		if firer.flags2.vision_missing == false then
			firer.flags2.vision_good = false
			firer.flags2.vision_missing = true
			dfhack.timeout(1000, "ticks", function() makeFearless(firer, false) end)
		end
	else
		firer.flags2.vision_good = true
		firer.flags2.vision_missing = false
	end
end

function cannonIsLoaded(firer, cannon)
	local ammo
	local powder
	for _, cannonItem in ipairs(cannon.contained_items) do
		if cannonItem.use_mode == 0 then
			local item = cannonItem.item
			if tostring(item._type) == "<type: item_trapcompst>" and item.flags.forbid == true then
				ammo = item
			elseif tostring(item._type) == "<type: item_barst>" and item.mat_type == 8 and item.flags.forbid == true then
				powder = item
			end
		end
	end
	if ammo == nil then
		dfhack.gui.showAnnouncement(getFullName(firer).." cancels fire cannon: No ammo loaded.", 12)
		if powder ~= nil then powder.flags.forbid = false end
		return false
	elseif powder == nil then
		dfhack.gui.showAnnouncement(getFullName(firer).." cancels fire cannon: No potash loaded.", 12)
		if ammo ~= nil then ammo.flags.forbid = false end
		return false
	else
		return {ammo, powder}
	end
end

function waitForTarget(job, firer, cannon, loadedItems)
	local nearestUnit = false
	local nearestDistance =  768
	for _,target in ipairs(df.global.world.units.active) do
		if checkDirection(cannon, target, 1) then
			local targetDistance = findDistance(firer.pos, target.pos)
			if targetDistance < nearestDistance and targetDistance > minrange then
				if isHostile(firer, target, job.reaction_name) then
					if canPathTo(firer.pos, target.pos, targetDistance) then
						nearestUnit = target
						nearestDistance = targetDistance
					end
				end
			end
		end
	end
	if nearestUnit then --found a target
		--printTargetDebug(firer, nearestUnit, nearestDistance) --TODO: DISABLE
		fireCannon(firer, cannon, loadedItems, nearestUnit)
		job.completion_timer = 0
	else
		if firer.job.current_job ~= nil and firer.job.current_job.id == job.id then
			job.completion_timer = 100
			dfhack.timeout(50, "ticks", function() waitForTarget(job, firer, cannon, loadedItems) end)
		else
			job.completion_timer = 0
		end
	end
end

function fireCannon(firer, cannon, loadedItems, nearestUnit)
	local ammo = loadedItems[1]
	local powder = loadedItems[2]
	local ammoClone = df.item.find(dfhack.items.createItem(ammo:getType(), ammo:getSubtype(), ammo.mat_type, ammo.mat_index, firer))
	if ammo.subtype.id == "ITEM_TRAPCOMP_GASSHELL" then
		ammoClone.improvements:insert("#", ammo.improvements[0])
	end
	ammoClone.flags.forbid = true
	ammoClone.quality = ammo.quality
	ammo.flags.garbage_collect = true
	powder.flags.garbage_collect = true
	local muzzlePos = checkDirection(cannon, nil, 2)
	dfhack.items.moveToGround(ammoClone, muzzlePos)
	fireProjectile(ammoClone, muzzlePos, nearestUnit)
end

eventful.onJobCompleted.cannon = function(job)
	if job.reaction_name == "GUN_ROTATE_CANNON_R" or job.reaction_name == "GUN_ROTATE_CANNON_L" then
		local cannon = df.building.find(job.general_refs[0].building_id)
		local buildingDirection = string.sub(df.global.world.raws.buildings.all[cannon.custom_type].code, -2)
		if job.reaction_name == "GUN_ROTATE_CANNON_R" then
			if buildingDirection == "_N" or buildingDirection == "_E" or buildingDirection == "_S" then
				cannon.custom_type = cannon.custom_type + 1
			else
				cannon.custom_type = cannon.custom_type - 3
			end
		else
			if buildingDirection == "_E" or buildingDirection == "_S" or buildingDirection == "_W" then
				cannon.custom_type = cannon.custom_type - 1
			else
				cannon.custom_type = cannon.custom_type + 3
			end
		end
	elseif job.reaction_name == "GUN_LOAD_CANNON" then
		if #job.items == 2 then
			job.items[0].item.flags.forbid = true
			job.items[1].item.flags.forbid = true
			cannon = df.building.find(job.general_refs[0].building_id)
			local loadedCount = 0
			for _ in pairs(cannon.contained_items) do loadedCount = loadedCount + 1 end
			if loadedCount > 4 then
				dfhack.gui.showAnnouncement(getFullName(unit).." cancels load cannon: Already loaded.", 12)			
				job.items[0].item.flags.forbid = false
				job.items[1].item.flags.forbid = false
			end
		end
	elseif job.reaction_name == "GASSHELL" then
		for indx, itemRef in ipairs(job.items) do
			local item = itemRef.item
			if tostring(item._type) == "<type: item_trapcompst>" then
				item:setSubtype(item:getSubtype() + 1) --venom is stored as an item improvement, filled shell is seperate trapcomp to prevent multiple fillings and for graphical reasons
			end
		end
	end
end

function getFullName(unit) --doesn't account for heroic names yet because I wasn't sure if they replace the normal surname
	local firstName = unit.name.first_name
	firstName = firstName:sub(1,1):upper()..firstName:sub(2)
	local surname = ""
	for indx, wordID in pairs(unit.name.words) do 
		if wordID ~= -1 then
			local word = df.global.world.raws.language.translations[unit.name.language].words[unit.name.words[indx]].value
			if indx == 0 then 
				surname = word:sub(1,1):upper()..word:sub(2)
			elseif indx == 1 then 
				surname = surname..word
			end
		end
	end
	return firstName.." "..surname..", Siege Operator"
end

function checkDirection(cannon, target, mode) --mode 1 checks direction of target against cannon orientation, mode 2 returns muzzle position
	local cannon_direction = string.sub(df.global.world.raws.buildings.all[cannon.custom_type].code, -2)
	if cannon_direction == "_N" then --Never
		if mode == 1 then
			if target.pos.y < cannon.centery - minrange then return true else return false end
		elseif mode == 2 then
			return {x = cannon.centerx, y = cannon.centery - 1, z = cannon.z}
		end
	elseif cannon_direction == "_E" then --Eat
		if mode == 1 then
			if target.pos.x > cannon.centerx + minrange then return true else return false end
		elseif mode == 2 then
			return {x = cannon.centerx + 1, y = cannon.centery, z = cannon.z}
		end
	elseif cannon_direction == "_S" then --Shredded
		if mode == 1 then
			if target.pos.y > cannon.centery + minrange then return true else return false end	
		elseif mode == 2 then
			return {x = cannon.centerx, y = cannon.centery + 1, z = cannon.z}
		end
	elseif cannon_direction == "_W" then --Wheat
		if mode == 1 then
			if target.pos.x < cannon.centerx - minrange then return true else return false end
		elseif mode == 2 then
			return {x = cannon.centerx - 1, y = cannon.centery, z = cannon.z}
		end
	end
end

function isHostile(firer, target, reaction) --TODO: implement better hostility check
	if reaction == "GUN_FIRE_CANNON" then
		if target.flags2.killed == false then
			if target.civ_id == firer.civ_id or target.flags1.diplomat == true or target.flags1.merchant == true or target.flags2.visitor == true or target.flags2.resident == true then
				return false
			else
				return true
			end
		end
	elseif reaction ==  "GUN_TEST_FIRE_CANNON" then
		if target.flags2.killed == false then
			if target.name.first_name ~= "" or target.flags1.diplomat == true or target.flags1.merchant == true or target.flags2.visitor == true or target.flags2.resident == true then
				return false
			else
				return true
			end
		end
	end
end

function canPathTo(originPos, targetPos, targetDistance)
	local directionVector = df.coord:new()
	directionVector.x = targetPos.x - originPos.x
	directionVector.y = targetPos.y - originPos.y
	directionVector.z = targetPos.z - originPos.z
	local stepAmount = 1 / targetDistance
	local step = 0
	local passCount = 0
	local linePath = df.coord:new()
	while step <= 1 do
		linePath.x = math.floor(originPos.x + (directionVector.x * step) + 0.5)
		linePath.y = math.floor(originPos.y + (directionVector.y * step) + 0.5)
		linePath.z = math.floor(originPos.z + (directionVector.z * step) + 0.5)
		if tilePassable(linePath) then
			passCount = passCount + 1
		end
		step = step + stepAmount
	end
	if passCount >= 1 / stepAmount then
		return true
	else
		return false
	end
end

function findDistance(originPos, targetPos)
	return math.floor(math.sqrt(((originPos.x - targetPos.x)^2) + ((originPos.y - targetPos.y)^2) + ((originPos.z - targetPos.z)^2)) + 0.5 )
end

function tilePassable(position)
	local isPassable = false
	if dfhack.maps.getTileBlock(position) ~= nil then
		if dfhack.maps.getTileBlock(position).walkable[position.x%16][position.y%16] ~= 0 or --found walkable tile
		dfhack.maps.getTileBlock(position).tiletype[position.x%16][position.y%16] == 32 or --found empty space
		dfhack.maps.getTileBlock(position).tiletype[position.x%16][position.y%16] == 1 then --found stairs
			isPassable = true
		end
	end
	return isPassable
end

function cannonSmoke(projectile, type, amount)
	if projectile.item:getSubtype() ~= -1 and tostring(dfhack.items.getSubtypeDef(projectile.item:getType(),projectile.item:getSubtype())._type) == "<type: itemdef_trapcompst>" then
		if type == 10 then --gas cannisters
			local matType = projectile.item.improvements[0].mat_type
			local matIndex = projectile.item.improvements[0].mat_index
			local northFlow = dfhack.maps.spawnFlow(projectile.cur_pos, type, matType, matIndex, amount)
				northFlow.density = gasDensity
				northFlow.dest = {x = projectile.target_pos.x, y = projectile.target_pos.y - gasSpread, z = projectile.target_pos.z}
			local eastFlow = dfhack.maps.spawnFlow(projectile.cur_pos, type, matType, matIndex, amount)
				eastFlow.density = gasDensity
				eastFlow.dest = {x = projectile.target_pos.x - gasSpread, y = projectile.target_pos.y, z = projectile.target_pos.z}			
			local southFlow = dfhack.maps.spawnFlow(projectile.cur_pos, type, matType, matIndex, amount)
				southFlow.density = gasDensity
				southFlow.dest = {x = projectile.target_pos.x, y = projectile.target_pos.y + gasSpread, z = projectile.target_pos.z}			
			local westFlow = dfhack.maps.spawnFlow(projectile.cur_pos, type, matType, matIndex, amount)
				westFlow.density = gasDensity
				westFlow.dest = {x = projectile.target_pos.x + gasSpread, y = projectile.target_pos.y, z = projectile.target_pos.z}
		else
			dfhack.maps.spawnFlow(projectile.cur_pos, type, -1, -1, amount) --other ammo types
		end
	end
end

function fireProjectile(item, muzzlePos, target)
	local projectile = dfhack.items.makeProjectile(item)
	projectile.origin_pos.x = muzzlePos.x
	projectile.origin_pos.y = muzzlePos.y
	projectile.origin_pos.z = muzzlePos.z
	projectile.prev_pos.x = muzzlePos.x
	projectile.prev_pos.y = muzzlePos.y
	projectile.prev_pos.z = muzzlePos.z
	projectile.cur_pos.x = muzzlePos.x
	projectile.cur_pos.y = muzzlePos.y
	projectile.cur_pos.z = muzzlePos.z
	projectile.target_pos.x = target.pos.x
	projectile.target_pos.y = target.pos.y
	projectile.target_pos.z = target.pos.z
	projectile.flags.no_impact_destroy=false
	projectile.flags.bouncing=false
	projectile.flags.piercing=true
	projectile.flags.parabolic=false
	projectile.flags.unk9=false
	projectile.flags.no_collide=false
	projectile.distance_flown=0
	projectile.fall_threshold=maxrange
	projectile.min_hit_distance=minrange
	projectile.min_ground_distance=maxrange-1
	projectile.fall_counter=0
	projectile.fall_delay=0
	projectile.hit_rating=max_hitrate
	projectile.unk22 = velocity
	projectile.speed_x=0
	projectile.speed_y=0
	projectile.speed_z=0
end

function printTargetDebug(firer, nearestUnit, nearestDistance)
	print(firer.name.first_name.." fired cannon from: ")
	print(pos2xyz(firer.pos))
	print("  at:")
	if nearestUnit.name.first_name ~= "" then
		print("	"..nearestUnit.name.first_name)
	else 
		print("	Creature")
	end
	print("	race: "..tostring(df.global.world.raws.creatures.all[nearestUnit.race].name[0]))
	print("	distance: "..tostring(nearestDistance))
end