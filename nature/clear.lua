local ws = {}

ws.name = "Clear"

function ws.start(spd)
  particles.bokeh:start()
end
--

function ws.update(dt)
end
--

function ws.draw()
end
--

function ws.finish(spd,after)
  after = after or function() end
  particles.bokeh:stop()
  after()
end
--

setmetatable(ws, { __index = function() return function() end end})
return ws