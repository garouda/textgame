local st = {}

out = require("output")
process = require("process")
choices = require("choices")
input = require("input")
icon_bar = require("icon_bar")
shop = require("shop")
local newPlayer = require("player")
local buttons = {}
st.flux = Flux.group()
st.keyboard_focus = 0

function st:init()
  states.combat:make_wishes()
end
--
function st:enter()
  player = newPlayer()
  st.flux = Flux.group()

  out._initialize()
  choices._initialize()
  package.loaded["nature"] = nil require("nature")
  species.refresh()
  bgimage.clear()

  combat.skills = combat.refresh_skills()
  states.explore.reset()
  icon_bar.reset()
  input.close()
  items.refresh()
  inventory.clear()
  notify.clear()
  out.initButtons()
  states.history.clear()
  out.speed = settings.text_speed
  Misc.action = Misc.action_backup
  st.keyboard_focus = 0
  states.explore.getWander()
  shop.setShopList({})
  smallHP.init()
  combat.enemies, combat.allies = {}, {}
  
  for i,v in pairs(combat.skills) do
    if not v.name:match("_") then player:addSkill(v.name,nil,true) end
  end

  collectgarbage()
end
--
function st:update(dt)
  if prompt.box.visible then return end
  out.update(dt)
  choices.update(dt)

  weather.update(dt)

  states.combat.updateWipe(dt)

  for i,v in pairs(out.buttons) do if v.label=="Next" or not out.buttons["Next"].selected then v:update(dt) end end

  input.update(dt)
  icon_bar.update(dt)
  shop.update(dt)
  st.flux:update(dt)
end
--
function st:draw()
  bgimage.draw()
  
  weather.draw()

  lg.setColor(1,1,1)
  out.draw()
  out.drawLocation()
  icon_bar.draw()
  choices.draw()

  shop.draw()

  for i,v in pairs(out.buttons) do v:draw() end
  input.draw()
  weather.drawOver()
  states.combat.drawWipe()
end
--
function st:keypressed(key)
  if keyset.editor(key) then return Misc.fade(function() Gamestate.push(states.editor) end, 0.3) end
  if input.keypressed(key) then return end
  if keyset.quicksave(key) then save.quick() end
  if shop.keypressed(key) then return end
  if keyset.back(key) then
    Gamestate.push(states.pause)
    st.keyboard_focus = 0
  end
  if choices.keypressed(key) then return end
  out.keypressed(key)
  icon_bar.keypressed(key)
end
--
function st:mousepressed(x,y,b,t)
  if prompt.box.visible then return end
  if shop.mousepressed(x,y,b,t) then return end
  for i,v in pairs(out.buttons) do if v.label=="Next" or not out.buttons["Next"].selected then v:mousepressed(x,y,b) end end
  if input.mousepressed(x,y,b,t) then return end
  if choices.mousepressed(x,y,b,t) then return end
  icon_bar.mousepressed(x,y,b,t)
  out.mousepressed(x,y,b,t)
  if b==2 then Gamestate.push(states.pause) end
end
--
function st:mousereleased(x,y,b,t)
  if prompt.box.visible then return end
  for i,v in pairs(out.buttons) do if v.label=="Next" or not out.buttons["Next"].selected then v:mousereleased(x,y,b) end end
  if input.mousereleased(x,y,b,t) then return end
  if choices.mousereleased(x,y,b,t) then return end
  if shop.mousereleased(x,y,b,t) then return end
  if icon_bar.mousereleased(x,y,b,t) then return end
  out.mousereleased(x,y,b,t)
end
--
function st:wheelmoved(x,y)
  if prompt.box.visible then return end
  if choices.wheelmoved(x,y) then return end
  out.wheelmoved(x,y)
end
--
function st:touchmoved(id,x,y,dx,dy)
  if prompt.box.visible then return end
  if choices.touchmoved(id,x,y,dx,dy) then return end
  out.touchmoved(id,x,y,dx,dy)
end
--
function st:textinput(text)
  if prompt.box.visible then return end
  input.textinput(text)
end
--
function st:leave()
  notify.clear()
end
--

return st