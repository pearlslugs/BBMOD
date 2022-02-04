# designate based on a '.csv' plan (deprecated: please use DFHack quickfort)
=begin

digfort
=======
A script to designate an area for digging according to a plan in csv format.

**Digfort is deprecated.** Please use DFHack's more powerful `quickfort` command
instead. You can use your existing .csv files. Just move them to the
``blueprints`` folder in your DF installation, and instead of ``digfort
file.csv`` run ``quickfort run file.csv``.

This script, inspired by (Python) quickfort, can designate an area for digging.
Your plan should be stored in a .csv file like this::

    # this is a comment
    d,d,u,d,d,skip this tile,d
    d,d,d,i

Other than ``d``, tile shapes are named after the 'dig' menu shortcuts:
``d`` for default, ``u`` upstairs, ``j`` downstairs, ``i`` updown,
``h`` channel, ``r`` upward ramp, and ``x`` remove designation.
Unrecognized characters are ignored (e.g. the 'skip this tile' in the sample).
``d`` is interpreted based on the shape of the current tile. It will dig
walls, remove stairs and ramps, gather plants, and fell trees.

Empty lines and data after a ``#`` are ignored as comments. Double quote (``"``)
characters that are inserted at the beginning of strings by csv exporters are
also ignored. To skip a row in your design, add a row consisting only of ``,``
characters.

One comment in the file may contain the phrase ``start(3,5)``. It is interpreted
as an offset for the pattern: instead of starting at the cursor, it will start
3 tiles left and 5 tiles up from the cursor.

Additionally a comment can have a ``<`` for a rise in z level or a ``>`` for a
drop in z.

The script takes the plan filename, starting from the root df folder (where
``dfhack.init`` is found).

Additional options can be specified after the filename:

* ``force``: if the blueprint would extend beyond the edge of the map, still
  draw the parts that remain on the map. (The default behavior in this case
  is to fail with an error message.)

=end

puts "The digfort script is deprecated. Please move your blueprints to the 'blueprints' folder (under your DF installation directory) and use DFHack's quickfort command instead:\n  quickfort run example.csv\nThe digfort script will be removed in a future DFHack release."

fname = $script_args[0].to_s
opts = $script_args[1..-1] or []
force = opts.any?{ |arg| arg == "force" }

if not $script_args[0] then
    puts "  Usage: digfort <plan filename> [options]"
    throw :script_finished
end
if not fname[-4..-1] == ".csv" then
    puts "  The plan file must be in .csv format."
    throw :script_finished
end
if not File.file?(fname) then
    puts "  The specified file does not exist."
    throw :script_finished
end

planfile = File.read(fname)

if df.cursor.x == -30000
    puts "place the game cursor to the top-left corner of the design and retry"
    throw :script_finished
end

offset = [0, 0]
tiles = []
max_x = 0
max_y = 0
y = 0
planfile.each_line { |l|
    l = l.chomp.sub(/^"/, '')

    if l =~ /#.*start\s*\(\s*(-?\d+)\s*[,;]\s*(-?\d+)/
        raise "Error: multiple start() comments" if offset != [0, 0]
        offset = [$1.to_i, $2.to_i]
    end
    if l == '#<'
        l = '<'
        y = 0
    end

    if l == '#>'
        l = '>'
        y = 0
    end

    l = l.sub(/#.*/, '')
    next if l == ''
    x = 0
    tiles << l.split(/[;,]/).map { |t|
        t = t.strip
        x = x + 1
        max_x = x if x > max_x and not t.empty?
        (t[0] == '"') ? t[1..-2] : t
    }
    y = y + 1
    max_y = y if y > max_y
}

x = df.cursor.x - offset[0]
y = df.cursor.y - offset[1]
z = df.cursor.z
starty = y - 1

map = df.world.map

if x < 0 or y < 0 or x+max_x > map.x_count or y+max_y > map.y_count
    max_x = max_x + x + 1
    max_y = max_y + y + 1
    msg = "Position would designate outside map limits. Selected limits are from (#{x+1}, #{y+1}) to (#{max_x},#{max_y})"
    if force then
        puts msg
    else
        raise msg
    end
end

tiles.each { |line|
    if line.empty? or line == [''] then
        y += 1
        next
    end
    line.each { |tile|
        if tile.empty?
            x += 1
            next
        end
        t = df.map_tile_at(x, y, z)
        next if t.nil?  # probably off map edge with "force" specified
        s = t.shape_basic
        case tile
        when 'd'; t.dig(:Default) if s == :Wall
        when 'u'; t.dig(:UpStair) if s == :Wall
        when 'j'; t.dig(:DownStair) if s == :Wall or s == :Floor
        when 'i'; t.dig(:UpDownStair) if s == :Wall
        when 'h'; t.dig(:Channel) if s == :Wall or s == :Floor
        when 'r'; t.dig(:Ramp) if s == :Wall
        when 'x'; t.dig(:No)
        when '<'; y=starty; z += 1
        when '>'; y=starty; z -= 1
        end
        x += 1
    }
    x = df.cursor.x - offset[0]
    y += 1
}

puts '  done'
