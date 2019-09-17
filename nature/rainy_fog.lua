local ws = {}

ws.name = "Rainy Fog"

function ws.start(spd)
  for i=2,3 do
    if weather.current ~= i then
      weather.types[i].start(spd)
    end
  end
end
--

function ws.update(dt)
  for i=2,3 do weather.types[i].update(dt) end
end
--

function ws.draw()
  for i=2,3 do weather.types[i].draw() end
end
--

function ws.drawOver()
  for i=2,3 do weather.types[i].drawOver() end
end
--

function ws.finish(spd,after)
  for i=2,3 do
    local a
    if i==3 then a = after end
    weather.types[i].finish(spd, a)
  end
end
--

setmetatable(ws, { __index = function() return function() end end})
return ws