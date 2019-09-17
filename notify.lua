local nt = {list = {}}
nt.__index = nt
setmetatable(nt, {__call = function(_, ...) return nt.new(...) end})

local queue = {}

local FONT_ = {
  fonts.notify,
  fonts.notify_bold,
}
--

local lookup = { 
  red = {0.9, 0.2, 0.04, 1},
  orange = {0.9,0.6,0.15, 1},
  yellow = {0.95,0.84,0.08, 1},
  green = {0, 0.8, 0.4, 1},
  blue = {0, 0.6, 1, 1},
  purple = {0.8,0.4,1, 1},
  pink = {1,0.6,0.9, 1},
  white = {1,1,1, 1},
  grey = {0.5,0.5,0.5, 1},
}

function nt.new(text)
  if type(text)~="table" then text = {lookup.white,tostring(text)} end
  if #nt.list>0 and nt.list[#nt.list].lifetime > 1.65 then return table.insert(queue, text) end
  local params = {
    alpha=0,
    xo=5,
    yo=5,
    box = {
      x=screen_width/2,
      y=screen_height/2,
      w=screen_width/2,
      h=FONT_[1]:getHeight()+10,
    },
  }
  for i=1,#text,2 do if type(text[i])=="string" then text[i] = lookup[text[i]] or lookup.white end end
  params.text = lg.newText(FONT_[1])
  params.text:set(text)
  
  params.text_w = 0
  for i=2,#text,2 do params.text_w = params.text_w + FONT_[1]:getWidth(text[i]) end

  params.box.w = params.text_w+15

  params.og = text

  params.box.x = screen_width-params.box.w
  params.box.y = params.box.y - params.box.h/2

  params.fly_in = params.box.w+params.xo
  params.float_up = 0
  params.up = 0
  params.lifetime = 2

  for i,v in pairs(nt.list) do nt.list[i].float_up = nt.list[i].float_up + v.box.h end
  if #nt.list==5 then table.remove(nt.list, 1) end
  table.insert(nt.list, params)
  return params
end
--

function nt.update(dt)
  if #queue>0 and nt.list[#nt.list].lifetime <= 1.65 then nt.new(table.remove(queue,1)) end
  for i=1,#nt.list do
    local n = nt.list[i]
    n.lifetime = n.lifetime - 1 * dt
    if n.lifetime >= 0 then n.alpha = math.min(n.alpha + 2 * dt, 1) else n.alpha = math.min(n.alpha - 1 * dt, 1) end
    n.fly_in = math.max(n.fly_in - n.fly_in * 10 * dt, 0)
    n.up = math.min(n.up + n.box.h * 2 * dt, n.float_up)
  end
end
--

function nt.draw()
  lg.setFont(FONT_[1])
  for i=1,#nt.list do
    local n = nt.list[i]
    if nt.list[i-1] then
      local b = nt.list[i-1]
    end
    lg.setColor(1,1,1,n.alpha/3)
    lg.draw(fadegradient, n.box.x+20-1, n.box.y-n.up-1, nil, (60+2)/-fadegradient:getWidth(), n.box.h+2)
    lg.rectangle("fill", n.box.x+20-1, n.box.y-n.up-1, n.box.w+2, n.box.h+2)
    lg.setColor(0,0,0,n.alpha)
    lg.draw(fadegradient, n.box.x+20, n.box.y-n.up, nil, 60/-fadegradient:getWidth(), n.box.h)
    lg.rectangle("fill", n.box.x+20, n.box.y-n.up, n.box.w, n.box.h)
    lg.setColor(1,1,1,n.alpha)
    lg.draw(n.text, n.box.x+n.fly_in, n.box.y+n.yo-n.up)
  end
end
--

function nt.clear()
  nt.list = {}
  queue = {}
end
--

return nt