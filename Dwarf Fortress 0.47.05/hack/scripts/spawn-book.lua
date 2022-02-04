local material = 'INORGANIC:SILVER'

function getSecretId()
  for _,i in ipairs(df.global.world.raws.interactions) do
    for _,is in ipairs (i.sources) do
      if getmetatable(is) == 'interaction_source_secretst' then
        if is.name == 'the secrets of life and death' then
          return i.id
        end
      end
    end
  end
end

local pos = copyall(df.global.cursor)
if pos.x <0 then
  error('Please place the cursor wherever you want to spawn the slab.')
end

local m = dfhack.matinfo.find(material)
if not m then
  error('Invalid material.')
end

local slab = df.item_slabst:new()
slab.id = df.global.item_next_id
df.global.world.items.all:insert('#',slab)
df.global.item_next_id = df.global.item_next_id+1
slab:setMaterial(m['type'])
slab:setMaterialIndex(m['index'])
slab:categorize(true)
slab.flags.removed = true
slab:setSharpness(0,0)
slab:setQuality(0)
slab.engraving_type = 6
slab.topic = getSecretId()
slab.description = 'The secrets of life and death'
dfhack.items.moveToGround(slab,{x=pos.x,y=pos.y,z=pos.z})