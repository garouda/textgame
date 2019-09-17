local ws = {alpha = 0}
local fog = {img=lg.newImage("res/img/fog.png"), x=-screen_width}
fog.img:setWrap("mirroredrepeat", "mirroredrepeat")
local quad = lg.newQuad(0, 0, screen_width*3, screen_height, screen_width, screen_height)
local dir = 1

local lspeed = 0
local oncomplete = function() end

ws.name = "Fog"

local canvas

function ws.start(spd)
  lspeed = spd
  if lspeed == 0 then ws.alpha = 1 end
  dir = weather.wind_direction
  return true
end
--

function ws.update(dt)
  if lspeed~=0 then ws.alpha = math.clamp(0, ws.alpha + 1 * dt / lspeed, 1) end
  if ws.alpha == 0 and oncomplete then oncomplete() oncomplete = nil end
  
  local spd = 500
  fog.x = fog.x + dir * spd * dt
  if fog.x < -screen_width*2 then fog.x = fog.x + screen_width*2 end
  if fog.x > 0 then fog.x = fog.x - screen_width*2 end
end
--

function ws.drawOver()
  lg.stencil(function() lg.rectangle("fill", 0, 0, screen_width, screen_height) end, "replace", 1)
  lg.setStencilTest("equal", 1)
  lg.setColor(1,1,1,ws.alpha/3)
  lg.draw(fog.img, quad, fog.x, 0)
  lg.setStencilTest()
end
--

function ws.finish(spd,after)
  after = after or function() end
  oncomplete = function() after() end
  lspeed = -spd
  if lspeed == 0 then ws.alpha = 0 oncomplete() oncomplete = nil end
end
--

setmetatable(ws, { __index = function() return function() end end})
return ws