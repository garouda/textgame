local target = {}

target.chosen = {}

local active
local block_input = 0
local zoom = 1.15
local box = {}
local box_target = {}
local alpha = 0
local talpha
local current = 1
local list = {}
local list_index = 1
local max_targets = 0
local chosen = {}
local arrow = {img=squarrow,offset=0,speed=0,base_rotation=0}

local prev
local ent
local ent_index
local skill

local function get_hover(mx,my)
  current = nil
  for i,v in pairs(list) do
    for ii,vv in pairs(v) do
      if Misc.checkPoint(mx,my,vv.box) and (current~=ii or list_index~=i) then
        if not skill and i==2 then return end
        list_index = i
        current = math.clamp(1, ii, #list[list_index])
        for i,v in pairs(box_target) do box_target[i] = list[list_index][current].box[i] end
        break
      end
    end
  end
end
--

function target.open(e,sk,from)
  prev = from or "skillselect"
  ent = combat.info.list[e].ent
  ent_index = e
  block_input = 1/6
  chosen = {}
  list_index = 1
  combat.info.active(0)
  box = {}
  box.tx = screen_width/3
  talpha = 0
  if states.combat.keyboard_focus==0 then
    local mx,my = Misc.getMouseScaled()
    mx, my = mx/zoom+(combat._scale.xy[1]-combat._scale.xy[1]/combat._scale.amount), my/combat._scale.amount+(combat._scale.xy[2]-combat._scale.xy[2]/combat._scale.amount)
    box.x = mx
    box.y = my
    box.w = 20
    box.h = 20
    box_target = Misc.tcopy(box)
    current = nil
  else
    current = math.ceil(#combat.enemy_info.list/2)
    for i,v in pairs(list[list_index][current].box) do box[i] = v end
    box_target = Misc.tcopy(box)
    states.combat.keyboard_focus = 1
  end
  skill = sk
  if skill then
    combat.queue.add({ent=ent, skill=skill.name})
    max_targets = -math.huge
    for i,v in pairs(skill.actions) do
      if type(v.opt.target)=="number" and v.opt.target > max_targets then max_targets = v.opt.target end
    end
    if max_targets < 0 then
      return target.select()
    elseif max_targets == 0 then
      current = ent_index
      list_index = 2
    end
  else
    max_targets = 1
  end
  active = true
end
--

function target.update(dt)
  list = {combat.enemy_info.list, combat.info.list}
  if not active then return end
  local mx,my = Misc.getMouseScaled()
  mx, my = mx/zoom+(combat._scale.xy[1]-combat._scale.xy[1]/combat._scale.amount), my/combat._scale.amount+(combat._scale.xy[2]-combat._scale.xy[2]/combat._scale.amount)

  alpha = Misc.lerp(12*dt, alpha, 1)
  arrow.speed = arrow.speed + 15 * dt
  arrow.offset = 10+math.sin(arrow.speed)*3
  if not current then
    local target = {
      x = mx,
      y = my,
      w = 20,
      h = 20,
    }
    arrow.base_rotation = Misc.lerp(14*dt, arrow.base_rotation, math.pi)
    target.x, target.y = target.x - target.w/2, target.y - target.h/2
    combat.view_scale(zoom, {mx,my}, 6)
    for i,v in pairs(target) do box[i] = Misc.lerp(18*dt, box[i], v) end
    return get_hover(mx,my)
  end

  arrow.base_rotation = Misc.lerp(14*dt, arrow.base_rotation, 0)

  current = math.clamp(1, current, #list[list_index])
  block_input = math.max(0, block_input - 1 * dt)

  if not list[list_index][current] then return end
  for i,v in pairs(box_target) do
    box_target[i] = list[list_index][current].box[i]
    box[i] = Misc.lerp(18*dt, box[i], v)
  end
--   get the infobox being hovered over
  if states.combat.keyboard_focus ~= 0 then
    return combat.view_scale(zoom, {box_target.x+box_target.w/2,box_target.y+box_target.h/2}, 6)
  elseif max_targets == 0 then
    return combat.view_scale(zoom, {mx,my}, 6)
  end
  combat.view_scale(zoom, {mx,my}, 6)
  get_hover(mx,my)
end
--


function target.draw(_box,c)
  if not active then return end
  c = c or {1,1,1,alpha}

  local box = _box or box

  if not _box then
    for i,v in pairs(chosen) do
      if v.box then target.draw(v.box,{1,1,0.5,alpha}) end
    end
  end

  c = {c[1]*1,c[2]*1,c[3]*1,alpha*0.4} lg.setColor(c)
  lg.setLineWidth(2)
  lg.rectangle("line",box.x,box.y,box.w,box.h,5,5)
  lg.setLineWidth(1)
  lg.rectangle("fill",box.x,box.y,box.w,box.h,5,5)

  local base = _box and 0 or arrow.base_rotation
  local rotation = base
  local function rot(reset) rotation = reset and base or rotation + math.pi/2 return reset and base or rotation end

  local y_off = (current and not _box) and arrow.img:getHeight()/2 or 0

  --arrow outlines
  lg.setColor(c[1]*0,c[2]*0,c[3]*0,alpha/4)
  lg.draw(arrow.img,box.x-arrow.offset,box.y+box.h/2, rot(true), 1.2, nil, arrow.img:getWidth()/2, arrow.img:getHeight()/2)
  lg.draw(arrow.img,box.x+box.w/2,box.y-y_off-arrow.offset, rot(), 1.2, nil, arrow.img:getWidth()/2, arrow.img:getHeight()/2)
  lg.draw(arrow.img,box.x+box.w+arrow.offset,box.y+box.h/2, rot(), 1.2, nil, arrow.img:getWidth()/2, arrow.img:getHeight()/2)
  lg.draw(arrow.img,box.x+box.w/2,box.y+box.h+y_off+arrow.offset, rot(), 1.2, nil, arrow.img:getWidth()/2, arrow.img:getHeight()/2)
  --arrows
  c = {c[1]*1,c[2]*1,c[3]*1,alpha*0.8} lg.setColor(c)
  lg.draw(arrow.img,box.x-arrow.offset,box.y+box.h/2, rot(true), nil, nil, arrow.img:getWidth()/2, arrow.img:getHeight()/2)
  lg.draw(arrow.img,box.x+box.w/2,box.y-y_off-arrow.offset, rot(), nil, nil, arrow.img:getWidth()/2, arrow.img:getHeight()/2)
  lg.draw(arrow.img,box.x+box.w+arrow.offset,box.y+box.h/2, rot(), nil, nil, arrow.img:getWidth()/2, arrow.img:getHeight()/2)
  lg.draw(arrow.img,box.x+box.w/2,box.y+box.h+y_off+arrow.offset, rot(), nil, nil, arrow.img:getWidth()/2, arrow.img:getHeight()/2)

end
--

function target.keypressed(key)
  if not active then return end
  if not current then current = 1 end
  if max_targets > 0 then
    if keyset.left(key) then
      current = current - 1
    elseif keyset.right(key) then
      current = current + 1
    elseif keyset.up(key) then
      list_index = math.clamp(1, list_index - 1, #list)
      current = math.ceil(#list[list_index]/2)
    elseif keyset.down(key) and skill then
      list_index = math.clamp(1, list_index + 1, #list)
      current = math.ceil(#list[list_index]/2)
    end
  end
  if block_input == 0 then
    if keyset.confirm(key) then
      return true, target.select()
    end
  end
  if keyset.back(key) then
    target.cancel()
    return true
  end
  current = math.clamp(1, current, #list[list_index])
  states.combat.keyboard_focus = 1
  for i,v in pairs(box_target) do
    box_target[i] = list[list_index][current].box[i]
  end
  return true
end
--

function target.mousepressed(x,y,b,t)
  if not active then return end
  if b == 2 then
    target.cancel()
  end
  return true
end
--

function target.mousereleased(x,y,b,t)
  if not active then return end
  if b == 2 then
    target.cancel()
    return true
  end
  local hit
  for i,v in pairs(list) do
    for ii,vv in pairs(v) do
      if Misc.checkPoint(x,y,vv.box) then
        hit = true
        if list_index == i and current == ii then return true, target.select() end
      end
    end
  end
  if hit then return true end
  target.cancel()
  return true
end
--

function target.cancel()
  active = false
  if skill then combat.queue.remove(1) end
  states.combat.changeMode(prev)
end
--

function target.finish(nxt,mode)
  active = false
  target.chosen = chosen
  states.combat.changeMode(mode or "idle", mode and ent_index or nxt)
end
--

function target.select()
  if max_targets > 0 and chosen[#chosen] ~= list[list_index][current] then
    chosen[#chosen+1] = list[list_index][current]
    if #chosen < math.abs(max_targets) and math.abs(max_targets) <= (#combat.enemy_info.list+#combat.info.list) then
      return
    end
  end
  active = false
  if skill then
    if ent:useAP(skill.cost) then
      combat.queue.list[1].flash = 1
      for i,v in pairs(chosen) do chosen[i] = v.ent end
      ent.cooldowns[skill.name:lower()] = skill.cooldown > 0 and skill.cooldown or nil
      event.push("ally_turn", {ent=ent, skill=skill.name, targets=chosen})
    end
    target.finish(ent.ap == 0)
  else
    target.finish(nil)
  end
end
--

setmetatable(target, { __index = function(_, ...) return function() end end})
return target