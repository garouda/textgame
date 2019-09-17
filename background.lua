local bg = {}

local images = {}
local allowed_states = {}
local talpha = 0.15
--

function bg.set(filename)
  if not filename then return table.insert(images,1,{}) end
  if settings.background_art == 0 then return table.insert(images,1,{name=filename}) end
  local full_filename = "res/img/backgrounds/"..tostring(filename)..".png"
  if not love.filesystem.getInfo(full_filename) then return notify{"white","Could not load background image ", "red", filename} end
  local img = lg.newImage(full_filename)
  table.insert(images,1,{img=img,alpha=0,name=filename})
end
--

function bg.remove(i)
  images[i] = nil
  collectgarbage()
end
--

function bg.get()
  return (images[1] or {})
end
--

function bg.update(dt)
  if settings.background_art == 0 then return end
  for i,v in pairs(images) do
    if next(v) then
      v.alpha = Misc.lerp(3*dt, v.alpha, i==1 and talpha or 0)
    end
  end
  for i=2,#images do
    if images[i] and next(images[i]) then
      if images[i].alpha <= 0.01 then
        bg.remove(i)
      end
    end
  end
  return true
end
--

function bg.draw(...)
  if settings.background_art == 0 then return end
  local old_col = {lg.getColor()}
  for i,v in pairs(images) do
    if v.img then
      lg.setColor(1,1,1,v.alpha)
      lg.draw(v.img,...)
    end
  end
  if images[1] and next(images[1]) then
    lg.setColor(0,0,0,math.min(0.15,images[1].alpha))
    lg.rectangle("fill",0,0,screen_width,screen_height)
  end
  lg.setColor(old_col)
  return true
end
--

function bg.checkAllowedState()
  local curr = Gamestate.current()
  for i,v in pairs(allowed_states) do
    if curr == v then return true end
  end
  return false
end
--

function bg._initialize()
  images = {}
  allowed_states = {
    states.history,
    states.mainmenu,
    states.rewards,
  }
  collectgarbage()
end
--

function bg.clear()
  images = {}
  collectgarbage()
end
--

setmetatable(bg, { __call = function(_, ...) return bg.set(...) end})

return bg