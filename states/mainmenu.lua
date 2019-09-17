local st = {}

local pointer_offset_max = 5

local FONT_ = {
  fonts.mainmenu_items,
  fonts.mainmenu_copyright,
} 
--

st.keyboard_focus = 1
st.selected = 1
st.alpha=0

local mouse_on
local bg_sin = 0

local mm_buttons = {
  {"New", function() Misc.fade(function() Gamestate.switch(states.game) out.change("introduction",nil,1) end, 1) end},
  {"Load", function() states.files.mode = 1 states.files.prevstate="mainmenu" Gamestate.push(states.files) end},
  {"Settings", function() Misc.fade(function() Gamestate.push(states.settings) end) end},
  {"Exit", love.event.quit},
}
--
local fg_ui = {
  newButton("Changelog", function() Misc.changelog() end, screen_width-150-15, 15, 150, nil)
}

for i=1, #mm_buttons do
  mm_buttons[i].box = {
    x = screen_width/2 - FONT_[1]:getWidth(mm_buttons[i][1])/2-10,
    y = (screen_height*0.7) - (45/2 * (#mm_buttons-1)) + 45 * (i-1) - FONT_[1]:getHeight(mm_buttons[i][1])/2+16,
    w = FONT_[1]:getWidth(mm_buttons[i][1])+20,
    h = FONT_[1]:getHeight(mm_buttons[i][1]),
  }
  mm_buttons[i].pointer_offset = 0
  mm_buttons[i].pointer_offset_dir = 1
end
--
local function get_selected()
  local x,y = Misc.getMouseScaled()
  for i,v in pairs(mm_buttons) do
    if x > v.box.x
    and y > v.box.y
    and x < v.box.x + v.box.w
    and y < v.box.y + v.box.h
    then
      st.selected = i
      st.keyboard_focus = i
      return i
    end
  end
end
--

function st:init()
  particles.bokeh:emit(127)
end
--
function st:enter()
  bgimage.clear()
  Misc.setBG(0.6,0.55,0.4,0)
  bg_sin = 0
--  Misc.setBG(0.4,0.6,0.4,0)
  weather.set(4,0)
  Flux.to(st,1,{alpha=0})
  
  bgimage._initialize()
end
--
function st:update(dt)
  weather.update(dt)
  if prompt.box.visible then return end
  if not mouse_on and st.keyboard_focus==0 then
    st.selected = 0
    get_selected()
  end
  for i,v in pairs(mm_buttons) do
    if st.selected == i then
      v.pointer_offset = (v.pointer_offset + pointer_offset_max * 4 * dt) % (pointer_offset_max*2)
    else
      v.pointer_offset = 0
      v.pointer_offset_dir = 1
    end
  end
  for i,v in pairs(fg_ui) do v:update(dt) end
  
  bg_sin = (bg_sin + dt)
--  Misc.setBG(0.3+(0.1)*math.sin(bg_sin*0.15),nil,nil,0)
end
--
function st:draw()
  lg.setColor(0.6,0.6,0.6)
  lg.setColor(1,1,1)
  weather.draw()

  lg.setColor(1,1,1,1)

  lg.setFont(FONT_[1])
  for i,v in ipairs(mm_buttons) do
    lg.setColor(1,1,1,0.3)
    if st.selected == i then
      lg.setColor(1,1,1,0.85)
      if mouse_on == i then
        lg.setColor(0,0,0,0.7)
      end
      lg.draw(squarrow, screen_width/2 + FONT_[1]:getWidth(v[1])/2 + squarrow:getWidth() + 10 + math.abs(v.pointer_offset-pointer_offset_max), (screen_height*0.7) - (45/2 * (#mm_buttons-1)) + 45 * (i-1) - 0, nil, -1, 1)
      lg.draw(squarrow, screen_width/2 - FONT_[1]:getWidth(v[1])/2 - squarrow:getWidth() - 3 -  math.abs(v.pointer_offset-pointer_offset_max), (screen_height*0.7) - (45/2 * (#mm_buttons-1)) + 45 * (i-1) - 0, nil, 1, 1)
    end
    lg.printf(v[1], 0, (screen_height*0.7) - (45/2 * (#mm_buttons-1)) + 45 * (i-1) - 9, screen_width, "center")
    lg.setColor(1,1,1,0.3)
    if i < #mm_buttons then Misc.fadeline(0, (screen_height*0.7) - (45/2 * (#mm_buttons-1)) + 45 * (i) - 6) end
  end

  for i,v in pairs(fg_ui) do v:draw(nil,0.55) end

  lg.setColor(0,0,0,st.alpha)
  lg.rectangle("fill",0,0,screen_width,screen_height)
end
--
function st:keypressed(key)
  if keyset.up(key) then
    st.keyboard_focus = st.keyboard_focus-1
    if st.keyboard_focus < 1 then st.keyboard_focus = 4 end
  end
  if keyset.down(key) then
    st.keyboard_focus = st.keyboard_focus+1
    if st.keyboard_focus > #mm_buttons then st.keyboard_focus = 1 end
  end
  if keyset.confirm(key) and st.selected>0 then
    mm_buttons[st.selected][2]()
  end
  if keyset.back(key) then love.event.quit() end
  st.selected = st.keyboard_focus
end
--
function st:mousepressed(x,y,b)
  if b~=1 then return end
  mouse_on = get_selected()
  
  for i,v in pairs(fg_ui) do v:mousepressed(x,y,b) end
end
--
function st:mousereleased(x,y,b)
  for i,v in pairs(fg_ui) do v:mousereleased(x,y,b) end
  if not mouse_on then return end
  if mouse_on == get_selected() then
    mm_buttons[st.selected][2]()
  end
  mouse_on = nil
end
--
function st:leave()
  st.keyboard_focus = 0
end
--

return st