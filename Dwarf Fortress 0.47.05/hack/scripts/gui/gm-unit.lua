-- Interface powered, user friendly, unit editor

--[====[

gui/gm-unit
===========
An editor for various unit attributes.

]====]
local gui = require 'gui'
local dialog = require 'gui.dialogs'
local widgets = require 'gui.widgets'
local guiScript = require 'gui.script'
local utils = require 'utils'
local args = {...}
local setbelief = dfhack.reqscript("modtools/set-belief")
local setpersonality = dfhack.reqscript("modtools/set-personality")
local setneed = dfhack.reqscript("modtools/set-need")
local setorientation = dfhack.reqscript("set-orientation")

rng = rng or dfhack.random.new(nil, 10)

local target
--TODO: add more ways to guess what unit you want to edit
if args[1] ~= nil then
    target = df.units.find(args[1])
else
    target = dfhack.gui.getSelectedUnit(true)
end

if target == nil then
    qerror("No unit to edit") --TODO: better error message
end
local editors = {}
function add_editor(editor_class)
    local title = editor_class.ATTRS.frame_title
    table.insert(editors, {text=title, search_key=title:lower(), on_submit=function(unit)
        editor_class{target_unit=unit}:show()
    end})
end

function weightedRoll(weightedTable)
  local maxWeight = 0
  for index, result in ipairs(weightedTable) do
    maxWeight = maxWeight + result.weight
  end

  local roll = rng:random(maxWeight) + 1
  local currentNum = roll
  local result

  for index, currentResult in ipairs(weightedTable) do
    currentNum = currentNum - currentResult.weight
    if currentNum <= 0 then
      result = currentResult.id
      break
    end
  end

  return result
end


-------------------------------various subeditors---------
--TODO set local should or better yet skills vector to reduce long skill list access typing
editor_skills = defclass(editor_skills, gui.FramedScreen)
editor_skills.ATTRS = {
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Skill editor",
    target_unit = DEFAULT_NIL,
    learned_only = false,
}
function list_skills(unit,learned_only)
    local u_skills = unit.status.current_soul.skills
    local ret = {}
    for skill,v in ipairs(df.job_skill) do
        if skill ~= df.job_skill.NONE then
            local u_skill = utils.binsearch(u_skills, skill, "id")
            if u_skill or not learned_only then
                if not u_skill then
                    u_skill={rating=-1,experience=0}
                end

                local rating
                if u_skill.rating >=0 then
                    rating=df.skill_rating.attrs[u_skill.rating]
                else
                    rating={caption="<unlearned>",xp_threshold=0}
                end

                local text=string.format("%s: %s %d %d/%d",
                    df.job_skill.attrs[skill].caption,
                    rating.caption,u_skill.rating,
                    u_skill.experience,rating.xp_threshold)
                table.insert(ret,{
                    text=text,
                    id=skill,
                    search_key=text:lower()
                })
            end
        end
    end
    return ret
end
function editor_skills:update_list(no_save_place)
    local skill_list=list_skills(self.target_unit,self.learned_only)
    if no_save_place then
        self.subviews.skills:setChoices(skill_list)
    else
        self.subviews.skills:setChoices(skill_list,self.subviews.skills:getSelected())
    end
end
function editor_skills:init( args )
    if self.target_unit.status.current_soul==nil then
        qerror("Unit does not have soul, can't edit skills")
    end

    local skill_list=list_skills(self.target_unit,self.learned_only)

    self:addviews{
        widgets.FilteredList{
            choices=skill_list,
            frame = {t=0, b=1,l=1},
            view_id="skills",
        },
        widgets.Label{
            frame = { b=0,l=1},
            text ={{text= ": exit editor ",
                key  = "LEAVESCREEN",
                on_activate= self:callback("dismiss")
                },
                {text=": remove level ",
                key = "SECONDSCROLL_UP",
                on_activate=self:callback("level_skill",-1)},
                {text=": add level ",
                key = "SECONDSCROLL_DOWN",
                on_activate=self:callback("level_skill",1)}
                ,
                {text=": show learned only ",
                key = "CHANGETAB",
                on_activate=function ()
                    self.learned_only=not self.learned_only
                    self:update_list(true)
                end}
            }
        },
    }
end
function editor_skills:get_cur_skill()
    local list_wid=self.subviews.skills
    local _,choice=list_wid:getSelected()
    if choice==nil then
        qerror("Nothing selected")
    end
    local u_skill=utils.binsearch(self.target_unit.status.current_soul.skills,choice.id,"id")
    return choice,u_skill
end
function editor_skills:level_skill(lvl)
    local sk_en,sk=self:get_cur_skill()
    if lvl >0 then
        local rating

        if sk then
            rating=sk.rating+lvl
        else
            rating=lvl-1
        end

        utils.insert_or_update(self.target_unit.status.current_soul.skills, {new=true, id=sk_en.id, rating=rating}, 'id') --TODO set exp?
    elseif sk and sk.rating==0 and lvl<0 then
        utils.erase_sorted_key(self.target_unit.status.current_soul.skills,sk_en.id,"id")
    elseif sk and lvl<0 then
        utils.insert_or_update(self.target_unit.status.current_soul.skills, {new=true, id=sk_en.id, rating=sk.rating+lvl}, 'id') --TODO set exp?
    end
    self:update_list()
end
function editor_skills:remove_rust(skill)
    --TODO
end
add_editor(editor_skills)

------- civ editor
RaceBox = defclass(RaceBox, dialog.ListBox)
RaceBox.focus_path = 'RaceBox'

RaceBox.ATTRS{
    format_name="$NAME ($TOKEN)",
    with_filter=true,
    allow_none=false,
}
function RaceBox:format_creature(creature_raw)
    local t = {NAME=creature_raw.name[0],TOKEN=creature_raw.creature_id}
    return string.gsub(self.format_name, "%$(%w+)", t)
end
function RaceBox:preinit(info)
    self.format_name=RaceBox.ATTRS.format_name or info.format_name -- preinit does not have ATTRS set yet
    local choices={}
    if RaceBox.ATTRS.allow_none or info.allow_none then
        table.insert(choices,{text="<none>",num=-1})
    end
    for i, v in ipairs(df.global.world.raws.creatures.all) do
        local text=self:format_creature(v)
        table.insert(choices,{text=text,raw=v,num=i,search_key=text:lower()})
    end
    info.choices=choices
end
function showRacePrompt(title, text, tcolor, on_select, on_cancel, min_width,allow_none)
    RaceBox{
        frame_title = title,
        text = text,
        text_pen = tcolor,
        on_select = on_select,
        on_cancel = on_cancel,
        frame_width = min_width,
        allow_none = allow_none,
    }:show()
end
CivBox = defclass(CivBox,dialog.ListBox)
CivBox.focus_path = "CivBox"

CivBox.ATTRS={
    format_name="$NAME ($ENGLISH):$ID",
    format_no_name="<unnamed>:$ID",
    name_other="<other(-1)>",
    with_filter=true,
    allow_other=false,
}

function civ_name(id,format_name,format_no_name,name_other,name_invalid)
    if id==-1 then
        return name_other or "<other (-1)>"
    end
    local civ
    if type(id)=='userdata' then
        civ=id
    else
        civ=df.historical_entity.find(id)
        if civ==nil then
            return name_invalid or "<invalid>"
        end
    end
    local t={NAME=dfhack.TranslateName(civ.name),ENGLISH=dfhack.TranslateName(civ.name,true),ID=civ.id} --TODO race?, maybe something from raws?
    if t.NAME=="" then
        return string.gsub(format_no_name or "<unnamed> ($ID)", "%$(%w+)", t)
    end
    return string.gsub(format_name or "$NAME ($ENGLISH) ($ID)", "%$(%w+)", t)
end
function CivBox:update_choices()
    local choices={}
    if self.allow_other then
        table.insert(choices,{text=self.name_other,num=-1})
    end

    for i, v in ipairs(df.global.world.entities.all) do
        if not self.race_filter or (v.race==self.race_filter) then --TODO filter type
            local text=civ_name(v,self.format_name,self.format_no_name,self.name_other,self.name_invalid)
            table.insert(choices,{text=text,raw=v,num=i})
        end
    end
    if self.subviews.list then
        self.subviews.list:setChoices(choices)
    end
end
function CivBox:update_race_filter(id)
    local raw=df.creature_raw.find(id)
    if raw then
        self.subviews.race_label:setText(": "..raw.name[0])
        self.race_filter=id
    else
        self.subviews.race_label:setText(": <none>")
        self.race_filter=nil
    end

    self:update_choices()
end
function CivBox:choose_race()
    showRacePrompt("Choose race","Select new race:",nil,function (id,choice)
        self:update_race_filter(choice.num)
    end,nil,nil,true)
end
function CivBox:init(info)
    self.subviews.list.frame={t=3,r=0,l=0}
    self:addviews{
        widgets.Label{frame={t=1,l=0},text={
        {text="Filter race ",key="CUSTOM_CTRL_A",key_sep="()",on_activate=self:callback("choose_race")},
        }},
        widgets.Label{frame={t=1,l=21},view_id="race_label",
        text=": <none>",
        }
    }
    self:update_choices()
end
function showCivPrompt(title, text, tcolor, on_select, on_cancel, min_width,allow_other)
    CivBox{
        frame_title = title,
        text = text,
        text_pen = tcolor,
        on_select = on_select,
        on_cancel = on_cancel,
        frame_width = min_width,
        allow_other = allow_other,
    }:show()
end

editor_civ=defclass(editor_civ,gui.FramedScreen)
editor_civ.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Civilization editor",
    target_unit = DEFAULT_NIL,
}

function editor_civ:update_curren_civ()
    self.subviews.civ_name:setText("Currently: "..civ_name(self.target_unit.civ_id))
end
function editor_civ:init( args )
    if self.target_unit==nil then
        qerror("invalid unit")
    end

    self:addviews{
    widgets.Label{view_id="civ_name",frame = { t=1,l=1}, text="Currently: "..civ_name(self.target_unit.civ_id)},
    widgets.Label{frame = { t=2,l=1}, text={{text=": set to other (-1, usually enemy)",key="CUSTOM_N",
        on_activate= function() self.target_unit.civ_id=-1;self:update_curren_civ() end}}},
    widgets.Label{frame = { t=3,l=1}, text={{text=": set to current civ ("..df.global.ui.civ_id..")",key="CUSTOM_C",
        on_activate= function() self.target_unit.civ_id=df.global.ui.civ_id;self:update_curren_civ() end}}},
    widgets.Label{frame = { t=4,l=1}, text={{text=": manually enter",key="CUSTOM_E",
        on_activate=function ()
         dialog.showInputPrompt("Civ id","Enter new civ id:",COLOR_WHITE,
            tostring(self.target_unit.civ_id),function(new_value)
                self.target_unit.civ_id=new_value
                self:update_curren_civ()
            end)
        end}}
        },
    widgets.Label{frame= {t=5,l=1}, text={{text=": select from list",key="CUSTOM_L",
        on_activate=function (  )
            showCivPrompt("Choose civilization", "Select units civilization",nil,function ( id,choice )
                self.target_unit.civ_id=choice.num
                self:update_curren_civ()
            end,nil,nil,true)
        end
        }}},
    widgets.Label{
                frame = { b=0,l=1},
                text ={{text= ": exit editor ",
                    key  = "LEAVESCREEN",
                    on_activate= self:callback("dismiss")
                    },
                    }
            },
        }
end
add_editor(editor_civ)

------- counters editor
editor_counters=defclass(editor_counters,gui.FramedScreen)
editor_counters.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Counters editor",
    target_unit = DEFAULT_NIL,
    counters1={
    "think_counter",
    "job_counter",
    "swap_counter",
    "winded",
    "stunned",
    "unconscious",
    "suffocation",
    "webbed",
    "soldier_mood_countdown",
    "soldier_mood", --todo enum,
    "pain",
    "nausea",
    "dizziness",
    },
    counters2={
    "paralysis",
    "numbness",
    "fever",
    "exhaustion",
    "hunger_timer",
    "thirst_timer",
    "sleepiness_timer",
    "stomach_content",
    "stomach_food",
    "vomit_timeout",
    "stored_fat" --TODO what to reset to?
    }
}
function editor_counters:fill_counters()
    local ret = {}
    local u = self.target_unit
    for i, v in ipairs(self.counters1) do
        table.insert(ret, {f=u.counters:_field(v),name=v})
    end
    for i, v in ipairs(self.counters2) do
        table.insert(ret, {f=u.counters2:_field(v),name=v})
    end
    return ret
end
function editor_counters:update_counters()
    for i, v in ipairs(self.counter_list) do
        v.text=string.format("%s: %d", v.name, v.f.value)
    end
    self.subviews.counters:setChoices(self.counter_list)
end
function editor_counters:set_cur_counter(value,index,choice)
    choice.f.value = value
    self:update_counters()
end
function editor_counters:choose_cur_counter(index,choice)
    dialog.showInputPrompt(choice.name,"Enter new value:",COLOR_WHITE,
            tostring(choice.f.value),function(new_value)
                self:set_cur_counter(new_value,index,choice)
            end)
end
function editor_counters:init( args )
    if self.target_unit==nil then
        qerror("invalid unit")
    end

    self.counter_list=self:fill_counters()


    self:addviews{
        widgets.FilteredList{
            choices=self.counter_list,
            frame = {t=0, b=1,l=1},
            view_id="counters",
            on_submit=self:callback("choose_cur_counter"),
            on_submit2=self:callback("set_cur_counter",0),--TODO some things need to be set to different defaults
        },
        widgets.Label{
            frame = { b=0,l=1},
            text = {{text= ": exit editor ",
                key  = "LEAVESCREEN",
                on_activate= self:callback("dismiss")
                },
                {text=": reset counter ",
                key = "SEC_SELECT",
                },
                {text=": set counter ",
                key = "SELECT",
                }

            }
        },
    }
    self:update_counters()
end
add_editor(editor_counters)

prof_editor = defclass(prof_editor, gui.FramedScreen)
prof_editor.ATTRS = {
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Profession editor",
    target_unit = DEFAULT_NIL,
}

function prof_editor:init()
    local u = self.target_unit
    local opts = {}
    local craw = df.creature_raw.find(u.race)
    for i in ipairs(df.profession) do
        if i ~= df.profession.NONE then
            local attrs = df.profession.attrs[i]
            local caption = attrs.caption or '?'
            local tile = string.char(attrs.military and craw.creature_soldier_tile ~= 0 and
                craw.creature_soldier_tile or craw.creature_tile)
            table.insert(opts, {
                text = {
                    (i == u.profession and '*' or ' ') .. ' ',
                    {text = tile, pen = dfhack.units.getCasteProfessionColor(u.race, u.caste, i)},
                    ' ' .. caption
                },
                profession = i,
                search_key = caption:lower(),
            })
        end
    end

    self:addviews{
        widgets.FilteredList{
            frame = {t=1, l=1, b=2},
            choices = opts,
            view_id = 'professions',
            on_submit = self:callback('save_profession'),
        },
        widgets.Label{
            frame = {b=0,l=1},
            text = {
                {key = "LEAVESCREEN", text= ": exit editor ",
                on_activate = self:callback("dismiss")},
            }
        }
    }
end

function prof_editor:save_profession(_, choice)
    self.target_unit.profession = choice.profession
    self.target_unit.profession2 = choice.profession
    self:dismiss()
end

add_editor(prof_editor)

-------------------
editor_wounds=defclass(editor_wounds,gui.FramedScreen)
editor_wounds.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Wound editor",
    target_unit = DEFAULT_NIL,
    --filter
}
function is_scar( wound_part )
    return wound_part.flags1.scar_cut or wound_part.flags1.scar_smashed or
        wound_part.flags1.scar_edged_shake1 or wound_part.flags1.scar_blunt_shake1
end
function format_flag_name( fname )
    return fname:sub(1,1):upper()..fname:sub(2):gsub("_"," ")
end
function name_from_flags( wp )
    for i, v in ipairs(wp.flags1) do
        if v then
            return format_flag_name(df.wound_damage_flags1[i])
        end
    end
    for i, v in ipairs(wp.flags2) do
        if v then
            return format_flag_name(df.wound_damage_flags2[i])
        end
    end
    return "<unnamed wound>"
end
function lookup_bodypart( wound_part,unit,is_singular )
    local bp=unit.body.body_plan.body_parts
    local part=bp[wound_part.body_part_id]

    if is_singular then
        return part.name_singular[0].value
    else
        return part.name_plural[0].value
    end
end
function format_wound( list_id,wound, unit)
    --TODO(warmist): what if there are more parts?
    local name="<unnamed wound>"
    local body_part=""
    if wound.flags.severed_part then
        name="severed"
        if #wound.parts>0 then
            body_part=lookup_bodypart(wound.parts[0],unit,true)
        end
    else
        if #wound.parts>0 then
            if #wound.parts[0].effect_type>0 then --try to make wound name by effect...
                name=tostring(df.wound_effect_type[wound.parts[0].effect_type[0]])
                if #wound.parts>1 then --cheap and probably incorrect...
                    name=name.."s"
                end
            elseif is_scar(wound.parts[0]) then
                name="Scar"
            else
                local wp=wound.parts[0]
                name=name_from_flags(wp)
            end
            body_part=lookup_bodypart(wound.parts[0],unit,true)
        end
    end

    return string.format("%d. %s %s(%d)",list_id,body_part,name,wound.id)
end
function editor_wounds:update_wounds()
    local ret={}
    for i, v in ipairs(self.trg_wounds) do
        table.insert(ret,{text=format_wound(i, v,self.target_unit),wound=v})
    end
    self.subviews.wounds:setChoices(ret)
end
function editor_wounds:dirty_unit()
    self.target_unit.flags2={calculated_nerves=false,calculated_bodyparts=false,calculated_insulation=false}
    --[=[
        FIXME(warmist): testing required, this might be not enough:
            * look into body.body_plan.flags
            * all the "good" flags
        worked kindof okay so maybe not?
    --]=]
end
function editor_wounds:get_cur_wound()
    local list_wid=self.subviews.wounds
    local _,choice=list_wid:getSelected()
    if choice==nil then
        qerror("Nothing selected")
    end
    local ret_wound=utils.binsearch(self.trg_wounds,choice.id,"id")
    return choice,ret_wound
end
function editor_wounds:delete_current_wound(index,choice)

    utils.erase_sorted(self.trg_wounds,choice.wound,"id")
    choice.wound:delete()
    self:dirty_unit()
    self:update_wounds()
end
function editor_wounds:create_new_wound()
    print("Creating")
end
function editor_wounds:edit_cur_wound(index,choice)

end
function editor_wounds:init( args )
    if self.target_unit==nil then
        qerror("invalid unit")
    end
    self.trg_wounds=self.target_unit.body.wounds

    self:addviews{
    widgets.List{

        frame = {t=0, b=1,l=1},
        view_id="wounds",
        on_submit=self:callback("edit_cur_wound"),
        on_submit2=self:callback("delete_current_wound")
    },
    widgets.Label{
                frame = { b=0,l=1},
                text ={{text= ": exit editor ",
                    key  = "LEAVESCREEN",
                    on_activate= self:callback("dismiss")},

                    --[[ TODO(warmist): implement this and the create_new_wound
                    {text=": edit wound ",
                    key = "SELECT"},]]

                    {text=": delete wound ",
                    key = "SEC_SELECT"},
                    --[[{text=": create wound ",
                    key = "CUSTOM_CTRL_I",
                    on_activate= self:callback("create_new_wound")},]]
                    }
            },
        }
    self:update_wounds()
end
add_editor(editor_wounds)
---------------------------------------------------------
editor_attrs = defclass(editor_attrs, gui.FramedScreen)
editor_attrs.ATTRS = {
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Attribute editor",
    target_unit = DEFAULT_NIL,
}
function format_attr( name ,max_len)
    local n=name
    n=n:gsub("_"," "):lower() --"_" to " " and lower case
    n=n .. string.rep(" ", max_len - #n+1) --pad to max_len+1 for nice columns
    n=n:gsub("^%l",string.upper) --uppercase first character
    return n
end
function list_attrs(unit)
    local m_attrs=unit.status.current_soul.mental_attrs
    local b_attrs=unit.body.physical_attrs
    local ret = {}
    local max_len=0
    for i,v in ipairs(df.mental_attribute_type) do
        if(max_len<#v) then
            max_len=#v
        end
    end
    for i,v in ipairs(df.physical_attribute_type) do
        if(max_len<#v) then
            max_len=#v
        end
    end
    for i,v in ipairs(m_attrs) do
        local attr_name=format_attr(df.mental_attribute_type[i],max_len)
        local text=string.format("%s: %d/%d",
            attr_name,v.value,v.max_value)
        table.insert(ret,{
            text=text,
            attr=v,
            attr_name=attr_name,
            search_key=text:lower()
        })
    end
    for i,v in ipairs(b_attrs) do
        local attr_name=format_attr(df.physical_attribute_type[i],max_len)
        local text=string.format("%s: %d/%d",
            attr_name,v.value,v.max_value)
        table.insert(ret,{
            text=text,
            attr=v,
            attr_name=attr_name,
            search_key=text:lower()
        })
    end
    return ret
end
function editor_attrs:update_list(no_save_place)
    local attr_list=list_attrs(self.target_unit)
    if no_save_place then
        self.subviews.attributes:setChoices(attr_list)
    else
        self.subviews.attributes:setChoices(attr_list,self.subviews.attributes:getSelected())
    end
end

function editor_attrs:init( args )
    if self.target_unit.status.current_soul==nil then
        qerror("Unit does not have soul, can't edit mental attributes")
    end

    local attr_list=list_attrs(self.target_unit)

    self:addviews{
        widgets.FilteredList{
            choices=attr_list,
            frame = {t=0, b=1,l=1},
            view_id="attributes",
        },
        widgets.Label{
            frame = { b=0,l=1},
            text ={{text= ": exit editor ",
                key  = "LEAVESCREEN",
                on_activate= self:callback("dismiss")
                },
                {text=": set max attribute ",
                key = "SEC_SELECT",
                on_activate= function (  )
                    local a,a_name=self:get_cur_attr()
                    dialog.showInputPrompt(a_name,"Enter new max value:",COLOR_WHITE,
                    tostring(a.max_value),function(new_value)
                        a.max_value=new_value
                        self:update_list()
                    end)
                end
                },
                {text=": set attribute ",
                key = "SELECT",
                on_activate= function (  )
                    local a,a_name=self:get_cur_attr()
                    dialog.showInputPrompt(a_name,"Enter new value:",COLOR_WHITE,
                    tostring(a.value),function(new_value)
                        a.value=new_value
                        self:update_list()
                    end)
                end
                }
            }
        },
    }
end
function editor_attrs:get_cur_attr()
    local list_wid=self.subviews.attributes
    local _,choice=list_wid:getSelected()
    if choice==nil then
        qerror("Nothing selected")
    end
    return choice.attr,choice.attr_name
end
function editor_attrs:remove_rust(attr)
    --TODO
    attr.unused_counter=0;
    attr.soft_demotion =0;
    attr.rust_counter=0;
    attr.demotion_counter=0;
end
add_editor(editor_attrs)

-- Orientation editor
editor_orientation=defclass(editor_orientation,gui.FramedScreen)
editor_orientation.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Orientation editor",
    target_unit = DEFAULT_NIL,
}

function editor_orientation:sexSelected(index, choice)
  local newInterest = choice.interest + 1
  -- Cycle back around if out of bounds
  if newInterest > 2 then
    newInterest = 0
  end

  setorientation.setOrientation(self.target_unit, choice.sex, newInterest)
  self:updateChoices()
end

function editor_orientation:random()
  local index, choice = self.subviews.sex:getSelected()

  setorientation.randomiseOrientation(self.target_unit, choice.sex)
  self:updateChoices()
end

function editor_orientation:updateChoices()
  local choices = {}
  -- Male
  local maleInterest = setorientation.getInterest(self.target_unit, "male")
  local maleInterestString = setorientation.getInterestString(maleInterest)
  table.insert(choices, {text = "Male: " .. maleInterestString, interest = maleInterest, sex = 1})
  -- Female
  local femaleInterest = setorientation.getInterest(self.target_unit, "female")
  local femaleInterestString = setorientation.getInterestString(femaleInterest)
  table.insert(choices, {text = "Female: " .. femaleInterestString, interest = femaleInterest, sex = 0})

  self.subviews.sex:setChoices(choices)
end

function editor_orientation:init(args)
  if self.target_unit == nil then
    qerror("invalid unit")
  end

  self:addviews{
    widgets.List{
      frame = {t=0, b=1,l=1},
      view_id = "sex",
      on_submit = self:callback("sexSelected"),
    },
    widgets.Label{
      frame = {b=0, l=1},
      text = {
        {text = ": exit editor ", key = "LEAVESCREEN", on_activate = self:callback("dismiss")},
        {text = ": cycle selected ", key = "SELECT"},
        {text = ": randomise selected", key = "CUSTOM_R", on_activate = self:callback("random")},
      },
    }
  }

  self:updateChoices()
end
add_editor(editor_orientation)

-- Body / Body Part editor
-- TODO: Trigger recalculation of body sizes after size is edited

editor_body_modifier=defclass(editor_body_modifier, gui.FramedScreen)

function showModifierScreen(target_unit, partChoice)
  editor_body_modifier{
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Select a modifier",
    target_unit = target_unit,
    partChoice = partChoice
  }:show()
end

function editor_body_modifier:beautifyString(text)
  local out = text
  out = out:lower() --Make lowercase
  out = out:gsub("_", " ") --Replace underscores with spaces
  out = out:gsub("^%l", string.upper) --capitalises first letter

  return out
end

function editor_body_modifier:setPartModifier(indexList, value)
  for _, index in ipairs(indexList) do
    self.target_unit.appearance.bp_modifiers[index] = tonumber(value)
  end
  self:updateChoices()
end

function editor_body_modifier:setBodyModifier(modifierIndex, value)
  self.target_unit.appearance.body_modifiers[modifierIndex] = tonumber(value)
  self:updateChoices()
end

function editor_body_modifier:selected(index, selected)
  dialog.showInputPrompt(
    self:beautifyString(df.appearance_modifier_type[selected.modifier.entry.type]),
    "Enter new value:",
    nil,
    tostring(selected.value),
    function(newValue)
      local value = tonumber(newValue)
      if self.partChoice.type == "part" then
        self:setPartModifier(selected.modifier.idx, value)
      else -- Body
        self:setBodyModifier(selected.modifier.index, value)
      end
    end,
    nil,nil
  )
end

function editor_body_modifier:random()
  local _, selected = self.subviews.modifiers:getSelected()
  -- How modifier randomisation works (to my knowledge):
  -- 7 values are listed in the _APPEARANCE_MODIFIER token
  -- One of the first 6 values is randomly selected with the same odds for any
  -- A random number is rolled within the range of that number, and the next one to get the modifier value

  local startIndex = rng:random(6) -- Will give a number between 0-5 which, when accounting for the fact that the range table starts at 0, gives us the index of which of the first 6 to use

  -- Set the ranges
  local min = selected.modifier.entry.ranges[startIndex]
  local max = selected.modifier.entry.ranges[startIndex+1]

  -- Get the difference between the two
  local difference = math.abs(min - max)

  -- Use the minimum, the difference, and a random roll to work out the new value.
  local roll = rng:random(difference+1) -- difference + 1 because we want to include the max value as an option
  local value = min + roll

  -- Set the modifier to the new value
  if self.partChoice.type == "part" then
    self:setPartModifier(selected.modifier.idx, value)
  else
    self:setBodyModifier(selected.modifier.index, value)
  end
end

function editor_body_modifier:step(amount)
  local _, selected = self.subviews.modifiers:getSelected()

  -- Build a table of description ranges
  local ranges = {}
  for index, value in ipairs(selected.modifier.entry.desc_range) do
    -- Only add a new entry if: There are none, or the value is higher than the previous range
    if #ranges == 0 or value > ranges[#ranges] then
      table.insert(ranges, value)
    end
  end

  -- Now determine what range the modifier currently falls into
  local currentValue = selected.value
  local rangeIndex

  for index, value in ipairs(ranges) do
    if ranges[index+1] then -- There's still a next entry
      if currentValue < ranges[index+1] then -- The current value is less than the next entry
        rangeIndex = index
        break
      end
    else -- This is the last entry
      rangeIndex = index
    end
  end

  -- Finally, move the modifier's value up / down in range tiers based on given amount
  local newTier = math.min(#ranges, math.max(1, rangeIndex + amount)) -- Clamp values to not go beyond bounds of ranges
  local newValue = ranges[newTier]

  if self.partChoice.type == "part" then
    self:setPartModifier(selected.modifier.idx, newValue)
  else
    self:setBodyModifier(selected.modifier.index, newValue)
  end
end

function editor_body_modifier:updateChoices()
  local choices = {}

  for index, modifier in ipairs(self.partChoice.modifiers) do
    local currentValue
    if self.partChoice.type == "part" then
      currentValue = self.target_unit.appearance.bp_modifiers[modifier.idx[1]]
    else -- Body
      currentValue = self.target_unit.appearance.body_modifiers[modifier.index]
    end
    table.insert(choices, {text = self:beautifyString(df.appearance_modifier_type[modifier.entry.type]) .. ": " .. currentValue, value = currentValue, modifier = modifier})
  end

  self.subviews.modifiers:setChoices(choices)
end

function editor_body_modifier:init(args)
  self.target_unit = args.target_unit
  self.partChoice = args.partChoice

  self:addviews{
    widgets.List{
      frame = {t=0, b=1,l=1},
      view_id = "modifiers",
      on_submit = self:callback("selected"),
    },
    widgets.Label{
      frame = {b=0, l=1},
      text = {
        {text = ": back ", key = "LEAVESCREEN", on_activate = self:callback("dismiss")},
        {text = ": edit modifier ", key = "SELECT"},
        {text = ": raise ", key = "CURSOR_RIGHT", on_activate = self:callback("step", 1)},
        {text = ": reduce ", key = "CURSOR_LEFT", on_activate = self:callback("step", -1)},
        {text = ": randomise selected", key = "CUSTOM_R", on_activate = self:callback("random")},
      },
    }
  }

  self.frame_title = self.partChoice.text .. " - Select a modifier"
  self:updateChoices()
end

editor_body=defclass(editor_body,gui.FramedScreen)
editor_body.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Body appearance editor",
    target_unit = DEFAULT_NIL,
}

function makePartList(caste)
  local list = {}
  local lookup = {} -- Stores existing part's index in the list

  for index, modifier in ipairs(caste.bp_appearance.modifiers) do
    local name
    if modifier.noun ~= "" then
      name = modifier.noun
    else
      name = caste.body_info.body_parts[modifier.body_parts[0]].name_singular[0].value -- Use the name of the first body part modified
    end

    -- Make a new entry if this is a new part
    if lookup[name] == nil then
      local entryIndex = #list + 1
      table.insert(list, {name = name, modifiers = {}})
      lookup[name] = entryIndex
    end

    -- Find idxes associated with this modifier. These are what will be used later when setting the unit's appearance
    local idx = {}
    for searchIndex, modifierId in ipairs(caste.bp_appearance.modifier_idx) do
      if modifierId == index then
        table.insert(idx, searchIndex)
      end
    end

    -- Add modifiers to list of part
    table.insert(list[lookup[name]].modifiers, {index = index, entry = modifier, idx = idx})
  end

  return list
end

function editor_body:updateChoices()
  local choices = {}
  local caste = df.creature_raw.find(self.target_unit.race).caste[self.target_unit.caste]

  -- Body is a special case
  if #caste.body_appearance_modifiers > 0 then
    local bodyEntry = {text = "Body", modifiers = {}, type = "body"}
    for index, modifier in ipairs(caste.body_appearance_modifiers) do
      table.insert(bodyEntry.modifiers, {index = index, entry = modifier})
    end
    table.insert(choices, bodyEntry)
  end

  local partList = makePartList(caste)
  for index, partEntry in ipairs(partList) do
    table.insert(choices, {text = partEntry.name:gsub("^%l", string.upper), modifiers = partEntry.modifiers, type = "part"})
  end

  self.subviews.featureSelect:setChoices(choices)
end

function editor_body:partSelected(index, choice)
  showModifierScreen(self.target_unit, choice)
end

function editor_body:init(args)
  if self.target_unit == nil then
    qerror("invalid unit")
  end

  self:addviews{
    widgets.List{
      frame = {t=0, b=1,l=1},
      view_id = "featureSelect",
      on_submit = self:callback("partSelected"),
    },
    widgets.Label{
      frame = {b=0, l=1},
      text = {
        {text = ": exit editor ", key = "LEAVESCREEN", on_activate = self:callback("dismiss")},
        {text = ": select feature ", key = "SELECT"},
      },
    }
  }

  self:updateChoices()
end
add_editor(editor_body)


-- Colors editor
editor_colors=defclass(editor_colors,gui.FramedScreen)
editor_colors.ATTRS={
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Colors editor",
    target_unit = DEFAULT_NIL,
}

function patternString(patternId)
  local pattern = df.descriptor_pattern.find(patternId)
  local prefix
  if pattern.pattern == 0 then --Monochrome
    return df.descriptor_color.find(pattern.colors[0]).name
  elseif pattern.pattern == 1 then --Stripes
    prefix = "striped"
  elseif pattern.pattern == 2 then --Iris_eye
    return df.descriptor_color.find(pattern.colors[2]).name .. " eyes"
  elseif pattern.pattern == 3 then --Spots
    prefix = "spotted" --that's a guess
  elseif pattern.pattern == 4 then --Pupil_eye
    return df.descriptor_color.find(pattern.colors[2]).name .. " eyes"
  elseif pattern.pattern == 5 then --mottled
    prefix = "mottled"
  end
  local out = prefix .. " "
  for i=0, #pattern.colors-1 do
    if i == #pattern.colors-1 then
      out = out .. "and " .. df.descriptor_color.find(pattern.colors[i]).name
    elseif i == #pattern.colors-2 then
      out = out .. df.descriptor_color.find(pattern.colors[i]).name .. " "
    else
      out = out .. df.descriptor_color.find(pattern.colors[i]).name .. ", "
    end
  end
  return out
end

function editor_colors:random()
  local featureChoiceIndex, featureChoice = self.subviews.features:getSelected() -- This is the part / feature that's selected
  local caste = df.creature_raw.find(self.target_unit.race).caste[self.target_unit.caste]

  -- Nil check in case there are no features
  if featureChoiceIndex == nil then
    return
  end

  local options = {}

  for index, patternId in ipairs(featureChoice.mod.pattern_index) do
    local addition = {}
    addition.patternId = patternId
    addition.index = index -- This is the position of the pattern within the modifier index. It's this value (not the pattern ID), that's used in the unit appearance to select their color
    addition.weight = featureChoice.mod.pattern_frequency[index]
    table.insert(options, addition)
  end

  -- Now create a table from this to use for the weighted roller
  -- We'll use the index as the item appears in options for the id
  local weightedTable = {}
  for index, entry in ipairs(options) do
    local addition = {}
    addition.id = index
    addition.weight = entry.weight
    table.insert(weightedTable, addition)
  end

  -- Roll randomly. The result will give us the index of the option to use
  local result = weightedRoll(weightedTable)

  -- Set the unit's appearance for the feature to the new pattern
  self.target_unit.appearance.colors[featureChoice.index] = options[result].index

  -- Notify the user on the change, so they get some visual feedback that something has happened
  local pluralWord
  if featureChoice.mod.unk_6c == 1 then
    pluralWord = "are"
  else
    pluralWord = "is"
  end

  dialog.showMessage("Color randomised!",
    featureChoice.text .. " " .. pluralWord .." now " .. patternString(options[result].patternId),
    nil, nil)
end

function editor_colors:colorSelected(index, choice)
  -- Update the modifier for the unit
  self.target_unit.appearance.colors[self.modIndex] = choice.index
end

function editor_colors:featureSelected(index, choice)
  -- Store the index of the modifier we're editing
  self.modIndex = choice.index

  -- Generate color choices
  local colorChoices = {}

  for index, patternId in ipairs(choice.mod.pattern_index) do
    table.insert(colorChoices, {text = patternString(patternId), index = index})
  end

  dialog.showListPrompt(
    "Choose color",
    "Select feature's color", nil,
    colorChoices,
    function(selectIndex, selectChoice)
      self:colorSelected(selectIndex, selectChoice)
    end,
    nil, nil,
    true
  )
end

function editor_colors:updateChoices()
  local caste = df.creature_raw.find(self.target_unit.race).caste[self.target_unit.caste]
  local choices = {}
  for index, colorMod in ipairs(caste.color_modifiers) do
    table.insert(choices, {text = colorMod.part:gsub("^%l", string.upper), mod = colorMod, index = index})
  end

  self.subviews.features:setChoices(choices)
end

function editor_colors:init(args)
  if self.target_unit == nil then
    qerror("invalid unit")
  end

  self:addviews{
    widgets.List{
      frame = {t=0, b=1,l=1},
      view_id = "features",
      on_submit = self:callback("featureSelected"),
    },
    widgets.Label{
      frame = {b=0, l=1},
      text = {
        {text = ": exit editor ", key = "LEAVESCREEN", on_activate = self:callback("dismiss")},
        {text = ": edit feature ", key = "SELECT"},
        {text = ": randomise color", key = "CUSTOM_R", on_activate = self:callback("random")},
      },
    }
  }

  self:updateChoices()
end
add_editor(editor_colors)

-- Belief editor
editor_belief = defclass(editor_belief, gui.FramedScreen)
editor_belief.ATTRS = {
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Belief editor",
    target_unit = DEFAULT_NIL,
}

function editor_belief:randomiseSelected()
  local index, choice = self.subviews.beliefs:getSelected()

  setbelief.randomiseUnitBelief(self.target_unit, choice.belief)
  self:updateChoices()
end

function editor_belief:step(amount)
  local index, choice = self.subviews.beliefs:getSelected()

  setbelief.stepUnitBelief(self.target_unit, choice.belief, amount)
  self:updateChoices()
end

function editor_belief:updateChoices()
  local choices = {}

  for index, belief in ipairs(df.value_type) do
    if belief ~= 'NONE' then
      local niceText = belief
      niceText = niceText:lower()
      niceText = niceText:gsub("_", " ")
      niceText = niceText:gsub("^%l", string.upper)

      local strength = setbelief.getUnitBelief(self.target_unit, index)
      local symbolAddition = ""
      if setbelief.isCultureBelief(self.target_unit, index) then
        symbolAddition = "*"
      end

      table.insert(choices, {["text"] = niceText .. ": " .. strength .. symbolAddition, ["belief"] = index, ["value"] = strength, ["name"] = niceText})
    end
  end

  self.subviews.beliefs:setChoices(choices)
end

function editor_belief:average(index, choice)
  setbelief.removeUnitBelief(self.target_unit, choice.belief)
  self:updateChoices()
end

function editor_belief:edit(index, choice)
  dialog.showInputPrompt(
    choice.name,
    "Enter new value:",
    COLOR_WHITE,
    tostring(choice.value),
    function(newValue)
      setbelief.setUnitBelief(self.target_unit, choice.belief, tonumber(newValue), true)
      self:updateChoices()
    end
  )
end

function editor_belief:close()
  setneed.rebuildNeeds(self.target_unit)
  self:dismiss()
end

function editor_belief:init(args)
  if self.target_unit==nil then
      qerror("invalid unit")
  end

  self:addviews{
    widgets.List{
      frame = {t=0, b=2,l=1},
      view_id = "beliefs",
      on_submit = self:callback("edit"),
      on_submit2 = self:callback("average")
    },
    widgets.Label{
      frame = {b=1, l=1},
      text = {
        {text = ": exit editor ", key = "LEAVESCREEN", on_activate = self:callback("close")},
        {text = ": edit value ", key = "SELECT"},
        {text = ": randomise selected ", key = "CUSTOM_R", on_activate = self:callback("randomiseSelected")},
        {text = ": raise ", key = "CURSOR_RIGHT", on_activate = self:callback("step", 1)},
        {text = ": reduce", key = "CURSOR_LEFT", on_activate = self:callback("step", -1)},
      },
    },
    widgets.Label{
      frame = {b = 0, l = 1},
      text = {
        {text = "* denotes cultural default "},
        {text = ": set to cultural default", key = "SEC_SELECT"}
      }
    },
  }

  self:updateChoices()
end
add_editor(editor_belief)


-- Personality editor
editor_personality = defclass(editor_personality, gui.FramedScreen)
editor_personality.ATTRS = {
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "Personality editor",
    target_unit = DEFAULT_NIL,
}

function editor_personality:randomiseSelected()
  local index, choice = self.subviews.traits:getSelected()

  setpersonality.randomiseUnitTrait(self.target_unit, choice.trait)
  self:updateChoices()
end

function editor_personality:step(amount)
  local index, choice = self.subviews.traits:getSelected()

  setpersonality.stepUnitTrait(self.target_unit, choice.trait, amount)
  self:updateChoices()
end

function editor_personality:updateChoices()
  local choices = {}

  for index, traitName in ipairs(df.personality_facet_type) do
    if traitName ~= 'NONE' then
      local niceText = traitName
      niceText = niceText:lower()
      niceText = niceText:gsub("_", " ")
      niceText = niceText:gsub("^%l", string.upper)

      local strength = setpersonality.getUnitTraitBase(self.target_unit, index)

      table.insert(choices, {["text"] = niceText .. ": " .. strength, ["trait"] = index, ["value"] = strength, ["name"] = niceText})
    end
  end

  self.subviews.traits:setChoices(choices)
end

function editor_personality:averageTrait(index, choice)
  setpersonality.averageUnitTrait(self.target_unit, choice.trait)
  self:updateChoices()
end

function editor_personality:editTrait(index, choice)
  dialog.showInputPrompt(
    choice.name,
    "Enter new value:",
    COLOR_WHITE,
    tostring(choice.value),
    function(newValue)
      setpersonality.setUnitTrait(self.target_unit, choice.trait, tonumber(newValue))
      self:updateChoices()
    end
  )
end

function editor_personality:close()
  setneed.rebuildNeeds(self.target_unit)
  self:dismiss()
end

function editor_personality:init(args)
  if self.target_unit==nil then
      qerror("invalid unit")
  end

  self:addviews{
    widgets.List{
      frame = {t=0, b=2,l=1},
      view_id = "traits",
      on_submit = self:callback("editTrait"),
      on_submit2 = self:callback("averageTrait")
    },
    widgets.Label{
      frame = {b=1, l=1},
      text = {
        {text = ": exit editor ", key = "LEAVESCREEN", on_activate = self:callback("close")},
        {text = ": edit value ", key = "SELECT"},
        {text = ": randomise selected ", key = "CUSTOM_R", on_activate = self:callback("randomiseSelected")},
        {text = ": raise ", key = "CURSOR_RIGHT", on_activate = self:callback("step", 1)},
        {text = ": reduce", key = "CURSOR_LEFT", on_activate = self:callback("step", -1)},
      },
    },
    widgets.Label{
      frame = {b = 0, l = 1},
      text = {
        {text = ": set to caste average", key = "SEC_SELECT"}
      }
    },
  }

  self:updateChoices()
end
add_editor(editor_personality)

-------------------------------main window----------------
unit_editor = defclass(unit_editor, gui.FramedScreen)
unit_editor.ATTRS = {
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = "GameMaster's unit editor",
    target_unit = DEFAULT_NIL,
}


function unit_editor:init(args)
    self:addviews{
        widgets.FilteredList{
            frame = {l=1, t=1},
            choices=editors,
            on_submit=function (idx,choice)
                if choice.on_submit then
                    choice.on_submit(self.target_unit)
                end
            end
        },
        widgets.Label{
            frame = { b=0,l=1},
            text = {{
                text = ": exit editor",
                key = "LEAVESCREEN",
                on_activate = self:callback("dismiss")
            }},
        }
    }
end


unit_editor{target_unit=target}:show()
