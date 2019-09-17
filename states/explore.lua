local st = {}
local lerping
local mouse_on
local FONT_ = {
  fonts.explore_header,
  fonts.explore_list,
}
st.keyboard_focus = 0
st.flux = Flux.group()
-----------------------

local newScroller = require("elements.scroller")

st.origin = {x=0,y=0}
local box
local smaller_box = {
  w = screen_width/6,
  h = screen_height/4,
  label = "",
}
local tail = {
  x=0,
  y=0,
  w=screen_width/40,
  h=screen_width/40,
}
local pulse_effect = {
  offset=0,
  alpha=0,
  x=0, y=0, w=0, h=0
}

local box_tween
local max_height = 6
local pad = 10
local alpha = 1
local state = 1
local refresh_timer = 0
local scroller
local recent_location
local fg_ui = {}
--
local wander = {}
local nav = {}
local list = {}

local function update(dt)
end
local function draw()
end
--

function st.reset()
  recent_location = nil
  wander = {}
  nav = {}
  list = {}
end
--

function st.getNavList() return nav end
function st.setNavList(n) nav = n end
--

function st.getWander(location)
  local t = {}
  if not location then
    for _,d in pairs{"res/wander.txt"} do
      local dir = d:match("(.+)/")
      for l in love.filesystem.lines(d) do
        if not l:match("^%s*//") then
          local key, value = l:match("(.+)%s*[:=]%s*(.+)")
          if key then
            key = key:gsub("^%s*(.-)%s*$","%1"):lower()
            t[key] = t[key] or {}
            for w in value:gmatch(";*%s*([^;]+)%s*;*%s*") do
              table.insert(t[key], {w:match("^%s*([^%%]+)%s*"):gsub("^%s*(.-)%s*$","%1"), tonumber(w:match("%%([%d%.]+)") or 1)})
            end
          end
        end
      end
    end
    --
    for l,a in pairs(t) do
      local weights = {}
      for _,v in pairs(a) do table.insert(weights,v[2]) end
      for i, chance in pairs(Misc.gbd(weights)) do t[l][i][2] = chance end
    end
    wander = t
  else
    local areas
    for i,v in pairs(wander) do
      if string.match(location:lower(),"^"..Misc.sanitize(i:lower())) then
        areas = areas or {}
        for i,v in pairs(wander[i]) do
          if v[1]~=out.to then table.insert(areas, v) end
        end
      end
    end
    if areas then
      list[1] = {label="Wander",area=areas}
      return true
    end
  end
end
--
function st.getAreas(location)
  local success
  local temp = {}
  -- Get the explorable areas for a particular location
  for l,a in pairs(nav) do
    if string.match(location:lower(),"^"..Misc.sanitize(l:lower())) then
      success = true
      for i,v in pairs(a) do
        table.insert(temp, {label=i,area={v}})
      end
    end
  end
  table.sort(temp, function(o,t) return o.label<t.label end)
  local initial = #list
  for i=1,#temp do list[initial+i] = temp[i] end
  return success
end
--
function st.addArea(name,location,file,weight)
  if not (file and location and name) then return end
  weight = weight or 1

  local location_list = {}

  for w in string.gmatch(location, ";*%s*([^;]+)%s*;*%s*") do
    local l = w:match("^%s*([^%%]+)%s*"):gsub("^%s*(.-)%s*$","%1")
    table.insert(location_list, l)
  end
  for i,location in pairs(location_list) do
    nav[location] = nav[location] or {}
    nav[location][Misc.capitalize(name)] = {file,weight}
  end
  st.updateList(true)
end
--
function st.removeArea(name,location)
  name = name~="nil" and name
  if (not location or not nav[location]) or (nav[location] and name and not nav[location][name]) then return end
  if not name then
    nav[location] = nil
  else
    nav[location][name] = nil
  end
  st.updateList(true)
end
--
local function removeConflictingListItems()
  if not (list[1] or {}).area then return end
  local ListItems = {}
  local deletion_count = 0
  local initial = 2
  if list[1].label~="Wander" then initial = 1 end
  for i=initial,#list do
    table.insert(ListItems, list[i].area[1][1])
  end
  if initial == 2 then
    for i,v in pairs(list[1].area) do
      if __.any(ListItems, function(_,listitem) return v[1]==listitem end) then
        list[1].area[i] = nil
      end
    end
    local weights = {}
    for i,v in pairs(list[1].area) do weights[i]=v[2] end
    for i, chance in pairs(Misc.gbd(weights)) do list[1].area[i][2] = chance end
    if not next(list[1].area) then table.remove(list,1) end
  end

  for i=1,#list do
    i = i - deletion_count
    if list[i].label~="Wander" and list[i].area[1][1] == out.to then
      table.remove(list,i)
      deletion_count = deletion_count + 1
    elseif list[i].label=="Wander" then
    end
  end
end
--


function st.updateList(force)
  if recent_location~=out.location or force then
    list = {}
    st.getWander(out.location)
    st.getAreas(out.location)
    removeConflictingListItems()
    icon_bar.set(3,#list~=0)
    recent_location = out.location
  end
end
--

local function transition(...)
  state = 3
  lerping = true

  if box_tween then box_tween:stop() end

  local args = {...}

  local img = lg.newImage("res/img/transition.png")
  local flashed = false
  local t = {sw = 0, fly = 0, time=math.pi/2}
  local inc = 7
  local speed = 1
  local text = ({"A presence!","Ambushed!"})[math.random(2,2)]
  update = function(dt)
    t.sw = math.min(2, t.sw + dt * 5)
    if t.sw < 2 then return end
    if not flashed then flashed = true Misc.flash() end
    if t.fly < screen_width/2 then inc = 6.5 else inc = 7 end
    t.time = t.time + inc * dt
    speed = math.clamp(0.05, math.sin(t.time)*0.5+0.5, 1)
    dt = dt * speed
    t.fly = t.fly + (screen_width*(inc/3)) * dt
    if t.fly >= screen_width*1.25 then
      Gamestate.pop()
      lerping = false
      combat(unpack(args))
      combat.globals.was_ambushed = true
      return
    end
  end
  draw = function()
    lg.setColor(0,0,0)
    if flashed then lg.setColor(Misc.HSV(unpack(Misc.background_color))) end
    lg.push()
    lg.translate(screen_width/2, screen_height/2) 
    lg.rotate(math.pi/4)
    lg.translate(-screen_width/2, -screen_height/2)
    lg.draw(img,-screen_width/4,0,nil,math.min(1,t.sw)*1.5,1)
    lg.translate(screen_width/2, screen_height/2) 
    lg.rotate(math.pi/2)
    lg.translate(-screen_width/2, -screen_height/2) 
    if t.sw >= 1 then
      lg.draw(img,-screen_width/4,0,nil,(t.sw-1)*1.5,1)
    end
    lg.pop()
    if t.fly > 0 then
      lg.setColor(0,0,0,1)
      lg.rectangle("fill",0,screen_height/2-(fonts.mainmenu_logo_big:getHeight())/2,screen_width,fonts.mainmenu_logo_big:getHeight())
      lg.setColor(1,1,1)
      lg.setFont(fonts.mainmenu_logo_big)
      lg.printf(text,-screen_width/2+t.fly,screen_height/2-(fonts.mainmenu_logo_big:getHeight())/2, screen_width, "center")
    end
  end
end
--

local button_cols = {bg = {{1,1,1,0.1},{1,1,1,0.2},{0.03,0.12,0.1,0.3}},fg = {{1,1,1,0.5},{1,1,1},{1,1,1,0.5}}}

local function selectButton(index)
  for i,v in pairs(list) do
    if i == index then
      if v.button.key_selected then return end
      v.button.key_selected = true
      local diff1 = ((v.button.y+v.button.h)-(box.y+pad+FONT_[1]:getHeight())-scroller.y_offset_target) - (box.h-(pad*2+FONT_[1]:getHeight()))
      local diff2 = (v.button.y)-(box.y+pad*2+FONT_[1]:getHeight()) - scroller.y_offset_target
      local diff = 0
      if diff1 > 0 then diff = diff1 elseif diff2 < 0 then diff = diff2 end
      scroller:moveTo(scroller.y_offset_target+diff)
    else
      v.button.key_selected = false
      v.button.selected = false
    end
  end
end
--
local function getSelectedButton()
  for i,v in pairs(list) do
    if v.button.selected then return i end
  end
  return nil
end
--

local function pulse()
  local selected = getSelectedButton()
  for i,v in pairs(list) do
    if i~=selected then
      v.button.param.target_alpha=0
      v.button.param.alpha_speed=7
    end
  end

  pulse_effect = {
    alpha = 0.75,
    offset = 0,
    x = list[selected].button.x,
    y = list[selected].button.y,
    w = list[selected].button.w,
    h = list[selected].button.h,
  }
  st.flux:to(pulse_effect, 1.5, {alpha=0, offset=pulse_effect.w/4}):ease("quintout"):onupdate(function() selectButton(selected) end)
  lerping = true
end
--

local function wait_anim(label)
  if true then return end
  state = 2
  smaller_box.label = label or ""
  smaller_box.w = math.max(screen_width/6, FONT_[1]:getWidth(smaller_box.label)+pad*2)
  alpha = -0.25
  lerping = true
  local x,y = st.origin.x-smaller_box.w/2, st.origin.y-smaller_box.h-tail.h

  box_tween = st.flux:to(box, 1/3, {x=x, y=y, w=smaller_box.w, h=FONT_[1]:getHeight()+pad*2}):ease("quadinout"):oncomplete(function() lerping = false end)

  local index = 1
  local timer = 1
  update = function(dt)
    index = index + 4 * dt
    if index >= 4 then index = 1 end
    timer = timer - dt
    if timer <= 1 then timer = math.huge st.prep_leave(smaller_box.label) end
  end
  draw = function()
    lg.setFont(FONT_[1])
    lg.setColor(1,1,1,alpha*0.9)
    lg.print(smaller_box.label, box.x + box.w/2 - FONT_[1]:getWidth(smaller_box.label)/2, st.origin.y-box.h-pad*1.5)
    for i=1,3 do
      lg.setColor(1,1,1,alpha*0.15)
      if i==math.floor(index) then lg.setColor(1,1,1,alpha*0.9) end
      lg.circle("fill", x + smaller_box.w/2+32*(i-2), y + pad + smaller_box.h/2, 8)
    end
  end
end
--
local function show_buttons()
  state = 1
  lerping = false
  box.w = screen_width/3
  local bw = box.w-pad*2
  local bh = FONT_[2]:getHeight()

  if love.system.getOS()=="Android" then
    box.w = screen_width/2.5
    bw = box.w-pad*2
    bh = FONT_[2]:getHeight()*1.5
  end

  for i,v in pairs(list) do if FONT_[2]:getWidth(v.label)+pad*4 > box.w then box.w = FONT_[2]:getWidth(v.label)+pad*4 end end
  box.h = (FONT_[1]:getHeight() + pad*4 + math.min(max_height, #list) * (bh+3))

  tail.x = st.origin.x
  box.x = st.origin.x-box.w/2
  tail.y = st.origin.y
  box.y = st.origin.y-box.h-tail.h
  alpha = 1

  for i,v in pairs(list) do
    v.func = function() st.prep_leave(v.label) end
    v.button = newButton(v.label, v.func, box.x+pad, box.y + FONT_[1]:getHeight() + pad*2 + (bh+3) * (i-1), bw, bh,
      {font=FONT_[2], no_ripple=true, cols=button_cols})
  end

  update = function(dt)
    if prompt.box.visible then return end
    for i,v in pairs(list) do v.button:update(dt,nil,scroller.y_offset) end
    scroller:update(dt)
    for i,v in pairs(fg_ui) do
      v.x, v.y = box.x+box.w-30-10, box.y+10
      v:update(dt)
    end
  end
  draw = function()
    local w = box.w
    local x, y = st.origin.x-box.ow/2,st.origin.y-tail.h-box.oh

    lg.stencil(function() lg.rectangle("fill",x,y,w,pad+FONT_[1]:getHeight()) end, "replace", 1)
    lg.setStencilTest("equal",1)

    lg.setFont(FONT_[1])
    lg.setColor(1,1,1,alpha*0.9)
    lg.printf("Explore:", box.x, box.y + box.h - box.h*(box.oh/box.h) + pad, w, "center")

    for i,v in pairs(fg_ui) do v:draw() end

    lg.stencil(function() lg.rectangle("fill",x,y+pad+FONT_[1]:getHeight(),box.ow,box.oh-(pad*2+FONT_[1]:getHeight()),8,8) end, "replace", 1)
    lg.setStencilTest("equal",1)

    lg.push()
    lg.translate(0,scroller.y_offset)

    lg.setFont(FONT_[2])
    for i,v in pairs(list) do
      v.button:draw()
    end
    lg.pop()
    scroller:draw()
    lg.setStencilTest()
    lg.setColor(1,1,1)
  end
end
--

function st.prep_leave(target)
  lerping = false
  if box_tween then box_tween:stop() end
  if target then
    pulse()
    local result
    local r = math.random()
    for i,v in pairs(list) do
      if v.label == target then
        for ii,vv in pairs(v.area) do
          if r < vv[2] then result = vv[1] break end
          r = r - vv[2]
        end
      end
    end
    local enemies = {}
    for w in result:gmatch("[^&]+") do
      w = w:gsub("^%s*(.-)%s*$","%1")
      if Misc.exists(w, {"res/enemies/"}) then
        table.insert(enemies, w)
      end
    end
    if next(enemies) then
      return transition(unpack(enemies))
    else 
      return Timer.after(0.2, function() if not out.change(result,true) then show_buttons() Misc.message(target.." can't be accessed right now.") end end)
    end
  end
  Gamestate.pop()
end
--

function st:init()
  fg_ui = {
    newButton("?", function() Misc.tutorial("explore") end, screen_width-30-15, 15, 30,30)
  }
end
--
function st:enter(from)
  if not next(list) then return Gamestate.pop() end
  box = {
    speed = 14,
    x = 0,
    y = 0,
    w = screen_width/3,
    ow = 0,
    h = screen_height/2,
    oh = 0,
  }

  icon_bar.whenExploring()
  st.origin = {x=icon_bar.buttons[3].x+icon_bar.buttons[3].w/2,y=icon_bar.buttons[3].y}
  st.keyboard_focus = 0
  if #list > max_height then box.x, box.w = box.x-(25+pad), box.w+pad end
  show_buttons()
  scroller = newScroller(math.huge, 0, (FONT_[2]:getHeight()+3)*(#list)-(box.h-(FONT_[1]:getHeight()+pad*4))-pad, box.x+box.w-pad, box.y+FONT_[1]:getHeight()+pad*2, box.h-(FONT_[1]:getHeight()+pad*4))
  if #list <= max_height then scroller.visible = false end
end
--
function st:update(dt)
  st.flux:update(dt)

  box.ow = Misc.lerp(box.speed*dt, box.ow, box.w)
  box.oh = Misc.lerp(box.speed*dt, box.oh, box.h)

  alpha = math.min(1, alpha + dt)

  selectButton(st.keyboard_focus)
  update(dt)
end
--
function st:draw()
  states.game.draw()
  lg.stencil(function() lg.rectangle("fill",box.x,box.y,box.ow,box.oh,8,8) end, "replace", 1)
  box.x, box.y, box.ow, box.oh = math.floor(box.x),math.floor(box.y),math.floor(box.ow),math.floor(box.oh)

  -- Strange order of drawing, but makes the outline much easier to pull off
  -- Downside is it requires the box to be opaque
  lg.setColor(1,1,1,0.25)
  lg.rectangle("line",math.floor(st.origin.x-box.ow/2),st.origin.y-tail.h-box.oh,math.floor(box.ow),box.oh,8,8)
  lg.setColor(0,0,0,1)
  lg.polygon("fill", tail.x,tail.y, tail.x-tail.w,tail.y-tail.h-1, tail.x+tail.w,tail.y-tail.h-1)
  lg.setStencilTest("equal",0)
  lg.setColor(1,1,1,0.25)
  lg.polygon("line", tail.x,tail.y, tail.x-tail.w,tail.y-tail.h-1, tail.x+tail.w,tail.y-tail.h-1)
  lg.setStencilTest()
  lg.setColor(0,0,0,1)
  lg.rectangle("fill",math.floor(st.origin.x-box.ow/2),st.origin.y-tail.h-box.oh,math.floor(box.ow),box.oh,8,8)

  draw()

  local offset = pulse_effect.offset/1.5
  lg.setColor(1,1,1,pulse_effect.alpha)
  lg.push() lg.translate(offset/2,offset/2+scroller.y_offset)
  lg.rectangle("line",pulse_effect.x-offset,pulse_effect.y-offset,pulse_effect.w+offset,pulse_effect.h+offset,8,8)
  lg.pop()
  lg.setColor(1,1,1,pulse_effect.alpha)
  lg.rectangle("fill",pulse_effect.x,pulse_effect.y,pulse_effect.w,pulse_effect.h,8,8)

  lg.setFont(FONT_[2])
  lg.setColor(1,1,1)
end
--
function st:keypressed(key)
  if lerping or state==3 then return end
  if keyset.back(key) or keyset.explore(key) then 
    return self.prep_leave()
  end
  if state==1 then
    if keyset.confirm(key) and st.keyboard_focus > 0 then
      list[st.keyboard_focus].button:func()
    elseif keyset.up(key) then
      local selected = getSelectedButton() or st.keyboard_focus
      st.keyboard_focus = selected - 1
      if st.keyboard_focus < 1 then st.keyboard_focus = #list end
    elseif keyset.down(key) then
      local selected = getSelectedButton() or st.keyboard_focus
      st.keyboard_focus = selected + 1
      if st.keyboard_focus > #list then st.keyboard_focus = 1 end
    end
  end
end
--
function st:mousepressed(x,y,b,t)
  if state==3 then return end
  if b==2 then return self.prep_leave() end
  for i,v in pairs(fg_ui) do v:mousepressed(x,y,b) end
  if x > box.x and x < box.x + box.w and y > box.y and y < box.y + box.h then mouse_on = true else mouse_on = nil return end
  if state == 1 then
    scroller:checkArea(x,y, {box.x, box.y, box.w, box.h})
    for i,v in pairs(list) do v.button:mousepressed(x,y,b,nil,scroller.y_offset) end
  end
end
--
function st:mousereleased(x,y,b,t)
  if state==3 then return end
  for i,v in pairs(fg_ui) do v:mousereleased(x,y,b) end
  if x > box.x and x < box.x + box.w and y > box.y and y < box.y + box.h then
    --  Do nothing
  elseif not mouse_on then
    return self.prep_leave()
  end
  if state == 1 then
    for i,v in pairs(list) do v.button:mousereleased(x,y,b,nil,scroller.y_offset) end
  end
end
--
function st:wheelmoved(x,y)
  scroller:wheelmoved(x,y)
end
--
function st:touchmoved(id,x,y,dx,dy)
  scroller:touchmoved(id,x,y,dx,dy)
  for i,v in pairs(list) do v.button:touchmoved(id,x,y,dx,dy) end
end
--
function st:leave()
end
--

return st