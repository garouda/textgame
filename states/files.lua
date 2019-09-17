local st = {}

st.keyboard_focus = 0
st.selected = 0
st.page = 1
st.mode = 1
st.prevstate = "mainmenu"
local book = {img=lg.newImage("res/img/book.png"), yo = 0}
local box = {x=30, y=30, w=screen_width/3-30, h=screen_height/2.5-30}
local buttons = {}
local holdtime = 0
local holdlimit = 1.5
local filenames
local holding
local pagebaralpha = 0
local slide = {x=0, y=0}
local lerping
local l
local location_xoffs = {}
local mouse_on = {up=nil,down=nil}
local delete_warning = "Are you sure you want to delete this save file? You cannot undo this decision!"
local modename = {"Load","Save"}
local mode_name_alpha = 0.3
local mode_name_x = screen_width
local page_limit = 10
local prototype_entity = entity()

local FONT_ = {
  fonts.files_head,
  fonts.files_sub,
  fonts.files_time,
  fonts.files_mode,
  fonts.files_quicksave,
}

local function get_selected()
  local x,y = Misc.getMouseScaled()
  for i=1,6 do
    local xoff, yoff = i-1, 0
    if i>3 then yoff = yoff + 1 end
    if i>3 then xoff = xoff - 3 end
    if x > box.x + (box.w+15) * (xoff)
    and y > box.y + (box.h+15) * (yoff)
    and x < box.x + (box.w+15) * (xoff) + box.w
    and y < box.y + (box.h+15) * (yoff) + box.h
    then
      st.selected = i
    end
  end
  if mouse_on.down ~= st.selected then
    holdtime = 0
    holding = false
  end
end
--

local function handle_saveload()
  if st.mode==1 and st.list[st.selected+6*(st.page-1)] then
    if save.load(st.selected+6*(st.page-1)) then
      lerping = true
      Flux.to(slide, 0.5, {y=-screen_height*1.5}):ease("quadinout")
    end
  elseif st.mode==2 then
    if st.list[st.selected+6*(st.page-1)] then
      prompt("Do you really want to overwrite this file?",{function() save(nil,"save_" .. st.selected+6*(st.page-1)) end})
    else
--      save(nil,"save_" .. st.selected+6*(st.page-1))
      save()
    end
  end
end
--
local function change_mode(m)
  if m==0 then
    if st.prevstate=="mainmenu" then m = 1 else m = 2 end
  else
    if st.prevstate == "mainmenu" then return Misc.message("You can only switch modes when you're in-game.\nCheck the Tutorial on the top right for more info.") end
  end
  st.mode = m or math.abs((st.mode+1) % 2 - 2)
  mode_name_x = screen_width
end
--

function st.reload()
  st.list = {}
  filenames = {}
  for i,v in pairs(love.filesystem.getDirectoryItems("/")) do
    if v:match("%d+%.sv") then
      local decompedFile = love.filesystem.read(v)
      local index = tonumber(v:match("(%d+)"))
      st.list[index] = Tserial.unpack(decompedFile)
      st.list[index].player.species = Misc.capitalize(st.list[index].player.species)
      filenames[index] = v
      location_xoffs[index] = 0
    end
  end
end

function st.flip(d)
  d = d or 1
  pagebaralpha = 0.6
  st.page = math.clamp(1, st.page+d, page_limit)
end
--

function st:init()
  table.insert(buttons, newButton("Return", function() self.prep_leave() end, 30 ,screen_height-screen_height/6.5, 125, 50))
  table.insert(buttons, newButton("Prev", function() self.flip(-1) end, screen_width/2-130, screen_height-screen_height/6.5, 125, 50))
  table.insert(buttons, newButton("Next", function() self.flip() end, screen_width/2+5, screen_height-screen_height/6.5, 125, 50))
  buttons["?"] = newButton("?", function() Misc.tutorial("files") end, screen_width-30-10, 10, 30,30)
end
--
function st:enter(previous)
  st.reload()
  st.page = 1
  holding = false
  holdtime = 0
  l = 30
  lerping = true
  slide.y=0
  if slide.tween then slide.tween:stop() end
  slide.tween = Flux.to(slide, 0.35, {y=-screen_height-1}):ease("quadout"):oncomplete(function() lerping = false end)

  for i,v in pairs(states) do if v==previous then st.prevstate=i end end
  change_mode(0)
end
--
local old_isDown = love.mouse.isDown
function st:update(dt)
  if lerping then
    love.mouse.isDown = function()
      return false
    end
  else 
    love.mouse.isDown = old_isDown
  end

  if prompt.box.visible then
    holdtime = 0
    holding = false
    mouse_on.down = nil
    mouse_on.up = nil
    return
  end

  for i,v in pairs(buttons) do v:update(dt) end

  if holdtime == holdlimit and st.list[st.selected+6*(st.page-1)] then
    holdtime = 0
    holding = false
    mouse_on.down = nil
    mouse_on.up = nil
    prompt(delete_warning, {function() save.delete(st.selected) end})
  end

  if st.keyboard_focus==0 then
    st.selected = 0
    get_selected()
  end
  if holding then
    holdtime = math.min(holdlimit, holdtime + 1.5 * dt)
  end

  pagebaralpha = math.max(pagebaralpha - 0.8 * dt, 0)

  local x,y = Misc.getMouseScaled()
  if x>screen_width-140 and y>screen_height-80 then
    mode_name_alpha = math.min(mode_name_alpha + 1 *  5 * dt, 1)
  else
    mode_name_alpha = math.max(mode_name_alpha - 1 * 5 * dt, 0.3)
  end
  mode_name_x = Misc.lerp(dt*13, mode_name_x, screen_width-FONT_[4]:getWidth(modename[st.mode])-10)

  book.yo = book.yo + 1.5 * dt

  for i=1,6 do
    local v = st.list[i+6*(st.page-1)]
    if i==st.selected and v then
      location_xoffs[i+6*(st.page-1)] = location_xoffs[i+6*(st.page-1)] - FONT_[2]:getWidth(v.location)/6 * dt
      if location_xoffs[i+6*(st.page-1)] <= -FONT_[2]:getWidth(v.location)/2 then
        location_xoffs[i+6*(st.page-1)] = FONT_[2]:getWidth(v.location)/4
      end
    elseif i~=st.selected and v then
      location_xoffs[i+6*(st.page-1)] = 15
    end
  end
end
--
function st:draw()
  if slide.y > -screen_height and Gamestate.current() == states.files then
    lg.push()
    lg.translate(slide.x,-slide.y)
    states[st.prevstate].draw()
    lg.pop()
  end
  lg.push()
  lg.translate(slide.x,-math.floor(slide.y+1)-screen_height)

  lg.setColor(0,0,0)
  lg.draw(fadegradient,screen_width,-screen_height/2,math.pi/2,0.5,screen_width)

  lg.stencil(function() lg.rectangle("fill", 0, 0, screen_width, screen_height) end, "replace", 1)
  lg.setStencilTest("greater", 0)
  lg.setColor(0.1,0.1,0.1,0.5)
  lg.draw(book.img,screen_width-60,screen_height-40+(math.sin(book.yo)*10),0,1,1,book.img:getWidth()/2,book.img:getHeight()/2)
  lg.setStencilTest()

  for i=1,6 do
    local xoff, yoff = i-1, 0
    if i>3 then yoff = yoff + 1 end
    if i>3 then xoff = xoff - 3 end
    if i==st.selected then
--      lg.setColor(80,120,100,127)
      lg.setColor(0.4,0.4,0.4,0.4)
      if mouse_on.down == st.selected then
--        lg.setColor(50,90,80,127)
        lg.setColor(0.7,0.7,0.7,0.5)
      end
    else
      lg.setColor(0,0,0,0.5)
    end
    local a = holdtime/holdlimit
    if st.selected ~= i then a = 0 end
    lg.rectangle("fill", box.x+(box.w+15)*(xoff), box.y+(box.h+15)*(yoff), box.w, box.h, 10,10)
    lg.setColor(1,1,1,0.1)
    lg.rectangle("line", box.x+(box.w+15)*(xoff), box.y+(box.h+15)*(yoff), box.w, box.h, 10,10)

    if i+6*(st.page-1) == settings.quicksave_slot then
--      lg.setLineWidth(5)
      lg.setColor(1,0.7,0.2,0.15)
      lg.rectangle("fill", box.x+(box.w+15)*(xoff), box.y+(box.h+15)*(yoff), box.w, box.h, 10,10)
      lg.setLineWidth(1)
    end

    lg.setColor(1,1,1,0.8)
    if st.list[i+6*(st.page-1)] then
      lg.stencil(function() lg.rectangle("fill", box.x+(box.w+15)*(xoff), box.y+(box.h+15)*(yoff), box.w, box.h, 10,10) end, "replace", 1)
      lg.setStencilTest("greater", 0)
      local v = st.list[i+6*(st.page-1)]
      setmetatable(v.player, { __index = prototype_entity})
      lg.setFont(FONT_[1])
      lg.setColor(1,1,1,0.95)
      lg.printf(v.player.name, box.x + (box.w+15) * (xoff), box.y + 5 + (box.h+15) * (yoff), box.w, "center")
      Misc.fadeline(box.x + 20 + (box.w+15) * xoff, box.y + 43 + (box.h+15) * yoff, nil, box.w-40, 1)

      if i+6*(st.page-1) == settings.quicksave_slot then
        lg.setFont(FONT_[4])
        lg.setColor(0,0,0,0.25)
        lg.print("Quicksave", box.x+box.w/2+(box.w+15)*(xoff), box.y+box.h/2 + (box.h+15)*(yoff), -math.pi/6, 1, nil, FONT_[4]:getWidth("Quicksave")/2, FONT_[4]:getHeight()/2)
      end

      lg.setFont(FONT_[2])
      lg.setColor(1,1,1,0.8)
      lg.printf("Lv. "..v.player.lvl, box.x + (box.w+15) * (xoff), box.y + 5 + FONT_[1]:getHeight(v.player.name) + (box.h+15) * (yoff), box.w, "center")
      lg.printf(v.player.species, box.x + (box.w+15) * (xoff), box.y + 5 + FONT_[1]:getHeight(v.player.name)*1.7 + (box.h+15) * (yoff), box.w, "center")

      local loc_scroll_offset = 0
      if FONT_[2]:getWidth(v.location) > box.w then
        loc_scroll_offset = math.clamp(-(FONT_[2]:getWidth(v.location)%box.w)-box.w/2+FONT_[2]:getWidth(v.location)/2-15, location_xoffs[i+6*(st.page-1)]-box.w/2+FONT_[2]:getWidth(v.location)/2, -box.w/2+FONT_[2]:getWidth(v.location)/2+15)
      end
      lg.print(v.location, box.x + box.w/2 - FONT_[2]:getWidth(v.location)/2 + loc_scroll_offset + (box.w+15) * (xoff), box.y + 5 + FONT_[1]:getHeight(v.player.name)*2.45 + (box.h+15) * (yoff))

      lg.setFont(FONT_[3])
      lg.setColor(1,1,1,0.5)
      lg.printf(v.save_time,box.x + 20 + (box.w+15) * (xoff), box.y + box.h - FONT_[3]:getHeight(1) - 10 + (box.h+15) * (yoff), box.w-15, "left")
      lg.printf(v.save_date,box.x + (box.w+15) * (xoff), box.y + box.h - FONT_[3]:getHeight(1) - 10 + (box.h+15) * (yoff), box.w-15, "right")
      if st.selected == i then
        lg.setColor(0,0,0,0.4)
        lg.rectangle("fill", box.x+(box.w+15)*(xoff), box.y+(box.h+15)*(yoff)+box.h, box.w, -box.h*(holdtime/(holdlimit-.4)-.4))
      end
      lg.setStencilTest()
    else
      lg.setFont(FONT_[2])
      if i+6*(st.page-1) == settings.quicksave_slot then
        lg.setFont(FONT_[4])
        lg.setColor(0,0,0,0.25)
        lg.print("Quicksave", box.x+box.w/2+(box.w+15)*(xoff), box.y+box.h/2 + (box.h+15)*(yoff), -math.pi/6, nil, nil, FONT_[4]:getWidth("Quicksave")/2, FONT_[4]:getHeight()/2)
      else
        lg.setColor(0,0,0,0.4)
        lg.print("Empty",box.x+box.w/2-FONT_[2]:getWidth("Empty")/2+(box.w+15) * xoff, box.y+box.h/2-17+(box.h+15)*yoff)
      end
    end
  end

  lg.setColor(1,1,1,math.min(pagebaralpha,0.4))
  l = Misc.lerp(love.timer.getDelta()*10, l, 30+((screen_width-60)/page_limit)*(st.page-1))
  lg.rectangle("fill", l, screen_height-108, (screen_width-60)/page_limit, 5, 5, 5)

  lg.setColor(1,1,1,mode_name_alpha)
  lg.setFont(FONT_[4])
  lg.print(modename[st.mode], mode_name_x, screen_height-FONT_[4]:getHeight(modename[st.mode])-10)

  for i,v in pairs(buttons) do v:draw() end
  lg.pop()

  lg.setColor(1,1,1)
end
--
function st:prep_leave()
  lerping = true
  if slide.tween then slide.tween:stop() end
  slide.tween = Flux.to(slide, 0.35, {y=0}):ease("quadout"):oncomplete(Gamestate.pop)
end
--
function st:keypressed(key)
  if lerping then return end

  if st.keyboard_focus == 0 then st.keyboard_focus = 1 end
  if keyset.left(key) then
    if st.selected == 1 and st.page > 1 then
      st.flip(-1)
      st.selected = 3
    elseif st.selected == 4 and st.page > 1 then
      st.flip(-1)
      st.selected = 6
    elseif st.selected~=1 and st.selected~=4 then
      st.selected = st.selected-1
    end
    if st.selected<1 then st.selected = 1 end
  end
  if keyset.right(key) then
    if st.selected == 3 and st.page < 10 then
      st.flip(1)
      st.selected = 1
    elseif st.selected == 6 and st.page < 10 then
      st.flip(1)
      st.selected = 4
    elseif st.selected~=3 and st.selected~=6 then
      st.selected = st.selected+1
    end
  end
  if keyset.up(key) and st.selected >=4 then
    st.selected = st.selected-3
  end
  if keyset.down(key) and st.selected <=3 then
    st.selected = math.clamp(1, st.selected+3, 6)
  end
  if keyset.confirm(key) and st.selected > 0 then
    handle_saveload()
  end
  if keyset.back(key) then
    self.prep_leave()
  end
  if key=="delete" and st.list[st.selected+6*(st.page-1)] then 
    prompt(delete_warning, {function() save.delete(st.selected) end})
  end

  if key=="tab" then
    change_mode()
  end
end
--
function st:mousepressed(x,y,b,t)
  if lerping or prompt.box.visible then return end
  if b==2 then return self.prep_leave() end
  for i,v in pairs(buttons) do v:mousepressed(x,y,b) end

  if x>screen_width-150 and y>screen_height-150 then
    change_mode()
  end

  st.keyboard_focus = 0
  mouse_on.down = st.selected
  holding = true
  holdtime = 0
end
--
function st:mousereleased(x,y,b,t)
  if prompt.box.visible or lerping or b~=1 then mouse_on.down = nil return end
  mouse_on.up = st.selected

  for i,v in pairs(buttons) do v:mousereleased(x,y,b) end

  if st.selected > 0 and holdtime < holdlimit and mouse_on.down == mouse_on.up then
    handle_saveload()
  end
  mouse_on.down = nil
  holding = false
  holdtime = 0
end
--
function st:wheelmoved(x,y)
  if prompt.box.visible then return end
  st.flip(-y)
end
--
function st:leave()
  slide.tween:stop()
  slide.x,slide.y = 0,0
  lerping = false
  st.keyboard_focus = 0
end
--

return st