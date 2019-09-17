local skillselect = {}

local cd_icon = lg.newImage("res/img/cooldown.png")
local element_icon

local FONT_ = {
  fonts.planning_selector,
}
--

local active
local block_input = 0
local zoom = 1.15
local alpha = 0
local talpha
local apglow = 0
local line_canvas
local ent
local ent_index
local mouse_on
local buttons = {}
local box_timing
local box = {
  w = screen_width/4.5,
  h = screen_height/12,
  pad = 10,
  alpha = 0,
  talpha = 1,
}
box.x = box.w+box.pad/2
box.y = screen_height-box.h*1.5-box.pad-15
--box.x = (screen_width/zoom)-box.w-box.pad/2-30
local offsets = { {x=-0.5,y=0}, {x=0,y=-1}, {x=0.5,y=0}, {x=0,y=1} }
local boxes = {}

local function selectButton(index)
  for i,v in pairs(buttons) do
    if i == index then
      if v.key_selected then return end
      v.selected = true
      v.key_selected = true
    else
      v.key_selected = false
      v.selected = false
    end
  end
end
--
local function getSelectedButton()
  for i,v in pairs(buttons) do
    if v.selected then
      return i
    end
  end
  combat.skillinfo.close()
  return nil
end
--

local function draw_lines()
  line_canvas = nil
  collectgarbage()
  line_canvas = lg.newCanvas(box.w,box.h)
  lg.setCanvas(line_canvas)
  lg.clear()
  lg.push()
  local sx, sy = Misc.toGame()
  lg.scale(1/sx, 1/sy)
  local space = 10
  local slant = box.w/5
  for x = 0-(slant), 0+box.w, space do
    lg.line(x, 0+box.h-1, x+slant, 0+2)
  end
  lg.pop()
  lg.setCanvas()
end
--
event.wish({"window_reset"}, draw_lines)

local function draw_box(b,alpha,as_stencil)
  local box = boxes[b]
  local r = 15
  local x,y,w,h = box.x+r/2,box.y,box.w,box.h
  if as_stencil then
    x = x+3
    y = y+3
    w = w-6
    h = h-6
  end
  if not box.skill then
    lg.setColor(0,0,0,0.66*alpha)
    lg.rectangle("fill",x,y,w,h,r)
    lg.setColor(1,1,1,0.66*alpha)
    lg.rectangle("line",x+1,y+1,w-2,h-2,r)
    return
  end
  lg.setColor(0.1,0,0,1*alpha)
  Misc.pgram("fill",x,y,w,h,-r)
  lg.setColor(1,1,1,1*alpha)
  Misc.pgram("line",x+1,y+1,w-2,h-2,-r)
  lg.setColor(0,0,0,1*alpha)
  Misc.pgram("line",x,y,w,h,-r)
end
--

function skillselect.reset()
  element_icon = combat.skillinfo.element_icon
  block_input = 1/5
  if not ent then return end
  buttons = {}
  for i,v in pairs(boxes) do
    local box = v
    if v.skill then
      buttons[i] = newButton(Misc.capitalize(v.skill), function() skillselect.close("target",i) end, box.x,box.y,box.w,box.h, {visible=false,mobile_friendly=true})
    end
  end
  if not line_canvas then draw_lines() end
end
--

function skillselect.open(e)
  combat.view_scale(zoom, {0,screen_height}, 6)
  ent = (type(e)=="table" and e) or (e and combat.info.list[e].ent) or ent
  ent_index = e or ent_index
  combat.info.show()
  combat.info.active(ent_index)

  for i=1,4 do boxes[i] = Misc.tcopy(box) end
  for i,v in pairs(boxes) do
    local base_x = v.x - v.w/2 + (combat.info.list[ent_index].box.tx+combat.info.list[ent_index].box.w)
    v.x = base_x + ((screen_width/zoom)-(base_x+v.w*1.5+v.pad))/2
    v.y = v.y - v.h/2
    v.ox, v.oy, v.ow, v.oh = v.x, v.y, v.w, v.h
    v.active = false
    v.skill = ent.active_skills[i]
  end
  combat.timer:script(function(wait)
      for i,v in pairs(boxes) do
        v.active = true
        wait(0.05)
      end
    end)

  skillselect.reset()

  active = true
  states.combat.keyboard_focus = 0
end
--

function skillselect.close(mode,sel)
  local sk = combat.skills(ent.active_skills[sel])
  if mode then
--    if ent.ap < sk.cost then return combat.info.list[ent_index].flashAP(false,sk.cost) end
    if not ent:useAP(sk.cost,true) then return combat.info.list[ent_index].flashAP(false,sk.cost) end
    if ent.cooldowns[sk.name:lower()] then
      local box = boxes[sel]
      local x,y = (box.x+box.w/2)*zoom,(box.y-box.h*1.5)*zoom
      return
    end
    states.combat.changeMode(mode,ent_index,sk)
  else
    states.combat.changeMode("idle")
  end

  active = false
  for i,v in pairs(boxes) do
    v.talpha = 0
  end
  combat.skillinfo.close()

  skillselect.reset()
end
--

local prev_selected
function skillselect.update(dt)
  block_input = math.max(0, block_input - 1 * dt)  
  apglow = (apglow + math.pi * 1.5 * dt) % math.pi

  selectButton(states.combat.keyboard_focus)
  local mx, my = Misc.getMouseScaled()
  mx, my = mx/zoom, my/combat._scale.amount+(combat._scale.xy[2]-combat._scale.xy[2]/combat._scale.amount)
  local selected
  for i,_ in pairs(boxes) do
    local box = boxes[i]
    local v = buttons[i]
    if box.active then
      box.x = Misc.lerp(16*dt, box.x, box.ox + (box.w+box.pad) * offsets[i].x)
      box.y = Misc.lerp(16*dt, box.y, box.oy + (box.h+box.pad) * offsets[i].y)
      box.alpha = Misc.lerp(18*dt, box.alpha, box.talpha)
    end
    if v and active then
      v.x, v.y, v.w, v.h = box.x, box.y, box.w, box.h
      v:set_mouse_coords(mx,my)
      v:update(dt)
      if v.selected and box.skill then
        combat.skillinfo.open(ent_index,box.skill)
        combat.info.list[ent_index].glowAP(combat.skills(v.label).cost, apglow)
        if prev_selected~=i then combat.skillinfo.close() end
        prev_selected = i
        selected = true
      end
    end
  end
  if not selected then combat.skillinfo.close() end
  
  combat.skillinfo.update(dt)
  return true
end
--

local old_setColor = lg.setColor
local setColor_mod = 0.5
local function new_setColor(r,g,b,a)
  local m = setColor_mod
  return old_setColor(r*m,g*m,b*m,a)
end
--
function skillselect.draw()
  combat.skillinfo.draw()
  lg.setFont(FONT_[1])
  for i,_ in pairs(boxes) do
    lg.setColor = new_setColor
    local box = boxes[i]
    local v = buttons[i]
    local alpha = box.alpha*0.85

    if v and v.selected then
      setColor_mod = 1
      alpha = box.alpha
    else
      setColor_mod = 0.5
    end

    draw_box(i,alpha)
    lg.stencil(function() draw_box(i,alpha,true) end,"replace",1)
    lg.setStencilTest("equal", 1)
    if not box.skill then
      lg.setColor(1,1,1,0.75*alpha)
      lg.draw(line_canvas, box.x, box.y)
    end
    if v then
      lg.setColor(1,1,1,alpha)
      local y = box.y+box.h/2-FONT_[1]:getHeight()/2
      for o=-2,2 do
        lg.setColor(0,0,0,1*alpha)
        lg.printf(v.label, v.x+o, y, v.w, "center")
        lg.printf(v.label, v.x+o, y+o, v.w, "center")
      end
      if v.button_down then
        lg.setColor(0.35,0.3,0.3,1*alpha)
      elseif ent.cooldowns[ent.active_skills[i]:lower()] then
        lg.setColor(1,0,0,0.66*alpha)
      else
        lg.setColor(1,1,1,1*alpha)
      end
      if not ent:useAP(combat.skills(box.skill).cost,true) then lg.setColor(1,0,0,1*alpha) end
      lg.printf(v.label, v.x, y, v.w, "center")
      lg.setStencilTest()

      if ent.cooldowns[ent.active_skills[i]:lower()] then
        lg.setColor(1,0,0,0.9*alpha)
        lg.draw(cd_icon, v.x, v.y+v.h/2-(cd_icon:getHeight()*0.4)/2, nil, v.w/cd_icon:getWidth(), 0.4)--v.h/cd_icon:getHeight())
      end
    else
      lg.setStencilTest()
    end
    lg.setColor = old_setColor
  end
  return true
end
--

function skillselect.keypressed(key)
  if not active then return end

  if block_input == 0 then
    if keyset.confirm(key) and states.combat.keyboard_focus > 0 then
      buttons[states.combat.keyboard_focus]:func()
    elseif keyset.back(key) then
      skillselect.close()
    end
  end
  if keyset.left(key) and boxes[1].skill then
    local selected = getSelectedButton() or states.combat.keyboard_focus
    states.combat.keyboard_focus = 1
  elseif keyset.right(key) and boxes[3].skill then
    local selected = getSelectedButton() or states.combat.keyboard_focus
    states.combat.keyboard_focus = 3
  elseif keyset.up(key) and boxes[2].skill then
    local selected = getSelectedButton() or states.combat.keyboard_focus
    states.combat.keyboard_focus = 2
  elseif keyset.down(key) and boxes[4].skill then
    local selected = getSelectedButton() or states.combat.keyboard_focus
    states.combat.keyboard_focus = 4
  end

  return true
end
--

function skillselect.keyreleased(key)
  if not active then return end
  return true
end
--

function skillselect.mousepressed(x,y,b,t)
  if not active or block_input > 0 then return end
  x, y = x/zoom, y/combat._scale.amount+(combat._scale.xy[2]-combat._scale.xy[2]/combat._scale.amount)
  if b==2 then skillselect.close() return true end

  for i,v in pairs(buttons) do
    if v:mousepressed(x,y,b) then return true end
  end

  skillselect.close()
  return true
end
--

function skillselect.mousereleased(x,y,b,t)
  if not active then return end
  x, y = x/zoom, y/combat._scale.amount+(combat._scale.xy[2]-combat._scale.xy[2]/combat._scale.amount)
  for i,v in pairs(buttons) do v:mousereleased(x,y,b) end
  return true
end
--

function skillselect.touchmoved(id,x,y,dx,dy)
  if not active then return end
  for i,v in pairs(buttons) do v:touchmoved(id,x,y,dx,dy) end
  return true
end
--

function skillselect.wheelmoved(x,y)
  if not active or block_input > 0 then return end
  return true
end
--

setmetatable(skillselect, { __index = function(_, ...) return function() end end})
return skillselect