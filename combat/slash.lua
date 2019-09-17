local stroke_img = lg.newImage("res/img/stroke.png")
local dotted_line = lg.newImage("res/img/dotted_line.png")
local dotted_line_alpha = 1
local decay
local head
local began
local slsh = {}
local explosions = {}
local slashes = {}

local function explode(point,i)
  point.col = {1,1,1,1}
  point.r = 0
  table.insert(explosions,(i or #explosions+1), point)
end
--
local function add(s,param)
  param = param or {}
  s.alpha = s.alpha or 2
  s.crit = param.crit
  s.only_explode = param.only_explode

  if s.crit then Misc.shake(10,0.35) else Misc.shake(2,0.2) end
  local p = {
    x = (s.tail.x+s.head.x)/2,
    y = (s.tail.y+s.head.y)/2,
  }
  explode(p,#slashes+1)
  table.insert(slashes,s)
end
--

function slsh.new(target,param)
  local x = math.random(target.box.x+target.box.w/4,target.box.x+target.box.w-target.box.w/4)
  local y = math.random(target.box.y+target.box.h/4,target.box.y+target.box.h-target.box.h/4)
  local factor = screen_height*0.5
  local ox, oy = math.random(-factor,factor), math.random(-factor,factor)
  local distance = math.sqrt(((x-ox)-(x+ox))^2 + ((y-oy)-(y+oy))^2)
  while math.abs(distance) < factor do
    ox, oy = math.random(-factor/2,factor), math.random(-factor/2,factor)
    distance = math.sqrt(((x-ox)-(x+ox))^2 + ((y-oy)-(y+oy))^2)
  end
  local s = {
    head = {x=x+ox,y=y+oy},
    tail = {x=x-ox,y=y-oy},
    began = love.timer.getTime(),
    ended = love.timer.getTime(),
    distance = distance
  }
  add(s,param)  
end
--

function slsh.update(dt)
  for i,v in pairs(slashes) do
    if v.crit then decay = 0.6 else decay = 0.75 end
    v.alpha = Misc.lerp(decay * 5 * dt, v.alpha, -0.1)
    if v.alpha <= 0 then
      slashes[i]=nil
    end

    v = explosions[i]
    if v then 
      v.r = Misc.lerp(6 * dt, v.r, 40)
      v.col[4] = v.col[4] - 1 * 3 * dt
      if v.col[4] <= 0 then explosions[i] = nil end
    end
  end
end
--

function slsh.draw()
  for i,v in pairs(slashes) do
    if not v.only_explode then
      local height = 0.4
      if v.crit then height = 0.75 end
      local w = math.min(v.distance/stroke_img:getWidth()*(2.25/(v.alpha)-1), v.distance/stroke_img:getWidth())
      local h = math.clamp(0, height*v.alpha, height)

      lg.setColor(0,0,0,v.alpha)
      lg.draw(stroke_img, v.head.x, v.head.y, math.atan2(v.tail.y-v.head.y,v.tail.x-v.head.x), w, h*1.15, nil, stroke_img:getHeight()/2)
      lg.setColor(1,1,1,v.alpha)
      if v.crit then lg.setColor(1,0.07,0.07,v.alpha) end
      lg.draw(stroke_img, v.head.x, v.head.y, math.atan2(v.tail.y-v.head.y,v.tail.x-v.head.x), w, h, nil, stroke_img:getHeight()/2)
    end
    v = explosions[i]
    if v then
      lg.setColor(0,0,0,v.col[4])
      lg.setLineWidth(2)
      lg.circle("line", v.x, v.y, v.r, 50)
      lg.circle("line", v.x, v.y, v.r*(v.r/20), 50)
      lg.setColor(1,1,1,v.col[4]*2)
      lg.setLineWidth(1)
      lg.circle("line", v.x, v.y, v.r, 50)
      lg.circle("line", v.x, v.y, v.r*(v.r/20), 50)
      if slashes[i].only_explode then
        lg.circle("line", v.x, v.y, v.r*(v.r/14), 50)
      end
    end    
  end
end
--

function slsh.clear()
  head = nil
  slashes = {}
end
--

function slsh.getExplosion(index)
  return explosions[index or #explosions]
end
--

setmetatable(slsh, {__call = function(_, ...) return slsh.new(...) end})
return slsh