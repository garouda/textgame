local ib = {}

local textbubble = require("textbubble")

ib.list = {}
ib.dead = {}

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
      {1,0.6,0.85},
      --purple
      {0.7,0.1,0.7},
    }

local FONT_ = {
  fonts.combatinfo_large,
  fonts.combatinfo_med,
  fonts.combatinfo_small,
  fonts.combatinfo_damage,
}

local offsets = {
  [1] = {{x=0,y=0}},
  [2] = {{x=-screen_width/(10/3)/2-15,y=0},{x=screen_width/(10/3)/2+15,y=0}},
--  [3] = {{x=0,y=0},{x=-screen_width/3,y=-60},{x=screen_width/3,y=-60}},
  [3] = {{x=-screen_width/3,y=-60},{x=0,y=0},{x=screen_width/3,y=-60}},
}

local function drawName(w)
  if not w.ent or not next(w.ent or {}) then return end
  local name = w.ent.name
  w.namecanv=lg.newCanvas()
  lg.setCanvas({w.namecanv,stencil=true})
  lg.clear()
  local sx, sy = Misc.toGame()
  lg.push() lg.scale(1/sx, 1/sy) lg.translate(5,5)

  lg.setFont(FONT_[1])
  for o=-1,1,2 do
    lg.setColor(0,0,0,0.8)
    lg.print(name,0+o,0)
    lg.print(name,0,0+o)
    lg.setColor(0,0,0,0.2)
    lg.print(name,0+o*2,0)
    lg.print(name,0,0+o*2)
    lg.setColor(0,0,0,0.1)
    lg.print(name,0+o*3,0)
    lg.print(name,0,0+o*3)
  end  
  lg.setColor(1,1,1,1*w.box.a)
  lg.print(name,0,0)

  lg.pop()
  lg.setCanvas()
end
--

event.wish({"combat_start", "window_reset"}, function() for i,v in pairs(ib.list) do drawName(v) end end)

local function new(ent)
  if not ent or #ib.list==max_amount then return end
  local w = {}

  event.grant("new_enemy",ent)
  w.enemy = true
  w.ent = ent
  w.box = {
    x = 30,
    y = screen_height/5,
    w = screen_width/(10/3),
    h = screen_height/6,
    a = 1,
    ta = 1,
    --The colored "flash" that appears in reaction to certain things, such as taking damage.
    overlay = 0,
    overlay_speed = 2,
  }
  w.box.x = screen_width/2 - w.box.w/2
  w.box.y = w.box.y
  w.box.tx = w.box.x
  w.box.ty = w.box.y
  w.box.by = w.box.y
  w.box.tw = w.box.w
  w.shake_param = {h=0,v=0}
  w.original = Misc.tcopy(w.box)  
  local y_speed = 10

  local col = 1
  local WIDTH = w.box.w-40
  local difference = WIDTH
  local freeze_diff = 0

  w.namecanv = lg.newCanvas()
  drawName(w)

--Draw function for the box containing all the ent info.
  local function BigBox()
    lg.setColor(0.15,0,0,0.95*w.box.a)
    lg.rectangle("fill",w.box.x, w.box.y, w.box.w, w.box.h, 5, 5)
    lg.setColor(1,1,1,0.2*w.box.a)
    lg.rectangle("line",w.box.x, w.box.y, w.box.w, w.box.h, 5, 5)

    lg.setColor(1,1,1,0.9*w.box.a)
    lg.setFont(FONT_[3])
    local p1 = "Lv. "..ent.lvl
    lg.printf(p1,w.box.x,w.box.y+18,w.box.w,"center")


    lg.setColor(0.3,0.22,0.22,1*w.box.a)
    lg.rectangle("fill",w.box.x+20,w.box.y+w.box.h/1.5,w.box.w-40,16)
    --The "behind" part that lowers slowly with lerp
    lg.setColor(0.65,0.15,0.15,0.8*w.box.a)
    lg.rectangle("fill",w.box.x+20,w.box.y+w.box.h/1.5,difference,16)
    --The "in front" part that lowers quickly
    lg.setColor(0.9,0.3,0.3,1*w.box.a)
    lg.rectangle("fill",w.box.x+20,w.box.y+w.box.h/1.5,WIDTH,16)
    --The "cap" piece
    lg.setColor(1,0.7,0.7,0.8*w.box.a)
    lg.rectangle("fill",w.box.x+20+WIDTH,w.box.y+w.box.h/1.5,2,16)
    --Highlight
    lg.setColor(1,1,1,0.3*w.box.a)
    lg.line(w.box.x+20,w.box.y+w.box.h/1.5,w.box.x+20+WIDTH,w.box.y+w.box.h/1.5)
    --Shading
    lg.setColor(0.1,0.1,0.2,0.6*w.box.a)
    lg.line(w.box.x+20,w.box.y+w.box.h/1.5+16,w.box.x+20+w.box.w-40,w.box.y+w.box.h/1.5+16)

    --Draw the overlay (just a solid rectangle)
    col_list[col][4] = w.box.overlay
    lg.setColor(col_list[col])
    lg.rectangle("fill",w.box.x, w.box.y, w.box.w, w.box.h, 5, 5)

    lg.setColor(1,1,1,w.box.a)
    lg.draw(w.namecanv,w.box.x+w.box.w/2-FONT_[1]:getWidth(ent.name)/2-5,w.box.y-15-5)

    combat.drawStatuses(w)
  end
--

  function w.check(stroke)
    local function checkIntersect(l1p1, l1p2, l2p1, l2p2)
      local function sign(n) return n>0 and 1 or n<0 and -1 or 0 end
      local function  checkDir(pt1, pt2, pt3) return sign(((pt2.x-pt1.x)*(pt3.y-pt1.y)) - ((pt3.x-pt1.x)*(pt2.y-pt1.y))) end
      return (checkDir(l1p1,l1p2,l2p1) ~= checkDir(l1p1,l1p2,l2p2)) and (checkDir(l2p1,l2p2,l1p1) ~= checkDir(l2p1,l2p2,l1p2))
    end
    local ww,h = w.box.w, w.box.h
    local x,y = w.box.x, w.box.y
    if checkIntersect(stroke.tail,stroke.head, {x=x,y=y},{x=x+ww,y=y})
    or checkIntersect(stroke.tail,stroke.head, {x=x,y=y},{x=x,y=y+h})
    or checkIntersect(stroke.tail,stroke.head, {x=x+ww,y=y},{x=x+ww,y=y+h})
    or checkIntersect(stroke.tail,stroke.head, {x=x,y=y+h},{x=x+ww,y=y})
    or stroke.tail.x > x and stroke.tail.y > y and stroke.tail.x < x+ww and stroke.tail.y < y+h
    or stroke.head.x > x and stroke.head.y > y and stroke.head.x < x+ww and stroke.head.y < y+h
    then
      return 1
    end
    return 0
  end
--

  function w.speak(text)
    if not text then return end
    if type(text)~="table" then text = {tostring(text)} end
    textbubble(text,w.box.x,w.box.y)
  end
--

  function w.move(y)
    w.box.ty = y
  end
--

  function w.shake(amp,time)
    amp, time = amp or 8, time or 0.3
    w.shake_param.h, w.shake_param.v = amp, amp
    combat.flux:to(w.shake_param, time, {h=0,v=0}):ease("quadinout")
    love.system.vibrate(time/2)
  end
--

  function w.push(func)
    if w.box.ty ~= w.original.y then return false end

    func = func or function() end

    w.white()
    combat.timer:script(function(wait)
        y_speed = 10
        wait(0.15)
        y_speed = 30
        w.box.ty = screen_height/3
        wait(0.08)
        func()
        w.box.ty = w.original.y
        y_speed = 15
      end)
    return true
  end
--

  function w.white(spd,alpha)
    w.box.overlay = alpha or 0.8
    col = 1
    w.box.overlay_speed = spd or 2
  end
--

  function w.blue(spd,alpha)
    w.box.overlay = alpha or 1
    col = 2
    w.box.overlay_speed = spd or 2
  end
--

  function w.red(spd,alpha)
    if w.box.overlay ~= 0 and col~=3 then return end
    w.box.overlay = alpha or 0.5
    freeze_diff = 0.3
    col = 3
    w.box.overlay_speed = spd or 2
  end
--

  function w.green(spd,alpha)
    w.box.overlay = alpha or 0.8
    col = 4
    w.box.overlay_speed = spd or 2
  end
--

  function w.yellow(spd,alpha)
    w.box.overlay = alpha or 0.8
    col = 5
    w.box.overlay_speed = spd or 2
  end
--

  function w.pink(spd,alpha)
    w.box.overlay = alpha or 0.8
    col = 6
    w.box.overlay_speed = spd or 2
  end
--
  function w.purple(spd,alpha)
    w.box.overlay = alpha or 0.8
    col = 7
    w.box.overlay_speed = spd or 2
  end
--

  function w.die()
    local _, index = ib.getByEnt(w.ent)
    w.red(nil,1)
    w.shake(nil,2)
    Misc.shake(nil,1)
    w.box.ta = 0
    combat.removeEnemyByEnt(w.ent)
    table.insert(ib.dead, table.remove(ib.list, index))
    ib.reorder()
  end
--

  function w.dismiss()
    --if true then return end
    local _, index = ib.getByEnt(w.ent)
    w.box.ta = 0
    combat.removeEnemyByEnt(w.ent)
    table.insert(ib.dead, table.remove(ib.list, index))
    ib.reorder()
  end
  --

  function w.update(dt)
    for i,v in pairs(ent.damage_taken) do
      --Lower alpha
      ent.damage_taken[i].a = v.a - 1.5 * dt
      --Fall downward
      ent.damage_taken[i].vel = (v.vel or -300) + 1200 * dt
      ent.damage_taken[i].y = v.y + v.vel * dt 
      if v.a < 0 then
        ent.damage_taken[i] = nil
      end
    end
    w.box.a = Misc.lerp(5*dt, w.box.a, w.box.ta)
    w.box.overlay = math.max(0, w.box.overlay - w.box.overlay_speed * dt)
    w.box.y = Misc.lerp(y_speed*dt, w.box.y, w.box.ty)
    w.box.x = Misc.lerp(y_speed*dt, w.box.x, w.box.tx)
    w.box.w = Misc.lerp(y_speed*dt, w.box.w, w.box.tw)
    if freeze_diff == 0 then
      difference = Misc.lerp(5*dt, difference, WIDTH)
    end
    WIDTH = Misc.lerp(10*dt, WIDTH, math.max(0,(w.box.w-40)*(ent.hp/ent:getStat("max_hp"))))
    freeze_diff = math.max(0, freeze_diff - dt)
  end
--

  function w.draw()
    lg.push()
    if w.shake_param.h>0 then lg.translate(math.random(w.shake_param.h*2)-w.shake_param.h, math.random(w.shake_param.v*2)-w.shake_param.v) end
    BigBox()
    lg.pop()

    -- Damage numbers
    for _,v in pairs(ent.damage_taken) do
--      local font, col, amount = FONT_[4], {1,3/4,3/4,v.a}, v.d
      local font, col, amount = FONT_[4], {1,1,1,v.a}, v.d
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
        lg.print(amount,math.floor(w.box.x+w.box.w/2-font:getWidth(amount)/2+v.x)+o,math.floor(w.box.y+w.box.h/1.5-10+v.y))
        lg.print(amount,math.floor(w.box.x+w.box.w/2-font:getWidth(amount)/2+v.x),math.floor(w.box.y+w.box.h/1.5-10+v.y)+o)
      end
      lg.setColor(col)
      lg.print(amount,math.floor(w.box.x+w.box.w/2-font:getWidth(amount)/2+v.x),math.floor(w.box.y+w.box.h/1.5-10+v.y))
    end

  end
--
  table.insert(ib.list,w)
  return w
end
--

function ib.update(dt,element)
  for _,b in pairs(ib.list) do b.update(dt) end
  for _,b in pairs(ib.dead) do b.update(dt) end
  textbubble.update(dt)
end
--

function ib.draw()
  for _,b in pairs(ib.list) do b.draw() end
  for _,b in pairs(ib.dead) do b.draw() end
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

function ib.show(index,instant)
  local s,e = index or 1, index or max_amount
  for i=s,e do
    local b = ib.list[i]
    if b then
      b.box.ta = 1
      if instant then
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
      b.box.ta = 0
      if instant then
        b.box.a = b.box.ta
      end
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

function ib.reorder()
  for i,v in pairs(ib.list) do
    v.box.tx = v.original.tx+offsets[#ib.list][i].x
    v.box.ty = v.original.ty+offsets[#ib.list][i].y
    if #ib.list == 1 then
      v.box.tw = screen_width/2
      v.box.tx = screen_width/2-(v.box.tw/2)
    else
      v.box.tw = v.original.w
    end
  end
end
--

function ib.clear()
  for i,v in pairs(ib.list) do
    event.endWish("window_reset",v)
    event.endWish("combat_start",v)
  end
  ib.list = {}
  ib.dead = {}
end
--

setmetatable(ib, {__call = function(_, ...) return new(...) end})
return ib
