local flee = {}

local FONT_ = {
  fonts.combatinfo_med_small,
}
--

local back = newButton("Cancel", function() flee.cancel() end, 30, screen_height-50-30, screen_width/7, 50)
local active
local mashing
local success
local fail
local flash = 0
local progress = 0
local bottom = 0
local base = 0.05
local box = {
  x=screen_width/2-(screen_width/3)/2,
  y=screen_height-(screen_height/4)-(screen_height/16)/2,
  w=screen_width/3,
  h=screen_height/16,
}
local alpha = 0
local finish_alpha = 0
local difficulty = 0

local infotip = [[Mash "Confirm" to flee from battle!]]
if love.system.getOS() == "Android" then infotip = [[Tap frantically to flee from battle!]] end

local function inc_progress() progress = progress + 1/8 Misc.shake(2,0.15) mashing = true end

local canvas
local function draw_lines()
  local x = box.x-15
  canvas = nil
  collectgarbage()
  canvas = lg.newCanvas(screen_width,box.y+box.h)
  lg.setCanvas({canvas,stencil=true})
  lg.clear()
  lg.push()
  local sx, sy = Misc.toGame()
  lg.scale(1/sx, 1/sy)
  lg.setLineWidth(20)
  for i=1,10 do
    lg.line(x+40*(i-1), box.y+box.h+15, x+20+40*(i-1), box.y-15)
  end
  lg.setLineWidth(1)
  lg.pop()
  lg.setCanvas()
end
--
draw_lines()
event.wish({"window_reset"}, draw_lines)

function flee.begin(ent)
  love.keyboard.setKeyRepeat(false)
  difficulty = math.clamp(1/6, 1-(ent.lvl/(__.reduce(combat.enemies, 0, function(memo,_,v) return memo + v.lvl end)/2)), 2/3)
  progress = base
  active = true
  combat.view_scale(1, nil, 6)
  combat.log.close()
  if __.detect(combat.enemies, function(_,v) return v.no_flee end) then return flee.fail() end
end
--

function flee.success()
  particles.radial:emit(250)
  finish_alpha = 1
  combat.idle.finish()
  flee.reset()
  success = true
  Misc.fade(function() combat.fled_battle() end, 1.5)
end
--

function flee.fail()
  combat.log("Couldn't escape!")
  finish_alpha = 1
  states.combat.mode = "idle"
  combat.idle.next()
  flee.reset()
  fail = true
end
--

function flee.reset()
  progress = base
  flash = 0
  bottom = 0
  active = false
  success = false
  fail = false
  mashing = false
  alpha = 0
  love.keyboard.setKeyRepeat(true)
end
--

function flee.cancel()
  states.combat.mode = "idle"
  combat.idle.next(0)
  flee.reset()
end
--

function flee.update(dt)
  if success then
    particles.radial:update(dt)
  end

  finish_alpha = math.max(0, finish_alpha - 1 * dt)

  if not active then return end

  alpha = math.min(1, alpha + 4 * dt)

  if progress >= 1 then flee.success()
  elseif progress <= bottom then flee.fail() end
  if mashing then
    progress = math.clamp(0, progress - 1/3 * dt, 1)
    bottom = math.clamp(0, bottom + difficulty * dt, 1)
    flash = flash + 1/5 * dt
  end
  
  back:update(dt)

  return true
end
--

function flee.draw()
  lg.setFont(FONT_[1])
  if success then
    lg.setColor(1,1,1,0.75)
    lg.draw(particles.radial, box.x+box.w, box.y+box.h/2)
    lg.setColor(1,1,1,finish_alpha)
    lg.rectangle("fill", box.x, box.y, box.w, box.h)
  end
  if fail then
    lg.setColor(1,0,0,finish_alpha/2)
    lg.printf("FAILED",box.x,box.y-(30-(finish_alpha*30)),box.w,"center")
  end

  if not active then return end

  lg.setColor(0,0,0,0.8*alpha)
  lg.rectangle("fill", box.x, box.y, box.w, box.h)

  lg.stencil(function() lg.rectangle("fill", box.x, box.y, box.w, box.h) end, "replace", 1)
  lg.setStencilTest("equal",1)
  lg.setColor(1,1,1,0.05*alpha)
  lg.draw(canvas)
  lg.setStencilTest()

  lg.setColor(1,1,1,0.8*alpha)
  lg.rectangle("fill", box.x, box.y, box.w*progress, box.h)

  local gb = 0.75-(flash%0.05)*20
  lg.setColor(0.85,0.1+gb,gb,0.8*alpha)
  lg.rectangle("fill", box.x, box.y, box.w*bottom, box.h)
  lg.setColor(1,1,1,0.4*alpha)
  lg.rectangle("line", box.x, box.y, box.w, box.h)

  lg.setColor(0,0,0,1*alpha)
  Misc.fadeline(0, box.y-FONT_[1]:getHeight()-15, nil, nil, FONT_[1]:getHeight())
  lg.setColor(1,1,1,1*alpha)
  lg.printf(infotip, 0, box.y-FONT_[1]:getHeight()-15, screen_width, "center")
  
  back:draw()

  return true
end
--

function flee.keypressed(key)
  if not active then return end
  if keyset.confirm(key) then inc_progress() end
  if keyset.back(key) then flee.cancel() end
  return true
end
--

function flee.mousepressed(x,y,b,t)
  if not active then return end
  if back:mousepressed(x,y,b) then return true end
  inc_progress()
  return true
end
--

function flee.mousereleased(x,y,b,t)
  if not active then return end
  if back:mousereleased(x,y,b) then return true end
  return true
end
--

setmetatable(flee, { __index = function(_, ...) return function() end end})
return flee