local queue = {}

local FONT_ = {
  fonts.planning_info_small,
}
--

local len = 0
local alpha = 2/3
local box = {
  x = 15,
  y = (FONT_[1]:getHeight()+15)*6+15*2,
  w = screen_width/6,
  h = FONT_[1]:getHeight()+10,
}
box.oy = box.y
box.by = box.y
box.ty = box.y

queue.list = next(queue.list or {}) and queue.list or {}
queue.dead = next(queue.dead or {}) and queue.dead or {}

function queue.reset()
  queue.list = {}
  queue.dead = {}
  box.y = box.oy
  box.ty = box.y
end
--

function queue.add(q,index)
  if #q == 0 then box.y = box.oy end
  local s = {
    msg=nil,
    y=box.y, x=-15, tx=0, ty=0, w=0, h=box.h,
    alpha=0,
    talpha=1,
    flash=0,
  }
  for i,v in pairs(q) do
    s[i] = v
  end
  s.msg = s.msg or tostring(s.ent.name)..": "..s.skill
  s.w = FONT_[1]:getWidth(s.msg)+100
  if index then queue.list[index] = s else table.insert(queue.list,1,s) end
  len = len + 1
  box.y = box.oy
end
--
function queue.remove(index)
  index = index or 1
  if index < 0 then index = #queue.list+(index+1) end
  len = len - 1
  queue.list[index].tx = box.x+box.w
  queue.list[index].talpha = -0.1
  table.insert(queue.dead, table.remove(queue.list,index))
end
--
function queue.update(dt)
  for _,t in pairs{queue.list,queue.dead} do
    for i,v in pairs(t) do
      v.ty = box.y-(box.h+15)*(i-1)
      v.alpha = Misc.lerp(10*dt, v.alpha, v.talpha)
      v.x = Misc.lerp(5*dt, v.x, v.tx)
      v.y = Misc.lerp(10*dt, v.y or v.ty, v.ty) 
      v.flash = math.max(0, v.flash - 3 * dt)
      if v.alpha < 0 then t[i] = nil end
    end
  end
end
--
function queue.draw()
  for _,t in pairs{queue.list,queue.dead} do
    local a = alpha
    for i,v in ipairs(t) do
      local a = a*v.alpha
      local y = v.y
      if y+box.h < 1 then a = 0 end
      lg.push() lg.translate(v.x)
      if v.enemy then lg.setColor(0.2,0.05,0,1*a) else lg.setColor(0,0,0,1*a) end
      lg.polygon("fill",
        box.x, y,
        box.x+v.w-20, y,
        box.x+v.w, y+box.h/2,
        box.x+v.w-20, y+box.h,
        box.x, y+box.h)
      lg.polygon("line",
        box.x-2, y-2,
        box.x-2+v.w+4-20, y-2,
        box.x-2+v.w+4, y-2+(box.h+4)/2,
        box.x-2+v.w+4-20, y-2+box.h+4,
        box.x-2, y-2+box.h+4)
      lg.setColor(1,1,1,0.8*a)
      lg.polygon("line",
        box.x, y,
        box.x+v.w-20, y,
        box.x+v.w, y+box.h/2,
        box.x+v.w-20, y+box.h,
        box.x, y+box.h)
      lg.draw(squarrow, box.x-7.5, y+box.h/2-squarrow:getHeight()/2)
      lg.setFont(FONT_[1])
      lg.setColor(1,1,1,2*a)
      lg.printf(v.msg, box.x, y+box.h/2-FONT_[1]:getHeight()/2, v.w, "center")
      if v.flash > 0 then
        lg.setColor(1,1,1,1*v.flash)
        lg.polygon("fill",
          box.x, y,
          box.x+v.w-20, y,
          box.x+v.w, y+box.h/2,
          box.x+v.w-20, y+box.h,
          box.x, y+box.h)
      end
      lg.pop()
      lg.setLineWidth(1)
    end
  end
end
--

local function _turn_skill(list,moment,wait)
  -- We need to transfer entries to a proxy list so that we can safely pop and shift entities from the real table.
  -- This solves the issue of enemies dying from turn-start or turn-end effects and displacing indices (causing some entities to have their turn effects skipped).
  local proxy_list = {}
  for i,v in pairs(list) do proxy_list[i] = v end
  for i,v in pairs(proxy_list) do
    for _,d in pairs(combat.retrieveData(v.ent,"turn_"..moment.."_skill") or {}) do
      local targets = {(d.target==0) and d.from or (d.target>0) and v.ent} or {}
      local from = (d.target==0 and v.ent) or d.from
      local param = {no_ap=true, accurate=true, no_cd=true}
      for i,v in pairs(d) do param[i] = param[i] or v end
      from:skill(d.skill, targets, param)
      wait(0.5)
    end
  end
end
--

event.wish("turn_start", function(q,wait)
    queue.list = {}
    queue.dead = {}

    Misc.msort(q, function(f,s)
        local o, t = 0, 0
        for i,v in pairs(combat.skills(f.skill).actions) do
          o = math.max(o, (v.attrib.priority and 9999 or 0) + f.ent:getStat("speed"))
        end
        for i,v in pairs(combat.skills(s.skill).actions) do
          t = math.max(t, (v.attrib.priority and 9999 or 0) + s.ent:getStat("speed"))
        end
        return o > t
      end)

    for i,v in ipairs(q) do
      queue.add({ent=v.ent, msg=v.ent.name..": "..Misc.capitalize(v.skill), enemy=combat.enemy_info.getByEnt(v.ent)},i)
    end

    _turn_skill(combat.info.list,"start",wait)
    _turn_skill(combat.enemy_info.list,"start",wait)

    if not next(queue.list) then return end
    box.y = 15
  end)
event.wish("turn_end", function(wait)
    queue.list = {}
    _turn_skill(combat.info.list,"end",wait)
    _turn_skill(combat.enemy_info.list,"end",wait)
  end)
event.wish("action", function(a)
    if not next(queue.list) then return end
    queue.remove(1)
    while queue.list[1] and (not queue.list[1].ent or queue.list[1].ent.hp <= 0) do queue.remove(1) end
  end)
event.wish("entity_defeat", function(ent)
    if not next(queue.list) then return end
  end)
event.wish("combat_start", function(q,wait)
    queue.list, queue.dead = {}, {}
  end)
--

setmetatable(queue, { __index = function(_, ...) return function() end end})
return queue