local st = {}
st.flux = Flux.group()

local isdead
local slash = lg.newImage("res/img/slash.png")
local display_subtext
local timer = Timer.new()
local gameover_splash
local subtxt
local sub_alpha = 0
local stencilstuff = {
  h = 4,
  a = 1,
  y = screen_height,
  a2 = 0,
  a3 = 1,
}

local FONT_ = {
  fonts.gameover_main,
  fonts.gameover_sub,
}

local function exit()
  st.flux:to(stencilstuff, 2, {a3=0})
  timer:after(3, function()
      Misc.fade(function() Gamestate.switch(states.mainmenu) end)
    end)
  timer:after(0.5, function() display_subtext = true end)
end
--

function st:init()
end
--
function st:enter(_,final)
  isdead = final
  gameover_splash = "GAME OVER"
  subtxt = "You will return to the main menu."

  Misc.flash()
  Misc.shake(10,0.75)
  stencilstuff.h = 0
  stencilstuff.a = 1
  stencilstuff.a2 = 0
  stencilstuff.a3 = 1
  display_subtext = false
  sub_alpha = 0
  st.flux:to(stencilstuff, 0.15, {h=screen_height*1.5}):after(1, {a=0}):delay(1)
  st.flux:to(stencilstuff, 2, {a2=1}):delay(2):oncomplete(function() exit() end):after(1.2,{a2=0}):delay(1.5)
  event.grant("combat_end")
end
--
function st:update(dt)
  st.flux:update(dt)
  timer:update(dt)
  if display_subtext then sub_alpha = math.min(1, sub_alpha + 1 * dt) end
end
--
function st:draw()
  lg.setColor(0,0,0,1)
  lg.rectangle("fill",0,0,screen_width,screen_height)
  local stencil_function = function()
    lg.push()
    lg.translate(screen_width/2, screen_height/2)
    lg.rotate(1)
    lg.translate(-screen_width/2, -screen_height/2)
    lg.rectangle("fill",0,-100,screen_width,stencilstuff.h)
    lg.pop()
  end
  lg.setColor(1,0,0,stencilstuff.a)
  lg.stencil(stencil_function, "replace", 1)
  lg.setStencilTest("greater",0)
  lg.draw(slash)
  lg.setStencilTest()
  lg.setFont(FONT_[1])
  lg.setColor(1,0,0,stencilstuff.a2)
  lg.print(gameover_splash,screen_width/2-FONT_[1]:getWidth(gameover_splash)/2,screen_height/2-FONT_[1]:getHeight(gameover_splash)/2)

  if display_subtext then
    lg.setColor(1,1,1,1*sub_alpha)
    lg.setFont(FONT_[2])
    lg.print(subtxt,screen_width/2-FONT_[2]:getWidth(subtxt)/2,screen_height-50)
  end
end
--
function st:keypressed(key)
end
--
function st:mousepressed(x,y,b,t)
end
--
function st:mousereleased(x,y,b,t)
end
--
function st:leave()
end
--

return st