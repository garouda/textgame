local ib = {}

local textbubble = require("textbubble")
local points_reminder = {
  alpha = 1, 
  img = lg.newImage("res/img/browser_newfile.png"),
}

ib.buttons = {}
ib.focused = false
local lerping

-- Bar icons
local icons = {
  {img=lg.newImage("res/img/bag.png"),func=function() Gamestate.push(states.inventory) end, tip="Check the items in your bag.", visible=true},
  {img=lg.newImage("res/img/stats.png"),func=function() Gamestate.push(states.stats) end, tip="Review your appearance, stats, and skills.", visible=true},
  {img=lg.newImage("res/img/explore.png"),func=function() Gamestate.push(states.explore) end, tip="Explore the surrounding area.", visible=true},
  {img=lg.newImage("res/img/history_book.png"),func=function() Misc.fade(function() Gamestate.push(states.history) end, 0.33) end,  tip="View the history log.", visible=true},
  {img=lg.newImage("res/img/menu.png"),func=function() Gamestate.push(states.pause) end, tip="Open the pause menu.", visible=true},
}
--
local icons_bak = Misc.tcopy(icons)

local bar
local icon_cols = {fg={{1,1,1,1},{1,1,1,1},{1,1,1,1}}}

function ib.whenExploring() bar.alpha = 0.5 ib.buttons[3].selected = true end

function ib.reset()
  bar = nil
  lerping = nil
  icons = Misc.tcopy(icons_bak)
  event.clear("override_icon")
  ib.init()
end
--

function ib.set(b,bool)
  for i,v in event.poll("override_icon") do if b == v[1] then bool = v[2] end end
  if bool==false then
    icons[b].visible = false
    ib.buttons[b].func = function() ib.say("You cannot do that here.", b) end
  elseif bool then
    ib.buttons[b].func = icons[b].func
    icons[b].visible = true
  end
end

function ib.getVisible()
  local t = {}
  for i,v in pairs(icons) do t[i] = v.visible end
  return t
end
--

function ib.say(msg,index,time)
  Timer.during(time or 1.5, function() ib.focused = true end, function() ib.focused = false end)
  return textbubble(msg, icon_bar.buttons[index].x+icon_bar.buttons[index].w/2,icon_bar.buttons[index].y,time or 1.5)
end
--

function ib.init()
  bar = {
    x = screen_width/4,
    y = screen_height-screen_height/20,
    w = screen_width-screen_width/2,
    h = screen_height/20,
    y_offset=0,
    alpha = 0.5,
    length = #icons,
  }
--
  bar.icon_pad = (bar.w-icons[1].img:getWidth()*4)/(bar.length+1)

  ib.buttons = {}
  local x = bar.x + bar.w/2 + bar.icon_pad/2 - ((icons[1].img:getWidth() + bar.icon_pad)*(bar.length))/2
  local y = bar.y - icons[1].img:getHeight() + bar.h/2
  for i,v in pairs(icons) do
    ib.buttons[i] = newButton(v.img, v.func, x, y, nil,nil, {cols=icon_cols,tip=v.tip,no_ripple=true})
    x = x + v.img:getWidth() + bar.icon_pad
  end
end
--

function ib.update(dt)
  points_reminder.alpha = (points_reminder.alpha - 1 * dt)
  if points_reminder.alpha < 0.33 then points_reminder.alpha = 1 end
  
  if choices.visible or shop.visible then return end
  if textbubble.update(dt) then return end

  local mx, my = Misc.getMouseScaled()

  if ib.focused or (mx > bar.x and mx < bar.x+bar.w and my > bar.y-icons[1].img:getHeight()) then
    bar.alpha = math.min(bar.alpha+2*dt,0.5)
  else
    bar.alpha = math.max(0.15,bar.alpha-1*dt)
  end

  for i,v in pairs(ib.buttons) do
    v:update(dt)
  end
end
--

function ib.draw()
  lg.setLineWidth(1)
  for i,v in pairs(ib.buttons) do
    lg.setColor(0,0,0,bar.alpha*0.6)
    lg.rectangle("fill", v.x-4, v.y-4, v.w+8, v.h+8, 8, 8)
    lg.setColor(1,1,1,bar.alpha*0.4)
    lg.rectangle("line", v.x-4, v.y-4, v.w+8, v.h+8, 8, 8)
    local col = {fg={{1,1,1,bar.alpha*0.6},{1,1,1,bar.alpha},{1,1,1,bar.alpha*0.25}}}
    if not icons[i].visible then
      col = {fg={{0,0,0,bar.alpha*0.6},{0,0,0,bar.alpha},{0,0,0,bar.alpha*0.25}}}
    end
    v:draw(col)
    if i==2 and player.points>0 then
      local w, h = 10, 30
      lg.setColor(0.6,1,0.6,points_reminder.alpha*(bar.alpha*2))
      lg.draw(points_reminder.img, v.x+v.w-5, v.y+5, nil, nil, nil, points_reminder.img:getWidth()/2, points_reminder.img:getHeight()/2)
    end
  end
  textbubble.draw()
end
--

function ib.keypressed(key)
  for i,v in pairs{"inventory","stats","explore","history"} do
    if icons[i].visible and keyset[v](key) then
      icons[i].func()
    end
  end
end
--

function ib.mousepressed(x,y,b,t)
  if choices.visible then return end
  for i,v in pairs(ib.buttons) do v:mousepressed(x,y,b) end
end
--

function ib.mousereleased(x,y,b,t)
  if choices.visible then return end
  for i,v in pairs(ib.buttons) do if v:mousereleased(x,y,b) then return true end end
  if textbubble.mousereleased(x,y,b,t) then return true end
end
--

ib.init()

return ib