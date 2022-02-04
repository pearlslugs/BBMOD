-- Enforce monotheism on citizens
-- Monotheism 1.0
-- There can be only one...
-- Fortress mode script called from DFHack

local utils=require('utils')

validArgs = utils.invert({
 'help',
 'verbose',
 'deity',
 'level'
})

local args = utils.processArgs({...}, validArgs)
local verbose = false
local override = false



local helpme = [===[

monotheism.lua
=========
This script sets the citizens to only have a single deity. The default mode removes any deity after the first listed. The override mode sets the player selected deity

arguments:
    -help
        print this help message
		
    -verbose
        prints debug data to the dfhack console. Default is false
		
	-deity
		Expects the unit id of the deity to use
	
	-level
		Expects an integer value. 1=ardent, 2=faithful, 3=normal, 4=casual, and 5=dubious

    Examples:
        Default:
        monotheism
		
		Override:
		monotheism -deity 102 -level 4
     

]===]

-- Handle help requests
if args.help then
    print(helpme)
    return
end

if ( args.verbose ) then
    verbose = true
end

if (args.deity and args.level) then
    override = true
	force_deity = tonumber(args.deity)
	force_level = tonumber(args.level)
end
function EraseHFLinksDeity (hf)
    for i = #hf.histfig_links-1,0,-1 do
        if hf.histfig_links[i]._type == df.histfig_hf_link_deityst then
            local todelete = hf.histfig_links[i]
            hf.histfig_links:erase(i)
            todelete:delete()
        end
    end
end

function EraseDeityNeeds (needs)
    for i = #needs-1,0,-1 do
        if needs[i].id == 2 then
            needs:erase(i)
        end
    end
end


function set_deities ()

	-- Get the local civ id 
	local my_civ = df.global.world.world_data.active_site[0].entity_links[0].entity_id
	-- dfhack.println (my_civ)
 
 
	for i, unit in ipairs(df.global.world.units.all) do
		if unit.civ_id == my_civ and dfhack.units.isCitizen(unit) then
	 
		-- Per citizen variables
		local d_counter = 0
		local keep_deity = 0
		local keep_linkstrength = 0
		local keep_focus = 0
		local keep_need_level = 0
	 
		local hf = df.historical_figure.find(unit.hist_figure_id)
		if verbose then dfhack.println(dfhack.TranslateName(df.historical_figure.find(unit.hist_figure_id).name, true)) end

		-- Identify and count deity related relationships
		-- We'll grab the the first deity, delete everything, then reinsert it. Anything else leads to index order errors
		for k, histfig_link in ipairs(hf.histfig_links) do


			if histfig_link._type == df.histfig_hf_link_deityst then
		 
				d_counter = d_counter + 1
			
				if d_counter == 1 then
					keep_deity = hf.histfig_links[k].target_hf
					keep_linkstrength = hf.histfig_links[k].link_strength
					if verbose then dfhack.println(" == Will Keep " .. dfhack.TranslateName(df.historical_figure.find(keep_deity).name, true) .. " | " .. hf.histfig_links[k].link_strength ) end
				end
         
				if d_counter > 1 then
					-- Delete relationship
					if verbose then dfhack.println(" == Will Remove " .. dfhack.TranslateName(df.historical_figure.find(histfig_link.target_hf).name, true) .. " | " .. hf.histfig_links[k].link_strength) end
				end

			end
		
		end
	 

		
		-- Now we need to remove the needs. Just removing needs is not a great plan. They don't seem to regenerate.
		needs =  unit.status.current_soul.personality.needs
		
		for i = #needs-1,0,-1 do
			if needs[i].id == 2 then
				if verbose then dfhack.println(" == Deity Need " .. dfhack.TranslateName(df.historical_figure.find(needs[i].deity_id).name, true) .. ":" .. needs[i].focus_level .. ":" .. needs[i].need_level ) end
				if needs[i].deity_id == keep_deity then
					keep_focus = needs[i].focus_level
					keep_need_level = needs[i].need_level
					if verbose then dfhack.println(" == Keep Deity Need " .. dfhack.TranslateName(df.historical_figure.find(keep_deity).name, true) .. ":" .. keep_focus .. ":" .. keep_need_level ) end
				end
			end
		end

		
		-- We'll now remove all the deity relations
		EraseHFLinksDeity(hf)
		
		-- We'll now remove all Deity Needs
		EraseDeityNeeds(needs)
		
		-- Sometimes there isn't a need created for a deity?
		-- Oddly, need level doesn't seem directly linked to the linkstrength ranges for deity relationships?
		if(keep_need_level == 0) then
			if( keep_linkstrength >= 90 ) then
				keep_need_level = 10
			elseif( keep_linkstrength >= 70 ) then
				keep_need_level = 5
			elseif( keep_linkstrength >= 50 ) then
				keep_need_level = 2
			else
				keep_need_level = 1
			end
		end
		
		-- We can test for an override here
		if(override) then
		    if verbose then dfhack.println(" == Force Deity to " .. force_deity .. "|" .. force_level ) end
			keep_deity = force_deity
			if( force_level == 1 ) then
				keep_need_level = 10
				keep_linkstrength = 90
			elseif( force_level == 2 ) then
				keep_need_level = 5
				keep_linkstrength = 75
			elseif( force_level == 3 ) then
				keep_need_level = 2
				keep_linkstrength = 50
			elseif( force_level == 4 ) then
				keep_need_level = 2
				keep_linkstrength = 10
			else
				keep_need_level = 1
				keep_linkstrength = 1
			end
			if verbose then dfhack.println(" == Force Deity to " .. dfhack.TranslateName(df.historical_figure.find(keep_deity).name, true) .. "|" .. keep_linkstrength .. "|" .. keep_need_level ) end
		end
		
		-- We'll now add a deity link.
		local new_link = df.histfig_hf_link_deityst:new() -- adding hf link to source
		new_link.target_hf = keep_deity
		new_link.link_strength = keep_linkstrength
		hf.histfig_links:insert('#',new_link)
				
        -- Recreate our single deity need
		local new_need = df.unit_personality.T_needs:new()
		new_need.id = 2
		new_need.deity_id = keep_deity
		new_need.focus_level = keep_focus
		new_need.need_level = keep_need_level
		unit.status.current_soul.personality.needs:insert("#",new_need)
		
    end
  end
 
end

set_deities ()