local ip = {}

local ad_keyboard_check

local out = out

local FONT_ = {
  fonts.game_narrator,
}

ip.input = ""
ip.result = ""
ip.censor = false
ip.box = {
  visible = false,
  focus = false,
  msg = "",
  field = "",
  x = screen_width/2,
  y = screen_height/2-screen_height/4/2,
  w = 0,
  h = screen_height/4,
  targetw = screen_width/3,
  innards = 0,
}
ip.box.targetx = ip.box.x-ip.box.targetw/2
ip.box.basex, ip.box.basey = ip.box.x, ip.box.y
ip.box.tb = {
  index = 0,
  blink = 0,
  x = ip.box.x + 15, 
  y = ip.box.y + ip.box.h-15-40, 
  w = ip.box.w-30,
  h = 40,
}
local old_misc_action = function() out.next() end
local on_close

function ip.setOut(_out) out = _out end
function ip.getOut() return out end
--

function ip.show(msg,field,cens,on_close_func)
  if msg == 0 or ip.box.visible then return end
  ip.box.msg = msg or ""
  ip.box.field = field or ""

  if type(on_close_func)~="function" then on_close=nil else on_close = on_close_func end

  ip.censor = cens
  --instant_close = instant_close

  ip.input = ""
  ip.result = ""
  ip.box.visible = true
  ip.box.focus = true
  ip.box.lerping = true
  ip.box.tb.blink = 0

  ip.box.y = ip.box.basey
  ip.box.h = screen_height/4
  ip.box.x = ip.box.basex
  ip.box.targetx = ip.box.x-ip.box.targetw/2

  local width, wrapped = FONT_[1]:getWrap(ip.box.msg, screen_width/3 - 30)
  ip.box.msg = table.concat(wrapped,"\n")
  ip.box.h = ip.box.h + FONT_[1]:getHeight("A") * (#wrapped - 2)
  if msg~="" then ip.box.y = ip.box.y - (FONT_[1]:getHeight("A") * (#wrapped - 2))/2 end
  ip.box.tb.y = ip.box.y + ip.box.h-15-40

  local function fluxfunc()
    if ip.box.basey+ip.box.h < screen_height/2 then return end
    Flux.to(ip.box, 0.2, {y = screen_height/8}) 
    Flux.to(ip.box.tb, 0.2, {y = screen_height/8 + ip.box.h-15-40})
  end

  if not love.keyboard.hasTextInput() then
    ip.box.focus = true
    love.keyboard.setTextInput(true)
    fluxfunc()
  end

  ad_keyboard_check = Timer.every(0.1, function() 
      if ip.box.focus and ip.box.visible and not love.keyboard.hasTextInput() then
        love.keyboard.setTextInput(true)
        fluxfunc()
      elseif not ip.box.focus and ip.box.visible and love.keyboard.hasTextInput() and love.system.getOS()=="Android" then
        love.keyboard.setTextInput(false)
      end
    end)

  Flux.to(ip.box, 0.15, {x = ip.box.targetx, w = ip.box.targetw}):ease("quadinout")
  :after(ip.box, 0.15, {innards=1}):oncomplete(function() ip.box.lerping = false end)

  old_misc_action = old_misc_action or Misc.action

  Misc.action = function()
    if not ip.close() then ip.show(msg,field,cens) end
  end

  return true
end
--
function ip.close()
  if not ip.box.visible or ip.box.lerping or ip.input=="" then return end
  Timer.cancel(ad_keyboard_check)
  ip.result = ip.input
  ip.censor = nil
  ip.box.msg = ""
  ip.box.field = ""
  if love.system.getOS()=="Android" and love.keyboard.hasTextInput() then love.keyboard.setTextInput(false) end
  ip.box.tb.blink = 0
  ip.box.focus = false
  ip.box.lerping = true
  local function cleanup() ip.box.lerping = false ip.box.visible = false ip.input = "" end
  Flux.to(ip.box, 0.15, {innards=0}):after(ip.box, 0.15, {x = ip.box.basex, w = 0}):ease("quadinout"):oncomplete(cleanup)
  if Gamestate.current()==states.game then out.next(nil,nil,true) end

  Misc.action = old_misc_action or Misc.action
  old_misc_action = nil

  if on_close then on_close(ip.result) end

  return true
end
--

function ip.hide()
  if not ip.box.visible or ip.box.lerping then return end
  if love.system.getOS()=="Android" and love.keyboard.hasTextInput() then return love.keyboard.setTextInput(false) end
  Timer.cancel(ad_keyboard_check)
  ip.box.tb.blink = 0
  ip.box.focus = false
  ip.box.lerping = true
  local function cleanup() ip.box.lerping = false ip.box.visible = false end
  Flux.to(ip.box, 0.25, {innards=0}):after(ip.box, 0.25, {x = ip.box.basex, w = 0}):ease("quadinout"):oncomplete(cleanup)
end
--

function ip.update(dt)
  if not ip.box.visible then return end

  ip.box.tb.blink = (ip.box.tb.blink + 1 * dt) % 1

  return true
end
--

function ip.draw()
  if not ip.box.visible or ip.box.w < 3 then return end
  lg.setColor(0,0,0,0.8)
  lg.rectangle("fill",ip.box.x,ip.box.y,ip.box.w,ip.box.h,8,8)
  lg.setColor(1,1,1,0.2)
  lg.rectangle("line",ip.box.x,ip.box.y,ip.box.w,ip.box.h,8,8)

  -- Inside stuff
  lg.setFont(FONT_[1])
  lg.setColor(1,1,1,ip.box.innards)
  lg.print(ip.box.msg, ip.box.x + 15, math.floor(ip.box.y + 10))
  lg.setColor(0.685,0.685,0.685,ip.box.innards)
  ip.box.tb.x, ip.box.tb.w = ip.box.x + 15, ip.box.w-30
  lg.rectangle("fill",ip.box.tb.x, ip.box.tb.y, ip.box.tb.w, ip.box.tb.h,4,4)
  if not ip.box.focus then
    lg.setColor(0,0,0,ip.box.innards/2.5)
  else
    lg.setColor(0,0,0,ip.box.innards)
  end

  if ip.input~="" or ip.box.focus then

    lg.stencil(function() lg.rectangle("fill",ip.box.tb.x, ip.box.tb.y, ip.box.tb.w, ip.box.tb.h,4,4) end, "increment", 1)
    lg.setStencilTest("greater", 0)

    lg.push()
    lg.translate(-math.max(0, FONT_[1]:getWidth(ip.input)-(ip.box.w-46)), 0)

    lg.print(ip.input, ip.box.x+23, math.floor(ip.box.y + ip.box.h-15-40+5))
    lg.setStencilTest()
    -- Blinky cursor
    if ip.box.tb.blink < 0.5 and ip.box.focus then 
      lg.rectangle("fill",ip.box.x+22+FONT_[1]:getWidth(ip.input:sub(1,ip.box.tb.index)),ip.box.y+ip.box.h-15-40+5, 2, FONT_[1]:getHeight())
    end

    lg.pop()

  elseif not ip.box.focus then
    lg.printf(ip.box.field, ip.box.x + 23, math.floor(ip.box.y + ip.box.h-15-40+5), ip.box.tb.w-12, "center")
  end

  lg.setColor(1,1,1)
end
--

function ip.keypressed(key)
  if not ip.box.visible then return end
  if ip.box.lerping then return true end
  if key=="escape" then return ip.hide() end
  if key=="return" then return ip.close() end
  if not ip.box.focus then return true end
  if key=="backspace" then
    ip.input = ip.input:sub(1,ip.box.tb.index-1)..ip.input:sub(ip.box.tb.index+1)
    ip.box.tb.index = math.max(0, ip.box.tb.index - 1)
    ip.box.tb.blink = 0
  end
  if key == "delete" and ip.box.tb.index ~= #ip.input then
    ip.input = ip.input:sub(1,ip.box.tb.index)..ip.input:sub(ip.box.tb.index+2)
    ip.box.tb.blink = 0
  end
  if key == "end" then ip.box.tb.index = #ip.input elseif key == "home" then ip.box.tb.index = 0 end
  if key == "left" then ip.box.tb.index = math.max(0, ip.box.tb.index - 1) ip.box.tb.blink = 0 
  elseif key == "right" then ip.box.tb.index = math.min(#ip.input, ip.box.tb.index + 1) ip.box.tb.blink = 0 end
  return true
end
--

function ip.mousepressed(x,y,b,t)
  if not ip.box.visible then return end
  if ip.box.lerping then return true end
  if x > ip.box.tb.x and y > ip.box.tb.y and x < ip.box.tb.x + ip.box.tb.w and y < ip.box.tb.y + ip.box.tb.h then
    -- Clicked inside input textbox
    ip.box.focus = true
  else
    ip.box.focus = false
    if x > ip.box.x and y > ip.box.y and x < ip.box.x + ip.box.w and y < ip.box.y + ip.box.h then
      -- Clicked inside input window, but not in textbox
    else
      -- Clicked outside input window
      ip.hide()
    end
  end
  return true
end
--

function ip.mousereleased(x,y,b,t)
  if not ip.box.visible then return end
  if ip.box.lerping then return true end
  ip.box.targetx = ip.box.x
  return true
end
--

function ip.textinput(text)
  if not ip.box.visible or not ip.box.focus then return end
  if ip.box.lerping then return true end
  if ip.censor and (text:find("[%p]") or #ip.input >= 16) then return end

  if ip.box.tb.index < #ip.input then ip.input = ip.input:sub(1,ip.box.tb.index)..text..ip.input:sub(ip.box.tb.index+1) else ip.input = ip.input..text end
  ip.box.tb.index = ip.box.tb.index + 1
  ip.box.tb.blink = 0

  if ip.censor then ip.input = Misc.capitalize(ip.input) end
  return true
end
--

return ip