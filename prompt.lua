local pr = {}

local newScroller = require("elements.scroller")
local scroller

local lerping
pr.focus = 0
local bg_a = 0.95
local tw = screen_width/2.5

local FONT_ = {
  fonts.prompt,
  fonts.debug
}

pr.box = {
  visible = false,
  msg = {},
  msg_index = nil,
  x = screen_width/2,
  y = screen_height/2,
  w = 0,
  h = 0,
  innards = 0,
  buttons = {},
  final_buttons = {},
  final_funcs = {},
}
pr.box.tb = {
  x = pr.box.x + 15, 
  y = pr.box.y + pr.box.h-15-40, 
  w = pr.box.w-30,
  h = 40,
}

local function generate_buttons(t,funcs,buttons)
  pr.box.funcs = setmetatable(funcs or {},{__index = function() return function() end end})
  buttons = buttons or {"Yeah","No"}
  for i,v in pairs(buttons) do
    local w, h = 100, 50
    local x = t.x+(t.w)/2 - w/2
    local function getx(i)
      local pad = 30
      local len = (#buttons) - 1
      local x = (x - (w/2+pad) * len) + (w+pad)*(i-1)
      if len > 0 then x = x + (pad/2)*len end
      return x
    end
    table.insert(pr.box.buttons, newButton(v, function() pr.box.funcs[i]() pr.close() end, getx(i), t.y+t.h-60, 100, 50, {no_ripple=true}))
  end
end
--

function pr.open(msg,funcs,buttons,title)
  pr.box.visible = true

  pr.box.x = screen_width/2
  pr.box.y = screen_height/2--screen_height/2-screen_height/4/2
  pr.box.w = 0
  pr.box.h = 0--screen_height/4
  pr.box.innards = 0
  pr.box.buttons = {}

  pr.box.title = title or ""
  pr.box.msg = type(msg)=="table" and msg or {msg}
  pr.box.msg_index = pr.box.msg_index or 1
  pr.focus = 0
  
  pr.box.msg[pr.box.msg_index] = process(pr.box.msg[pr.box.msg_index])

  local width, wrapped = FONT_[1]:getWrap(pr.box.msg[pr.box.msg_index], tw - 60)
  pr.box.msg[pr.box.msg_index] = table.concat(wrapped,"\n")

  local t = {
    w = tw,
    h = math.min(screen_height*0.75, screen_height/4 + FONT_[1]:getHeight() * (#wrapped - 1)),
  }
  if title or #pr.box.msg > 1 then t.h = t.h + FONT_[2]:getHeight() end

  t.x = screen_width/2-t.w/2
--  t.y = screen_height/2-screen_height/4/2-(FONT_[1]:getHeight() * (#wrapped - 1))/2,
  t.y = screen_height/2-t.h/2

  pr.box.tb.y = t.y + t.h-15-40

  lerping = true
  Flux.to(pr.box, 0.2, t):ease("quadout")
  Timer.after(0.15, function() lerping = false end)

  pr.box.final_buttons = buttons
  pr.box.final_funcs = funcs

  generate_buttons(t, pr.box.msg_index~=#pr.box.msg and {} or funcs, pr.box.msg_index~=#pr.box.msg and {"Next"} or buttons)

  local scroller_max = FONT_[1]:getHeight() * (#wrapped) + 100 - t.h
  scroller = newScroller(0, 0, scroller_max + ((title or #pr.box.msg > 1) and FONT_[2]:getHeight() or 0), t.x+t.w-15, t.y+15, t.h-85)
end
--
function pr.close()
  if pr.box.msg_index and pr.box.msg_index < #pr.box.msg then
    return pr.next()
  end
  pr.box.msg_index = nil
  pr.focus = 0
  pr.box.buttons = {}
  pr.box.visible = false
  pr.box.final_buttons = {}
  Misc.lock_text_input = true
  Timer.after(love.timer.getDelta(), function() Misc.lock_text_input = false end)
end
--
function pr.next()
  pr.box.msg_index = pr.box.msg_index + 1
  pr.box.msg[pr.box.msg_index] = process(pr.box.msg[pr.box.msg_index])
  local width, wrapped = FONT_[1]:getWrap(pr.box.msg[pr.box.msg_index], tw - 60)
  pr.box.msg[pr.box.msg_index] = table.concat(wrapped,"\n")
  local t = {
    w = tw,
    h = math.min(screen_height*0.75, screen_height/4 + FONT_[1]:getHeight() * (#wrapped - 1)),
  }
  if pr.box.title or #pr.box.msg > 1 then t.h = t.h + FONT_[2]:getHeight() end
  t.x = screen_width/2-t.w/2
  t.y = screen_height/2-t.h/2
  
  pr.box.tb.y = t.y + t.h-15-40
  local buttons = {}
--  for i,v in ipairs(pr.box.buttons) do table.insert(buttons,v.label) end
  pr.box.buttons = {}
  generate_buttons(t, pr.box.msg_index~=#pr.box.msg and {} or pr.box.final_funcs, pr.box.msg_index~=#pr.box.msg and {"Next"} or pr.box.final_buttons)
  pr.box.innards = 0 
  lerping = true
  Flux.to(pr.box, 0.2, t):ease("quadout")
  Timer.after(0.15, function() lerping = false end)
  
  local scroller_max = FONT_[1]:getHeight() * (#wrapped) + 100 - t.h
  scroller = newScroller(0, 0, scroller_max + ((pr.box.title or #pr.box.msg > 1) and FONT_[2]:getHeight() or 0), t.x+t.w-15, t.y+15, t.h-85)
end
--
function pr.update(dt)
  if not pr.box.visible then return end
  if lerping then return true end

  pr.box.innards = math.clamp(0, pr.box.innards + dt * 10, 1)

  for i,v in pairs(pr.box.buttons) do
    v:update(dt)
    if pr.focus>0 then
      if pr.focus==i then
        v.key_selected=true
      else
        v.key_selected=false
        v.selected=false
      end
    else
      v.key_selected=false
    end
  end

  scroller:update(dt)

  return true
end
--

function pr.draw()
  if not pr.box.visible then return end
  lg.setColor(0.06,0.06,0.06,bg_a)
  lg.rectangle("fill",pr.box.x,pr.box.y,pr.box.w,pr.box.h,8,8)
  lg.setColor(1,1,1,0.3)
  lg.rectangle("line",pr.box.x,pr.box.y,pr.box.w,pr.box.h,8,8)
  lg.setColor(0,0,0,0.66)
  lg.rectangle("line",pr.box.x-2,pr.box.y-2,pr.box.w+4,pr.box.h+4,8,8)

  if lerping then return true end
  
  -- Inside stuff
  lg.setFont(FONT_[2])
  lg.setColor(1,1,1,pr.box.innards*0.5)
  if #pr.box.msg > 1 then
    lg.printf(pr.box.msg_index.."/"..#pr.box.msg, pr.box.x+15, pr.box.y + 15, tw-30, "left")
  end
  lg.printf(pr.box.title, pr.box.x, pr.box.y + 15, tw, "center")
  lg.stencil(function()
      local y = pr.box.y+15
      local h = pr.box.h-85
      if pr.box.title~="" or #pr.box.msg > 1 then
        y = y + (FONT_[2]:getHeight()+5)
        h = h - (FONT_[2]:getHeight())
      end
      lg.rectangle("fill",pr.box.x,y,pr.box.w,h,8,8)
    end, "replace", 1)
  lg.setStencilTest("equal",1)
  lg.push() lg.translate(0,scroller.y_offset)
  lg.push()
  if pr.box.title~="" or #pr.box.msg > 1 then lg.translate(0,FONT_[2]:getHeight()) end
  lg.setFont(FONT_[1])
  lg.setColor(1,1,1,pr.box.innards*0.85)
  lg.printf(pr.box.msg[pr.box.msg_index], pr.box.x + 30, math.floor(pr.box.y + 20), tw - 60, "center")
  lg.setColor(0.7,0.7,0.7,pr.box.innards)
  lg.pop()
  lg.pop()
  lg.setStencilTest()
  for i,v in pairs(pr.box.buttons) do v:draw() end

  scroller:draw()
end
--

function pr.keypressed(key)
  if not pr.box.visible then return end
  if lerping then return true end
  if keyset.left(key) then
    pr.focus = ((pr.focus-1)-1)%#pr.box.buttons+1
  elseif keyset.right(key) then
    pr.focus = ((pr.focus+1)-1)%#pr.box.buttons+1
  elseif keyset.confirm(key) and pr.focus > 0 then
    pr.box.buttons[pr.focus].func()
  elseif keyset.back(key) then
    pr.close()
  end
  scroller:keypressed(key)
  return true
end
--

function pr.mousepressed(x,y,b)
  if not pr.box.visible then return end
  if b~=1 or lerping then return true end
  for i,v in pairs(pr.box.buttons) do v:mousepressed(x,y,b) end
  scroller:checkArea(x,y, {pr.box.x,pr.box.y,pr.box.w,pr.box.h})
  return true
end
--

function pr.mousereleased(x,y,b)
  if not pr.box.visible then return end
  if b~=1 or lerping then return true end
  for i,v in pairs(pr.box.buttons) do v:mousereleased(x,y,b) end
  return true
end
--

function pr.touchmoved(id,x,y,dx,dy)
  if not pr.box.visible then return end
  scroller:touchmoved(id,x,y,dx,dy)
  return true
end
--
function pr.wheelmoved(x,y)
  if not pr.box.visible then return end
  scroller:wheelmoved(x,y)
  return true
end
--

setmetatable(pr, { __call = function(_, ...) return pr.open(...) end})

return pr