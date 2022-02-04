--[[musket-smoke]]
--Creates various weapon effects when a unit uses a firearm.
--author zaporozhets
--based on scripts by Roses, expwnent and Putnam
--thanks and credits for finding the think counter go to thefriendlyhacker allowing for nonstandard rates of fire
--thanks and credits for researching bow_id, (heavily) inspiring a combined weapon script and many other suggestions and bugfixes to Grimlocke

local eventful = require 'plugins.eventful'
print("smoke enabled")
local lightningInorganicIndx = 1 
local curviness = 5 --maximum lightning apex deviation from line to target 
dfhack.onStateChange.musket = function(state) --find lightning independent of load order
	if state == SC_WORLD_LOADED then
		for indx, inorganic in pairs(df.global.world.raws.inorganics) do 
			if inorganic.id == "LIGHTNING" then
				lightningInorganicIndx = indx
			end
		end
	end
end

local defaultSmoke = {0, 0, 0} --default muzzle smoke
local weaponProperties = { --currently just for muzzle smoke amounts. will turn into 2d array if needed for more stuff in future but trying to avoid too many table lookups
	--normal weapons
	["ITEM_WEAPON_GUN1"] = defaultSmoke,
	["ITEM_WEAPON_GUN2"] = defaultSmoke,
	["ITEM_WEAPON_RPG"] = defaultSmoke,
	["ITEM_WEAPON_GUN_PISTOL_BAYONET"] = defaultSmoke,
	
	--shotgun weapons
	["ITEM_WEAPON_SPEAR_GUN"] = defaultSmoke,
	["ITEM_WEAPON_GUN_DRAGON_PISTOL"] = defaultSmoke,
	
	--explosive weapons
	["ITEM_WEAPON_GUN_HANDMORTAR"] = defaultSmoke,
	["ITEM_WEAPON_RPG_SPEC"] = {5, 20, 20},

	--exotic weapons
	["ITEM_WEAPON_GUN_AUTOGUN"] = {5, 5, 10},
	["ITEM_WEAPON_GUN_TESLAGUN"] = {0, 0, 0}
	--["ITEM_WEAPON_GUN_FLAMETHROWER"] = {0, 0, 0}
}

eventful.onProjItemCheckMovement.musket = function(projectile)
	if df.item.find(projectile.bow_id) ~= nil then --fucking explosions destroying weapons
		local weaponType = df.item.find(projectile.bow_id).subtype.id
		if string.find(weaponType, "GUN", 11) then
			if projectile.distance_flown == 0 then
				weaponMod(projectile, weaponType) --apply unique weapon effects
			elseif projectile.distance_flown <= 3 then
				musketSmoke(projectile, 5, weaponProperties[weaponType][projectile.distance_flown]) --muzzle smoke
			elseif weaponType == "ITEM_WEAPON_GUN1" then
				musketSmoke(projectile, 5, 5)
				if projectile.distance_flown >= 30 then --rocket becomes unstable
					setInaccuracy(projectile, 2) 
				end
			end
		end
	end
end

eventful.onProjItemCheckImpact.musket = function(projectile)
	if dfhack.items.getSubtypeDef(projectile.item:getType(),projectile.item:getSubtype()) ~= nil then
		local ammoType = projectile.item.subtype.id
		if string.find(ammoType, "_BULLET", 9) then
			if ammoType == "ITEM_AMMO_GUN_GRENADES" then 
				musketSmoke(projectile, 6, 15)
				musketSmoke(projectile, 3, 40)
			elseif ammoType == "ITEM_WEAPON_RPG" then
				destroyConstructions(projectile)
				musketSmoke(projectile, 6, 45)
			end
			deleteProjectile(projectile)
		end
	end
end

--[[general purpose functions]]
function musketSmoke(projectile, type, amount)
	return dfhack.maps.spawnFlow(projectile.cur_pos, type, projectile.item.mat_type, projectile.item.mat_index, amount) --mat stuff only applies to hand mortar concussion dust
end

function weaponMod(projectile, weaponType)
	if weaponType == "ITEM_WEAPON_GATLING_GUN" then 
		setFireRate(projectile, 10)
	elseif weaponType == "ITEM_WEAPON_SPEAR_GUN" or weaponType == "ITEM_WEAPON_GUN_DRAGON_PISTOL" then
		blunderShot(projectile)
	elseif weaponType == "ITEM_WEAPON_ELECTRIC" then --"Yes, I loved that pigeon, I loved her as a man loves a woman, and she loved me."
		setFireRate(projectile, 120)
		lightningStrike(projectile)
		deleteProjectile(projectile)
	elseif weaponType == "ITEM_WEAPON_GUN_ROCKETLAUNCHER" then
		setFireRate(projectile, 120)
	--[[elseif weaponType == "ITEM_WEAPON_GUN_FLAMETHROWER" then
		setFireRate(projectile, 10)
		throwFlame(projectile, nil)
		]]
	end
end

function setFireRate(projectile, rate)
	if projectile.firer ~= nil then
		projectile.firer.counters.think_counter = rate --normal crossbow rate is 80
	end
end

function setInaccuracy(projectile, deviation)
	projectile.target_pos.x = projectile.target_pos.x + math.random(-deviation, deviation)
	projectile.target_pos.y = projectile.target_pos.y + math.random(-deviation, deviation)
end

function deleteProjectile(projectile)
	projectile.item.flags.garbage_collect = true
	local noPos = {x = -1, y = -1, z = -1} --here be multi-tile dragons
	projectile.origin_pos = noPos
	projectile.prev_pos = noPos
	projectile.cur_pos = noPos
end

function destroyConstructions(projectile)
--[[linear search through df.global.world.constructions comparing each construction pos with offset projectile pos to find construction and get material information is too slow, 
	 this precludes checking wall strength and flying chunks of masonry unless a way of obtaining construction index without searching is found.
	 not sure how to go about with building destruction, one way is invoking garbage collection on contained items but there is a delay with this method.
	 not figure out how to get tree destruction to produce logs
	 ]]
	local offsetPos = df.coord:new()
	for yOffset = -1, 1 do 
		for xOffset = -1 , 1  do --3x3 for ease, dynamic size offset for variable explosions would be something like local min = median(size) - size; for(i=min, size - median(size)) do... ; 5 == -2, -1,  0, 1, 2 
			offsetPos.x = projectile.cur_pos.x + xOffset
			offsetPos.y = projectile.cur_pos.y + yOffset
			offsetPos.z = projectile.cur_pos.z
			local tileType = dfhack.maps.getTileBlock(projectile.cur_pos).tiletype[offsetPos.x %16][offsetPos.y %16]
			if (tileType >= 490 and tileType <= 514) then --constructed walls, fortifications, stairs and ramps
				dfhack.maps.getTileBlock(projectile.cur_pos).tiletype[offsetPos.x%16][offsetPos.y%16] = 489 --transmute to floor (tried rubble, didn't work very well)
				dfhack.maps.spawnFlow(offsetPos, 5, -1, -1, 20) --smoke to be replaced with cave-in dust if faster material lookup is found
			elseif (tileType >= 91 and tileType <= 200) then --trees, branches, roots
				dfhack.maps.getTileBlock(projectile.cur_pos).tiletype[offsetPos.x%16][offsetPos.y%16] = 32 --transmute to empty space
			end
		end
	end
	df.global.world.cavein_flags[0] = true
	for indx, column in ipairs(df.global.world.map.map_block_columns) do
		column.flags[0] = true
	end
end

--[[shotgun functions]]
function blunderShot(projectile)
	if projectile.firer ~= nil then
		local shot = projectile.item
		shot:setSubtype(shot:getSubtype()) --original cartridge is perfectly good so transmuting it to pellet
		for i = 0, 4, 1 do
			local pellet = df.item.find(dfhack.items.createItem(shot:getType(), shot:getSubtype(), shot.mat_type, shot.mat_index, projectile.firer))
			pellet.flags.forbid = true
			pellet.quality = projectile.item.quality
			local pelletProjectile = dfhack.items.makeProjectile(pellet)
			pelletProjectile.origin_pos.x = projectile.origin_pos.x + math.random(-1, 1)
			pelletProjectile.origin_pos.y = projectile.origin_pos.y + math.random(-1, 1)
			pelletProjectile.origin_pos.z = projectile.origin_pos.z
			pelletProjectile.prev_pos.x = projectile.origin_pos.x
			pelletProjectile.prev_pos.y = projectile.origin_pos.y
			pelletProjectile.prev_pos.z = projectile.origin_pos.z
			pelletProjectile.cur_pos.x = projectile.origin_pos.x
			pelletProjectile.cur_pos.y = projectile.origin_pos.y
			pelletProjectile.cur_pos.z = projectile.origin_pos.z
			pelletProjectile.target_pos.x = projectile.target_pos.x + math.random(-20, 20)
			pelletProjectile.target_pos.y = projectile.target_pos.y + math.random(-20, 20)
			pelletProjectile.target_pos.z = projectile.target_pos.z
			pelletProjectile.flags.no_impact_destroy = false
			pelletProjectile.flags.bouncing = false
			pelletProjectile.flags.piercing = projectile.flags.piercing
			pelletProjectile.flags.parabolic = false
			pelletProjectile.flags.unk9 = false
			pelletProjectile.flags.no_collide = false
			pelletProjectile.distance_flown = projectile.distance_flown
			pelletProjectile.fall_threshold = projectile.fall_threshold
			pelletProjectile.min_hit_distance = projectile.min_hit_distance
			pelletProjectile.min_ground_distance = projectile.min_ground_distance
			pelletProjectile.fall_counter = 0
			pelletProjectile.fall_delay = 0
			pelletProjectile.hit_rating = projectile.hit_rating
			pelletProjectile.unk22 = projectile.unk22
			pelletProjectile.bow_id = projectile.bow_id
			pelletProjectile.unk_v40_1 = projectile.unk_v40_1
			pelletProjectile.speed_x = projectile.speed_x
			pelletProjectile.speed_y = projectile.speed_x
			pelletProjectile.speed_z = projectile.speed_x
		end
	end
end

--[[exotic weapon functions]] 
function lightningStrike(projectile)
	if projectile.origin_pos ~= nil and projectile.target_pos ~= nil then
		local line = getLine(projectile.origin_pos, projectile.target_pos)
		line = curveLine(line)
		drawLightning(line, 200)
	end
end

function getLine(origin_pos, target_pos) --returns [1] line position table, [2] size of table/length of line
	local line = {}
	line[0] = origin_pos
	lineCount = 0
	local directionVector = df.coord:new()
	directionVector.x = target_pos.x - origin_pos.x
	directionVector.y = target_pos.y - origin_pos.y
	directionVector.z = target_pos.z - origin_pos.z
	local targetDistance = findDistance(origin_pos, target_pos)
	local stepAmount = 1 / targetDistance
	local step = stepAmount
	local linePath = df.coord:new()
	while step <= 1 do
		lineCount = lineCount + 1
		linePath.x = math.floor(origin_pos.x + (directionVector.x * step) + 0.5)
		linePath.y = math.floor(origin_pos.y + (directionVector.y * step) + 0.5)
		linePath.z = math.floor(origin_pos.z + (directionVector.z * step) + 0.5)
		line[lineCount] = {x = linePath.x, y = linePath.y, z = linePath.z}
		if not checkTile(linePath) then
			break
		end
		step = step + stepAmount
	end
	return {line, lineCount}
end

function checkTile(position)
	local passable = false
	if dfhack.maps.getTileBlock(position) ~= nil then
		if dfhack.maps.getTileBlock(position).occupancy[position.x%16][position.y%16].unit == true then --found unit
			for i = 1, 15 do --spawn extra lightning to melt unit more effectively (maybe too effectively atm)
				drawLightning({position}, 5000)
			end
			passable = false --end line drawing, no chain lightning yet
		elseif dfhack.maps.getTileBlock(position).walkable[position.x%16][position.y%16] ~= 0 then  --found to be walkable
			passable = true
		elseif dfhack.maps.getTileBlock(position).tiletype[position.x%16][position.y%16] == 32 then --found empty space
			passable = true
		elseif dfhack.maps.getTileBlock(position).tiletype[position.x%16][position.y%16] == 1 then --found stairs
			passable = true
		end
	end
	return passable
end

function findDistance(originPos, targetPos)
	local distance = 0
	for dimension, value in pairs(originPos) do
      	if value > targetPos[dimension] then
			distance = distance + value - targetPos[dimension]
		else
			distance = distance + targetPos[dimension] - value
		end
    end
	return distance
end

function curveLine(line) --removed branching/forking for now
	local linePosArray = line[1]
	local lineArraySize = line[2]
	local midLine = linePosArray[math.floor(lineArraySize/2)] --always halfway down main path, might add some variation to this later
	midLine = {x = midLine.x + math.random(-curviness, curviness), y = midLine.y + math.random(-curviness, curviness), z = midLine.z} --add random curve apex
	local firstLeg = getLine(linePosArray[1], midLine)[1]
	local secondLeg = getLine(midLine, linePosArray[lineArraySize])[1]
    for i = 1, #secondLeg do
        firstLeg[#firstLeg+1] = secondLeg[i]
    end
    return firstLeg
end

function drawLightning(posArray, amount)
	for posIndx, pos in pairs(posArray) do
		if pos ~= nil then
			local ionizedGas = dfhack.maps.spawnFlow(pos, 9, 0, lightningInorganicIndx, amount)
			if ionizedGas ~= nil then ionizedGas.expanding = 0 end		
		end
	end
end
