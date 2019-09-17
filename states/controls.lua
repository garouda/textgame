local st = {}
st.keyboard_focus = 0
st.selected = 0

local newScroller = require("elements.scroller")

local elements = {}
local fg_ui = {}

local list = {}
local used_keys = {}

local buttons = {}

local active_map

local unable_msg = "That key is already in use."
local msg_alpha = 0

local box = {
  x = 60,
  y = 60,
  w = screen_width/2-60,
}

local FONT_ = {
  fonts.controls_headers,
  fonts.controls_descriptions,
  fonts.controls_mappings,
}

function st.load()
  if not love.filesystem.getInfo("controls") then return end
  local c = Tserial.unpack(love.filesystem.read("controls"),true) or {}
  for i,v in pairs(c) do if keyset[i] then keyset[i].map = v end end
end
--

function st:init()
  for i,v in pairs(keyset) do
    list[v.index] = {i,v}
    if not i:match("^hotkey[^%d]-%d+") then
      for _,v in pairs(v.map) do table.insert(used_keys,v) end
    end
  end
  box.h = (FONT_[1]:getHeight()*2.5)*(#list+1)+(box.y/2)-screen_height

  fg_ui["return_button"] = newButton("Return", function() st.commit(true) end, 30 ,screen_height-screen_height/6.5, 125, 50)
  fg_ui["scroller"] = newScroller(0, 0, box.h, screen_width-30, screen_height/8, screen_height-(screen_height/8*2))
end
--
function st:enter()
  fg_ui["scroller"].value = 0
  fg_ui["scroller"]:moveTo(0)
  active_map = nil
  msg_alpha = 0

  local yy = box.y
  for n,v in pairs(list) do
    for i=1,3 do
      local wh = FONT_[2]:getHeight()*5
      local x = box.x+box.w+10 + (30 + wh)*(i-1)
      local y = yy+FONT_[1]:getHeight()-wh/5
      local r_func = function()
        for ind,key in pairs(used_keys) do
          if key==v[2].map[i] and not v[1]:match("^hotkey[^%d]-%d+") then
            used_keys[ind] = nil
          end
        end
        v[2].map[i] = nil
        active_map = nil 
      end
      buttons[n..","..i] = buttons[n..","..i] or newButton("", {function() active_map={n,i} end, r_func}, x, y+wh/2-FONT_[3]:getHeight()/2-10, wh, FONT_[3]:getHeight()+20)
    end
    yy = yy + (FONT_[1]:getHeight()*2.5)
  end
end
--
local old_isDown = love.mouse.isDown
local dir = 1
function st:update(dt)
  for i,v in pairs(elements) do
    if v.y+v.h + fg_ui["scroller"].y_offset > 0 and v.y + fg_ui["scroller"].y_offset < screen_height then
      v:update(dt,nil,fg_ui["scroller"].y_offset)
    end
  end
  for i,v in pairs(fg_ui) do v:update(dt) end
  for i,v in pairs(buttons) do
    if v.y+v.h + fg_ui["scroller"].y_offset > 0 and v.y + fg_ui["scroller"].y_offset < screen_height then
      v:update(dt,nil,fg_ui["scroller"].y_offset)
    end
  end
  msg_alpha = msg_alpha - 1 * dt
end
--
function st:draw()
  lg.push()
  lg.translate(0,fg_ui["scroller"].y_offset)

  lg.stencil(function() lg.rectangle("fill",30,screen_height-screen_height/6.5-fg_ui["scroller"].y_offset,125,50,6,6) end, "replace", 1)
  lg.setStencilTest("less", 1)

  local yy = box.y
  for n,v in pairs(list) do
    if (yy+(FONT_[1]:getHeight()*2.5)) + fg_ui["scroller"].y_offset > 0 and yy + fg_ui["scroller"].y_offset < screen_height then
      lg.setColor(1,1,1)
      lg.setFont(FONT_[1])
      lg.print(Misc.capitalize(v[1]):gsub("_", " "), box.x, yy)
      lg.setFont(FONT_[2])
      lg.printf(v[2].desc, box.x, yy+FONT_[1]:getHeight(), box.w)
      lg.setColor(0,0,0,0.8)
      for i=1,3 do
        local wh = FONT_[2]:getHeight()*5
        local x = box.x+box.w+10 + (30 + wh)*(i-1)
        local y = yy+FONT_[1]:getHeight()-wh/5
        lg.setColor(0,0,0,0.8)
        lg.setLineWidth(3)
        lg.setFont(FONT_[3])
        if v[2].map[i] then
          lg.rectangle("fill",x, y+wh/2-FONT_[3]:getHeight()/2-10, wh, FONT_[3]:getHeight()+20, 8, 8)
          lg.setColor(1,1,1,0.9) 
          lg.printf(Misc.capitalize(v[2].map[i]),x,y+wh/2-FONT_[3]:getHeight()/2,wh,"center")
        else
          lg.setColor(1,1,1,0.3)
          lg.printf(". . .",x,y+wh/2-FONT_[3]:getHeight()/2,wh,"center")
        end
        if (active_map and active_map[1]==n and active_map[2]==i) then
          lg.setColor(0.9,0.82,0.3,0.4)
          lg.rectangle("fill",x, y+wh/2-FONT_[3]:getHeight()/2-10, wh, FONT_[3]:getHeight()+20, 8, 8)
        end
        lg.setLineWidth(1)
      end
    end
    yy = yy + (FONT_[1]:getHeight()*2.5)
  end

  lg.setStencilTest()

  for i,v in pairs(elements) do
    if v.y+v.h + fg_ui["scroller"].y_offset > 0 and v.y + fg_ui["scroller"].y_offset < screen_height then
      v:draw()
    end
  end
  for i,v in pairs(buttons) do
    if v.y+v.h + fg_ui["scroller"].y_offset > 0 and v.y + fg_ui["scroller"].y_offset < screen_height then
      v:draw()
    end
  end

  lg.pop()

  lg.setFont(FONT_[1])
  lg.setColor(0,0,0,0.7*(msg_alpha/1))
  lg.rectangle("fill",screen_width/2-FONT_[1]:getWidth(unable_msg)/2-15,screen_height/2-FONT_[1]:getHeight(unable_msg)/2-5,FONT_[1]:getWidth(unable_msg)+30, FONT_[1]:getHeight(unable_msg)+10,10,10)
  lg.setColor(1,1,1,0.8*(msg_alpha/1))
  lg.printf(unable_msg,0,screen_height/2-FONT_[1]:getHeight(unable_msg)/2,screen_width,"center")

  for i,v in pairs(fg_ui) do v:draw() end
end
--
function st:keypressed(key)
  st.keyboard_focus = 1

  if active_map then
    local function ok()
      local k = true
      for i,v in pairs(used_keys) do
        if v==list[active_map[1]][2].map[active_map[2]] then k = i end
        if v==key then return nil end
      end
      return k
    end
    local k = ok()
    if list[active_map[1]][1]:match("^hotkey[^%d]-%d+") then k = 0 end
    if k then
      list[active_map[1]][2].map[active_map[2]] = key
      if k~=0 then used_keys[k] = key end
    else
      msg_alpha = 1.5
    end
    active_map = nil
    return
  end
end
--
function st:mousepressed(x,y,b,t)
  st.keyboard_focus = 0
  for i,v in pairs(elements) do if v:mousepressed(x,y,b,nil,fg_ui["scroller"].y_offset) then return end end
  if fg_ui["return_button"]:mousepressed(x,y,b) then return end
  for i,v in pairs(buttons) do if v:mousepressed(x,y,b,nil,fg_ui["scroller"].y_offset) then return end end
end
--
function st:mousereleased(x,y,b,t)
  for i,v in pairs(elements) do v:mousereleased(x,y,b,nil,fg_ui["scroller"].y_offset) end
  fg_ui["return_button"]:mousereleased(x,y,b)
  for i,v in pairs(buttons) do v:mousereleased(x,y,b,nil,fg_ui["scroller"].y_offset) end
end
--
function st:wheelmoved(x,y)
  fg_ui["scroller"]:wheelmoved(x,y)
end
--
function st:leave()
  st.keyboard_focus = 0
end
--
function st.commit(pop)
  local c = {}
  for i,v in pairs(list) do
    c[v[1]] = v[2].map
  end
  save(c,"controls")
  if pop then Gamestate.pop() end
end
--

return st