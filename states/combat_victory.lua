local st = {}

local txt = ""
local scale = {txt=1, bg=1}
local slowmo = {factor=1}
local radius = 0
local ran = {1.7,1.2,1.1,1.6,1.2,1.5}
local text_fly_in
local wiping
local after_wipe
local old_bg
local zoom_target

local FONT_ = {
  fonts.mainmenu_logo_big,
}

st.flux = Flux.group()

function st.prep_leave()
  Gamestate.pop()
  Misc.shake(0, 0)
  Misc.setBG(unpack(old_bg))
--  states.combat.startWipe({1,1,1})
  Gamestate.push(states.rewards)
end
--

function st:enter() 
  txt = ""
  scale = {txt=1, bg=1}
  slowmo.factor=1
  radius = 0
  wiping = nil
  after_wipe = nil
  slowmo.factor=1
  if text_fly_in then text_fly_in:stop() end
  text_fly_in = st.flux:to(slowmo,1,{factor=50}):ease("quadin"):after(1.5,{factor=1}):ease("quadout"):oncomplete(function() st.prep_leave() end):delay(1)
  scale.txt = 5 txt = "Victory!"

  zoom_target = {x=screen_width/2, y=screen_height/3}

  combat.timer:clear()

  Misc.shake(2, 4)

  old_bg = Misc.tcopy(Misc.background_color) old_bg[4] = 0
  Misc.setBG(0,1,1,0)
  Misc.setBG(0,0,0,8)
end
--

function st:update(dt)
  st.flux:update(dt)
  particles.victory:update(dt)
  dt = dt/slowmo.factor
  states.combat:update(dt)
  scale.txt = Misc.lerp(11*dt, scale.txt, 0.9)
  scale.bg = Misc.lerp(4*dt, scale.bg, 1.35)
  radius = math.min(screen_width/1.5, radius + screen_height/2 * 5 * dt)
end
--

function st:draw()
  lg.setColor(1,1,1,0.4)
  lg.draw(particles.victory,screen_width/2,screen_height/2)
  lg.push()
  love.graphics.translate(zoom_target.x, zoom_target.y)
  love.graphics.scale(scale.bg)
  love.graphics.translate(-zoom_target.x, -zoom_target.y)
  states.combat:draw()
  lg.pop()

  lg.setColor(0,0,0,0.35)
  lg.rectangle("fill",0,0,screen_width,screen_height)

  lg.setFont(FONT_[1])
  lg.setColor(1,1,1)
  lg.print(txt, screen_width/2,screen_height/2, math.pi*1.9, scale.txt, scale.txt, FONT_[1]:getWidth(txt)/2,FONT_[1]:getHeight()/2)

  lg.setColor(1,1,1)
end
--

function st:keypressed(key)
  if keyset.confirm(key) then self.prep_leave() end
end
--

function st:keyreleased(key)
end
--

function st:mousepressed(x,y,b,t)
  if prompt.box.visible then return end
  self.prep_leave()
end
--
function st:mousemoved(mx,my,dx,dy)
end
--

function st:mousereleased(x,y,b,t)
  if prompt.box.visible then return end
end
--

function st:leave()
end
--

return st