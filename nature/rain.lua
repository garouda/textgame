local ws = {rate = 0}
local sprites = {lg.newImage("res/img/rain.png"), lg.newImage("res/img/rain_hit.png")}
local rain = lg.newParticleSystem(sprites[1],100)
local splash = lg.newParticleSystem(sprites[2],100)

local trigger_lightning = 0
local bg_interpolate
local old_bg
local lspeed = 0
local oncomplete

ws.name = "Rainy"

local function setup_particles()
  rain:reset()
  rain:setRotation(-(weather.wind_direction/10)*4)
  rain:setEmissionArea("uniform",screen_width*math.max(1, 1+rain:getRotation()),1)
  rain:setEmissionRate(ws.rate)
  rain:setEmitterLifetime(-1)
  rain:setSpeed(screen_height*5)
  rain:setDirection(math.pi/2+(rain:getRotation()))
  local life = (screen_height-50)*(1+math.abs(rain:getRotation())) / rain:getSpeed()
  rain:setParticleLifetime(life*0.9,life)
  rain:setOffset(8,8)
  rain:setSizes(1)
  rain:setSizeVariation(0)
  rain:setColors(1,1,1,0.175, 1,1,1,0.15, 1,1,1,0)

  splash:reset()
  splash:setEmissionArea("uniform",screen_width,screen_height/20)
  splash:setEmissionRate(ws.rate)
  splash:setEmitterLifetime(-1)
  splash:setParticleLifetime(0.15,0.3)
  splash:setOffset(8,8)
  splash:setSizes(0.5,1)
  splash:setSizeVariation(0)
  splash:setColors(1,1,1,0.175, 1,1,1,0)
end

local function lightning()
  if bg_interpolate then
    Misc.background_color_add = {0,0,0}
    bg_interpolate:stop()
  end
  Misc.background_color_add[3] = 1
  Misc.background_color_add[2] = -(Misc.background_color[2]-(Misc.background_color[2]*0.8))
  bg_interpolate = Flux.to(Misc.background_color_add, math.random(75,125)/100, {0,0,0})
  trigger_lightning = math.random(3,25)
end
--
event.wish("flash",function() if weather.get()==2 or weather.get()==4 then lightning() end end)

function ws.start(spd)
  lspeed = spd
  if lspeed == 0 then ws.rate = 500 end
  trigger_lightning = math.random(3,25)
  setup_particles()
  rain:start()
  splash:start()
  return true
end
--

function ws.update(dt)
  if lspeed~=0 then ws.rate = math.clamp(0, ws.rate + 500 * dt / lspeed, 500) end
  if ws.rate == 0 and oncomplete then oncomplete() oncomplete = nil end

  if rain:getEmissionRate() >= 250 then
    trigger_lightning = trigger_lightning - dt
    if trigger_lightning <= 0 then
      lightning()
    end
  end
  rain:setEmissionRate(ws.rate)
  rain:update(dt)
  splash:setEmissionRate(ws.rate)
  splash:update(dt)
end
--

function ws.draw()
  lg.draw(rain,0,-50)
  lg.draw(splash,0,screen_height-screen_height/20)
end
--

function ws.finish(spd,after)
  after = after or function() end
  oncomplete = function()
    rain:stop()
    splash:stop()
    after()
  end
  lspeed = -spd
  if lspeed == 0 then ws.rate = 0 oncomplete() oncomplete = nil end
end
--

setmetatable(ws, { __index = function() return function() end end})
return ws