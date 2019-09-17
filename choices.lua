local ch = {}
setmetatable(ch, { __call = function(_, ...) return ch.generate(...) end})

local op = out

local pointer_offset
local pointer_offset_max
local pointer_offset_dir
local working_src
local offset
local lerping
local dragging
local drag_offset
local hold_time
local old_misc_action
local selected_action
local queue
local FONT_
local mvment
local mvtotal
local mvtarget
local buttons

function ch.setOut(_out) op = _out end
function ch.getOut() return op end
--

function ch.select(num)
  if lerping or ch.box.a < ch.box.targeta then return end
  ch.chosen = ch.list[num]
  ch.chosen_n = num
  ch.last_pg_chosen = ch.chosen
  ch.close()

  selected_action(num)
end
--

function ch.nav(num)
  ch.selected = ch.selected + num
  if ch.selected < 1 then ch.selected = 1 end
  if ch.selected > #ch.list then ch.selected = #ch.list end
end
--

function ch.open(src,action)
  if lerping then return table.insert(queue, src) end

  if not src then return end
  ch.list_src = src
  ch.list = {}
  for c in src:gmatch("[%w%s%#%_%.%?%*%+%-%!%$%@%&%,%:\"\'%%/%(%)]*[^|]") do
    ch.list[#ch.list+1] = c:gsub("^%s*(.-)%s*$","%1")
  end

  ch.selected = 1
  ch.chosen = nil

  if #ch.list<3 then offset = offset + 45 end

  offset = (#ch.list-1)*-30

  old_misc_action = old_misc_action or Misc.action
  Misc.action = function() ch.select(ch.selected) end
  selected_action = action or function(num)
    local old_block = op.block
    op.block = false
    op.next(nil,num,true)
  end

  ch.box.h=0
  ch.box.a=0
  ch.box.texta=0
  ch.box.y = ch.box.basey
  ch.box.targety = ch.box.y - ch.box.targeth/2

  Flux.to(ch.box,0.5,{h=ch.box.targeth,a=ch.box.targeta,texta=0.75,y=ch.box.targety}):ease("quadout")
  ch.visible = true
end
--
function ch.close(instant)
  local speed = 0.5
  local function func()
    ch.box.h = 0
    ch.box.y = ch.box.basey
    ch.box.selyo = 0
    lerping=false
    ch.open(table.remove(queue,1))
  end
  ch.visible = false
  ch.list = {}
  Misc.action = old_misc_action or Misc.action
  old_misc_action = nil
  lerping = true
  local dir = 1
  if ch.box.targety+ch.box.targeth/2 < screen_height/2.5 then dir = -1 end
  if instant then
    ch.box.a, ch.box.texta, ch.box.selyo = 0, 0, screen_height/4
    return func()
  else
    Flux.to(ch.box, speed,{a=0,texta=0,y=ch.box.targety+(ch.box.targeth/2)*dir,selyo=screen_height/4}):ease("quadout"):oncomplete(func)
  end
end
--
function ch.hide(instant)
  if lerping or ch.box.a < ch.box.targeta or Gamestate.current()==states.postcombat then return end
  local speed = 0.5
  local function func()
    ch.box.h = 0
    ch.box.y = ch.box.basey
    ch.box.selyo = 0
    lerping = false
  end
  ch.visible = false
  ch.list = {}
  Misc.action = function() ch.open(ch.list_src) end
  lerping = true
  local dir = 1
  if ch.box.targety+ch.box.targeth/2 < screen_height/2.5 then dir = -1 end
  if instant then
    ch.box.a, ch.box.texta, ch.box.y, ch.box.selyo = 0, 0, ch.box.targety+(ch.box.targeth/2)*dir, screen_height/4
  else
    Flux.to(ch.box, speed,{a=0,texta=0,y=ch.box.targety+(ch.box.targeth/2)*dir,selyo=screen_height/4}):ease("quadout"):oncomplete(func)
  end
end
--


function ch.update(dt)
  offset = Misc.lerp(8*dt, offset, (ch.selected-1)*-30)

  pointer_offset = math.clamp(0, pointer_offset + (pointer_offset_max * pointer_offset_dir) * 4 * dt, pointer_offset_max)
  if (pointer_offset_dir == 1 and pointer_offset >= pointer_offset_max) or (pointer_offset_dir == -1 and pointer_offset <= 0) then
    pointer_offset_dir = pointer_offset_dir * -1
  end

  for i,v in pairs(buttons) do v:update(dt) end
end
--

function ch.draw()
  if ch.box.a == 0 then return end
  lg.setFont(FONT_[1])

  if lerping and ch.chosen then
    local x = (screen_width/2) - lg.getFont():getWidth(ch.chosen)/2
    local dir = 1
    if ch.box.targety+ch.box.targeth/2 < screen_height/2.5 then dir = -1 end
    lg.setColor(0,0,0,ch.box.texta*3)
    for _,o in pairs({-1,1,-2,2}) do
      lg.print(ch.chosen, x, ch.box.targety + ch.box.targeth/2 - ch.box.selyo*dir + o)
      lg.print(ch.chosen, x + o, ch.box.targety + ch.box.targeth/2 - ch.box.selyo*dir)
    end
    lg.setColor(1,1,1,ch.box.texta*3)
    lg.print(ch.chosen, x, ch.box.targety + ch.box.targeth/2 - ch.box.selyo*dir)
  end

  lg.stencil(function() lg.rectangle("fill",ch.box.x,ch.box.y,ch.box.w,ch.box.h) end, "replace", 1)
  lg.setStencilTest("greater",0)
  lg.setColor(0,0,0,ch.box.a*0.95)
  lg.rectangle("fill",ch.box.x,ch.box.y,ch.box.w,ch.box.h)
  if dragging then
    lg.setLineWidth(3)
    lg.setColor(1,1,0,ch.box.a)
    lg.rectangle("line",ch.box.x,ch.box.y,ch.box.w,ch.box.h)
    lg.setLineWidth(1)
  end

  if not lerping then
    for i,v in pairs(ch.list) do
      lg.setColor(1,1,1,ch.box.texta - (ch.box.texta*0.333)*(math.max(i,ch.selected) - math.min(i,ch.selected)))
      if i==ch.selected then lg.setColor(1,1,1,ch.box.texta*2) end
      local x = (screen_width/2) - lg.getFont():getWidth(v)/2
      lg.print(v,x,math.floor(offset+(ch.box.y+ch.box.h/2)+30*(i-1.65)))
    end
  end

  lg.setStencilTest()

  if not lerping then
    local w,h = lg.getFont():getWidth(ch.list[ch.selected] or ""),lg.getFont():getHeight(ch.list[ch.selected] or "")
    local sx,sy,sw,sh = screen_width/2-w/2-squarrow:getWidth()-10-pointer_offset, ch.box.y+ch.box.h/2-h/2, w+(squarrow:getWidth()+10+pointer_offset)*2, h
    lg.stencil(function() lg.rectangle("fill",sx,sy,sw,sh) end, "replace", 1)
    lg.setStencilTest("less",1 )
    lg.setColor(1,1,1,ch.box.texta/2)
    lg.line(ch.box.x,ch.box.y+ch.box.h/2,ch.box.w,ch.box.y+ch.box.h/2)
    lg.setStencilTest()
    lg.draw(squarrow, screen_width/2 + w/2 + squarrow:getWidth() + 10 + pointer_offset, ch.box.y + ch.box.h/2 - squarrow:getHeight()/2, nil, -1, 1)
    lg.draw(squarrow, screen_width/2 - w/2 - squarrow:getWidth() - 10 - pointer_offset, ch.box.y + ch.box.h/2 - squarrow:getHeight()/2)
    Misc.fadeline(ch.box.x,ch.box.y)
    Misc.fadeline(ch.box.x,ch.box.y+ch.box.h)
  end

  for i,v in pairs(buttons) do v:draw() end

  lg.setColor(1,1,1)
end
--

function ch.keypressed(key)
  if lerping then return true end
  if not ch.visible then return end
  if keyset.up(key) then
    ch.nav(-1)
  elseif keyset.down(key) then
    ch.nav(1)
  end
  if keyset.confirm(key) then
    ch.select(ch.selected)
  end
  return true
end
--

local mouse_on = false
function ch.mousepressed(x,y,b,t)
  mvment = 0
  mvtotal = 0
  mvtarget = FONT_[1]:getHeight()
  ch.moved_by_swipe = false
  if lerping then return true end
  if not ch.visible or b~=1 then return end
  for i,v in pairs(buttons) do v:mousepressed(x,y,b) end
  if x > ch.box.x and y > ch.box.y and x < ch.box.x+ch.box.w and y < ch.box.y+ch.box.h then
    if love.system.getOS()~="Android" then hold_time = 0.01 end
    mouse_on = true
    return true
  else
    ch.hide()
  end
end
--

function ch.mousereleased(x,y,b,t)
  local curr_mv = mvtotal
  mvtotal = 0
  hold_time, drag_offset = 0, 0
  if lerping then mouse_on = false return true end
  if math.abs(mvment) > FONT_[1]:getHeight() then mouse_on = false return true end
  if not ch.visible or b~=1 then return end
  if dragging then
    ch.box.targety = ch.box.y
    ch.box.basey = ch.box.targety+screen_height/4/2
    dragging = nil
    mouse_on = false
    return
  end
  for i,v in pairs(buttons) do if v:mousereleased(x,y,b) then mouse_on = false return true end end
  if x > ch.box.x and y > ch.box.y and x < ch.box.x+ch.box.w and y < ch.box.y+ch.box.h
  and mouse_on
  and curr_mv < mvtarget
  and (love.system.getOS()~="Android" or Gamestate.current()~=states.game) then
    mouse_on = false
    return true, ch.select(ch.selected)
  end
  mouse_on = false
end
--

function ch.touchmoved(id,x,y,dx,dy)
  if not mouse_on or not ch.visible or lerping then return end
  mvment = mvment + dy
  mvtotal = mvtotal + math.abs(dy)
  if mvment > mvtarget then
    ch.moved_by_swipe = true
    mvment = 0
    ch.nav(-1)
  elseif mvment < -mvtarget then
    ch.moved_by_swipe = true
    mvment = 0
    ch.nav(1)
  end
  for i,v in pairs(buttons) do v:touchmoved(id,x,y,dx,dy) end
  return true
end
--

function ch.wheelmoved(x,y)
  if lerping then return true end
  if not ch.visible then return end
  local mx,my = Misc.getMouseScaled()
  if mx > ch.box.x and my > ch.box.y and mx < ch.box.x+ch.box.w and my < ch.box.y+ch.box.h then
    if y>0 then
      ch.nav(-1)
    elseif y<0 then
      ch.nav(1)
    end
    return true
  end
end
--

function ch._initialize()
  pointer_offset = 0
  pointer_offset_max = 10
  pointer_offset_dir = 1

  op = out

  ch.visible = false
  ch.list = {}
  ch.list_src = ""
  ch.chosen = nil
  ch.last_pg_chosen = nil
  ch.chosen_n = nil
  ch.selected = 1
  ch.box = {
    x=0,
    y=screen_height-screen_height/4*(2/3),
    w=screen_width,
    h=0,
    targeth=screen_height/4,
    a=0,
    texta=0,
    selyo = 0,
    targeta=0.9,
  }
  ch.box.targety = ch.box.y-screen_height/4/2
  ch.box.basey = ch.box.y

  working_src = nil
  offset = 0
  lerping = nil
  dragging = nil
  drag_offset = 0
  hold_time = 0
  old_misc_action = nil
  selected_action = nil
  queue = {}

  FONT_ = {
    fonts.game_choices
  }

  buttons = {
    newButton("main", function() ch.select(ch.selected) end, ch.box.x, ch.box.targety+ch.box.targeth/2-FONT_[1]:getHeight()/2, ch.box.w, FONT_[1]:getHeight(), {visible=false}),
    newButton("up", function() ch.nav(-1) end, ch.box.x, ch.box.targety, ch.box.w, ch.box.targeth/2-FONT_[1]:getHeight()/2+1, {visible=false}),
    newButton("down", function() ch.nav(1) end, ch.box.x, ch.box.targety+ch.box.targeth/2+FONT_[1]:getHeight()/2-1, ch.box.w, ch.box.targeth/2, {visible=false})
  }

  mvment = 0
  mvtotal = 0
  mvtarget = FONT_[1]:getHeight()
  ch.moved_by_swipe = false  
end
--

ch._initialize()

return ch