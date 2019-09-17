local idle = {
  initialized = false,
}

local icons = {
  lg.newImage("res/img/attack_icon.png"),
  lg.newImage("res/img/magic_icon.png"),
  lg.newImage("res/img/placeholder icon.png"),
  lg.newImage("res/img/endturn_icon.png"),
  lg.newImage("res/img/flee_icon.png"),
}
--

local active
local block_input = 0
local zoom = 1.15
local alpha = 0
local talpha
local apglow = 0
local ent_index
local mouse_on
local last_selected
local buttons = {}
local box = {
  x = 0,
  y = 0,
  w = 0,
  h = 0,
}
--

event.wish({"combat_start","turn_end"}, function() event.clear("ally_turn","enemy_turn") ent_index = nil end)

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
    if v.selected then return i end
  end
  return nil
end
--

local function sls(i)
  last_selected = i or getSelectedButton()
end
--

local function create_buttons()
  local key = {
    {
      label = "Attack",
      func = function()
        local sk = combat.skills("strike")
        if not combat.info.list[ent_index].ent:useAP(sk.cost,true) then return combat.info.list[ent_index].flashAP(false,sk.cost) end
        combat.changeMode("target",ent_index,sk,"idle")
        talpha = 0
        box.tx = 0
        sls()
      end
    },
    {
      label = "Skills",
      func = function()
--        Misc.WIP()
        combat.changeMode("skillselect",ent_index)
        talpha = 0
        box.tx = 0
        sls()
      end
    },
    {
      label = "--------",
      func = function()
      end
    },
    {
      label = "End Turn",
      func = function()
        idle.next()
        sls()
      end
    },
    {
      label = "Flee",
      func = function()
        combat.changeMode("flee",combat.info.list[ent_index].ent)
        active = false
        sls()
      end
    },
  }
  buttons = {}
  for i,v in pairs(key) do
    table.insert(buttons, newButton(icons[i], function()
          if i~=4 then
            combat.pollData(combat.info.list[ent_index].ent, "attempt_action", "msg", function(_,v) combat.log(v,combat.info.list[ent_index].ent) end)
            for i,v in pairs(combat.retrieveData(combat.info.list[ent_index].ent,"attempt_action") or {}) do
              if v.disable then return end
            end
          end
          v.func()
        end,
        0,0,0,0, {no_ripple=true, visible=false, tip=v.label}))
  end
end
--

function idle.init()
  alpha = 0
  idle.reset()

  if idle.initialized then return end

  create_buttons()

  last_selected = nil
  states.combat.keyboard_focus = 1
  idle.initialized = true
end
--

function idle.reset()
  talpha = 0
  box.tx = 0
  block_input = 1/5
end
--

function idle.begin(next)
  if combat.auto or (ent_index and combat.info.list[ent_index] and combat.info.list[ent_index].ent.AI) then active = true return idle.finish() end

  if not active then
    combat.view_scale(zoom, {0,screen_height}, 6, {xy={0,screen_height}})
  else
    combat.view_scale(zoom, {0,screen_height}, 6)
  end
  idle.reset()
  create_buttons()

  box = {
    x = 0,
    tx = (screen_width/3+15),
    y = 0,
    ty = 0,
    w = screen_width/13,
    tw = screen_width/13,
    h = screen_height/6.5,
    th = screen_height/6.5
  }
  box.y = combat.info.list[1].box.y_orig + combat.info.list[1].box.h/2 - box.h/2
  box.ty = box.y

  combat.info.show()
  active = true
  talpha = 1
  combat.info.active(ent_index)
  states.combat.keyboard_focus = last_selected or 1
  if next and ent_index then idle.next() else ent_index = ent_index or 1 end
end
--

function idle.finish(mode)
  talpha = 0
  combat.info.active(0)
  combat.view_scale(1, nil, 6)
  if not active then
    box.x, alpha = 0, 0
    return
  end
  active = false
  combat.changeMode(mode or "turn")
  last_selected = nil
  states.combat.keyboard_focus = 1
end
--

function idle.cancel()
  active = false
  talpha = 0
  combat.info.active(0)
  combat.view_scale(1, nil, 6)

  idle.reset()
  states.combat.mode = 0
  box.tx = 0
end
--

function idle.next(index)
  if index == 0 then index = ent_index end
  index = index or ent_index+1
  idle.begin()
  combat.view_scale(zoom, {0,screen_height}, 6)
  if index > #combat.info.list then return idle.finish() end
  if combat.info.list[index].ent.AI then idle.next(index+1) return end
  combat.info.active(index)
  ent_index = index
  create_buttons()
  last_selected = nil
  states.combat.keyboard_focus = 1
end
--

function idle.update(dt)
  if not combat.info.list[ent_index] or not combat.info.list[ent_index].box.visible then return end
  block_input = math.max(0, block_input - 1 * dt)
  box.x = Misc.cerp(18*dt, box.x, box.tx)
  alpha = Misc.lerp(15*dt, alpha, talpha)
  if not active or alpha <= 0.01 then return end
  apglow = (apglow + math.pi * 1.5 * dt) % math.pi
  selectButton(states.combat.keyboard_focus)
  local mx, my = Misc.getMouseScaled()
  mx, my = mx/zoom, my/combat._scale.amount+(combat._scale.xy[2]-combat._scale.xy[2]/combat._scale.amount)
  for i,v in pairs(buttons) do
    v:set_mouse_coords(mx,my)
    v:update(dt)
  end
  local selected = getSelectedButton()
  if selected==1 then combat.info.list[ent_index].glowAP(2, apglow)
  elseif selected==3 then combat.info.list[ent_index].glowAP(3, apglow) end
  return true
end
--

function idle.draw()
  if not combat.info.list[ent_index] or not combat.info.list[ent_index].box.visible then return end
  for i,v in pairs(buttons) do
    local pad = ((screen_width/zoom-15  )-(box.x))/(#buttons)
    v.x = box.x+(pad)*(i-1)
    v.y, v.w, v.h = box.y, box.w+20, box.h
    local alpha = alpha/2
    if v.selected then alpha = alpha*2.5 end

    lg.setColor(0,0,0,0.8*alpha)
    Misc.pgram("fill",v.x+20,v.y,v.w-20,v.h,-20)
    lg.setColor(1,1,1,0.33*alpha)
    Misc.pgram("line",v.x+20,v.y,v.w-20,v.h,-20)

    if v.button_down then lg.setColor(0.35,0.3,0.3,1*alpha) else lg.setColor(1,1,1,0.75*alpha) end
    lg.draw(v.label,v.x+v.w/2,v.y+v.h/2,nil,nil,nil,v.label:getWidth()/2,v.label:getHeight()/2)
  end
  return true
end
--

function idle.keypressed(key)
  if not active then return end
  if not combat.info.list[ent_index] or not combat.info.list[ent_index].box.visible then return end

  if block_input == 0 then
    if keyset.confirm(key) and states.combat.keyboard_focus > 0 then
      buttons[states.combat.keyboard_focus]:func()
    elseif keyset.back(key) then
      idle.cancel()
    end
  end

  if keyset.left(key) then
    local selected = getSelectedButton() or states.combat.keyboard_focus
    states.combat.keyboard_focus = selected - 1
    if states.combat.keyboard_focus < 1 then states.combat.keyboard_focus = #buttons end
  elseif keyset.right(key) then
    local selected = getSelectedButton() or states.combat.keyboard_focus
    states.combat.keyboard_focus = selected + 1
    if states.combat.keyboard_focus > #buttons then states.combat.keyboard_focus = 1 end
  end

  return true
end
--

function idle.keyreleased(key)
  if not active then return end
  if not combat.info.list[ent_index] or not combat.info.list[ent_index].box.visible then return end
  return true
end
--

function idle.mousepressed(x,y,b,t)
  if not active or block_input > 0 then return end
  if not combat.info.list[ent_index] or not combat.info.list[ent_index].box.visible then return end
  x, y = x/zoom, y/combat._scale.amount+(combat._scale.xy[2]-combat._scale.xy[2]/combat._scale.amount)
  if b==2 then idle.cancel() return true end

  for i,v in pairs(buttons) do
    if v:mousepressed(x,y,b) then return true end
  end

  idle.cancel()
  return true
end
--

function idle.mousereleased(x,y,b,t)
  if not active then return end
  if not combat.info.list[ent_index] or not combat.info.list[ent_index].box.visible then return end
  x, y = x/zoom, y/combat._scale.amount+(combat._scale.xy[2]-combat._scale.xy[2]/combat._scale.amount)
  for i,v in pairs(buttons) do v:mousereleased(x,y,b) end
  return true
end
--

function idle.touchmoved(id,x,y,dx,dy)
  if not active then return end
  if not combat.info.list[ent_index] or not combat.info.list[ent_index].box.visible then return end
  for i,v in pairs(buttons) do v:touchmoved(id,x,y,dx,dy) end
  return true
end
--

function idle.wheelmoved(x,y)
  if not active or block_input > 0 then return end
  if not combat.info.list[ent_index] or not combat.info.list[ent_index].box.visible then return end
  return true
end
--

setmetatable(idle, { __index = function(_, ...) return function() end end})
return idle