local ib = {}

local textbubble = require("textbubble")

local FONT_ = {
  fonts.combatinfo_large,
  fonts.combatinfo_med,
  fonts.combatinfo_med_small,
  fonts.combatinfo_small,
  fonts.combatinfo_damage,
}

local vignette_alpha = 0

local max_amount = 3

local col_list = {
  --white 
  {1,1,1},
  --blue
  {0.4,0.5,1},
  --red
  {1,0.5,0.4},
  --green
  {0.5,1,0.4},
  --yellow
  {0.8,1,0.4},
  --pink
  {1,0.75,0.5},
  --black
  {0.7,0.1,0.7},
}

ib.list = {}
ib.dead = {}
--

local canvas
local function draw_lines(b)
  b = b or b
  if not b then return end
  local x = b.box.x-15
  canvas = nil
  collectgarbage()
  canvas = lg.newCanvas(screen_width,b.box.y+b.box.h)
  lg.setCanvas({canvas,stencil=true})
  lg.clear()
  lg.push()
  local sx, sy = Misc.toGame()
  lg.scale(1/sx, 1/sy)
  lg.setLineWidth(10)
  for i=1,15 do
    lg.line(x+20*(i-1), b.box.y+b.box.h+15, x+20+20*(i-1), b.box.y-15)
  end
  lg.setLineWidth(1)
  lg.pop()
  lg.setCanvas()
end
event.wish({"window_reset"}, draw_lines)
--

local function new(ent)
  event.grant("new_ally",ent)
  local e = {}
  e.box = {
    x=15,
    y=screen_height-screen_height/4.5-15,
    w=(screen_width-(15+15*max_amount))/max_amount,
    h=screen_height/4.5,
    a=1,
    ta=1,
    overlay=0,
    overlay_speed=2,
    visible = true
  }
  e.col = 1
  e.ent = ent
  e.shake_param = {h=0,v=0}

  e.WIDTH = e.box.w-40
  e.difference = e.WIDTH

  e.box.x_orig = e.box.x
  e.box.y_orig = e.box.y
  e.box.tx = e.box.x
  e.box.ty = e.box.y

  e.box.ap = {}
  
  if states.combat.mode~="turn" and states.combat.mode~=0 then
    e.box.visible = false
    e.box.a = 0
    e.box.ta = 0
  end

  function e.white(spd)
    e.col = 1
    e.box.overlay = 0.5
    e.box.overlay_speed = spd or 2
  end
  function e.blue(spd)
    e.col = 2
    e.box.overlay = 1
    e.box.overlay_speed = spd or 2
  end
  function e.red(spd)
    e.col = 3
    e.box.overlay = 0.5
    vignette_alpha = 0.2
    e.box.overlay_speed = spd or 2
  end
  function e.green(spd)
    e.col = 4
    e.box.overlay = 0.6
    e.box.overlay_speed = spd or 2
  end
  function e.yellow(spd)
    e.col = 5
    e.box.overlay = 0.6
    e.box.overlay_speed = spd or 2
  end
  function e.pink(spd)
    e.col = 6
    e.box.overlay = 0.6
    e.box.overlay_speed = spd or 2
  end
  function e.purple(spd)
    e.col = 7
    e.box.overlay = 0.6
    e.box.overlay_speed = spd or 2
  end
  function e.speak(text)
    if not text then return end
    if type(text)~="table" then text = {tostring(text)} end
    textbubble(text,e.box.x+e.box.w/2,e.box.y)
  end
  function e.shake(amp,time)
    amp, time = amp or 8, time or 0.25
    e.shake_param.h, e.shake_param.v = amp, amp
    combat.flux:to(e.shake_param, time, {h=0,v=0}):ease("quadinout")
    love.system.vibrate(time/2)
  end
  function e.flashAP(good,amount)
    if not good and e.box.ap and e.box.ap.amount==amount then return end
    if not good then notify{"orange", ent.name, "white", " doesn't have enough AP."} end
    e.box.ap = {good=good,amount=amount,alpha=1}
  end
  function e.glowAP(amount,sin)
    local _, amount = e.ent:useAP(amount,true)
    if e.box.ap and e.box.ap.amount==amount then return end
    e.box.ap = {good=e.box.ap.good~=nil and e.box.ap.good or true,amount=amount-e.ent.ap,alpha=math.sin(sin or math.pi)*(5/4) - (1/4)}
  end
  function e.die()
    if e.ent==player then return end
    local _, index = ib.getByEnt(e.ent)
    e.red(nil,1)
    e.shake(nil,2)
    Misc.shake(nil,1)
    e.box.ta = 0
    table.insert(ib.dead, table.remove(ib.list, index))
    ib.reorder()
  end
  --
  function e.dismiss()
    if e.ent==player then return Misc.fade(combat.fled_battle, 1) end
    local _, index = ib.getByEnt(e.ent)
    e.box.ta = 0
    table.insert(ib.dead, table.remove(ib.list, index))
    ib.reorder()
  end
  --
  function e.update(self,dt)
    self.box.overlay = math.max(0, self.box.overlay - self.box.overlay_speed * dt)
    self.box.a = Misc.lerp(8*dt, self.box.a, self.box.ta)
    self.box.x = Misc.lerp(10*dt, self.box.x, self.box.tx)
    self.box.y = Misc.lerp(10*dt, self.box.y, self.box.ty)
    self.WIDTH = Misc.lerp(12*dt, self.WIDTH, math.max(0,(self.box.w-40)*(self.ent.hp/self.ent:getStat("max_hp"))))
    self.difference = Misc.lerp(5*dt, self.difference, self.WIDTH)
    if self.box.ap.alpha then
      self.box.ap.alpha = self.box.ap.alpha - 3 * dt
      if self.box.ap.alpha <= 0 then self.box.ap = {} end
    end
    for i,v in pairs(self.ent.damage_taken) do
      v.a = v.a - 1.5 * dt
      v.vel = Misc.lerp(7*dt, v.vel or 1000, 0)
      v.y = v.y - v.vel * dt 
      if v.a < 0 then
        table.remove(self.ent.damage_taken, i)
      end
    end
  end

  draw_lines(e)

  table.insert(ib.list, e)
end
--

function ib.show(index,instant)
  local s,e = index or 1, index or max_amount
  for i=s,e do
    local b = ib.list[i]
    if b then
      b.box.visible = true
      b.box.ty = b.box.y_orig
      b.box.ta = 1
      if instant then
        b.box.y = b.box.ty
        b.box.a = b.box.ta
      end
    end
  end
end
--
function ib.hide(index,instant)
  local s,e = index or 1, index or max_amount
  for i=s,e do
    local b = ib.list[i]
    if b then
      b.box.visible = false
      b.box.ty = screen_height+5
      b.box.ta = 0
      if instant then
        b.box.y = b.box.ty
        b.box.a = b.box.ta
      end
    end
  end
end
--
function ib.active(index,instant)
  index = index or 1
  local s,e = 1, #ib.list
  for i=s,e do
    local b = ib.list[i]
--    if i==index then b.box.ty = b.box.y_orig - 60 else b.box.ty = b.box.y_orig end
    if i==index then
      b.box.tx = 15
      b.box.ty = b.box.y_orig
      b.box.ta = 1
    elseif index > 0 and index <= #ib.list then
      b.box.tx = b.box.x_orig
      b.box.ta = 0
    elseif index <= 0 or index > #ib.list then
      b.box.tx = b.box.x_orig
      b.box.ta = 1
    end
    if instant then
      b.box.x = b.box.tx
    end
  end
end
--

function ib.getByEnt(ent)
  for i,v in pairs(ib.list) do
    if v.ent == ent then return v,i end
  end
  return
end
--

local function hp_bar(b)
  -- HP bar
  local x = b.box.x+20
  local y = b.box.y+b.box.h/1.75

  lg.setColor(0.3,0.2,0.2,1*b.box.a)
  lg.rectangle("fill",x,y,b.box.w-40,12)

  ---- the "behind" part that lowers slowly with lerp
  lg.setColor(0.8,0.15,0.15,0.8*b.box.a)
  lg.rectangle("fill",x,y,b.difference,12)

  ---- the red part, display HP with no lerping
  lg.setColor(0.92,0.3,0.3,1*b.box.a)
  lg.rectangle("fill",x,y,b.WIDTH,12)

  ---- subtle top and bottom lines, for definition
  lg.setColor(1,1,1,0.3*b.box.a)
  lg.line(x,y,x+b.WIDTH,y)
  lg.setColor(0.1,0.1,0.2,0.6*b.box.a)
  lg.line(x,y+12,x+b.box.w-40,y+12)
end
--
local function ap_bar(b)
  -- AP bar
  local x = b.box.x+20
  local y = b.box.y+b.box.h/1.75 + 12*2
  local pad = 5
  local w = ((b.box.w-40)/b.ent.stat.max_ap-pad)

  lg.setLineWidth(2)
  for i=1,b.ent.stat.max_ap do
--    local col = {0.22,0.62,0.3,1*b.box.a}
    local col = {0.3,0.65,0.2,1*b.box.a}
    local x = x + (i-1)*(w+pad)
    if i>b.ent.ap then col = {0.2,0.2,0.2,0.75*b.box.a} end
    lg.setColor(col)
    lg.polygon("fill",x,y+12,x+6,y,x+6+w,y,x+w,y+12)
    lg.setColor(1,1,1,0.1*b.box.a)
    lg.line(x+6,y+2,x+6+w,y+2)
    lg.setColor(0,0,0,0.15*b.box.a)
    lg.line(x,y+12-2,x+w,y+12-2)
    lg.setColor(1,1,1,0.2*b.box.a)
    lg.polygon("line",x,y+12,x+6,y,x+6+w,y,x+w,y+12)

--    if b.box.ap.good and i>b.ent.ap and i<=b.ent.ap+b.box.ap.amount then
    if b.box.ap.good and i<=b.ent.ap+b.box.ap.amount then
      lg.setColor(1,1,1,b.box.ap.alpha*b.box.a)
      lg.polygon("fill",x,y+12,x+6,y,x+6+w,y,x+w,y+12)
--    elseif b.box.ap.good==false and i>b.ent.ap and i<=b.box.ap.amount then
    elseif b.box.ap.good==false and i<=b.box.ap.amount then
      lg.setColor(1,0,0,b.box.ap.alpha*b.box.a)
      lg.polygon("fill",x,y+12,x+6,y,x+6+w,y,x+w,y+12)
    end
  end
  lg.setLineWidth(1)
end
--

local function infobox(b)
  b = b or b
  if not b then return end
  lg.push()
  if b.shake_param.h>0 then lg.translate(math.random(b.shake_param.h*2)-b.shake_param.h, math.random(b.shake_param.v*2)-b.shake_param.v) end

  if b.ent == player then lg.setColor(0.25,0.1,0,0.6*b.box.a) else lg.setColor(0,0,0,0.6*b.box.a) end
  lg.rectangle("fill",b.box.x, b.box.y, b.box.w, b.box.h, 10, 10)
  lg.setColor(1,1,1,0.2*b.box.a)
  lg.rectangle("line",b.box.x, b.box.y, b.box.w, b.box.h, 10, 10)

  lg.setColor(1,1,1,0.9*b.box.a)
  lg.setFont(FONT_[4])
  local p1 = "Lv "
  lg.printf(p1, b.box.x+20, b.box.y+42, b.box.w-40, "left")

  lg.setFont(FONT_[2])
  lg.printf(b.ent.lvl, b.box.x+20+FONT_[4]:getWidth(p1), b.box.y+25, b.box.w-40, "left")

  hp_bar(b)
  ap_bar(b)

  col_list[b.col][4] = b.box.overlay
  lg.setColor(col_list[b.col])
  lg.rectangle("fill",b.box.x, b.box.y, b.box.w, b.box.h, 5, 5)

  lg.setFont(FONT_[1])
  lg.setColor(1,1,1,0.9*b.box.a)
  lg.printf(b.ent.name,b.box.x,b.box.y, b.box.w, "center")
  lg.setFont(FONT_[4])
  lg.setColor(1,1,1,0.85*b.box.a)
  lg.printf("HP: "..b.ent.hp.."/"..b.ent.stat.max_hp, b.box.x+20, b.box.y+40, b.box.w-40, "right")
  lg.setColor(1,1,1,0.5*b.box.a)
  Misc.fadeline(b.box.x, b.box.y+28, nil, b.box.w, 1)

  lg.pop()

  -- Damage numbers
  for _,v in pairs(b.ent.damage_taken) do
    local font, col, amount = FONT_[5], {1,1/3,1/3,v.a}, v.d
    if v.d==0 then
      col = {1,1,1,v.a}
      amount = "MISS"
    elseif tonumber(v.d)<0 then
      amount = "+"..math.abs(v.d)
      col = {0.3,1,0.4,v.a}
    end
    lg.setFont(font)
    lg.setColor(0,0,0,v.a)
    for o=-1,1,2 do
      lg.print(amount,math.floor(b.box.x+b.box.w/2-font:getWidth(amount)/2+v.x)+o,math.floor(b.box.y+v.y))
      lg.print(amount,math.floor(b.box.x+b.box.w/2-font:getWidth(amount)/2+v.x),math.floor(b.box.y+v.y)+o)
    end
    lg.setColor(col)
    lg.print(amount,math.floor(b.box.x+b.box.w/2-font:getWidth(amount)/2+v.x),math.floor(b.box.y+v.y))
  end

  if b.box.ta == 0 or not b.box.visible then return end

  combat.drawStatuses(b)
end
--

function ib.update(dt,element)
  for _,b in pairs(ib.list) do b:update(dt) end
  for _,b in pairs(ib.dead) do b:update(dt) end
  textbubble.update(dt)
  vignette_alpha = vignette_alpha - 1.5 * dt
end
--

function ib.draw()
  for _,b in pairs(ib.list) do infobox(b) end
  for _,b in pairs(ib.dead) do infobox(b) end
  lg.setColor(1,0,0,vignette_alpha)
  lg.draw(vignette, 0, 0, nil, screen_width/vignette:getWidth(), screen_height/vignette:getHeight())
  textbubble.draw()
end
--

function ib.mousepressed(x,y,b,t)
  for _,v in pairs(ib.list) do
  end
end
--
function ib.mousereleased(x,y,b,t)
  for _,v in pairs(ib.list) do
  end
  if textbubble.mousereleased(x,y,b,t) then return true end
end
--

function ib.reorder()
  for i,v in pairs(ib.list) do
    v.box.tx =  screen_width/2 - (v.box.w/2)*(#ib.list) + (v.box.w+15)*(i-1) - (15/2)*(#ib.list-1)
    v.box.x_orig = v.box.tx
  end
end
--

function ib.clear()
  ib.list = {}
  ib.dead = {}
  vignette_alpha = 0
end
--

setmetatable(ib, {__call = function(_, ...) return new(...) end})
return ib