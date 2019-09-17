local st = {}
local c = combat

local swipe = lg.newImage("res/img/swipe.png")

local wiping
local wipe_timer = 0
local wipe_x
local swipe_col
local intro_alpha
local pause
local auto_button = {
  x = screen_width/3,
  y = 0,
  w = screen_width/3,
  h = 40,
  a = 0.9,
  font = fonts.combatinfo_small,
  arrow_offset = 0,
  get_msg = function() return "Auto-Battle is " .. (combat.auto and "ON" or "OFF") .. ".\n" .. "Click here to " .. (combat.auto and "cancel" or "resume") .. "." end
}
--
st._scale = {
  amount = 1,
  target = 1,
  speed = 12,
  xy = {0,screen_height},
  xy_target = {0,screen_height}
}
st.keyboard_focus = 0
st.enemy_info = require("combat.enemy_info")
st.info = require("combat.ally_info")
st.skillinfo = require("combat.skillinfo")
st.tell = require("combat.tell")
st.log = require("combat.log")
st.slash = require("combat.slash")

st.queue = require("combat.queue")

st.flux = Flux.group()
st.timer = Timer.new()

-- Modes
st.mode = 0
st.modelist = {"idle","skillselect","target","turn","flee"}
for i,v in pairs(st.modelist) do
  st[v:lower()] = require("combat."..v:lower())
end

function st.changeMode(n,...)
--  st.keyboard_focus = 0
  st.mode = type(n) == "string" and n:lower() or n
  local args = {...}
  local t = {}
  t[0] = function() end
  t["idle"] = function()
    combat.info.show()
    st.idle.init()
    st.idle.begin(unpack(args))
  end
  t["skillselect"] = function()
    combat.info.show()
    st.skillselect.open(unpack(args))
  end
  t["target"] = function()
    combat.info.show()
    st.target.open(unpack(args))
  end
  t["turn"] = function()
    combat.info.show()
    st.turn.begin(unpack(args))
  end
  t["flee"] = function()
    combat.info.hide()
    st.flee.begin(unpack(args)) 
  end
  return t[n]()
end
--

function st.view_scale(sc,xy,sp,set)
  if combat.auto and st.mode=="turn" then return end
  set = set or {}
  st._scale.amount = set.amount or st._scale.amount
  st._scale.xy = set.xy or st._scale.xy
  st._scale.xy_target = xy or set.xy_target or {screen_width/2,screen_height/5}
  st._scale.target = sc or set.target or 1
  st._scale.speed = sp or set.speed or 12
end
--

function st.startWipe(col)
  swipe_col = col
  wipe_x = -screen_width*0.75
  particles.combat_wipe:reset()
  wiping = true
  wipe_timer = 0
end
--

function st.drawWipe()
  if wiping then
    local a = 0.85
--    local a = 0
--    swipe_col = {a,a,a}
--    swipe_col = {Misc.HSV(unpack(Misc.background_color))}
    lg.push()
    lg.rotate(-1)
    lg.setColor(a,a,a)
--      lg.setColor(swipe_col)
    lg.draw(swipe, wipe_x-screen_width/2, 0, nil, 1.4, screen_height*2.1)
    lg.draw(particles.combat_wipe,0,screen_height)
    lg.rectangle("fill",wipe_x+screen_width*0.75,0,screen_width/1.5,screen_height*2)
    lg.pop()
  end
end
function st.updateWipe(dt)
  if wiping then
    particles.combat_wipe:emit(20)
    wipe_x = wipe_x + screen_width * 5 * dt
    particles.combat_wipe:setPosition(wipe_x,0)
    particles.combat_wipe:update(dt)
    wipe_timer = wipe_timer + 1 * dt
    if wipe_timer >= 1.5 then wiping = false end
    if wipe_x < screen_width/1.75 then return end
  end
end
--

function st.drawStatuses(w)
  if not w.ent then return end
  local res = 32
  local midpad = 4
  local sidepad = w.box.w%(res+midpad)/2
  local xo = 0
  local yo = 0
  local y = (w.box.y-res-midpad)-(res+midpad)*yo
  if w.enemy then y = (w.box.y+w.box.h+midpad)+(res+midpad)*yo end
  local mx,my = Misc.getMouseScaled()
  mx, my = mx/combat._scale.amount+(combat._scale.xy[1]-combat._scale.xy[1]/combat._scale.amount), my/combat._scale.amount+(combat._scale.xy[2]-combat._scale.xy[2]/combat._scale.amount)
  for i,v in pairs(w.ent.statuses) do
    local status = combat.status(v.name)
    if status.icon then
      if Misc.checkPoint(mx,my, w.box.x+sidepad+(res+midpad)*xo,y,res,res) then
        local name = status.name.."\n----\n"
        local desc = ((status.desc~="") and status.desc.."\n----\n" or "")
        local turns = "("..(v.time >= 0 and v.time.." Turn(s)" or "Permanent")..")"
        event.grant("show_tooltip", name..desc..turns, {id=name..desc..turns,ent=w.ent})
      end
      lg.setColor(0,0,0,w.box.a/1.5)
      lg.rectangle("fill",w.box.x+sidepad+(res+midpad)*xo,y,res,res)
      lg.setColor(1,1,1,w.box.a*(2/5))
      lg.rectangle("line",w.box.x+sidepad+(res+midpad)*xo+1,y+1,res-2,res-2)
      lg.setColor(1,1,1,w.box.a/1.5)
      lg.draw(status.icon,w.box.x+sidepad+(res+midpad)*xo,y)
      xo = xo + 1
      if sidepad+(res+midpad)*xo+res > w.box.w then xo, yo = 0, yo + 1 end
    end
  end
end
--

function st:init()  
end
--

function st:enter()
  st.clear()

  combat.info.hide(nil,true)
  combat.globals.time_elapsed = 0

  st.view_scale(1,{screen_width/2,screen_height/5},nil,{amount=10})
  st.startWipe()

  local intro_log = {}
  for i,v in pairs(combat.enemies) do table.insert(intro_log,v.intro) end
  combat.timer:after(0.15, function() combat.info.show() if next(intro_log) then st.log(intro_log) end end)
  intro_alpha = 1
end
--

function st:update(dt)

  weather.update(dt)

  if combat.auto and st.mode=="turn" then
    auto_button.arrow_offset = (auto_button.arrow_offset + 10 * dt) % math.pi
    dt = dt * 1.5
  end

  st._scale.amount = Misc.lerp(st._scale.speed*dt, st._scale.amount, st._scale.target)
  for i=1,2 do
    st._scale.xy[i] = Misc.lerp(st._scale.speed*dt, st._scale.xy[i], st._scale.xy_target[i])
  end

  intro_alpha = Misc.lerp(5.5*dt, intro_alpha, 0)

  st.updateWipe(dt)

  states.game.flux:update(dt)
  st.flux:update(dt)

  st.info.update(dt)
  st.enemy_info.update(dt)

  st.tell.update(dt)

  st.slash.update(dt)

  if prompt.box.visible then return end

  for i,effect in pairs(combat.effects) do effect:update(dt) end

  combat.globals.time_elapsed = combat.globals.time_elapsed + dt

  for i,v in pairs(st.modelist) do st[v:lower()].update(dt) end
  st.queue.update(dt)

  st.log.update(dt)
  if st.log.visible or Gamestate.current()~=st then return end

  st.timer:update(dt)

  st.turn.timer:update(dt)
end
--
function st:draw()
  local sx,sy = unpack(st._scale.xy)

  lg.push()
  bgimage.draw(screen_width/2,screen_height/2,nil,1+(st._scale.amount*0.4),nil,screen_width/2,screen_height/2)
  lg.pop()

  lg.push()
  love.graphics.translate(sx,sy)
  love.graphics.scale(st._scale.amount)
  love.graphics.translate(-sx,-sy)

  lg.setColor(1,1,1,0.5)
  lg.circle("line", 0, 0, 100)
  lg.circle("line", 0, 0, 50)
  lg.circle("line", screen_width, 0, 100)
  lg.circle("line", screen_width, 0, 50)

  weather.draw()

  for i,effect in pairs(combat.effects) do effect:background() end

  st.enemy_info.draw()

  for i,v in pairs(st.modelist) do st[v:lower()].draw() end

  st.info.draw()

  st.tell.draw()

  st.slash.draw()

  for i,effect in pairs(combat.effects) do effect:draw() end

  weather.drawOver()

  lg.pop()

  st.queue.draw()

  st.log.draw()

  if settings.autocombat==1 then
    local b = auto_button
    -- "Fast-forward" arrows
    if combat.auto and st.mode=="turn" then
      local w, h = 75, 100
      lg.setColor(0,0,0,b.a/2.5)
      lg.rectangle("fill",0,0,screen_width,screen_height)
      lg.setColor(1,1,1,b.a/1.5)
      lg.push() lg.translate(screen_width/2-75/2-15*math.pi/2+15*math.sin(auto_button.arrow_offset),screen_height/2-100/2)
      lg.stencil(function() lg.polygon("fill", 50,0, 50,h, 50+w,h/2) end, "replace", 1)
      lg.setStencilTest("equal", 0)
      lg.polygon("fill", 0,0, 0,h, w,h/2)
      lg.setStencilTest()
      lg.polygon("fill", 50,0, 50,h, 50+w,h/2)
      lg.pop()
    end
    -- Auto-Battle notice/button
    lg.setColor(1,1,1,b.a/3)
    lg.polygon("fill", b.x-5,b.y, b.x+b.w+5,b.y, b.x+b.w-15+5,b.y+b.h+5, b.x+15-5,b.y+b.h+5)
    lg.setColor(0,0,0,b.a)
    lg.polygon("fill", b.x,b.y, b.x+b.w,b.y, b.x+b.w-15,b.y+b.h, b.x+15,b.y+b.h)
    lg.setColor(1,1,1,b.a)
    lg.setFont(b.font)
    lg.printf(b.get_msg(), 0, b.y+b.h/2-b.font:getHeight(), screen_width, "center")
  end

  -- Draw white fade intro
  lg.setColor(1,1,1,intro_alpha)
  lg.rectangle("fill",0,0,screen_width,screen_height)

  st.drawWipe()
end
--
function st:keypressed(key)
  if st.log.visible then return st.log.keypressed(key) end
  if st[st.mode] and st[st.mode].keypressed(key) then return end
  if st.mode == 0 and keyset.confirm(key) then st.changeMode("idle") end
end
--
function st:keyreleased(key)
  if prompt.box.visible then return end
  if st.log.visible then return end
  if st[st.mode] and st[st.mode].keyreleased(key) then return end
end
--

function st:mousepressed(x,y,b,t)
  if prompt.box.visible then return prompt.mousepressed(x,y,b,t) end
  if st.log.visible then return st.log.mousepressed(x,y,b,t) end

  if settings.autocombat==1
  and (x > auto_button.x and x < auto_button.x+auto_button.w and y > auto_button.y and y < auto_button.y+auto_button.h) then
    if not combat.auto then st.view_scale(1) end
    combat.auto = not combat.auto
    return
  end

--[
  for _,list in pairs{combat.enemy_info.list,combat.info.list} do
    for _,w in pairs(list) do
      local res = 32
      local midpad = 4
      local sidepad = w.box.w%(res+midpad)/2
      local xo = 0
      local yo = 0
      local yy = (w.box.y-res-midpad)-(res+midpad)*yo
      if w.enemy then yy = (w.box.y+w.box.h+midpad)+(res+midpad)*yo end
      local mx, my = x/st._scale.amount+(st._scale.xy[1]-st._scale.xy[1]/st._scale.amount), y/st._scale.amount+(st._scale.xy[2]-st._scale.xy[2]/st._scale.amount)
      if w.box.ta > 0 and w.box.visible then
        for i,v in pairs(w.ent.statuses) do
          if combat.status(v.name).icon then
            if Misc.checkPoint(mx,my, w.box.x+sidepad+(res+midpad)*xo,yy,res,res) then
              return -- clicked status icon
            end
            xo = xo + 1
            if sidepad+(res+midpad)*xo+res > w.box.w then xo, yo = 0, yo + 1 end
          end
        end
      end
    end
  end
--]]
  if st[st.mode] and st[st.mode].mousepressed(x,y,b,t) then return end
  if st.mode == 0 and b==1 then st.changeMode("idle") end
end 
--
function st:mousereleased(x,y,b,t)
  if st.log.visible then return end
  if st[st.mode] and st[st.mode].mousereleased(x,y,b,t) then return end
end
--
function st:mousemoved(x,y,dx,dy)
  if st.log.visible then return end
  if st[st.mode] and st[st.mode].mousemoved(x,y,dx,dy) then return end
end
--
function st:touchmoved(id,x,y,dx,dy)
  if st.log.visible then return end
  if st[st.mode] and st[st.mode].touchmoved(id,x,y,dx,dy) then return end
end
--
function st:wheelmoved(x,y)
  if st.log.visible then return end
  if st[st.mode] and st[st.mode].wheelmoved(x,y) then return end
end
--
function st:leave()
  for i,v in pairs(st.modelist) do st[v:lower()].reset() end
end
--
function st:clear()
  for i,v in pairs{textbubble,notify,st.log,st.info,st.enemy_info,st.tell,st.slash} do v.clear() end
  for i,v in pairs(st.modelist) do st[v:lower()].reset() end
  st.idle.initialized = false
  st.mode = 0
  st.timer:clear()
end
--

function st:make_wishes()
  event.wish("combat_start", function()
      for _,v in pairs(combat.enemies) do
        combat.enemy_info(v)
        v.cooldowns = {}
        v.damage_taken = {}
        v.ap = v.ap_regen
      end
      combat.enemy_info.reorder()
      combat.info(player)
      for _,v in pairs(combat.allies) do
        combat.info(v)
        for _,status in pairs(v.status or {}) do
          local name, duration = status:lower():match("^([^%*]+)%s*%**([%d%-]*)")
          name = name:gsub("^%s*(.-)%s*$","%1")
          v:addStatus(name, duration and {duration=tonumber(duration)} or nil)
        end
        v.cooldowns = {}
        v.damage_taken = {}
        v.ap = v.ap_regen
        if v.hp <= 0 then v.hp = math.ceil(v:getStat("max_hp")/10) end
      end
      combat.info.reorder()
      player.cooldowns = {}
      player.damage_taken = {}
      player.ap = player.ap_regen
      event.clear("guarantee_goodend")
      event.clear("no_goodend")
    end)
  event.wish("combat_end", function()
      for i,v in pairs(combat.allies) do
        v.cooldowns = {}
        v.damage_taken = {}
        v.statuses = {}
        v.ap = v.ap_regen
        v:removeSkillBoosts()
        if v.hp <= 0 then v.hp = math.ceil(v:getStat("max_hp")/10) end
        if v.summon then combat.allies[i] = nil end
      end
      player.cooldowns = {}
      player.damage_taken = {}
      player.ap = player.ap_regen
      player:removeSkillBoosts()
    end)
  event.wish("entity_hit", function(amount,params,ent)
      if Gamestate.current()~=states.combat then
        if ent == player then smallHP.show(1,amount) Misc.shake() end
        return
      end
      local info = combat.info.getByEnt(ent) or combat.enemy_info.getByEnt(ent)
      if not info then return end
      info.red()
      info.shake()
      combat.slash(info,params)
      if ent.enemy then return end
      Misc.shake()
    end)
  event.wish({"entity_heal"}, function(amount,ent)
      if Gamestate.current()~=states.combat then
        if ent == player then smallHP.show(2,amount) end
        return
      end
      local info = combat.info.getByEnt(ent) or combat.enemy_info.getByEnt(ent)
      if not info then return end
      info.green()
      if ent.enemy then return end
    end)
  event.wish({"entity_status"}, function(status,ent)
      if Gamestate.current()~=states.combat then return end
      local info = combat.info.getByEnt(ent) or combat.enemy_info.getByEnt(ent)
      if not info then return end
      info.blue()
      if ent.enemy then return end
    end)
  event.wish({"entity_endstatus"}, function(status,ent)
      if Gamestate.current()~=states.combat then return end
      local info = combat.info.getByEnt(ent) or combat.enemy_info.getByEnt(ent)
    end)
  event.wish({"entity_defeat"}, function(ent)
      if ent == player then
        GameOver(Gamestate.current()~=states.combat)
        player.hp = math.floor(player:getStat("max_hp")/10)
        return
      end
      local enemy_info,enemy_index = combat.enemy_info.getByEnt(ent)
      local info,info_index = combat.info.getByEnt(ent)
      if enemy_info then
        combat.clearData(ent)
        combat.globals.exp = combat.globals.exp + ent.exp
        combat.getRewards(ent)
        enemy_info.die()
      elseif info then
        ent.hp = math.floor(ent:getStat("max_hp")/10)
        info.die()
      end
    end)
  event.wish("combat_win", function()
      if not combat.globals.was_ambushed and (out.pg<(#out.src-1) or not out.done) then out.next() end
    end)
  event.wish("turn_end", function()
      for i,v in pairs(combat.enemies) do
        v:update()
      end
      for i,v in pairs(combat.info.list) do
        v.ent:update()
      end
    end)
  event.wish("new_enemy", function(ent)
      ent.isEnemy = true
    end)
  event.wish("new_ally", function(ent)
      ent.isEnemy = nil
    end)
end
--

return st