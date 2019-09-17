local te = {}
setmetatable(te, { __call = function(_, ...) return te.set(...) end})

local list = {}

local FONT_ = {
  fonts.combat_tell_bold,
}


local function flash(v)
  v.flash_alpha = 1
end
--

function te.set(ent,skill)
  local t = {}

  local info
  local a = combat.info.getByEnt(ent)
  local e = combat.enemy_info.getByEnt(ent)
  info = a or e
  if not info then return end
  info.white()

  t.entity = ent
  t.skill = Misc.capitalize(skill or "")

  t.w = {}
  t.w.w = FONT_[1]:getWidth(t.skill)+30
  t.w.h = FONT_[1]:getHeight(t.skill)+20
  t.w.x = info.box.x+info.box.w/2 - t.w.w/2
  if a then
    t.w.y = info.box.y-t.w.h+15
    t.target_y = t.w.y-30
  elseif e then
    t.w.y = info.box.y+info.box.h+30
    t.target_y = t.w.y-15
  end

  t.alpha = 1
  t.flash_alpha = 1
  states.combat.flux:to(t, 0.15, {alpha=1})
  states.combat.timer:after(1, function() te.done(t) end)
  table.insert(list, t)
  return true
end
--

function te.update(dt)
  if Misc.fade.lerping then return end
  for i,v in pairs(list) do
    if v.alpha <= 0 then list[i] = nil end
    if v.flash_alpha > 0 then 
      v.flash_alpha = v.flash_alpha - 4 * dt
    end
    if v.alpha ~= 0 then
      v.w.y = Misc.lerp(8*dt, v.w.y, v.target_y)
    end
  end
end
--

function te.draw()
  for i,v in pairs(list) do
    if v.alpha ~= 0 then
      local mod_setColor = lg.setColor
      if v.flash_alpha>0 then mod_setColor = function(r,g,b,a) return lg.setColor(1,1,1,v.flash_alpha) end end
      lg.setFont(FONT_[1])
      mod_setColor(0,0,0,0.85*v.alpha)
      lg.rectangle("fill", v.w.x, v.w.y, v.w.w, v.w.h, 5, 5)
      lg.setColor(1,1,1,0.3*v.alpha)
      lg.rectangle("line", v.w.x, v.w.y, v.w.w, v.w.h, 5, 5)
--      lg.setColor(1,0.8,0.4,0.9*v.alpha)
      lg.setColor(1,1,1,0.9*v.alpha)
      lg.printf(v.skill, v.w.x, v.w.y+10, v.w.w, "center")
    end
  end
end
--

function te.done(v)
  states.combat.flux:to(v, 0.3, {alpha=0})
  v.target_y = v.target_y+30
end
--

function te.clear()
  list = {}
end
--

return te