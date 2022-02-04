-- Get worshippers per deity
-- deity_list 1.0
-- Courtesy of PatrikLundell's (superior) original
-- http://www.bay12forums.com/smf/index.php?topic=169626.msg7706526#msg7706526


local utils=require('utils')

validArgs = utils.invert({
 'help',
 'verbose'
})

local args = utils.processArgs({...}, validArgs)
local verbose = false

local helpme = [===[

deity_list.lua
=========
This script prints the deities and a count of their worshippers in the fort

arguments:
    -help
        print this help message
		
    -verbose
        prints debug data to the dfhack console. Default is false

    Examples:
        deity_list
     

]===]

-- Handle help requests
if args.help then
    print(helpme)
    return
end

if ( args.verbose ) then
    verbose = true
end



function show_deities ()
  local deities = {}

  local my_civ = df.global.world.world_data.active_site[0].entity_links[0].entity_id
  -- dfhack.println (my_civ)
 
  for i, entity in ipairs (df.global.world.entities.all[my_civ].unknown1b.deities) do
    -- Populate the deities table with worshipped deities from my civ
	-- Distrib is: ardent, faithful, normal, casual, dubious
    table.insert(deities, {entity, 0, {0,0,0,0,0} })
  end

 
  for i, unit in ipairs(df.global.world.units.all) do
    if unit.civ_id == my_civ and dfhack.units.isCitizen(unit) then
	 
	  local hf = df.historical_figure.find(unit.hist_figure_id)
      if verbose then dfhack.println(dfhack.TranslateName(df.historical_figure.find(unit.hist_figure_id).name, true)) end
	   
      for k, histfig_link in ipairs(hf.histfig_links) do
        if histfig_link._type == df.histfig_hf_link_deityst then
		  if verbose then dfhack.println(" == Worships " .. dfhack.TranslateName(df.historical_figure.find(histfig_link.target_hf).name, true) .. " |" .. histfig_link.link_strength) end
          local found = false
		 
          -- Loop through my_civ's deities, incrementing count based on worshippers
          for l, entry in ipairs(deities) do
            if histfig_link.target_hf == entry[1] then
              entry[2] = entry[2] + 1
			 
			  if(histfig_link.link_strength >= 90) then
				entry[3][1] = entry[3][1] + 1
			  elseif(histfig_link.link_strength >= 75) then
			    entry[3][2] = entry[3][2] + 1
			  elseif(histfig_link.link_strength >= 25) then
			    entry[3][3] = entry[3][3] + 1
			  elseif(histfig_link.link_strength >= 10) then
			    entry[3][4] = entry[3][4] + 1
			  else
				entry[3][5] = entry[3][5] + 1
			  end
			 
              found = true
              break
            end
          end
         
          if not found then
		    if verbose then dfhack.println("Initializing foreign deity") end
		    -- Initialize the entry for this foreign deity
			if(histfig_link.link_strength >= 90) then
				table.insert (deities, {histfig_link.target_hf, 1, {1,0,0,0,0} } )
			elseif(histfig_link.link_strength >= 75) then
				table.insert (deities, {histfig_link.target_hf, 1, {0,1,0,0,0} } )
			elseif(histfig_link.link_strength >= 25) then
				table.insert (deities, {histfig_link.target_hf, 1, {0,0,1,0,0} } )
			elseif(histfig_link.link_strength >= 10) then
				table.insert (deities, {histfig_link.target_hf, 1, {0,0,0,1,0} } )
			else
				table.insert (deities, {histfig_link.target_hf, 1, {0,0,0,0,1} } )
			end

          end
		 
        end -- End deity test
      end -- End citizen relation loop
    end -- End all my citizens test
  end -- End all units in the world loop
 
 
 
  for i = 1, #df.global.world.entities.all[my_civ].unknown1b.deities do
    local distrib = "Ardent: " .. deities[i][3][1] .. "; Faithful:" .. deities[i][3][2] .. "; Normal:" .. deities[i][3][3] .. "; Casual:" .. deities[i][3][4] .. "; Dubious:" .. deities[i][3][5]
    dfhack.println (tostring (deities[i][2]) .. " total worshippers for " .. dfhack.TranslateName(df.historical_figure.find(deities[i][1]).name, true) .. "(" .. deities[i][1] .. ") - " .. distrib )
  end
 
  if #df.global.world.entities.all[my_civ].unknown1b.deities < #deities then
    dfhack.println ("Acquired deities:")
   
    for i = #df.global.world.entities.all[my_civ].unknown1b.deities + 1, #deities do
	  local distrib = "Ardent: " .. deities[i][3][1] .. "; Faithful:" .. deities[i][3][2] .. "; Normal:" .. deities[i][3][3] .. "; Casual:" .. deities[i][3][4] .. "; Dubious:" .. deities[i][3][5]
      dfhack.println(tostring(deities[i][2]) .. " total worshippers for " .. dfhack.TranslateName(df.historical_figure.find(deities[i][1]).name, true) .. "(" .. deities[i][1] .. ") - " .. distrib )
    end
  end
end

show_deities ()