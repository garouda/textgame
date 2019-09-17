local st = {}

local FONT_ = {
  fonts.mainmenu_items,
  fonts.credits,
} 


local pad = screen_width/10
local canvases = {}
local max_size = (FONT_[2]:getHeight()*1.5)*10

local newScroller = require("elements.scroller")
local scroller
local back = newButton("Return", Gamestate.pop, 30, screen_height-screen_height/6.5, 125, 50)

local credits

local function fetch_credits()
  credits = {
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
    "",
    "Nam suscipit nibh urna, a tempor lacus pulvinar ac. Proin lacinia metus lacus, sed viverra quam auctor sit amet.",
    "Praesent non risus ipsum. Integer viverra mauris ac velit viverra maximus.",
    "",
    "Quisque vulputate quam non gravida pellentesque. Nam aliquam eget ex in consequat. In at iaculis lectus.",
  }
  local _, wrapped = FONT_[2]:getWrap(" ",screen_width-pad*2)
  for i,v in pairs(wrapped) do
    if (screen_height/5+FONT_[1]:getHeight()*2.5+(FONT_[2]:getHeight()*1.5)*(i-1)) / max_size >= #canvases then
      table.insert(canvases,lg.newCanvas(screen_width,max_size))
    end
    table.insert(credits,v)
  end
  canvases[0] = lg.newCanvas(screen_width,max_size)
end
--

local function draw_credits()
  local last = -math.huge
  for i,v in pairs(credits) do
    local y = screen_height/5+FONT_[1]:getHeight()*2.5+(FONT_[2]:getHeight()*1.5)*(i-1)
    local ratio = math.floor(y/max_size)
    if last ~= ratio then
      last = ratio
      lg.setCanvas(canvases[ratio])
      lg.clear()
    end
    y = y % max_size
    lg.push()
    local sx, sy = Misc.toGame()
    lg.scale(1/sx, 1/sy)

    lg.setColor(0,0,0,3/4)
    lg.setFont(FONT_[2])
    for o=-2,2,2 do
      lg.printf(v,pad+o,y,screen_width-pad*2,"center") 
      lg.printf(v,pad,y+o,screen_width-pad*2,"center") 
    end
    lg.setColor(1,1,1)
    lg.printf(v,pad,y,screen_width-pad*2,"center")

    lg.pop()
  end
  lg.setCanvas()
end
--

event.wish({"window_reset"}, function()
    fetch_credits()
    draw_credits()
  end)

function st:init()
end
--
function st:enter()
  fetch_credits()
  scroller = newScroller(0, 0, (screen_height/5+FONT_[1]:getHeight()*2.5+(FONT_[2]:getHeight()*1.5)*(#credits)+pad)-screen_height*0.9, screen_width-pad/2, pad/2, screen_height-pad)
  draw_credits()
  scroller:snapTo(0)
end
--
function st:update(dt)
--  scroller:update(dt)
  back:update(dt)
end
--
function st:draw()
  lg.setColor(1,1,1)
  weather.draw()
  lg.setColor(0,0,0,1/8)
  lg.rectangle("fill",0,0,screen_width,screen_height)
  lg.push() lg.translate(0,scroller.y_offset)

  lg.setColor(0,0,0,1/3)
  lg.setFont(FONT_[1])
  for o=-3,3,2 do
    lg.printf("Credits",pad+o,screen_height/5+FONT_[1]:getHeight(),screen_width-pad*2,"center") 
    lg.printf("Credits",pad,screen_height/5+FONT_[1]:getHeight()+o,screen_width-pad*2,"center") 
  end
  lg.setColor(1,1,1)
  lg.printf("Credits",pad,screen_height/5+FONT_[1]:getHeight(),screen_width-pad*2,"center")

  for i,v in pairs(canvases) do
    lg.setColor(1,1,1)
    lg.draw(v,0,screen_height/2.5+FONT_[1]:getHeight()*3.5+max_size*(i-1))
  end
  lg.pop()

--  scroller:draw()
  back:draw()

  lg.setColor(0,0,0,1/3)
  lg.draw(vignette, 0, 0, nil, screen_width/vignette:getWidth(), screen_height/vignette:getHeight())
end
--
function st:keypressed(key)
  if keyset.back(key) then
    Gamestate.pop()
  end
  -- Directional keys aren't used in the Credits screen, so repurpose Up/Down for scrolling.
--  scroller:keypressed(key,keyset.up(key) and "up" or keyset.down(key) and "down")
end
--
function st:mousepressed(x,y,b)
  if back:mousepressed(x,y,b) then return end
--  scroller:checkArea(x,y,{0,0,screen_width,screen_height})
end
--
function st:mousereleased(x,y,b)
  if back:mousereleased(x,y,b) then return end
end
--
function st:touchmoved(id,x,y,dx,dy)
--  scroller:touchmoved(id,x,y,dx,dy)
end
--
function st:wheelmoved(x,y)
--  scroller:wheelmoved(x,y)
end
--
function st:leave()
  canvases = {}
  collectgarbage()
end
--

return st