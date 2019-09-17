local wt = {}

wt.types = {require("nature.clear"),require("nature.rain"),require("nature.fog"),require("nature.rainy_fog")}
setmetatable(wt.types, { __index = function(t) return t[1] end})

wt.restricted = nil

wt.timer = Timer.new()
wt.current = 1
wt.wind_direction = 1

function wt.update(dt)
  wt.types[wt.current].update(dt)  
  wt.timer:update(dt)
end
--

function wt.draw()
  lg.stencil(function() lg.rectangle("fill",0,0,screen_width,screen_height) end, "replace", 1)
  lg.setStencilTest("equal",1)
  wt.types[wt.current].draw()
  lg.setStencilTest()
end
--  

function wt.drawOver()
  wt.types[wt.current].drawOver()
end
--

function wt.get()
  return wt.current,wt.types[wt.current].name
end
--
  
function wt.set(n,spd)
  spd = spd or 10
  wt.restricted = nil
  if wt.current == n then return wt.types[wt.current].start(spd) end
  wt.wind_direction = math.random(500,1000)/1000*({-1,1})[math.random(1,2)]
  wt.types[wt.current].finish(spd, function() wt.current = n wt.types[wt.current].start(spd) end)
end
--

function wt.restrict()
  if wt.restricted then return end
  local spd = 1
  wt.restricted = wt.current
  wt.types[wt.current].finish(spd, function() wt.current = 1 wt.types[wt.current].start(spd) end)
end
--
function wt.release()
  local spd = 1
  if wt.restricted then return wt.set(wt.restricted,spd) end
end
--

return wt