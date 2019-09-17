local st = {}
st.list = {}
st.texts = {}

local newScroller = require("elements.scroller")
local fg_ui = {}

local bar = lg.newImage("res/img/inv_bar.png")

local FONT_ = {
  fonts.game_maintext,
  fonts.game_location,
  fonts.game_narrator,
  fonts.stats_title,
}

local box = {
  x = 60,
  y = 30,
  w = screen_width-(60)*2,
  h = 0,
  text = "",
  pad = 30,
  alpha = 1,
}


local function drawText(b)
  local h = FONT_[1]:getHeight()
  local _, wrapped = FONT_[1]:getWrap(b.text, b.w-b.pad*2)
  local function draw(text,x,y)
    lg.setFont(FONT_[1])
    for o=-1,1,2 do
      lg.setColor(0,0,0,b.alpha*0.8)
      lg.print(text, x+o, y)
      lg.print(text, x, y+o)
      lg.setColor(0,0,0,b.alpha*0.2)
      lg.print(text, x+o*2, y)
      lg.print(text, x, y+o*2)
      lg.setColor(0,0,0,b.alpha*0.1)
      lg.print(text, x+o*3, y)
      lg.print(text, x, y+o*3)
    end  
    lg.setColor(1,1,1,b.alpha*0.9)
    lg.print(text, x, y)
  end
  local texturesize = love.graphics.getSystemLimits().texturesize
  local max_canvas_height
  for i=0, b.h, h do
    max_canvas_height = i
  end
  max_canvas_height = math.min(max_canvas_height, texturesize*0.8)

  for i=0, b.h, max_canvas_height do
    table.insert(b.canvases, {canvas=lg.newCanvas(screen_width, max_canvas_height), y=i})
  end
  for i,text in pairs(wrapped) do
    i = i-1
    local canv = math.floor(((i) * h) / (max_canvas_height))+1
    lg.setCanvas({b.canvases[canv].canvas,stencil=true})
    local sx, sy = Misc.toGame()
    lg.push() lg.scale(1/sx, 1/sy)

    local x, y = 0, ((i) * h) % (max_canvas_height)
    draw(text,x,y)

    lg.pop()
    lg.setCanvas()
  end
end
--

local function newBox(text,speaker,location,choice)
  local b = Misc.tcopy(box)
  local wrapped
  b.canvases = {}
  b.text = text
  b.speaker = speaker
  b.location = location
  b.choice = choice
  _, wrapped = FONT_[1]:getWrap(text, box.w-box.pad*2)
  b.h = #wrapped*FONT_[1]:getHeight() + box.pad*2 + FONT_[2]:getHeight()
  if b.speaker then b.h = b.h + FONT_[3]:getHeight() end
  if b.choice then b.h = b.h + FONT_[1]:getHeight() end
  function b.predraw()
    b.canvases = {}
    drawText(b)
  end
  function b.draw()
    lg.push() lg.translate(b.x,b.y)
    lg.setColor(0,0,0,b.alpha*0.75)
    lg.rectangle("fill", 0, 0, b.w, b.h, 15, 15)
    lg.rectangle("line", -2, -2, b.w+4, b.h+4, 15, 15)
    lg.setColor(1,1,1,b.alpha/3)
    lg.rectangle("line", -1, -1, b.w+2, b.h+2, 15, 15)
    lg.setColor(1,1,1,b.alpha*0.66)
    lg.translate(0, 5)
    lg.setFont(FONT_[2])
    lg.printf(b.location,0,0,b.w,"center")
    if b.choice then
      lg.setColor(1,0.75,0.2,b.alpha*0.8)
      lg.translate(0, FONT_[2]:getHeight())
      lg.setFont(FONT_[1])
      lg.print(">> "..b.choice,b.pad)
      lg.translate(0,b.pad/2)
    end
    if b.speaker then
      lg.translate(0, b.choice and FONT_[1]:getHeight() or FONT_[2]:getHeight())
      lg.setColor(1,1,1,b.alpha*0.66)
      lg.setFont(FONT_[3])
      lg.print(b.speaker,b.pad)
    end
    lg.translate(b.pad,b.pad)
    lg.setColor(1,1,1,b.alpha)
    for i,v in pairs(b.canvases) do
      lg.draw(v.canvas,0,v.y)
    end
    lg.pop()
  end
  b.predraw()
  table.remove(st.list,10)
  table.insert(st.list,1,b)
end
--

event.wish("pageflip", function(output)
    table.insert(st.texts,{o=output,n=out.narrator,l=out.location,c=choices.last_pg_chosen})
    choices.last_pg_chosen = nil
    if #st.texts>10 then table.remove(st.texts,1) end
  end)

function st:init()
  fg_ui["return"] = newButton("Return", st.prep_leave, 30, screen_height-screen_height/6.5, 125, 50)
  event.wish({"window_reset"}, function()
      for i,v in pairs(st.list) do
        v.canvases = {}
        v.predraw()
      end
    end)
end
--
function st:enter()
  for i,v in pairs(st.texts) do
    newBox(v.o,v.n,v.l,v.c)
  end
  local max = bar:getHeight()
  for i,v in pairs(st.list) do max = max + v.h + v.pad end
  fg_ui["scroller"] = newScroller(0, 0, max-fg_ui["return"].y+30, screen_width-30, 30, screen_height-60)
  collectgarbage()
end
--
function st:update(dt)
  for i,v in pairs(fg_ui) do v:update(dt) end
end
--
function st:draw()
  lg.push()
  lg.translate(0,bar:getHeight())

  lg.translate(0,fg_ui["scroller"].y_offset)
  local yy = 0
  for i,v in pairs(st.list) do
    if (yy+fg_ui["scroller"].y_offset)+v.h+v.pad > -bar:getHeight() and (yy+fg_ui["scroller"].y_offset) < screen_height-bar:getHeight()-v.pad then
      lg.push() lg.translate(0,yy)
      v.draw()
      lg.pop()
    end
    yy = yy + (v.h+v.pad)
  end
  lg.pop()

  for i,v in pairs(fg_ui) do v:draw() end

  lg.setColor(1,1,1,1/3)
  lg.draw(bar, 0, 5)
  lg.setColor(1,1,1)
  lg.draw(bar)
  lg.setFont(FONT_[4])
  lg.printf("History", 0, bar:getHeight()-FONT_[4]:getHeight()-10, screen_width, "center")
end
--
function st:keypressed(key)
  if keyset.back(key) or keyset.history(key) then return st.prep_leave() end
  -- Directional keys aren't used in the History screen, so repurpose Up/Down for scrolling.
  fg_ui["scroller"]:keypressed(key,keyset.up(key) and "up" or keyset.down(key) and "down")
end
--
function st:mousepressed(x,y,b,t)
  if fg_ui["return"]:mousepressed(x,y,b) then return end
  if b==2 then return st.prep_leave() end
  fg_ui["scroller"]:checkArea(x,y, {0, 0, screen_width, screen_height})
end
--
function st:wheelmoved(x,y)
  fg_ui["scroller"]:wheelmoved(x,y)
end
--
function st:touchmoved(id,x,y,dx,dy)
  fg_ui["scroller"]:touchmoved(id,x,y,dx,dy)
end
--
function st:mousereleased(x,y,b,t)
  if fg_ui["return"]:mousereleased(x,y,b) then return end
end
--
function st.prep_leave()
  Misc.fade(Gamestate.pop, 0.33)
end
--
function st:leave()
  st.list = {}
  collectgarbage()
end
--
function st.clear()
  st.list = {}
  st.texts = {}
  collectgarbage()
end
--

return st