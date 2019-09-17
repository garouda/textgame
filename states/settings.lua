local st = {}

local newSlider = require("elements.slider")
local newSelect = require("elements.select")
local newScroller = require("elements.scroller")

local cog = {img=lg.newImage("res/img/cog.png"), r=0}
local cog2 = {img=lg.newImage("res/img/cog.png"), r=0}

local label_canvas

local elements = {}
local fg_ui = {}

-- This pad is the distance between label and element
local label_pad = screen_height/8
local element_y = screen_height/10 + label_pad
-- This pad is the STARTING distance between element and THE NEXT label. pls no touch
local element_pad = 0
-- How much the element_pad increments each time it is updated
local pad_increment = label_pad*2

st.keyboard_focus = 0

local FONT_ = {
  fonts.settings_headers,
  fonts.element
}
local function resize_window(index)
  local sizes = {
    {w=960,h=540},
    {w=1280,h=720},
    {w=1600,h=900},
    {w=1920,h=1080},
  }
  if not sizes[index] then return end
  love.window.updateMode(sizes[index].w,sizes[index].h)
  Timer.after(0.1, function() event.grant("window_reset") end)
end
--

settings = {
  text_speed = 40,
  font_size = 30,
  fullscreen = 0,
  fullscreen_type = 1,
  autosave = 0,
  autocombat = 0,
  quicksave_slot = 1,
  background_art = 1,
  window_size = 1,
  vsync = 1,
  outline_canvas_prerender = 1,
  filter = {}
}
local backup = Misc.tcopy(settings)
local init

local function getPad(reset,no_inc)
  if reset then element_pad = 0 return 0 end
  if no_inc then return element_pad end
  element_pad = element_pad + pad_increment
  return element_pad
end
--

local function generate_buttons()
  elements = {}
  table.insert(elements, {label="Text Speed", e=newSlider({settings,"text_speed"}, 10, 70, screen_width/2-screen_width/4, element_y+getPad(true), screen_width/2)})
  table.insert(elements, {label="Font Size", e=newSlider({settings,"font_size"}, 24, 48, screen_width/2-screen_width/4 , element_y+getPad(), screen_width/2)})
  table.insert(elements, {label="Auto-Battle", e=newSelect({"Off/On"}, settings, "autocombat", screen_width/2, element_y+getPad())})
  table.insert(elements, {label="Background Art", e=newSelect({"Off/On"}, settings, "background_art", screen_width/2, element_y+getPad())})
--  table.insert(elements, {label="Autosave", e=newSelect({"Off/On"}, settings, "autosave", screen_width/2, element_y+getPad())})
  if love.system.getOS()~="Android" then
    table.insert(elements, {label="Controls", e=newButton("Edit Controls", function() Gamestate.push(states.controls) end, screen_width/2-FONT_[2]:getWidth("Edit Controls")*1.75/2, element_y+getPad())})
    table.insert(elements, {label="Fullscreen Type", e=newSelect({"Borderless","Exclusive"}, settings, "fullscreen_type", screen_width/2, element_y+getPad(), {no_blank=true})})
    table.insert(elements, {label="Fullscreen (Alt+Enter)", e=newSelect({"Off/On"}, settings, "fullscreen", screen_width/2, element_y+getPad())})
    table.insert(elements, {label="Resolution", e=newSelect({"960x540","1280x720","1600x900","1920x1080"}, settings, "window_size", screen_width/2, element_y+getPad(), {no_blank=true})})
    elements[#elements].e.value_set = function() resize_window(settings.window_size) end
  end
  table.insert(elements, {label="Reset", e=newButton("Reset all settings", function() notify("All settings successfully reset to default.") st.reset() end, screen_width/2-FONT_[2]:getWidth("Reset all settings")*1.75/2, element_y+getPad())})
end
--

local function drawLabels()
  lg.setCanvas(label_canvas)
  lg.clear()
  lg.push()
  local sx, sy = Misc.toGame()
  lg.scale(1/sx, 1/sy)
  lg.setFont(FONT_[1])
  local count = 0
  for i,v in pairs(elements) do
    local y = element_y - label_pad
    local y_pad = getPad()
    if i == 1 then y_pad = getPad(true) end
    lg.setColor(0,0,0,0.4)
    for o=-1,1,2 do
      lg.printf(v.label, 0, y + y_pad+o - 3, screen_width, "center")
      lg.printf(v.label, 0+o, y + y_pad - 3, screen_width, "center")
    end
    lg.setColor(1,1,1)
    lg.printf(v.label, 0, y + y_pad - 3, screen_width, "center")
  end
  lg.pop()
  lg.setCanvas()
end
--

event.wish({"window_reset"}, function()
    drawLabels()
  end)

function st.load()
  local s = love.filesystem.read("settings")
  if s then 
    s = Tserial.unpack(s,true) or {}
    for i,v in pairs(s) do if settings[i] then settings[i] = v end end
  end

  generate_buttons()

  fg_ui["return_button"] = newButton("Return", function() st.commit() end, 30, screen_height-screen_height/6.5, 125, 50)
  fg_ui["scroller"] = newScroller(0, 0, element_y+getPad()-screen_height-pad_increment/3, screen_width-30, 30, screen_height-60)
end
--

function st:enter()
  fg_ui["scroller"].value = 0
  fg_ui["scroller"]:moveTo(0)
  init = Misc.tcopy(settings)

  local h = 0
  for i,v in pairs(elements) do
    local y = element_y - label_pad
    h = y + getPad()
    if i == 1 then h = getPad(true) end
  end
  label_canvas = nil
  collectgarbage()
  label_canvas = lg.newCanvas(screen_width,h+FONT_[1]:getHeight())
  drawLabels()
end
--
function st:update(dt)
  cog.r = cog.r + 0.5 * dt
  cog2.r = cog2.r - 0.2 * dt
  for i,v in pairs(elements) do
    if v.e.y+v.e.h + fg_ui["scroller"].y_offset > 0 and v.e.y + fg_ui["scroller"].y_offset < screen_height then
      v.e:update(dt,nil,fg_ui["scroller"].y_offset)
    end
  end
  for i,v in pairs(fg_ui) do v:update(dt) end

  if love.system.getOS()~="Android" then love.window.setFullscreen(settings.fullscreen==1,({"desktop","exclusive"})[settings.fullscreen_type]) end
end
--
function st:draw()
  lg.setColor(0,0,0,0.1)
  lg.rectangle("fill",0,0,screen_width,screen_height)

  lg.push()
  lg.translate(0,fg_ui["scroller"].y_offset/6)
  lg.setColor(0,0,0,0.7)
  lg.draw(cog.img, screen_width, screen_height, cog.r, 1, 1, cog.img:getWidth()/2, cog.img:getHeight()/2)
  lg.draw(cog2.img, 0, 0, cog2.r, 1, 1, cog2.img:getWidth()/2, cog2.img:getHeight()/2)
  lg.pop()

  lg.push()
  lg.translate(0,fg_ui["scroller"].y_offset)

  for i,v in pairs(elements) do
    local y = element_y - label_pad
    local y_pad = getPad()
    if i == 1 then y_pad = getPad(true) end
    if i%2 == 0 then
      lg.setColor(0,0,0,0.03)
    else
      lg.setColor(1,1,1,0.03)
    end
    lg.rectangle("fill", 0, y + y_pad + FONT_[1]:getHeight()/2, screen_width, pad_increment)
    
    if v.e.y+v.e.h + fg_ui["scroller"].y_offset > 0 and v.e.y + fg_ui["scroller"].y_offset < screen_height then
      local function sten_()
        lg.rectangle("fill", screen_width/2-FONT_[1]:getWidth(v.label)/2, y + y_pad + FONT_[1]:getHeight()/2, FONT_[1]:getWidth(v.label), FONT_[1]:getHeight(v.label))
      end
      lg.stencil(sten_, "replace", 1)
      lg.setStencilTest("less",1)
      lg.setColor(1,1,1,0.8)
      Misc.fadeline(0, y + y_pad + FONT_[1]:getHeight()/2)
      lg.setStencilTest()
      v.e:draw()
    end
  end

  lg.setColor(1,1,1)
  lg.draw(label_canvas)

  lg.pop()

  for i,v in pairs(fg_ui) do v:draw() end

  lg.setColor(1,1,1)
end
--
function st:keypressed(key)
  if keyset.up(key) then
    if st.keyboard_focus == 1 then st.keyboard_focus = 6 end
    st.keyboard_focus = math.clamp(1,st.keyboard_focus-1,6)
  end
  if keyset.down(key) then 
    if st.keyboard_focus == 5 then st.keyboard_focus = 0 end
    st.keyboard_focus = math.clamp(1,st.keyboard_focus+1,6)
  end
  if keyset.left(key) then
  end
  if keyset.right(key) then
  end
  if keyset.confirm(key) then
  end
  if keyset.back(key) then
    Timer.after(love.timer.getDelta(), st.commit)
  end
  fg_ui["scroller"]:keypressed(key)
end
--
function st:mousepressed(x,y,b,t)
  if b==2 then return self.commit() end
  if fg_ui["return_button"]:mousepressed(x,y,b) then return end
  for i,v in pairs(elements) do if v.e:mousepressed(x,y,b,nil,fg_ui["scroller"].y_offset) then return end end
  fg_ui["scroller"]:checkArea(x,y, {0, 0, screen_width, screen_height})
end
--
function st:mousereleased(x,y,b,t)
  fg_ui["return_button"]:mousereleased(x,y,b)
  for i,v in pairs(elements) do v.e:mousereleased(x,y,b,nil,fg_ui["scroller"].y_offset) end
end
--
function st:touchmoved(id,x,y,dx,dy)
  fg_ui["scroller"]:touchmoved(id,x,y,dx,dy)
end
--
function st:wheelmoved(x,y)
  fg_ui["scroller"]:wheelmoved(x,y)
end
--
function st:leave()
end
--
function st.commit()
  settings.text_speed = math.round(settings.text_speed)
  settings.font_size = math.round(settings.font_size)

  out.speed = settings.text_speed
  st.keyboard_focus = 0


  if settings.font_size ~= math.round(init.font_size) then
    out.setFontSize(settings.font_size)
  end

  Misc.fade(function()
      Gamestate.pop()
    end)
  save(settings,"settings")
end
--

function st.reset()
  for i,v in pairs(settings) do
    settings[i] = backup[i]
  end
  generate_buttons()
end
--

return st