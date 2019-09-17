local st = {}
local newScroller = require("elements.scroller")

st.flux = Flux.group()

local fg_ui = {}
local prev_state
local orig
local cg = {}
local alpha = 0
local lerping

function st:init()
  fg_ui["return_button"] = newButton("Return", function() self.prep_leave() end, 30, screen_height-50-30, screen_width/7, 50)
  fg_ui["scroller"] = newScroller(0, 0, 0, screen_width-30, 30, screen_height-60)
  fg_ui["panner"] = newScroller(0, 0, 0, 0, 0, screen_width-60)
  local old_draw = fg_ui["panner"].draw
  fg_ui["panner"].draw = function(self)
    lg.push() lg.translate(30,screen_height-30) lg.rotate(-math.pi/2)
    old_draw(self)
    lg.pop()
  end

end
--

function st:enter(...)
  local args = {...}
  prev_state = args[1]
  orig = args[3] or {x=screen_width/2, y=screen_height/2, w=0, h=0}
--  cg = {img=args[2], x=orig.x, y=orig.y, xscale=orig.w/args[2]:getWidth(), yscale=orig.h/args[2]:getHeight(), alpha=0}
  cg = {
    img=args[2],
    x=orig.x, y=orig.y,
    xscale=0, yscale=0,
    alpha=0
  }
  cg.tscale = math.min(cg.img:getWidth(), screen_width)/cg.img:getWidth()
  if (cg.img:getWidth()*cg.tscale) < screen_width/4 and (cg.img:getHeight()*cg.tscale) < screen_height/4 then
    cg.tscale = (screen_width/8)/cg.img:getWidth()
--    cg.tscale = math.max(1.5, cg.tscale)
  elseif cg.img:getHeight()>=screen_height or cg.img:getWidth()>=screen_width then
    cg.tscale = 1
  end
  cg.tx = math.max(0, cg.x-(cg.img:getWidth()*cg.tscale)/2) 
  cg.ty = math.max(0, cg.y-(cg.img:getHeight()*cg.tscale)/2)
  alpha = 0

  fg_ui["scroller"]:snapTo(0)
  fg_ui["scroller"]:setMax(cg.img:getHeight()*(cg.tscale)-screen_height)
  fg_ui["panner"]:snapTo(0)
  fg_ui["panner"]:setMax(cg.img:getWidth()*(cg.tscale)-screen_width)

  lerping = false
end
--

function st:update(dt)
  if not cg.img then Gamestate.pop() end
  local speed = dt*10
  
  if not lerping then
    cg.x = Misc.lerp(speed, cg.x, cg.tx)
    cg.y = Misc.lerp(speed, cg.y, cg.ty)
    cg.xscale = Misc.lerp(speed, cg.xscale, cg.tscale)
    cg.yscale = Misc.lerp(speed, cg.yscale, cg.tscale)
    alpha = Misc.lerp(speed, alpha, 1)
  else
    cg.x = Misc.lerp(speed, cg.x, orig.x)
    cg.y = Misc.lerp(speed, cg.y, orig.y)
    cg.xscale = Misc.lerp(speed, cg.xscale, orig.w/cg.img:getWidth())
    cg.yscale = Misc.lerp(speed, cg.yscale, orig.h/cg.img:getHeight())
    alpha = Misc.lerp(speed, alpha, 0)
  end

  for i,v in pairs(fg_ui) do v:update(dt) end  
  st.flux:update(dt)
end
--

function st:draw()
  prev_state:draw()
  lg.setColor(0,0,0,alpha*1.5)
  lg.rectangle("fill", 0, 0, screen_width, screen_height)
  lg.setColor(1,1,1,alpha)
  lg.push()   lg.translate(fg_ui["panner"].y_offset,fg_ui["scroller"].y_offset) --lg.alpha(alpha)
  lg.draw(cg.img, cg.x, cg.y, nil, cg.xscale, cg.yscale)
  lg.pop()

  lg.setColor(0,0,0,alpha*0.2)
  lg.draw(vignette, 0, 0, nil, screen_width/vignette:getWidth(), screen_height/vignette:getHeight())

  if lerping then return end
  for i,v in pairs(fg_ui) do v:draw() end  
end
--

function st:keypressed(key)
  if keyset.back(key) then return self.prep_leave() end
  local d = key:match("%d+$")
  if d then alpha = tonumber(d)/10 end
  -- Modify what keys the scroller/panner receive; allows for intuitive pan and scroll with directional keys
  local check = {
    {pageup=keyset.up(key), pagedown=keyset.down(key)},
    {pageup=keyset.left(key), pagedown=keyset.right(key)}
  }
  for i,v in pairs(check[1]) do
    if v then
      return fg_ui["scroller"]:keypressed(i)
    end
  end
  for i,v in pairs(check[2]) do
    if v then 
      return fg_ui["panner"]:keypressed(i)
    end
  end
end
--
function st:mousepressed(x,y,b,t)
  if fg_ui["return_button"]:mousepressed(x,y,b) then return end
  fg_ui["scroller"]:checkArea(x,y, {0,0,screen_width,screen_height})
  fg_ui["panner"]:checkArea(x,y, {0,0,screen_width,screen_height})
end
--
function st:mousereleased(x,y,b,t)
  if b==2 then return self.prep_leave() end
  if fg_ui["return_button"]:mousereleased(x,y,b) then return end
end
--
function st:wheelmoved(x,y)
  fg_ui["scroller"]:wheelmoved(x,y)
end
--
function st:mousemoved(x,y,dx,dy)
end
--
function st:touchmoved(id,x,y,dx,dy)
  fg_ui["scroller"]:touchmoved(id,x,y,dx,dy)
  fg_ui["panner"]:touchmoved(id,x,x,dx,dx)
end
--
function st:prep_leave()
  if lerping then return end
  lerping = true
  fg_ui["scroller"]:moveTo(0)
  fg_ui["panner"].y_offset_target = 0
  cg.xscale_t, cg.yscale_t = 0, 0
  Timer.after(1/3, Gamestate.pop)
end
--
function st:leave()
end
--

return st