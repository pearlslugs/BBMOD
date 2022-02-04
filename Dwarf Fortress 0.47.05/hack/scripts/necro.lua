--Author: Burrito25man
--Based off the amazing work done by Atomic Chicken and Meph for guidance
--Version: 0.44.XX

local utils = require 'utils'

validArgs = validArgs or utils.invert({
 'material_id',
 'booktitle_name',
 'secret_id',
 'location',
 'copy',
 'help'})

local args = utils.processArgs({...}, validArgs)

local artifact = true

if args.help then
 print([[ Spawn spellbook.lua
 This script is designed to work with a reaction to spawn a spellbook.

 arguments:
 
 -material_id
	Material book will be made of.
	
 -booktitle_name
	Title of the book to be made. String must be contained within ' ' .
	
 -secret_id
	Secret conveyed by the book (must use the IS_NAME of the secret). String must be contained within ' ' .
	
 -copy
	If this optional argument is included, the script will make the book be treated as a copy
	
 -location
	Location which the book will spawn.

  To use:
 
 Create a file called "onLoad.init" in Dwarf Fortress/raw if one does not already exist.
 Enter the following:
  modtools/reaction-trigger -reactionName YOUR_REACTION -command [ Spawn-spellbook -material_id INORGANIC:SILVER -booktitle_name "BOOK TITLE" -secret_id "SECRET ID" -location \\WORKER_ID -copy]
 
  such as:
 
  modtools/reaction-trigger -reactionName SPAWN_NECROBOOK -command [ necro -material_id INORGANIC:SILVER -booktitle_name "The Necronomicon" -secret_id "the secrets of life and death" -location \\WORKER_ID -copy ]

 ]])
 return
end	
	
local material_id = args.material_id
local booktitle_name = args.booktitle_name
local secret_id = args.secret_id
local worker = df.unit.find(tonumber(args.location))

if not args.material_id then error 'ERROR: material_id not specified.' end
if not args.booktitle_name then error 'ERROR: booktitle_name not specified.' end
if not args.secret_id then error 'ERROR: secret_id not specified.' end
if args.copy then artifact = false end

function getSecretId(secret_id)
  for _,i in ipairs(df.global.world.raws.interactions) do
    for _,is in ipairs (i.sources) do
      if getmetatable(is) == 'interaction_source_secretst' then
        if is.name == secret_id then
          return i.id
        end
      end
    end
  end
end

local pages = math.random(169,666)
local style = math.random(0,18)

function createWriting(booktitle_name,secret_id)
  local w = df.written_content:new()
  w.id = df.global.written_content_next_id
  w.title = booktitle_name
  w.page_start = 1
  w.page_end = pages --number of pages
  w.styles:insert('#',style) --writing style
  w.style_strength:insert('#',0) --'the writing drives forward relentlessly'
  local ref = df.general_ref_interactionst:new()
  ref.interaction_id = getSecretId(secret_id)
  ref.source_id = 0
  ref.unk_08 = -1
  ref.unk_0c = -1
  w.refs:insert('#',ref)
  w.ref_aux:insert('#',0)
 
  df.global.written_content_next_id = df.global.written_content_next_id+1
  df.global.world.written_contents.all:insert('#',w)
  return w.id
end

local m = dfhack.matinfo.find(material_id)
if not m then
  error('Invalid material.')
end

local book = df.item_bookst:new()
	book.id = df.global.item_next_id
	df.global.world.items.all:insert('#',book)
	df.global.item_next_id = df.global.item_next_id+1
	book:setMaterial(m['type'])
	book:setMaterialIndex(m['index'])
	book:categorize(true)
	book.flags.removed = true
	book:setSharpness(0,0)
	book:setQuality(0)
	book.title = booktitle_name

local imp = df.itemimprovement_pagesst:new()
	imp.mat_type = m['type']
	imp.mat_index = m['index']
	imp.count = pages --number of pages
	imp.contents:insert('#',createWriting(booktitle_name,secret_id))
	book.improvements:insert('#',imp)


if artifact == true then
  local a = df.artifact_record:new()
  a.id = df.global.artifact_next_id
  df.global.artifact_next_id = df.global.artifact_next_id+1
  a.item = book
  a.name.first_name = booktitle_name
  a.name.has_name = true
  a.flags:assign(df.global.world.artifacts.all[0].flags)
  a.anon_1 = -1000000
  a.anon_2 = -1000000
  df.global.world.artifacts.all:insert('#',a)
  local ref = df.general_ref_is_artifactst:new()
  ref.artifact_id = a.id
  book.general_refs:insert('#',ref)
 
  df.global.world.items.other.ANY_ARTIFACT:insert('#',book)
 
  local e = df.history_event_artifact_createdst:new()
  e.year = df.global.cur_year
  e.seconds = df.global.cur_year_tick
  e.id = df.global.hist_event_next_id
  e.artifact_id = a.id
  df.global.world.history.events:insert('#',e)
  df.global.hist_event_next_id = df.global.hist_event_next_id+1
end

dfhack.items.moveToGround(book,{x=worker.pos.x,y=worker.pos.y,z=worker.pos.z})

print('A magical book as been created!')


