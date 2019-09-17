local turn = {}

local FONT_ = {
  fonts.combatinfo_med_small,
}
--

turn.timer = Timer.new()

--local speed = 1.75
local speed = 1.5
local wait_safety_time = 0
local zoom = 1+1/3
local queue = {}
local turn_play
local time_out = 0

local active

local ally_zoomxy = {
  {{screen_width/2,screen_height}},
  {{screen_width/4,screen_height},{screen_width/1.5,screen_height}},
  {{0, screen_height},{screen_width/2,screen_height},{screen_width,screen_height}},
}
local enemy_zoomxy = {
  {{screen_width/2,screen_height/4}},
  {{screen_width/4,screen_height/4},{screen_width/1.5,screen_height/4}},
  {{0, 0},{screen_width/2,screen_height/4},{screen_width,0}},
}

function turn.getQueue() return queue end
--

function turn.begin()
  active = true

  combat.run_ai()

  for _,a in event.poll("ally_turn") do
    table.insert(queue,1,a)
  end

  for _,e in event.poll("enemy_turn") do
    table.insert(queue,1,e)
  end

  turn.timer:script(function(wait)
      wait(1/speed)
      time_out = 5
      event.grant("turn_start",queue,wait)
      for _,v in pairs(queue) do
        local sk = combat.skills[v.skill]
        local entinfo, entind = combat.info.getByEnt(v.ent)
        local a, b = combat.enemy_info.getByEnt(v.ent)
        if a then entinfo, entind = a, b end
        local targinfo, targind
        if entinfo then
          -- Zoom
          if not entinfo.enemy then
            combat.view_scale(zoom,ally_zoomxy[#combat.info.list][entind],6)
          else
            combat.view_scale(zoom,enemy_zoomxy[#combat.enemy_info.list][entind],6)
          end
          combat.tell(v.ent, v.skill)
          wait(1/speed)
          -- Handle targets
          combat.globals.hits_dealt = 0

          combat.view_scale(1,nil,8)
          -- |------SKILL------|
          for i,targ in pairs(v.targets) do
            if targ.hp <= 0 then
              local new_target = combat.getNewTarget(targ,v.targets)
              v.targets[i] = new_target or v.targets[i]
            end
          end
          combat.pollData(v.ent, "set_action", "skill", function(_,a,t)
              v.skill = a 
              sk = combat.skills[a]
            end)
          v.ent:skill(v.skill,v.targets)
          -- |------SKILL------|

          while (combat.globals.wait) do
            wait(love.timer.getDelta())
          end
          
          wait(1/speed)

          if combat.info.getByEnt(v.ent) then event.pop("ally_turn") end  
          event.grant("action")
        end
      end
      for i,v in pairs(combat.enemy_info.list,combat.info.list) do
        for i,v in pairs(combat.retrieveData(v.ent,"turn_end_msg") or {}) do if v.msg then combat.log(v.msg) end end
      end
      event.grant("turn_end",wait)
      wait(1/speed)
      return turn.finish()
    end)
end
--

function turn.finish()
  turn.reset()
  combat.changeMode("idle")
end
--

function turn.update(dt)
  if not active then return end
  time_out = time_out - dt
  return true
end
--

function turn.draw()
  if not active then return end
  return true
end
--

function turn.keypressed(key)
  if not active then return end
  return true
end
--

function turn.mousepressed(x,y,b,t)
  if not active then return end
  return true
end
--

function turn.mousereleased(x,y,b,t)
  if not active then return end
  return true
end
--

function turn.reset()
  active = false
  turn.timer:clear()
  queue = {}
  event.clear("ally_turn","enemy_turn")
end
--

setmetatable(turn, { __index = function(_, ...) return function() end end})
return turn