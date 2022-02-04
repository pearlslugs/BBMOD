-- alias expansion logic for the quickfort script query module
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local quickfort_common = reqscript('internal/quickfort/common')
local quickfort_parse = reqscript('internal/quickfort/parse')
local quickfort_reader = reqscript('internal/quickfort/reader')

local log = quickfort_common.log

-- special keycode shortcuts inherited from python quickfort.
local special_keys = {
    ['&']={'Enter'},
    ['!']={'Ctrl'},
    ['~']={'Alt'},
    ['@']={'Shift','Enter'},
    ['^']={'ESC'},
    ['%']={'Wait'},
}
local special_aliases = {
    ExitMenu={'ESC'},
    ['r+']={'r','+','Enter'},
}

local alias_stack = {}

function reset_aliases()
    alias_stack = {}
end

-- pushes a collection of aliases on the stack. aliases are resolved with the
-- definition nearest the top of the stack.
-- note: this function overwrites the metatable of the passed-in aliases map
function push_aliases(aliases)
    local prev = alias_stack
    setmetatable(aliases, {prev=prev,
                           __index=function(_, key) return prev[key] end})
    alias_stack = aliases
end

local function pop_aliases()
    alias_stack = getmetatable(alias_stack).prev
end

local function push_aliases_reader(reader)
    local aliases, num_aliases = {}, 0
    local line = reader:get_next_row()
    while line do
        if quickfort_parse.parse_alias_combined(line, aliases) then
            num_aliases = num_aliases + 1
        end
        line = reader:get_next_row()
    end
    push_aliases(aliases)
    return num_aliases
end

function push_aliases_file(filepath)
    local num_aliases = push_aliases_reader(
            quickfort_reader.TextReader{filepath=filepath})
    log('read in %d aliases from "%s"', num_aliases, filepath)
end

local function process_text(text, tokens, depth)
    depth = depth or 1
    if depth > 50 then
        qerror(string.format('alias maximum recursion depth exceeded (%d)',
                             depth))
    end
    local i = 1
    while i <= #text do
        local next_char = text:sub(i, i)
        local expansion, repetitions = {}, 1
        if next_char ~= '{' then
            -- token is a special key or a key literal
            expansion[1] = special_keys[next_char] or next_char
        else
            local etoken, params, reps, next_pos =
                quickfort_parse.parse_extended_token(text, i)
            if not special_aliases[etoken] and alias_stack[etoken] then
                push_aliases(params)
                process_text(alias_stack[etoken], expansion, depth+1)
                pop_aliases()
            else
                expansion[1] = special_aliases[etoken] or etoken
            end
            repetitions, i = reps, next_pos - 1
        end
        for j=1,repetitions do
            for k=1, #expansion do
                if type(expansion[k]) == "string" then
                    tokens[#tokens+1] = expansion[k]
                else
                    for _, token in ipairs(expansion[k]) do
                        tokens[#tokens+1] = token
                    end
                end
            end
        end
        i = i + 1
    end
end

-- expands aliases in a string and returns the individual key tokens.
-- if the entirety of text matches an alias, expands the entire text as an alias
-- otherwise, if the text contains a substring like '{alias}', matches the alias
-- between the curly brackets and replaces the substring. Aliases themselves
-- can contain other aliases, but must use the {} format if they do. Literal
-- key names can also appear in curly brackets to allow the parser to recognize
-- multi-character keys, such as '{F10}'. Anything in curly brackets can be
-- followed by a number to indicate repetition. For example, '{Down 5}'
-- indicates 'Down' 5 times. 'Numpad' is treated specially so that '{Numpad 8}'
-- doesn't get expanded to 'Numpad' 8 times, but rather 'Numpad 8' once. You can
-- repeat Numpad keys like this: '{Numpad 8 5}'.
-- returns an array of character key tokens
function expand_aliases(text)
    local tokens = {}
    if special_aliases[text] then
        tokens = special_aliases[text]
    elseif alias_stack[text] then
        process_text(alias_stack[text], tokens)
    else
        process_text(text, tokens)
    end
    local expanded_text = table.concat(tokens, '')
    if text ~= expanded_text then
        log('expanded keys to: "%s"', table.concat(tokens, ' '))
    end
    return tokens
end

if dfhack.internal.IN_TEST then
    unit_test_hooks = {
        reset_aliases=reset_aliases,
        push_aliases=push_aliases,
        pop_aliases=pop_aliases,
        push_aliases_reader=push_aliases_reader,
        process_text=process_text,
        expand_aliases=expand_aliases,
    }
end
