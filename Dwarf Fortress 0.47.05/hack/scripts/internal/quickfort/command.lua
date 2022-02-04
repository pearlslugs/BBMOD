-- command routing logic for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local utils = require('utils')
local guidm = require('gui.dwarfmode')
local quickfort_common = reqscript('internal/quickfort/common')
local quickfort_list = reqscript('internal/quickfort/list')
local quickfort_orders = reqscript('internal/quickfort/orders')
local quickfort_parse = reqscript('internal/quickfort/parse')

local mode_modules = {}
for mode, _ in pairs(quickfort_parse.valid_modes) do
    if mode ~= 'ignore' and mode ~= 'aliases' then
        mode_modules[mode] = reqscript('internal/quickfort/'..mode)
    end
end

local command_switch = {
    run='do_run',
    orders='do_orders',
    undo='do_undo',
}

function init_ctx(command, blueprint_name, cursor, aliases, dry_run)
    return {
        command=command,
        blueprint_name=blueprint_name,
        cursor=cursor,
        aliases=aliases,
        dry_run=dry_run,
        stats={},
        messages={},
    }
end

function do_command_internal(ctx, section_name)
    ctx.stats.out_of_bounds = ctx.stats.out_of_bounds or
            {label='Tiles outside map boundary', value=0}
    ctx.stats.invalid_keys = ctx.stats.invalid_keys or
            {label='Invalid key sequences', value=0}

    local sheet_name, label = quickfort_parse.parse_section_name(section_name)
    ctx.sheet_name = sheet_name
    local filepath = quickfort_list.get_blueprint_filepath(ctx.blueprint_name)
    local section_data_list = quickfort_parse.process_section(
            filepath, sheet_name, label, ctx.cursor)
    local command = ctx.command
    local first_modeline = nil
    for _, section_data in ipairs(section_data_list) do
        if not first_modeline then first_modeline = section_data.modeline end
        ctx.cursor.z = section_data.zlevel
        mode_modules[section_data.modeline.mode][command_switch[ctx.command]](
            section_data.zlevel, section_data.grid, ctx)
    end
    if first_modeline and first_modeline.message then
        table.insert(ctx.messages, first_modeline.message)
    end
end

function finish_command(ctx, section_name, quiet)
    if ctx.command == 'orders' then quickfort_orders.create_orders(ctx) end
    if not quiet then
        print(string.format('%s successfully completed',
                            quickfort_parse.format_command(
                                ctx.command, ctx.blueprint_name, section_name)))
        for _,stat in pairs(ctx.stats) do
            if stat.always or stat.value > 0 then
                print(string.format('  %s: %d', stat.label, stat.value))
            end
        end
    end
end

local function parse_cursor(arg)
    local _, _, x, y, z = arg:find('^(-?%d+),(-?%d+),(-?%d+)$')
    if not x then
        qerror(('invalid argument for --cursor option: "%s"; expected format' ..
                ' is "<x>,<y>,<z>", for example: "30,60,150"'):format(arg))
    end
    return {x=tonumber(x), y=tonumber(y), z=tonumber(z)}
end

function do_command(args)
    local command = args.action
    if not command or not command_switch[command] then
        qerror(string.format('invalid command: "%s"', command))
    end
    local cursor = guidm.getCursorPos()
    local quiet, verbose, dry_run, section_name = false, false, false, nil
    local other_args = utils.processArgsGetopt(args, {
            {'c', 'cursor', hasArg=true,
             handler=function(optarg) cursor = parse_cursor(optarg) end},
            {'d', 'dry-run', handler=function() dry_run = true end},
            {'n', 'name', hasArg=true,
             handler=function(optarg) section_name = optarg end},
            {'q', 'quiet', handler=function() quiet = true end},
            {'v', 'verbose', handler=function() verbose = true end},
        })
    local blueprint_name = other_args[1]
    if not blueprint_name or blueprint_name == '' then
        qerror('expected <list_num> or <blueprint_name> parameter')
    end
    if #other_args > 1 then
        local extra = other_args[2]
        qerror(('unexpected argument: "%s"; did you mean "-n %s"?')
               :format(extra, extra))
    end

    local mode = nil
    local list_num = tonumber(blueprint_name)
    if list_num then
        blueprint_name, section_name, mode =
                quickfort_list.get_blueprint_by_number(list_num)
    else
        mode = quickfort_list.get_blueprint_mode(blueprint_name, section_name)
    end

    if not cursor then
        if command == 'orders' or mode == 'notes' then
            cursor = {x=0, y=0, z=0}
        else
            qerror('please position the game cursor at the blueprint start ' ..
                   'location or use the --cursor option')
        end
    end

    quickfort_common.verbose = verbose
    dfhack.with_finalize(
        function() quickfort_common.verbose = false end,
        function()
            local aliases = quickfort_list.get_aliases(blueprint_name)
            local ctx = init_ctx(command, blueprint_name, cursor, aliases,
                                 dry_run)
            do_command_internal(ctx, section_name)
            finish_command(ctx, section_name, quiet)
            if command == 'run' then
                for _,message in ipairs(ctx.messages) do
                    print('* '..message)
                end
            end
        end)
end
