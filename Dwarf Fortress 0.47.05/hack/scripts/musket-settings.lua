--[[musket-settings]]
--author zaporozhets
--crude bespoke settings manager based on the criminally underused mod-manager by Warmist, PeridexisErrant and Lethosor (because it was broken when I tried to use it)
--it's not pretty but it seems to work

local gui=require 'gui'
local widgets=require 'gui.widgets'

local installFile = "./hack/scripts/musket/installed.txt"
local mephGraphics = "./data/art/Meph_32x32.png"
local graphicsType

local featureList = {}
table.insert(featureList,{text="Gunsmith's Workshop (Required)", data = "gunsmith"})
table.insert(featureList,{text="Muskets and Pistols", data = "musket"})
table.insert(featureList,{text="Bayonets", data = "bayonet"})
table.insert(featureList,{text="Blunderbusses", data = "blunderbuss"})
table.insert(featureList,{text="Hand Mortars", data = "grenade"})
table.insert(featureList,{text="Rocket Launchers", data = "rocket"})
table.insert(featureList,{text="Cannons", data = "cannon"})
table.insert(featureList,{text="Alchemist's Laboratory", data = "alchemist"})

local customInstaller = defclass(customInstaller,gui.FramedScreen)
function customInstaller:init(args)
	self:addviews{
		widgets.Panel{
			view_id = 'panel',
			subviews = {
				widgets.Label{
					text = "Musket Mod Settings Manager",
					frame={t = 1, l = 1}
				},
				widgets.Label{
					text = "(Settings will not take effect unless a new world is created)",
					frame = {t = 2, l = 1}
				},
				widgets.Label{
					text = "===========================",
					frame = {t = 3, l = 1}
				},
				widgets.Label{
					text = "Features:",
					frame = {t = 4, l = 1}
				},
				widgets.Panel{subviews={
					widgets.List{
						choices = featureList,
						frame = {t = 5,  l = 1},
						on_select=self:callback("selectFeature")
					},
					widgets.Label{
						text={
							{text="Enable",key="CUSTOM_E",key_sep="()", disabled=self:callback("curInstalled"),
								on_activate=self:callback("installCurrent")},NEWLINE,
							{text="Disable",key="CUSTOM_D",key_sep="()", enabled=self:callback("curInstalled"),
								on_activate=self:callback("uninstallCurrent")},NEWLINE,
							{text="Exit",key="LEAVESCREEN",key_sep="()",},NEWLINE
						},
					}
				},
					-- new elements here
				}
			}
		}
	}
end

function customInstaller:selectFeature(idx, choice)
	self.selected=choice
	installFile = io.open("./hack/scripts/musket/installed.txt")
		for line in installFile:lines() do
			if line == self.selected.data then
				self.selected.installed = true
				break
			else
				self.selected.installed = false
			end
		end
	installFile:close()
end

function customInstaller:curInstalled(selected)
	return self.selected.installed
end

function customInstaller:installCurrent()
	if self.selected.data == "gunsmith" then
		local initFile = io.open("./dfhackMusket.init", "w")
			initFile:write("musket/musket-smoke \n")
			initFile:write("musket/cannon-smoke")
		initFile:close()
	elseif self.selected.data == "alchemist" then
		injectVenom("on")
	end
	patchEntity(self.selected.data, "on")
	installFile = io.open("./hack/scripts/musket/installed.txt", "a") --[[persistent installation tracking]]
		installFile:write(self.selected.data .. "\n")
	installFile:close()
	self.selected.installed = true --[[end of persistent installation tracking]]
end

function patchEntity(feature, mode)
	local entity_target_dwarf = "[ENTITY:MOUNTAIN]"
	local entity_target_human = "[ENTITY:PLAINS]"
	local entity_file_dwarf = "./raw/objects/entity_default.txt"
	local entity_file_human = "./raw/objects/entity_default.txt"
	if graphicsType == "Meph" then
		entity_file_dwarf = "./raw/objects/entity_good_dwarf.txt"
		entity_file_human = "./raw/objects/entity_good_human.txt"
	end
	patchFile(entity_file_dwarf, entity_target_dwarf, "./hack/scripts/musket/entity/"..feature.."_dwarf.txt", mode)
	patchFile(entity_file_human, entity_target_human, "./hack/scripts/musket/entity/"..feature.."_human.txt", mode)
end

function patchFile(file, target, source, mode) --file: the file to be patched, target: the string insert new lines after, source: the source of the new lines, mode: "on" == add or "off" == remove
	--print("patching: "..file.." with: "..source.." after: "..target) --TODO: make sure this is turned off
	if io.open(file, "r") == nil then return false end
	if io.open(source, "r") == nil then return false end
	local sourceLines = {}
	local sourceFile = io.open(source, "r")
	for line in sourceFile:lines() do
		table.insert(sourceLines, line)
	end
	sourceFile:close()
	local targetLines = {}
	local targetFile = io.open(file, "r")
	for line in targetFile:lines() do
		table.insert(targetLines, line)
	end
	targetFile:close()		
	if mode == "on" then
		for indx,line in ipairs(targetLines) do
			if line:gsub("%s+", "") == target then
				--print("Found ".. target) --TODO: make sure this is turned off
				for indx2,line2 in ipairs(sourceLines) do
					table.insert(targetLines, indx + indx2, line2)
					--print("adding: "..line2.." to table") --TODO: make sure this is turned off
				end
				if target == "begin" then table.remove(targetLines, indx) end
				break
			end
		end
	elseif mode == "off" then
		for indx,line in ipairs(sourceLines) do
			for indx2,line2 in ipairs(targetLines) do	
				if line:gsub("%s+", "") == line2:gsub("%s+", "") then
					table.remove(targetLines, indx2)
					--print("removing: "..line.." from table") --TODO: make sure this is turned off
					break
				end
			end
		end
	end
	targetFile = io.open(file, "w")
	for indx,line in ipairs(targetLines) do
		targetFile:write(line .. "\n")
	end
	targetFile:close()
end

function injectVenom(mode) --injects syndrome tags to creature venom definitions and stores/restores unaltered creature raws
	local raws = dfhack.filesystem.listdir("./raw/objects")
	for indx, rawName in ipairs(raws) do
		if string.sub(rawName, 1, 8) == "creature" then
			if mode == "on" then
				local backupRaw
				local rawFile = io.open("./raw/objects/"..rawName, "r")
					backupRaw = rawFile:read("*all")
				rawFile:close()
				local backupFile = io.open("./hack/scripts/musket/backup/"..rawName, "w")
					backupFile:write(backupRaw)
				backupFile:close()
				local rawLines = {}
				local rawFile = io.open("./raw/objects/"..rawName, "r")
					for line in rawFile:lines() do
						table.insert(rawLines, line)
					end
				rawFile:close()			
				for indx,line in ipairs(rawLines) do
					if line:gsub("%s+", "") == "[SYN_INJECTED]" then
						table.insert(rawLines, indx + 1, "			[SYN_CONTACT]")
					end
				end
				local rawFile = io.open("./raw/objects/"..rawName, "w")
					for indx,line in ipairs(rawLines) do
						rawFile:write(line .. "\n")
					end
				rawFile:close()	
			elseif mode == "off" then
				local backupRaw
				local backupFile = io.open("./hack/scripts/musket/backup/"..rawName, "r")
					backupRaw = backupFile:read("*all")
				backupFile:close()
				local rawFile = io.open("./raw/objects/"..rawName, "w+")
					rawFile = rawFile:write(backupRaw)
				rawFile:close()
				os.remove("./hack/scripts/musket/backup/"..rawName)
			end
		end
	end
end

function customInstaller:uninstallCurrent()
	if self.selected.data == "gunsmith" then
		os.remove("./dfhackMusket.init")
	elseif self.selected.data == "alchemist" then
		injectVenom("off")
	end
	patchEntity(self.selected.data, "off")
	local installed = {} --[[persistent installation tracking]] 
	installFile = io.open("./hack/scripts/musket/installed.txt", "r")
	for line in installFile:lines() do
		table.insert(installed, line)
	end
	installFile:close()
	for indx,line in ipairs(installed) do
		if line == self.selected.data then
			table.remove(installed, indx)
		end
	end
	installFile = io.open("./hack/scripts/musket/installed.txt", "w")
		for indx,line in ipairs(installed) do
			installFile:write(line .. "\n")
		end
	installFile:close()
	self.selected.installed = false --[[end of persistent installation tracking]]
end

function customInstaller:onInput(keys)
    if keys.LEAVESCREEN then
		dfhack.run_script("musket/musket-smoke")
        self:dismiss()
		print("musket-mod settings updated.")
    else
        self:inputToSubviews(keys)
    end
end

if dfhack.gui.getCurFocus()~='title' then
    qerror("Can only be used in title screen")
else
	print("Please go back in-game and enable the features you want.")
	if io.open(mephGraphics) ~= nil then
		graphicsType = "Meph"
	end
	musketInstaller = customInstaller{}
	musketInstaller:show()
end