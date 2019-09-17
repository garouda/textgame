require("overloaded_functions")
__ = require("libs.underscore")
__.extend(math,require("libs.mlib"))

screen_width, screen_height = 960,540
game_version = "0.0.0"

require("fonts")
require("shared_img")

Misc = require("misc_functions")
Gamestate = require("libs.gamestate")
Flux = require("libs.flux")
Timer = require("libs.timer")
event = require("event")
require("nature")

particles = require("particle")
entity = require("combat.entities")
newButton = require("elements.button")
smallHP = require("small_hp")
states = require("states")
keyset = require("keyset")
player = require("player")
combat = require("combat.funcs")
save = require("save")
prompt = require("prompt")
notify = require("notify")
bgimage = require("background")

local tooltip = require("tooltip")

local hard_pause
local window_drag = {active = false, cx = nil , cy = nil}
local background = {
  img=lg.newImage("res/img/background bw.png"),
  prev_sum = 0,
  canvas=lg.newCanvas(love.graphics.getDimensions()),
  shader=lg.newShader[[
  vec4 effect( vec4 col, Image tex, vec2 tc, vec2 sc ){
  vec4 pixel = Texel(tex, tc);
  number average = (pixel.r+pixel.b+pixel.g)/3.0;
  // number factor = tc.y;
  number factor = tc.y;
  // pixel.r = (pixel.r) + (average-pixel.r) * (factor);
  pixel.r = (pixel.r) + (average-pixel.g*1.15) * (factor);
  // pixel.g = (pixel.g) + (average-pixel.g) * (factor);
  pixel.g = (pixel.g) + (average-pixel.g*1.15) * (factor);
  // pixel.b = (pixel.b) + (average-pixel.b) * (factor);
  pixel.b = (pixel.b) + (average-pixel.b*1.15) * (factor);
  return pixel;
  }]]}
local texture = {img = lg.newImage("res/img/scroll.png"), alpha = 0, dir = 1}

local basefont = lg.newFont()

local function recreate_bg(ww,wh)
  ww,wh = lg.getDimensions()
  background.canvas = nil
  collectgarbage()
  background.canvas = lg.newCanvas(ww,wh)
  lg.setCanvas(background.canvas)
  lg.clear()
  lg.push()
  local h,s,v = unpack(Misc.background_color)
  local h_a,s_a,v_a = unpack(Misc.background_color_add)
  lg.setColor(Misc.HSV(h+h_a,s+s_a,v+v_a))
  lg.draw(background.img,0,0,nil,ww*2,math.max(1,screen_height/background.img:getHeight()))
  lg.pop()
  lg.setCanvas()
end
event.wish({"resized","bg_color_changed","window_reset"}, recreate_bg)

function GameOver(final)
  Gamestate.pop()
  Gamestate.push(states.gameover,final)
end
--
function love.load(...)
  DEBUG_MODE = tostring((({...})[1] or {})[1]) == "-debug"
  
  love.keyboard.setKeyRepeat(true)
  math.randomseed(os.time())
  Gamestate.switch(states.mainmenu)
  particles.bokeh:start()
  states.controls.load()
  states.settings.load()

  if not love.filesystem.getInfo("settings") then save(settings,"settings") end
  if not love.filesystem.getInfo("controls") then states.controls.commit() end
  
  Misc.populate_data()
  out.setFontSize(settings.font_size)
  recreate_bg()
  event.wish("show_tooltip", function(...) tooltip.set(...) end)
  Timer.after(0.2, function() event.grant("window_reset") end)
  player = require("player")()
  
  --[
  Misc.fade.lerping = true
  Flux.to(Misc.fade, 1, {alpha=0})
  Timer.after(1/4, function() Misc.fade.lerping = false end)
  --]
--  Misc.fade.alpha = 0  
end
--

local old_isDown = love.mouse.isDown
local old_getPosition = love.mouse.getPosition
local old_title = ""
local orig_title
function love.update(dt)
  -- pls don't touch this, it prevents delta time from getting out of control when the window hangs (such as when it's being dragged)
  dt = math.min(dt, 0.07)

  Misc.uptime = Misc.uptime + dt

  if Misc.fade.lerping then
    love.mouse.isDown = function() return false end
    love.mouse.getPosition = function() return 0,0 end
  else
    love.mouse.isDown = old_isDown
    love.mouse.getPosition = old_getPosition
  end

  prompt.update(dt)

  Gamestate.update(dt)

  smallHP.update(dt)

  notify.update(dt)

  Flux.update(dt)
  Timer.update(dt)
  particles.bokeh:update(dt)

  texture.alpha = texture.alpha + (1 * texture.dir) * 0.025 *  dt
  if texture.alpha >= 1 then texture.dir = -1 elseif texture.alpha <= 0 then texture.dir = 1 end
  bgimage.update(dt)

  local new_sum = __.reduce(Misc.background_color, 0, function(memo,i,v) return memo+v+Misc.background_color_add[i] end) 
  if new_sum ~= background.prev_sum then event.grant("bg_color_changed") background.prev_sum = new_sum end

  if Misc.shake.tween and Misc.shake.tween.progress >= 1 then
    Misc.shake.base_a, Misc.shake.base_t = 0, 0
  end

  tooltip.update(dt)
end
--

function love.draw()
  if Misc.shake.h>0 then lg.translate(math.random(Misc.shake.h*2)-Misc.shake.h, math.random(Misc.shake.v*2)-Misc.shake.v) end

  local ww, wh = love.graphics.getDimensions()
  lg.setShader(background.shader)
  lg.draw(background.canvas)
  lg.setShader()

  lg.scale(Misc.toGame())

  if bgimage.checkAllowedState() then 
    bgimage.draw()
  end

  lg.push()
  lg.scale(screen_width/texture.img:getWidth(),screen_height/texture.img:getHeight())
  lg.setColor(1,1,1,texture.alpha)
  lg.draw(texture.img,0,0)
  lg.setColor(1,1,1,1-texture.alpha)
  lg.draw(texture.img,texture.img:getWidth(),texture.img:getHeight(), math.pi)
  lg.setColor(1,1,1)
  lg.pop()
  lg.draw(particles.bokeh)

  lg.setColor(1,1,1)
  Gamestate.draw()


  tooltip.draw()

  lg.setColor(1,1,1,Misc.flash.alpha)
  lg.rectangle("fill",0,0,screen_width,screen_height)

  lg.setColor(0,0,0,Misc.fade.alpha)
  lg.rectangle("fill",0,0,screen_width,screen_height)

  smallHP.draw()

  notify.draw()

  prompt.draw()

  lg.setColor(1,1,1)
  lg.setFont(basefont)
end
--

function love.keypressed(key)
  if key=="return" and (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")) then
    love.window.setFullscreen(settings.fullscreen == 0)
    settings.fullscreen = (settings.fullscreen + 1) % 2
    return event.grant("fullscreen")
  elseif key=="insert" and (love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")) and not love.window.getFullscreen() then
    local w, h, b = love.window.getMode()
    love.window.updateMode(w,h,{borderless=not b.borderless})
    return event.grant("window_reset")
  end
  if key=="v" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
    local cb_text = love.system.getClipboardText() or ""
    for i=1,#cb_text do love.textinput(cb_text:sub(i,i)) end
  end
  if prompt.keypressed(key) then return end
  if Misc.fade.lerping then return end
  Gamestate.keypressed(key)
  if keyset.credits(key) then if Gamestate.current()~=states.credits then Gamestate.push(states.credits) else Gamestate.pop() end end
end
--

function love.keyreleased(key)
  Gamestate.keyreleased(key)
end
--

function love.textinput(text)
  if Misc.lock_text_input then return end
  if text:byte() <= 31 or text:byte() >= 128 then return end
  Gamestate.textinput(text)
end
--

function love.mousepressed(x,y,b,t)
  if b==3 then
    window_drag.active = true
    window_drag.cx, window_drag.cy = love.mouse.getPosition()
  end

  if Misc.fade.lerping then return end

  x,y = Misc.toGame(x,y)
  if not x or not y then return end
  Gamestate.current().keyboard_focus = 0
  if prompt.mousepressed(x,y,b,t) then return end
  Gamestate.mousepressed(x,y,b,t)
end
--

function love.mousereleased(x,y,b,t)
  if b == 3 and window_drag.active then window_drag = {active=false} end
  x,y = Misc.toGame(x,y)
  if not x or not y then return end
  if Misc.fade.lerping then return end
  if prompt.mousereleased(x,y,b,t) then return end
  Gamestate.mousereleased(x,y,b,t)
end
--

local mvtotal = 0
function love.mousemoved(x,y,dx,dy)
  if window_drag.active then
    local wx,wy = love.window.getPosition()
    love.window.setPosition(wx-window_drag.cx+x,wy-window_drag.cy+y)
  end
  if Misc.fade.lerping then return end
  x,y = Misc.toGame(x,y)
  dx,dy = Misc.toGame(dx,dy)
  Gamestate.mousemoved(x,y,dx,dy)
  mvtotal = mvtotal + math.abs(dx)+math.abs(dy)
  if mvtotal>=10 then
    Gamestate.current().keyboard_focus = 0
    prompt.focus = 0
    mvtotal = 0
  end
  if love.system.getOS()=="Android" then return end
  if prompt.touchmoved(nil,x,y,dx,dy) then return end
  Gamestate.touchmoved(nil,x,y,dx,dy)
end
--

function love.touchmoved(id,x,y,dx,dy)
  if Misc.fade.lerping then return end
  if prompt.touchmoved(id,x,y,dx,dy) then return end
  x,y = Misc.toGame(x,y)
  dx,dy = Misc.toGame(dx,dy)
  Gamestate.touchmoved(id,x,y,dx,dy)
end
--

function love.wheelmoved(x,y)
  if Misc.fade.lerping then return end
  if prompt.wheelmoved(x,y) then return end
  Gamestate.wheelmoved(x,y)
end
--

function love.resize(w,h)
  Timer.after(0.1, function() event.grant("resized",w,h) end)
end
--

function love.focus(f)
  hard_pause = not f
end
--

function love.filedropped(file)
  local extension = file:getFilename():match("%.(%w-)$")
  if not extension then return Misc.message("Could not open file:\n\""..file:getFilename().."\"\nFile has no extension - TextGame can only load .txt files!")
  elseif extension~="txt" then return Misc.message("Could not open file:\n\""..file:getFilename().."\"\nFiletype is ."..extension.." when it should be .txt!","Error") end
  if Gamestate.current()==states.editor then return states.editor.input.import(file,true) end
end
--

function love.quit(r)
end
--

local oldloveeventquit = love.event.quit
function love.event.quit(...)
  local arg = {...}
  return prompt("Do you really want to quit TextGame?",{function() oldloveeventquit(unpack(arg)) end})
end
--

--[
local old_errorhandler = love.errhand
function love.errorhandler(e)
  if DEBUG_MODE then return old_errorhandler(e) end
  -- Collect info from LOVE
  local version = "game version: "..game_version
  local date = os.date("date: %d/%m/%Y  %H:%M:%S")
  local renderer_info = table.concat({lg.getRendererInfo()}, "   ")
  local render_statistics = ""
  for i,v in pairs(lg.getStats()) do
    render_statistics = render_statistics ..i..": "..v.. "    "
  end
  local system_limits = ""
  for i,v in pairs(lg.getSystemLimits()) do
    system_limits = system_limits ..i..": "..v.. "    "
  end
  local w_m = {love.window.getMode()}
  local window_mode = "width: "..w_m[1].."   ".."height: "..w_m[2].."    "
  for i,v in pairs(w_m[3]) do
    window_mode = window_mode..i..": "..tostring(v).."    "
  end
  -- Collect platform info
  local OS = "OS: "..love.system.getOS()
  local processor_count = "processor count: "..love.system.getProcessorCount()
  -- Condense into one string
  local system = string.format(string.rep("%s\n",8),version,date,OS,renderer_info,system_limits,render_statistics,window_mode,processor_count)
  
  local application = love.window.getTitle()
  local traceback = debug.traceback(e or "")
  local message = string.format("%s has encountered an error and closed unexpectedly.\nA crash report has been created in the game folder.\nPlease send the crash report to xxxxxxx@xxxxx.com with a short description so I can fix it ASAP.\nSorry for the inconvenience!", application)
  
  local data_folder = love.filesystem.getSaveDirectory()
  local dump_filename = "TextGame_crash_report.txt"
  if love.system.getOS() == "Android" then dump_filename = data_folder.."/"..dump_filename end
  local file, err = io.open(dump_filename,"wb")
  file:write(system.."\n")
  file:write("Error Message: \n\n"..traceback)
  io.close()
  
  love.window.showMessageBox("Error!", message, {"OK"})
end
--]]