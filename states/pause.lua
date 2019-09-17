local st = {}
local slide = {x=0, y=0, a=0}
local lerping
local mouse_on
local pad = 33
local previews = {
  {text="Save", img=lg.newImage("res/img/book.png"), func=function() Gamestate.push(states.files) end},
  {text="-------", img=lg.newImage("res/img/flock.png"), func=function() end},
  {text="Settings", img=lg.newImage("res/img/cog.png"), func=function() Misc.fade(function() Gamestate.push(states.settings) end) end},
  {text="Quit", img=lg.newImage("res/img/cloud.png"), func=function()
      prompt("Do you really want to quit?\nUnsaved progress will be lost.", {function() Misc.fade(function() Gamestate.switch(states.mainmenu) end) end})
    end},
}
local seg = {
  {x=pad,y=pad,w=screen_width/2-pad*1.5, h=screen_height/2-pad*1.8},
  {x=pad,y=screen_height/2-10,w=screen_width/2-pad*1.5, h=screen_height/2-pad*1.8},
  {x=screen_width/2+pad/2,y=pad,w=screen_width/2-pad*1.5,h=screen_height/2-pad*1.8},
  {x=screen_width/2+pad/2,y=screen_height/2-10,w=screen_width/2-pad*1.5,h=screen_height/2-pad*1.8},
}

local FONT_ = {
  fonts.pause_previews
}

local game_canvas = lg.newCanvas(screen_width,screen_height)
local previews_canvas = lg.newCanvas(screen_width,screen_height)

st.flux = Flux.group()

local function get_selected()
  local x,y = Misc.getMouseScaled()
  for i,v in pairs(seg) do
    if x > v.x
    and y > v.y
    and x < v.x + v.w
    and y < v.y + v.h
    then
      st.selected, st.keyboard_focus = i, i
      return i
    end
  end
end
--

local function drawBackground()
  lg.setCanvas({game_canvas, stencil=true})
  lg.clear()
  lg.push()
  local sx, sy = Misc.toGame()
  lg.scale(1/sx, 1/sy)
  states.game:draw()
  lg.pop()
  lg.setCanvas()
end
--

function st:prep_leave()
  if lerping or Misc.fade.lerping then return end
  lerping = true
  mouse_on = nil
  st.keyboard_focus = 0
  st.selected = 0
  prompt.close()
  slide.tween = Flux.to(slide, 0.35, {y=0,a=0}):ease("quadout"):oncomplete(function() Gamestate.pop() end)
end
--
function st:init()
  local function func()
    lg.setCanvas({previews_canvas,stencil=true})
    lg.clear()
    lg.push()
    local sx, sy = Misc.toGame()
    lg.scale(1/sx, 1/sy)
    -- Draw segment bgs
    for i=1,#seg do
      lg.setColor(0.07,0.07,0.07,1)
      lg.rectangle("fill",seg[i].x,seg[i].y,seg[i].w,seg[i].h,15,15)
      lg.setColor(1,1,1,0.3)
      lg.rectangle("line",seg[i].x,seg[i].y,seg[i].w,seg[i].h,15,15)
    end

    -- Draw button preview images
    lg.setFont(FONT_[1])
    for i,v in pairs(previews) do
      lg.stencil(function() lg.rectangle("fill", seg[i].x,seg[i].y,seg[i].w,seg[i].h,15,15) end, "replace", 1)
      lg.setStencilTest("greater", 0)
      lg.setColor(0.6,0.6,0.6,0.85)
      lg.draw(v.img,seg[i].x+seg[i].w,seg[i].y+seg[i].h,0,1,1,v.img:getWidth()/2,v.img:getHeight()/2)
      lg.setColor(1,1,1)
      lg.print(v.text,seg[i].x+seg[i].w/2-FONT_[1]:getWidth(v.text)/2,seg[i].y+seg[i].h/2-FONT_[1]:getHeight(v.text)/2)
      lg.setColor(1,1,1)
      Misc.fadeline(seg[i].x,seg[i].y+seg[i].h/2+FONT_[1]:getHeight()/3,0,seg[i].w,1)
      lg.setStencilTest()
    end
    lg.pop()
    lg.setCanvas()
  end
  func()
  event.wish("window_reset", function() drawBackground() func() end)
end
--
function st:enter()
  lerping = true
  slide.tween = Flux.to(slide, 0.5, {y=-screen_height-1,a=0.3}):ease("quintout"):oncomplete(function() lerping = false end)
  st.keyboard_focus = 0
  st.selected = 0
  get_selected()
  drawBackground()
end
--
function st:update(dt)
  st.flux:update(dt)
  if st.keyboard_focus==0 and not love.mouse.isDown(1) and not prompt.box.visible then
    st.selected = 0
    get_selected()
  end
end
--
function st:draw()
  lg.setColor(1,1,1)
  lg.setBlendMode("alpha", "premultiplied")
  lg.draw(game_canvas)
  lg.setBlendMode("alpha")
  
  lg.setColor(0,0,0,slide.a)
  lg.rectangle("fill",0,0,screen_width,screen_height)

  lg.push()
  lg.translate(slide.x,math.floor(slide.y+1)+screen_height)

  if st.selected>0 then
    if mouse_on ~= st.selected then lg.setColor(1,1,1) else lg.setColor(0,0,0,1) end
    lg.rectangle("fill",seg[st.selected].x,seg[st.selected].y,seg[st.selected].w,seg[st.selected].h,15,15)
    lg.setLineWidth(2)
    lg.rectangle("line",seg[st.selected].x,seg[st.selected].y,seg[st.selected].w,seg[st.selected].h,15,15)
    lg.setLineWidth(1)
  end

  lg.setColor(1,1,1,0.95)
  lg.draw(previews_canvas)

  lg.pop()
end
--
function st:keypressed(key)
  if lerping then return end

  if keyset.back(key) then 
    self.prep_leave()
    return
  end
  if keyset.confirm(key) and st.keyboard_focus ~= 0 then
    previews[st.keyboard_focus].func()
    return
  end

  if (st.keyboard_focus == 0 and st.selected == 0) then
    st.keyboard_focus, st.selected = 1, 1
    return
  end

  if keyset.left(key) and st.selected > 2 then
    st.keyboard_focus = math.clamp(1,st.keyboard_focus-2,4)
  end
  if keyset.right(key) and st.selected < 3 then
    st.keyboard_focus = math.clamp(1,st.keyboard_focus+2,4)
  end
  if keyset.up(key) and st.selected % 2 == 0 then
    st.keyboard_focus = math.clamp(1,st.keyboard_focus-1,4)
  end
  if keyset.down(key) and st.selected % 2 == 1 then
    st.keyboard_focus = math.clamp(1,st.keyboard_focus+1,4)
  end
  st.selected = st.keyboard_focus
end
--
function st:mousepressed(x,y,b,t)
  if b==2 then return self.prep_leave() end
  if prompt.box.visible then return end
  if mouse_on == 0 or not get_selected() then return self.prep_leave() end
  mouse_on = st.selected
end
--
function st:mousereleased(x,y,b,t)
  if prompt.box.visible or not mouse_on then return end
  if mouse_on == get_selected() then
    previews[mouse_on].func()
  end
  mouse_on = nil
end
--
function st:leave()
  slide.tween:stop()
  slide.x,slide.y,slide.a = 0,0,0
  mouse_on = nil
  lerping = false 
end
--

return st