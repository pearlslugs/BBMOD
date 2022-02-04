--Lights things on fire: items, locations, entire inventories even!
--[====[

firestarter
===========
Lights things on fire: items, locations, entire inventories even! Use while
viewing an item, unit inventory, or tile to start fires.

]====]
if dfhack.gui.getSelectedItem(true) then
    dfhack.gui.getSelectedItem(true).flags.on_fire = true
elseif dfhack.gui.getSelectedUnit(true) then
    for _, entry in ipairs(dfhack.gui.getSelectedUnit(true).inventory) do
        entry.item.flags.on_fire = true
    end
elseif df.global.cursor.x ~= -30000 then
    local curpos = xyz2pos(pos2xyz(df.global.cursor))
    df.global.world.fires:insert('#', {
        new=df.fire,
        timer=1000,
        pos=curpos,
        temperature=60000,
        temp_unk1=60000,
        temp_unk2=60000,
        temp_unk3=60000,
    })
end
