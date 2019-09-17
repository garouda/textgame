local st = {}
local newScroller = require("elements.scroller")
local newDropdown = require("elements.dropdown")

local base = {}
base.stats={
  x=30, y=screen_height/7, w=screen_width/5, h=screen_height-screen_height/3,
}
base.description={
  x=base.stats.x+base.stats.w+15, y=screen_height/8, w=screen_width-(base.stats.x+base.stats.w)-15-30, h=screen_height-screen_height/3
}
--
local desc
local slide = {x=0, y=0}
local lerping
local buttons = {}
local alt_buttons = {}
local ally_selected = 0
local scroller
local dropdown
local mode
local mode_ind
local allocated = {}
local curr_points, base_points = 0, 0

local ent

local bar = lg.newImage("res/img/inv_bar.png")
local description_icon = lg.newImage("res/img/papers.png")
local attribute_icon = lg.newImage("res/img/arrors.png")
local party_icon = lg.newImage("res/img/placeholder icon.png")
local skills_icon = lg.newImage("res/img/skills_icon.png")
local points_reminder = {
  alpha = 1, 
  img = lg.newImage("res/img/browser_newfile.png"),
}

local FONT_ = {
  fonts.stats_title,
  fonts.stats_description,
  fonts.stats_numbers,
  fonts.stats_small,
  fonts.debug,
  fonts.files_sub,
  fonts.stats_mode,
}

local function allocate(stat,amount)
  if amount > 0 and (curr_points == 0 or __.reduce(allocated, 0, function(memo,i,v) return memo+v end)==ent.points) then return
  elseif amount < 0 and (not allocated[stat] or allocated[stat] == 0) then return
  elseif amount == 0 then if (allocated[stat] or 0)+ent.stat[stat:lower()]>=99 then return true else return false end end

  allocated[stat]=math.max(0, (allocated[stat] or 0) + amount)
  curr_points = math.max(0, curr_points - amount)
  if allocated[stat] == 0 then allocated[stat] = nil end
end
--

local function small_hp(ent,x,y,w,h,a)
  a = a or 1
  local width = math.max(0,w*(ent.hp/ent:getStat("max_hp")))
  lg.setLineWidth(1)
  lg.setFont(FONT_[5])
  -- Background
  lg.setColor(0.3,0.2,0.2,a*1)
  lg.rectangle("fill",x,y,w,h)
  -- The red part, display HP with no lerping
  lg.setColor(0.55,0.2,0.2,a*1)
  lg.rectangle("fill",x,y,width,h)
  -- Subtle top and bottom lines, for definition
  lg.setColor(1,1,1,a*0.3)
  lg.line(x,y,x+width,y)
  lg.setColor(0.1,0.1,0.2,a*0.6)
  lg.line(x,y+h,x+width,y+h)
  for o=-2,2,4 do
    lg.setColor(0,0,0,a*0.5)
    lg.printf("HP: "..ent.hp.."/"..ent:getStat("max_hp"), x+o,y+1, w, "center")
    lg.printf("HP: "..ent.hp.."/"..ent:getStat("max_hp"), x,y+1+o, w, "center")
  end
  lg.setColor(1,1,1,a*0.9)
  lg.printf("HP: "..ent.hp.."/"..ent:getStat("max_hp"), x,y+1, w, "center")
end
--
local function _ally_bar(ent,x,y,w,h,a)
  a = a or 1
  local main_col = {0.85,0.55,0.6,a*1}
  lg.setColor(main_col)
  lg.push() lg.translate(16+5,0) w = w-(16+5)
  local width = 0
  lg.setLineWidth(1)
  -- Background
  lg.setColor(0.9,0.75,0.8,a*0.45)
  lg.rectangle("line",x,y,w,h,5)
  lg.setColor(0.25,0.125,0.175,a*1)
  lg.rectangle("fill",x,y,w,h,5)
  -- Main bar
  lg.setColor(main_col)
  if width > 1 then
    lg.rectangle("fill",x,y,width,h,5)
    -- Subtle top and bottom lines, for definition
    lg.setColor(1,1,1,a*0.3)
    lg.line(x+3,y+1,x+width-3,y+1)
    lg.setColor(0.1,0.1,0.2,a*0.6)
    lg.line(x+3,y+h-1,x+width-3,y+h-1)
  end
  lg.pop()
end
--

local function statbox(alpha)
  -- Stats box
  local offset = 0
  alpha = alpha or 1
  lg.setColor(1,1,1,1*alpha)
  lg.setFont(FONT_[3])
  lg.printf(ent.name,base.stats.x+15,base.stats.y+offset,base.stats.w,"center")
  offset = offset + FONT_[3]:getHeight()
  lg.setColor(1,1,1,0.8*alpha)
  lg.setFont(FONT_[7])
  lg.printf("Level",base.stats.x+45,base.stats.y+offset,base.stats.w,"left")
  lg.setColor(1,0.75,0.2,1*alpha)
  lg.setFont(FONT_[3])
  lg.printf(ent.lvl,base.stats.x,base.stats.y+offset-3,base.stats.w-15,"right")
  offset = offset + FONT_[3]:getHeight() + 5

  lg.setColor(1,1,1,0.4*alpha)
  lg.setLineWidth(3)
  lg.line(base.stats.x+30,base.stats.y+offset,base.stats.x+base.stats.w,base.stats.y+offset)
  lg.setColor(1,0.75,0.2,1*alpha)
  lg.line(base.stats.x+30,base.stats.y+offset,base.stats.x+30+((base.stats.w-30)*(ent.exp/ent:expToLevelUp())),base.stats.y+offset)
  lg.setColor(1,1,1,1*alpha)
  lg.line(base.stats.x+30+((base.stats.w-30-6)*(ent.exp/ent:expToLevelUp())),base.stats.y+offset,base.stats.x+30+((base.stats.w-30-6)*(ent.exp/ent:expToLevelUp()))+6,base.stats.y+offset)
  offset = offset + 15

  small_hp(ent,base.stats.x+25,base.stats.y+offset,base.stats.w-20,16,alpha)
  offset = offset + FONT_[3]:getHeight()

  for i,v in pairs{"ATK","MAG","DEF","STR","INT","AGI","CON","LUK"} do
    if allocated[v] then lg.setColor(0.5,1,0.5,0.9*alpha) else lg.setColor(1,1,1,0.9*alpha) end
    lg.setFont(FONT_[7])
    lg.print(v.." :",base.stats.x+30,base.stats.y+offset)
    local orig = ent.stat[v:lower()]
    local boost = ent:getStat(v:lower())-orig
    local total = orig+boost+(allocated[v:upper()] or 0)
    if boost ~= 0 then if boost > 0 then boost = "+"..boost end boost = " ("..boost..")" else boost = "" end
    if i <=2 then boost = nil end
    lg.setFont(FONT_[4])
    lg.printf(total..(boost or ""),base.stats.x+30,base.stats.y+offset,base.stats.w-25,"right")
    offset = offset + FONT_[4]:getHeight()
    if i==3 then
      lg.setColor(1,1,1,0.5*alpha)
      lg.setLineWidth(1)
      offset = offset + 10
      Misc.fadeline(base.stats.x+30, base.stats.y+offset, nil, base.stats.w-30, 1)
      offset = offset + 10
    end
  end
end
--

local function generate_buttons()
  local x, pad = screen_width/4+52-5, description_icon:getWidth()+30
  local cols = {fg={{1,1,1,0.5},{1,1,1,1},{1,1,1,0.35}},bg={{0,0,0,0.7},{0.1,0.1,0.1,0.7},{0,0,0,0.7}}}
  buttons = {}
  buttons.Return = newButton("Return", function() st.prep_leave() end, 60, screen_height-screen_height/6.5, 125, 50)
--  buttons["?"] = newButton("?", function() Misc.tutorial("stats_"..mode_ind) end, screen_width-30-15, screen_height-30-15, 30,30)
  buttons["?"] = newButton("?", function() Misc.tutorial("stats_"..mode_ind) end, screen_width-30-15, base.description.y+base.description.h+15, 30,30)
  if ent==player then
    table.insert(buttons, newButton(description_icon, function() st.setMode(1) end, x+pad*#buttons, screen_height-screen_height/6.5, nil, nil, {cols=cols,tip="View character description"}))
    table.insert(buttons, newButton(attribute_icon, function() st.setMode(2) end, x+pad*#buttons, screen_height-screen_height/6.5, nil, nil, {cols=cols,tip="Adjust character attributes"}))
  end
  table.insert(buttons, newButton(party_icon, function() st.setMode(3) end, x+pad*#buttons, screen_height-screen_height/6.5, nil, nil, {cols=cols,tip="Manage allies"}))
  table.insert(buttons, newButton(skills_icon, function() st.setMode(4) end, x+pad*#buttons, screen_height-screen_height/6.5, nil, nil, {cols=cols,tip="Review skills"}))
end
--

local ent_swap = {x_off=0,alpha=1,canvas=nil}
local function change_ent(e)
  ent_swap.x_off = base.stats.w
  ent_swap.alpha = 0
  ent_swap.canvas = nil
  collectgarbage()
  ent_swap.canvas = lg.newCanvas(screen_width,screen_height)
  ent_swap.canvas:renderTo(statbox)
  ent = e or player
  st:enter()
  buttons.Return:set_label(ent~=player and " Finish" or "Return")
  st.setMode(3)
end
--

function st:init()
  alt_buttons = {}
  scroller = newScroller(0, 0, 0, 0, 0, 0)
end
--
function st:enter()
  lerping = true
  ent = ent or player
  dropdown = newDropdown({}, function() end)
  slide.tween = Flux.to(slide, 0.3, {x=-screen_width-1}):ease("quadout")
  Timer.after(0.3, function() lerping = false end)
  local src = (out.load(ent.species:lower(),{"descriptions/","res/text/descriptions/"}) or {})
  local prev_src = process.getSrc()
  process.setSrc(src)
  desc = process(src[1] or "No description.",ent)
  process.setSrc(prev_src)
  allocated = {}
  curr_points = ent.points
  base_points = ent.points
  generate_buttons()
  ent_swap.canvas = nil
  collectgarbage()
  ent_swap.canvas = lg.newCanvas(screen_width,screen_height)
  ent_swap.canvas:renderTo(statbox)
  st.setMode(1)
end
--
function st:update(dt)
  ent_swap.x_off = Misc.lerp(12*dt, ent_swap.x_off, 0)
  ent_swap.alpha = Misc.lerp(10*dt, ent_swap.alpha, 1)
  if lerping then
    love.mouse.isDown = function()
      return false
    end
  end
  
  points_reminder.alpha = (points_reminder.alpha - 1 * dt)
  if points_reminder.alpha < 0.33 then points_reminder.alpha = 1 end
  
  if prompt.box.visible then return end

  mode.update(dt)

  scroller:update(dt)
  dropdown:update(dt)

  local mx,my = Misc.getMouseScaled()

  for i,v in pairs(buttons) do
    v:update(dt)
  end


  if Misc.checkPoint(mx,my, base.stats.x+30,base.stats.y+FONT_[3]:getHeight(),base.stats.w-30,FONT_[3]:getHeight()+12) then
    event.grant("show_tooltip", "EXP: "..math.round(ent.exp/ent:expToLevelUp()*100,2).."% ("..ent.exp.."/"..ent:expToLevelUp()..")")
  elseif Misc.checkPoint(mx,my, base.stats.x+30,base.stats.y+FONT_[3]:getHeight()*2+FONT_[4]:getHeight()*2+2,base.stats.w-30,FONT_[4]:getHeight()) then
    event.grant("show_tooltip", "Damage: "..ent:attack(nil,{nocrit=true,min=true,get_only=true}).."~"..ent:attack(nil,{nocrit=true,max=true,get_only=true}))
  elseif Misc.checkPoint(mx,my, base.stats.x+30,base.stats.y+FONT_[3]:getHeight()*2+FONT_[4]:getHeight()*3+2,base.stats.w-30,FONT_[4]:getHeight()) then
    event.grant("show_tooltip", "Magic Ability: "..ent:attack(nil,{nocrit=true,min=true,magic=true,get_only=true}))
  elseif Misc.checkPoint(mx,my, base.stats.x+30,base.stats.y+FONT_[3]:getHeight()*2+FONT_[4]:getHeight()*4+2,base.stats.w-30,FONT_[4]:getHeight()) then
    local res = ""
    for i,v in pairs(ent.stat.resistance) do res = res..Misc.capitalize(i).." Resist: "..ent:getStat("resistance",i)*(100).."%\n" end
    event.grant("show_tooltip", res)
  elseif Misc.checkPoint(mx,my, base.stats.x+30,base.stats.y+base.stats.h-28-FONT_[4]:getHeight()*3,base.stats.w-15,FONT_[4]:getHeight()) then
--    event.grant("show_tooltip", "Avoid: "..math.round(ent:getStat("avoid")).."%\n".."Crit Dmg: +"..math.round(ent:getStat("crit_damage")).."%")
    event.grant("show_tooltip", "Avoid Chance: "..math.round(ent:getStat("avoid")).."%\n".."Speed: "..math.round(ent:getStat("speed")))
  elseif Misc.checkPoint(mx,my, base.stats.x+30,base.stats.y+base.stats.h-28-FONT_[4]:getHeight()*1,base.stats.w-15,FONT_[4]:getHeight()) then
    event.grant("show_tooltip", "Crit Rate: "..math.round(ent:getStat("crit_rate")).."%\n".."Crit Dmg: +"..math.round(ent:getStat("crit_damage")).."%\n".."Bonus Item Chance: "..(ent:getStat("luk")*0.2).."%")
  end


  if base_points < ent.points then
    curr_points = curr_points + (ent.points-base_points)
    base_points = ent.points
  end
end
--
function st:draw()
  if slide.x > -screen_width and Gamestate.current() == states.stats then
    lg.push()
    lg.translate(slide.x,slide.y)
    states.game.draw()
    lg.pop()
  end
  lg.push()
  lg.translate(math.floor(slide.x+1)+screen_width,slide.y)

  bgimage.draw()

  lg.setColor(0,0,0,0.4)
  lg.rectangle("fill",0,base.description.y,screen_width, base.description.h)

  lg.setFont(FONT_[1])
  lg.setColor(1,1,1,0.7)
  lg.draw(bar)
  lg.setColor(1,1,1,0.35)
  lg.draw(bar,0,4)
  lg.setColor(1,1,1)
  lg.setFont(FONT_[1])
  lg.printf("Status", 0, 8, screen_width, "center")

  lg.stencil(function() lg.rectangle("fill", base.stats.x+15, base.stats.y, base.stats.w, base.stats.h) end, "replace", 1)
  lg.setStencilTest("equal", 1)
  lg.push() lg.translate(ent_swap.x_off)
  statbox(ent_swap.alpha)
  lg.translate(-base.stats.w)
  if ent_swap.x_off > 1 then
    lg.setColor(1,1,1,1-ent_swap.alpha)
    lg.draw(ent_swap.canvas)
  end
  lg.pop()
  lg.setStencilTest()

  lg.setColor(1,1,1,0.9)
  Misc.fadeline(base.description.x, base.description.y, math.pi/2, base.description.h, 1)
  lg.setColor(1,1,1,0.5)
  Misc.fadeline(0, base.description.y)
  Misc.fadeline(0, base.description.y+base.description.h)
  lg.setColor(0,0,0,0.5)
  lg.polygon("fill", screen_width*0.75,base.description.y, screen_width*0.8,30, screen_width,30, screen_width,base.description.y)
  lg.setColor(1,1,1,0.15)
  lg.polygon("line", screen_width*0.75,base.description.y, screen_width*0.8,30, screen_width,30, screen_width,base.description.y)

  lg.stencil(function() lg.rectangle("fill", base.description.x,base.description.y,base.description.w,base.description.h) end, "replace", 1)
  mode.draw()

  for i,v in ipairs(buttons) do
    lg.setColor(0,0,0,0.3)
    lg.rectangle("fill", v.x-4, v.y-4, v.w+8, v.h+8, 8)
    v:draw(nil, (v.param.inactive and 0.2) or 1)
    lg.setColor(1,1,1,0.4)
    lg.rectangle("line", v.x-4, v.y-4, v.w+8, v.h+8, 8)
    if i==2 and player.points>0 then
      local w, h = 10, 30
      lg.setColor(0.6,1,0.6,points_reminder.alpha)
      lg.draw(points_reminder.img, v.x+v.w-5, v.y+5, nil, nil, nil, points_reminder.img:getWidth()/2, points_reminder.img:getHeight()/2)
    end
  end
  buttons.Return:draw()
  buttons["?"]:draw()

  dropdown:draw()

  lg.setLineWidth(1)
  lg.pop()

  lg.setColor(1,1,1)
end
--

function st:prep_leave()
  local result = ""
  for i,v in pairs(allocated) do
    result = result.."\n"..i.." +"..v.." ("..ent.stat[i:lower()].."->"..ent.stat[i:lower()]+v..")"
  end
  local leave = function()
    allocated = {}
    lerping = true
    Flux.to(slide, 0.3, {x=0}):ease("quadout"):oncomplete(Gamestate.pop)
  end
  --
  if next(allocated) then
    prompt("Do you want to allocate these stats?"..result, {function()
          for i,v in pairs(allocated) do ent:incStat(i:lower(), v) end
          allocated = {}
          ent.points = curr_points
          base_points = ent.points
        end})
    return
  end
  if ent~=player then
    return prompt("Finish managing "..ent.name.." and return to "..player.name.."?", {change_ent})
  end
  leave()
end
--
function st:keypressed(key)
  if lerping then return end
  if key=="tab" then st.setMode() end
  if keyset.back(key) or keyset.stats(key) then
    self.prep_leave()
  end
  -- Directional keys aren't used in the Stats screen, so repurpose Up/Down for scrolling.
  scroller:keypressed(key,keyset.up(key) and "up" or keyset.down(key) and "down")
  if keyset.confirm(key) and next(allocated) then return self.prep_leave() end
end
--

function st:mousepressed(x,y,b,t)
  if lerping or prompt.box.visible then return end
  if dropdown:mousepressed(x,y,b) then return else dropdown.visible = false end
  if not dropdown.visible then
    if b==2 then return self.prep_leave() end
  end
  if not dropdown.visible then
    local r 
    for i,v in pairs(buttons) do if v:mousepressed(x,y,b) then return end end
    if Misc.checkPoint(x,y, {base.description.x, base.description.y, base.description.w, base.description.h}) then
      for i,v in pairs(alt_buttons) do if v:mousepressed(x,y,b,nil,scroller.y_offset) then r = true end end
    end
    if r then return end
  end
  ally_selected = 0
  scroller:checkArea(x,y, {base.description.x, base.description.y, base.description.w, base.description.h})
end
--
function st:mousereleased(x,y,b,t)
  if lerping or prompt.box.visible then return end
  local r
  dropdown:mousereleased(x,y,b)
  for i,v in pairs(buttons) do if v:mousereleased(x,y,b) then return end end
  for i,v in pairs(alt_buttons) do if v:mousereleased(x,y,b,nil,scroller.y_offset) then r = true end end
  if r then return end
end
--
function st:wheelmoved(x,y)
  if lerping or prompt.box.visible then return end
  if dropdown:wheelmoved(x,y) then return end
  scroller:wheelmoved(x,y)
end
--
function st:touchmoved(id,x,y,dx,dy)
  if lerping or prompt.box.visible then return end
  if dropdown:touchmoved(id,x,y,dx,dy) then return end
  for i,v in pairs(buttons) do v:touchmoved(id,x,y,dx,dy) end
  for i,v in pairs(alt_buttons) do v:touchmoved(id,x,y,dx,dy) end
  scroller:touchmoved(id,x,y,dx,dy)
end
--
function st:leave()
  slide.tween:stop()
  slide.x,slide.y = 0,0
  lerping = false
  ent = nil
end
--

------- Modes ----------------------------
local increase, decrease = lg.newImage("res/img/increase.png"), lg.newImage("res/img/decrease.png")
local player_description = {
  draw = function(len)
    if len then
      local _, wrapped = FONT_[2]:getWrap(desc,base.description.w-30)
      return FONT_[2]:getHeight()*#wrapped
    end
    lg.push() lg.translate(0,scroller.y_offset)
    lg.setFont(FONT_[2])
    lg.setStencilTest("equal",1)
    lg.setColor(1,1,1,0.9)
    lg.printf(desc, base.description.x+15, base.description.y+5, base.description.w-30)
    lg.setStencilTest()
    lg.pop()
    scroller:draw()

    lg.setFont(FONT_[7])
    lg.setColor(1,1,1,0.66)
    lg.printf("Description", screen_width*0.8, 30+2, screen_width*0.2, "center")
  end,
  update = function(dt)
  end
}
--
local _stats_ = {
  {"STR","Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse non mi accumsan, bibendum sapien vel cras non euismod lorem."},
  {"INT","Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse non mi accumsan, bibendum sapien vel cras non euismod lorem."},
  {"AGI","Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse non mi accumsan, bibendum sapien vel cras non euismod lorem."},
  {"CON","Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse non mi accumsan, bibendum sapien vel cras non euismod lorem."},
  {"LUK","Lorem ipsum dolor sit amet, consectetur adipiscing elit. Suspendisse non mi accumsan, bibendum sapien vel cras non euismod lorem."},
}
for i,v in pairs(_stats_) do
  local _, wrapped = FONT_[2]:getWrap(v,base.description.w-30)
  _stats_[i][3] = #wrapped*FONT_[2]:getHeight()
end

local button_cols = {
  fg = {
    --Default
    {1,1,1,0.3},
    --Hovered
    {1,1,1,0.6},
    --Pressed
    {0.7,0.6,0.3,0.3},
  },
  bg = {
    --Default
    {0.2,0.2,0.2,0.4},
    --Hovered
    {1,1,1,0.6},
    --Pressed
    {0.7,0.6,0.3,0.3},
  }
}

local stat_description = {
  draw = function(len)
    lg.push() lg.translate(0,scroller.y_offset)
    lg.setStencilTest("equal",1)
    local stat_desc_offsets = {}
    for i,v in pairs(_stats_) do
      stat_desc_offsets[i] = stat_desc_offsets[i-1] or 0
      lg.setColor(1,1,1,0.9)
      lg.setFont(FONT_[3])  
      lg.printf(v[1], base.description.x+15, base.description.y+5+stat_desc_offsets[i], base.description.w-30)
      stat_desc_offsets[i] = stat_desc_offsets[i] + FONT_[3]:getHeight()
      lg.setFont(FONT_[2])
      lg.printf(v[2], base.description.x+15, base.description.y+5+stat_desc_offsets[i], base.description.w-30)
      stat_desc_offsets[i] = stat_desc_offsets[i] + v[3] + screen_height/10
    end
    for i,v in pairs(alt_buttons) do v:draw(button_cols,(v.param.inactive and 0.2) or 1) end
    lg.pop()
    if len then 
      lg.setStencilTest()
      return stat_desc_offsets[#stat_desc_offsets]
    end

    lg.setStencilTest()
    scroller:draw()

    lg.setFont(FONT_[7])
    local w = FONT_[7]:getWidth("Remaining Points: "..curr_points)
    lg.setColor(0.1,0.1,0.1,0.9)
    lg.rectangle("fill", screen_width-w-20, base.description.y+base.description.h-FONT_[7]:getHeight()-10, w+20, FONT_[7]:getHeight()+10)
    lg.setColor(1,1,1,0.33)
    lg.rectangle("line", screen_width-w-20, base.description.y+base.description.h-FONT_[7]:getHeight()-10, w+20, FONT_[7]:getHeight()+10)
    lg.setColor(1,1,1,0.66)
    lg.printf("Remaining points: "..curr_points, screen_width-w-10, base.description.y+base.description.h-FONT_[7]:getHeight()-5, w, "center")

    lg.setColor(1,1,1,0.66)
    lg.printf("Attributes", screen_width*0.8, 30+2, screen_width*0.2, "center")
  end,
  update = function(dt)
    local mx,my = Misc.getMouseScaled()
    local in_bounds = Misc.checkPoint(mx,my, {base.description.x, base.description.y, base.description.w, base.description.h})
    local stat_desc_offsets = {}
    for i,v in pairs(_stats_) do
      stat_desc_offsets[i] = (stat_desc_offsets[i-1] or 0) + FONT_[3]:getHeight() + v[3] + screen_height/10
    end
    for i=1,#stat_desc_offsets*2 do
      local v = stat_desc_offsets[(i-1)%5+1]
      if (curr_points==0 and i<=5)
      or ((curr_points==base_points or not allocated[_stats_[(i-1)%5+1][1]]) and i>5)
      or ((allocate(_stats_[(i-1)%5+1][1],0)) and i<=5)
      then
        alt_buttons[i].param.inactive = true else alt_buttons[i].param.inactive = false
      end
      alt_buttons[i].y = v+20
      alt_buttons[i]:update(dt,nil,scroller.y_offset)
      if not in_bounds then alt_buttons[i].selected = false end
    end
  end,
}
--
local ally_box = {}
for i=1,2 do
  ally_box[i] = {
    x = base.description.x+15,
    y = base.description.y+15,
    w = base.description.w-60,
    h = (base.description.h-80-15*(2+1))/2
  }
  ally_box[i].y = ally_box[i].y + (ally_box[i].h + 15) * (i-1)
end
local ally_fonts = {
  na = FONT_[6],
}
local function draw_ally(i,a)
  local ally = combat.allies[i]
  local box = ally_box[i]
  if not ally then return end
  lg.push() lg.translate(box.x,box.y)
  local w = box.w/3+30
  local woff = 0
  -- Draw ally info

  lg.setColor(1,1,1,a)
  lg.setFont(FONT_[3])
  lg.print(Misc.truncate(ally.name,FONT_[3],w-15-5-woff),15,5)
  small_hp(ally, 20, FONT_[3]:getHeight()+15, w-25, 16, a)
  _ally_bar(ally, 25, FONT_[3]:getHeight()+25+21, w-25, 16, a)

  lg.translate(box.w/3+45)
  w = box.w-(box.w/3+30+5)
  lg.setFont(FONT_[3])
  lg.setColor(1,0.75,0.2,a)
  lg.printf("Lv. "..ally.lvl,0,5,w-15,"center")
  lg.translate(0,5+FONT_[3]:getHeight()+10)
  lg.setColor(1,1,1,a*0.33)
  Misc.fadeline(0, -5, 0, w, 1)
  lg.setColor(1,1,1,a)
  for i,v in pairs(_stats_) do
    local x = 15+((w)/#_stats_)*(i-1)
    lg.setFont(FONT_[7])
    lg.print(v[1]..":",x,0)
    lg.setFont(FONT_[3])
    lg.printf(ally:getStat(v[1]:lower()),x,FONT_[7]:getHeight()-5, FONT_[7]:getWidth(v[1]..":"), "center")
  end

  lg.pop()
end
--
local manage_allies = {
  draw = function(len)
    if len then return 0 end
    for i,v in pairs(ally_box) do
      if combat.allies[i] then
        if ally_selected==i then
          lg.setColor(0.1,0.05,0.05,4/6)
        else
          lg.setColor(0,0,0,3/5)
        end
        Misc.pgram("fill", v.x, v.y, v.w/3+30, v.h, 15)
        Misc.pgram("fill", v.x+v.w/3+30+5, v.y, v.w-(v.w/3+30+5), v.h, 15)
        if ally_selected==i then
          lg.setColor(1,1,1,2/3)
          lg.setLineWidth(2)
        else
          lg.setColor(1,1,1,1/3)
        end
        Misc.pgram("line", v.x, v.y, v.w/3+30, v.h, 15)
        Misc.pgram("line", v.x+v.w/3+30+5, v.y, v.w-(v.w/3+30+5), v.h, 15)
        draw_ally(i,({lg.getColor()})[4]+0.33)
        if combat.allies[i] == ent then
          lg.setColor(0,0,0,0.8)
          Misc.pgram("fill", v.x, v.y, v.w/3+30, v.h, 15)
          Misc.pgram("fill", v.x+v.w/3+30+5, v.y, v.w-(v.w/3+30+5), v.h, 15)
          lg.setColor(1,1,1)
          lg.setFont(ally_fonts.na)
          lg.printf("(Managing...)",v.x,v.y+v.h/2-ally_fonts.na:getHeight()/2,v.w,"center")
        end
      else
        lg.setFont(ally_fonts.na)
        lg.setColor(1,1,1,0.2)
        Misc.pgram("line", v.x, v.y, v.w, v.h, 15)
        lg.printf("N/A",v.x,v.y+v.h/2-ally_fonts.na:getHeight()/2,v.w,"center")
      end
      lg.setLineWidth(1)
    end
    for i,v in pairs(alt_buttons) do
      v:draw(nil,(v.param.inactive and 0.2) or 1)
    end

    lg.setFont(FONT_[7])
    lg.setColor(1,1,1,0.66)
    lg.printf("Manage Allies", screen_width*0.8, 30+2, screen_width*0.2, "center")
  end,
  update = function(dt)
    alt_buttons[2].param.inactive = ent~=player
    if not combat.allies[ally_selected] then
      ally_selected = 0
      for i=1,3 do alt_buttons[i].param.inactive = true end
    end
    for i,v in pairs(alt_buttons) do
      v:draw(nil,(v.param.inactive and 0.2) or 1)
      v:update(dt)
    end
  end
}
--
local skillselect_boxes = {
  offsets = { {x=-0.5,y=0}, {x=0,y=-1}, {x=0.5,y=0}, {x=0,y=1} },
  font = fonts.planning_selector,
  base = {
    x = base.description.x+base.description.w/2-(screen_width/4.5)/2,
--    y = screen_height/2-(screen_height/12)*1.5-(10)-15,
    y = base.description.y+(screen_height/12)*1.5+15,
    w = screen_width/4.5,
    h = screen_height/12,
    pad = 10,
    alpha = 0.3,
    talpha = 0.3,
  },
}
for i=1,4 do
  local base = skillselect_boxes.base
  skillselect_boxes[i] = Misc.tcopy(base)
  skillselect_boxes[i].x = base.x + (base.w+base.pad) * skillselect_boxes.offsets[i].x
  skillselect_boxes[i].y = base.y + (base.h+base.pad) * skillselect_boxes.offsets[i].y
end
local function draw_box(b,as_stencil)
  local box = skillselect_boxes[b]
  local proto = skillselect_boxes.proto
  local r = 15
  local x,y,w,h = box.x+r/2,box.y,box.w,box.h
  local alpha = box.alpha
  if as_stencil then
    x = x+3
    y = y+3
    w = w-6
    h = h-6
  end
  lg.setColor(0.1,0,0,1*alpha)
  Misc.pgram("fill",x,y,w,h,-r)
  lg.setColor(1,1,1,1*alpha)
  Misc.pgram("line",x+1,y+1,w-2,h-2,-r)
  lg.setColor(0,0,0,1*alpha)
  Misc.pgram("line",x,y,w,h,-r)
  if alt_buttons[b].selected and alt_buttons[b].button_down then
    lg.setColor(0,0,0,0.5*alpha)
    Misc.pgram("fill",x,y,w,h,-r)
  end
end
--
local review_skills = {
  draw = function(len)
    if len then return 0 end
    lg.setFont(skillselect_boxes.font)
    for i,v in ipairs(skillselect_boxes) do
      local b
      if alt_buttons[i].selected then b = alt_buttons[i] end
      lg.push()
      lg.translate(v.x+v.w/2,v.y+v.h/2)
      lg.scale(b and b.button_down and b.held_time>=0.1 and 1-(b.held_time-0.1)*0.6 or 1)
      lg.translate(-(v.x+v.w/2),-(v.y+v.h/2))
      draw_box(i)
      lg.stencil(function() draw_box(i,true) end,"replace",1)
      lg.setStencilTest("equal", 1)
      local sk = Misc.capitalize(ent.active_skills[i] or "[Empty]")
      lg.setColor(1,1,1,v.alpha)
      local y = v.y+v.h/2-skillselect_boxes.font:getHeight()/2
      for o=-2,2 do
        lg.setColor(0,0,0,1*v.alpha)
        lg.printf(sk, v.x+o, y, v.w, "center")
        lg.printf(sk, v.x+o, y+o, v.w, "center")
      end
      lg.setColor(1,1,1,1*v.alpha)
      lg.printf(sk, v.x, y, v.w, "center")
      lg.pop()
      lg.setStencilTest()
    end
    lg.setColor(0,0,0,0.6)
    Misc.fadeline(base.description.x, base.description.y+base.description.h/2+25, nil, base.description.w, (base.description.h/2-25))
    lg.push() lg.translate(10,skillselect_boxes.base.pad+skillselect_boxes.base.h/2+25)
    lg.setColor(1,1,1,0.55*(1-combat.skillinfo.box.alpha*2))
    lg.push() lg.translate(0, -love.graphics.getFont():getHeight()/2)
    lg.printf("Select a skill slot to change or review.\nHold-click to clear the slot.", base.description.x, base.description.h/1.33+5, base.description.w, "center")
    lg.pop()
    combat.skillinfo.draw(true)
    lg.pop()

    lg.setFont(FONT_[7])
    lg.setColor(1,1,1,0.66)
    lg.printf("Skills", screen_width*0.8, 30+2, screen_width*0.2, "center")
  end,
  update = function(dt)
    combat.skillinfo.update(dt*1.5)
    for i,v in pairs(alt_buttons) do
      if not dropdown.visible then v:update(dt) end
    end
    for i,v in ipairs(skillselect_boxes) do
      v.alpha = Misc.lerp(8*dt, v.alpha, v.talpha)
    end
  end
}
--

function st.setMode(m)
  local ind = {player_description, stat_description, manage_allies, review_skills}
  if not m then
    for i,v in pairs(ind) do if mode==v then m=i+1 end end
  end
  if ent~=player then
    m = (m-1)%2+3
  else
    m = (m-1)%#ind+1
  end

  for i=1,#buttons do
    local targ = i
    if ent~=player then targ = i+2 end
    if m==targ then buttons[i].param.inactive=true else buttons[i].param.inactive=false end
  end

  alt_buttons = {}
  if m == 2 then
    for i=1,#_stats_*2 do
      local v = _stats_[(i-1)%5+1]
      local func, func2 = function() allocate(v[1],1) end, function() allocate(v[1],-1) end
      if i<=5 then table.insert(alt_buttons, newButton(increase, func, base.description.x+15, 0, nil, nil, {held_func=func, rep=true}))
      else table.insert(alt_buttons, newButton(decrease, func2, base.description.x+104+5+15, 0, nil, nil, {held_func=func2, rep=true})) end
    end
  elseif m == 3 then
    ally_selected = 0
    local w, h = 150, 50
    local x = base.description.x+(base.description.w-30)/2 - w/2
    local function getx(i)
      local len = (3) - 1
      local x = (x - (w/2+15) * len) + (w+15)*(i-1)
      if len > 0 then x = x + (15/2)*len end
      return x
    end
    alt_buttons = {
      newButton("Manage", function()
          Misc.message("You are now managing "..combat.allies[ally_selected].name..".\nPress \"Return\" to switch back to "..player.name.." when you're finished.")
          change_ent(combat.allies[ally_selected])
        end, getx(1), base.description.y+base.description.h-25-h, w, h, {inactive=true}),
      newButton("--------", function() end, getx(2), base.description.y+base.description.h-25-h, w, h, {inactive=true}),
      newButton("Send Away", function()
          local sel = ally_selected
          prompt("Do you really want to dismiss "..combat.allies[sel].name.."?\nYou might not be able to get this ally back.",{function() combat.removeAlly(sel) end})
        end, getx(3), base.description.y+base.description.h-25-h, w, h, {inactive=true}),
    }
    for i,v in pairs(ally_box) do
      table.insert(alt_buttons, newButton(tostring(i),
          function()
            if combat.allies[i] == ent then for i=1,3 do alt_buttons[i].param.inactive = false end return end
            ally_selected = i
            for i=1,3 do alt_buttons[i].param.inactive = false end
          end,
          v.x, v.y, v.w, v.h, {no_ripple=true,visible=false}))
    end
  elseif m == 4 then
    local curr_info = nil
    combat.skillinfo.reset()
    for i,v in ipairs(skillselect_boxes) do v.alpha, v.talpha = 0.3, 0.3 end
    alt_buttons = {}
    for i=1,4 do
      alt_buttons[i] = newButton("", function()
          local sk = {}
          for _,v in pairs(ent:getSkills()) do
            local skip
            for _,vv in pairs(ent.active_skills) do
              if v:lower()==vv:lower() then skip = true end
            end
            if not skip then table.insert(sk,v) end
          end
          dropdown = newDropdown(sk)
          dropdown.func = function(_,v)
            ent.active_skills[i] = v
            alt_buttons[i].mouse_on()
          end
          dropdown:open(Misc.getMouseScaled())
        end, skillselect_boxes[i].x, skillselect_boxes[i].y, skillselect_boxes.base.w, skillselect_boxes.base.h,
        {visible=false,selected=false,mobile_friendly=true,
          held_func=function()
            ent.active_skills[i] = nil
            combat.skillinfo.reset()
          end,
          mouse_on=function()
            skillselect_boxes[i].talpha = 1
            combat.skillinfo.reset()
            if ent.active_skills[i] then combat.skillinfo.open(ent,ent.active_skills[i]) curr_info = i end
          end,
          mouse_off=function()
            skillselect_boxes[i].talpha = skillselect_boxes.base.talpha
            if curr_info == i then combat.skillinfo.reset() end
          end
        })
    end
  end

  mode = ind[m]
  mode_ind = m
  scroller = newScroller(15, 0, mode.draw(true)-base.description.h+15, base.description.x+base.description.w-6, base.description.y+12, base.description.h-12*2)
end
--

return st