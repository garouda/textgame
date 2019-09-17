local fc = {}

fc.globals = {}
fc.refresh_skills = require("combat.skills")
fc.skills = fc.refresh_skills
fc.refresh_status = require("combat.statuses")
fc.status = fc.refresh_status()
local effects = require("combat.effects")
fc.effects = {}
local new_ally = require("player")
fc.allies = {}
setmetatable(fc.allies, { __newindex = function(t,i,v) if i>=2 or #t==2 then return end return rawset(t,i,v) end})
fc.enemies = {}
fc.ai_pattern = require("combat.ai_patterns")
fc.ent_data = {}

local function resetGlobals()
  fc.globals = {
    exp = 0,
    items = {},
    was_ambushed = false,
    time_elapsed = 0,
    player_total_damage_taken = 0,
    enemy_total_damage_taken = 0,
    hits_dealt = 0,
    wait = false,
    mode = states.combat.mode,
  }
  fc.ent_data = {}
  fc.skills = fc.refresh_skills()
  fc.status = fc.refresh_status()
  fc.auto = settings.autocombat == 1
  Timer.every(0.33, function() fc.globals.mode = states.combat.mode end)
end
--

function fc.start(...)
  if Gamestate.current()==states.combat then
    for i,v in pairs{...} do
      if #combat.enemies < 3 then
        table.insert(combat.enemies, fc.getEnemy(v))
        combat.enemies[#combat.enemies].visual_hp = combat.enemies[#combat.enemies].hp
        combat.enemy_info(combat.enemies[#combat.enemies])
        combat.enemy_info.reorder()
      else
        return false
      end
    end
    return true
  end
  resetGlobals()
  combat.enemies = {}
  for i,v in pairs{...} do
    local en = fc.getEnemy(v)
    if en then
      table.insert(combat.enemies, en)
      combat.enemies[#combat.enemies].visual_hp = combat.enemies[#combat.enemies].hp
    end
  end
  if not next(combat.enemies) then return end
  Gamestate.push(states.combat)
  event.grant("combat_start")
  return true
end
--

function fc.run_ai()
  -- Enemies and Allies
  local passes = {"enem","all"}
  for p = 1, #passes do
    local t = passes[p]
    for i=1,#combat[t.."ies"] do
      local fallback = 20
      if p==1 or combat.auto or combat[t.."ies"][i].AI then
        while combat[t.."ies"][i].ap > 0 do
          fallback = fallback - 1
          local decision = fc.ai_pattern(combat[t.."ies"][i])
          if decision == 0 then break end
          event.push(t.."y_turn", decision)
          if fallback <= 0 then break end
        end
      end
    end
  end
  -- Player, if autocombat enabled
  local fallback = 20
  if combat.auto then
    while player.ap > 0 do
      fallback = fallback - 1
      local decision = fc.ai_pattern(player)
      if decision == 0 then break end
      event.push("ally_turn", decision)
      if fallback <= 0 then break end
    end
  end
end
--

function fc.getEnemy(enemy)
  for _,d in pairs{"res/enemies/"} do
    for i,v in pairs(love.filesystem.getDirectoryItems(d)) do
      if v:gsub("%..+$",""):lower() == enemy:lower() then
        local t = {}
        local mult = {}
        local item_weights = {}
        local stat_weights = {}
        for l in love.filesystem.lines(d.."/"..v) do
          local key, value = l:match("(.-)%s*[:=]%s*(.+)")
          if key then
            for w in value:gmatch(";*%s*([^;]+)%s*;*%s*") do
              if not mult[key] then mult[key] = {} end
              table.insert(mult[key], w)
            end

            if value:match("^[%.%d]+$") then value = tonumber(value)
            elseif value:match("^true$") then value = true
            elseif value:match("^false$") then value = false
            end
            if not l:match("^%s*//") then t[key:lower()] = value end
          end
        end

        if mult.items then
          t.items = {}
          for i=1,#mult.items do
            local name,weight = mult.items[i]:match("([^%%]+)%s*%%*([%d%.]*)")
            name = name:gsub("^%s*(.-)%s*$","%1")
            if weight=="" then weight = 1 end
            table.insert(t.items, {name,tonumber(weight)})
          end
        end
        mult.skills = mult.skills or {}
        for i,v in pairs(mult.skills) do mult.skills[i] = v:lower() end

        t.name = t.name or enemy
        t.internal_name = enemy
        t.lvl = t.lvl or 1
        t.exp = math.ceil(fc.exp_table[t.lvl]*(t.exp or 0.35))
        t.skills = mult.skills or {}
        t.items = t.items or {}
        for i,v in pairs(t.items) do
          if not items(v[1]) then v[1] = "nil" end
        end
        for _,item in pairs(t.items) do table.insert(item_weights,item[#item]) end
        for i,chance in pairs(Misc.gbd(item_weights)) do t.items[i][#t.items[i]] = chance end

        t.no_flee = t.no_flee or nil
        t.actions = t.actions or 1

        -- Enemy Stats
        t.stat = {}
        local points = (t.lvl+1) * 3
        local stats = {"str","int","agi","con","luk"}
        for i,v in pairs(stats) do
          local weight = (tostring(t[v]) or ""):match("%%([%d%.]*)")
          if weight=="" then t[v] = tonumber(v)
          else
            if not t[v] then weight = 1 end
            stat_weights[i] = tonumber(weight)
          end
        end
        for i,v in pairs(Misc.gbd(stat_weights)) do t[stats[i]] = math.max(1, math.round(points*v)) end
        t.stat.atk = t.str
        t.stat.mag = t.int

        t.hp_modifier = t.hp_modifier or 1+(t.lvl/10)

        table.sort(t.items, function(f,s) return f[2] < s[2] end)

        t = entity(t)

        for i,v in pairs(mult.status or {}) do
          local name, duration = v:lower():match("^([^%*]+)%s*%**([%d%-]*)")
          name = name:gsub("^%s*(.-)%s*$","%1")
          t:addStatus(name, duration and {duration=tonumber(duration)} or nil)
        end

        return t
      end
    end
  end
end
--

function fc.getAlly(ally, t)
  for _,d in pairs{"res/enemies/", "res/allies/"} do
    for i,v in pairs(love.filesystem.getDirectoryItems(d)) do
      if v:gsub("%..+$",""):lower() == ally:lower() then
        local t = t or {}
        local mult = {}
        local item_weights = {}
        local stat_weights = {}
        for l in love.filesystem.lines(d.."/"..v) do
          local key, value = l:match("(.-)%s*[:=]%s*(.+)")
          if key then
            for w in value:gmatch(";*%s*([^;]+)%s*;*%s*") do
              if not mult[key] then mult[key] = {} end
              table.insert(mult[key], w)
            end

            if value:match("^[%.%d]+$") then value = tonumber(value)
            elseif value:match("^true$") then value = true
            elseif value:match("^false$") then value = false
            end

            if not l:match("^%s*//") then t[key:lower()] = t[key:lower()] or value end
          end
        end
        
        mult.skills = mult.skills or {}
        for i,v in pairs(mult.skills) do mult.skills[i] = v:lower() end

        t.name = t.name or ally
        t.internal_name = t.internal_name or ally
        t.lvl = t.lvl or 1
        t.skills = mult.skills or {}

        -- Ally Stats
        t.stat = {}
        local points = (t.lvl+1) * 3
        local stats = {"str","int","agi","con","luk"}
        for i,v in pairs(stats) do
          local weight = (tostring(t[v]) or ""):match("%%([%d%.]*)")
          if weight=="" then
            t[v] = tonumber(v)
          else
            if not t[v] then weight = 1 end
            stat_weights[i] = tonumber(weight)
          end
        end
        for i,v in pairs(Misc.gbd(stat_weights)) do t[stats[i]] = math.max(1, math.round(points*v)) end

        t = new_ally(t)

        local skill_table = Misc.tcopy(t.skills)
        for i=1,4 do
          local roll = table.remove(skill_table,math.random(1,#skill_table))
          if roll and #t.active_skills<4 and not __.detect(t.active_skills, function(i,v) return v==roll end) then table.insert(t.active_skills, roll) end
        end
        
        t.status = mult.status

        return t
      end
    end
  end
end
--

function fc.newAlly(ally,param)
  if #combat.allies >= 2 then return end
  ally = fc.getAlly(ally)
  if not ally then return end
  if Gamestate.current()==states.combat then
    combat.info(ally)
    combat.info.reorder()
  end

  for i,v in pairs(param or {}) do
    ally[i] = v
  end

  notify{"yellow", ally.name, "white", " has joined your side!"}
  table.insert(combat.allies, ally)
  return ally 
end
--

function fc.removeAlly(index)
  local ally = combat.allies[index]
  if not ally then return end
  if Gamestate.current()==states.combat then
    event.grant("entity_defeat", ally)
    combat.info.reorder()
  end

  notify{"white", "Your ally ", "yellow", ally.name, "white", " has left."}

  table.remove(combat.allies,index)
end
--

function fc.removeEnemyByEnt(ent)
  if not ent then return end
  if #combat.enemies==1 then return combat.finish() end
  local index
  for i,v in pairs(combat.enemies) do if v == ent then table.remove(combat.enemies, i) break end end
end
--

function fc.getRewards(ent)
  local f = {}
  local r = combat.globals.items
  local amount = math.max(1, math.round(ent.lvl/10/2))
  if Misc.roll(player:getStat("luk")*0.2/100) then amount = amount + 1 end
  for i=1,#ent.items do table.insert(f, i, ent.items[i][#ent.items[i]]) end
  for i=1,amount do
--    if #r >= 5 then return r end
    local item = Misc.roll(f)
    if item then 
      table.insert(r, ent.items[item][1])
    end
  end
  return r
end
--

function fc.finish()
  event.grant("combat_end")
  event.grant("combat_win")
  Gamestate.pop()
  Gamestate.push(states.combat_victory)
end
--
function fc.fled_battle()
  event.grant("combat_end")
  Gamestate.pop()
end
--

function fc.calculateExp(e)
  return e.exp
end
--

function fc.getNewTarget(old_target,target_list)
  local t
  local alike = __.map(old_target.isEnemy and combat.enemy_info.list or combat.info.list, function(i,v) return v.ent end)
  local attempts = 0
  while not t or __.detect(target_list, function(i,v) return v==t end) do
    if attempts > #alike*2 then break end
    t = alike[math.random(1,#alike)]
    attempts = attempts + 1
  end
  return t
end
--

function fc.getTargets(user,action_target,lists)
  lists = lists or {
    allies = __.map(user.isEnemy and combat.enemy_info.list or combat.info.list, function(i,v) return v.ent end),
    foes = __.map(user.isEnemy and combat.info.list or combat.enemy_info.list, function(i,v) return v.ent end)
  }
  local allies = lists.allies
  local enemies = lists.foes
  local targets = {}

  local function get_random_targets(list,amount,except_user)
    amount = amount or math.huge
    local rand
    for i=1,math.min(#list, amount) do
      local escape = 0
      rand = math.random(1,#list)
      while __.any(targets, function(_,v) return v == list[rand] end) or (except_user and __.any(targets, function(_,v) return v == user end)) do
        if escape > 20 then break end
        rand = math.random(1,#list)
        escape = escape + 1
      end
      if not __.any(targets, function(_,v) return v == list[rand] end)
      and (not except_user or (except_user and list[rand] ~= user)) then
        table.insert(targets, list[rand])
      end
    end
  end
  --

  local lookup = {
    -- Self
    ["self"] = function() table.insert(targets,user) end,
    -- All combatants
    ["all"] = function() get_random_targets(allies) get_random_targets(enemies) end,
    -- All combatants except self
    ["all_except"] = function() get_random_targets(allies,nil,true) get_random_targets(enemies) end,
    -- All allies
    ["allies"] = function() get_random_targets(allies) end,
    -- All allies except self
    ["allies_except"] = function() get_random_targets(allies,nil,true) end,
    -- All enemies
    ["enemies"] = function()  get_random_targets(enemies) end,
    -- Random combatant
    ["random"] = function() if Misc.roll(0.5) then get_random_targets(enemies,1) else get_random_targets(allies,1) end end,
    -- Random combatant except self
    ["random_except"] = function() if Misc.roll(0.5) then get_random_targets(enemies,1) else get_random_targets(allies,1,true) end end,
    -- Random ally
    ["random_ally"] = function() get_random_targets(allies,1) end,
    -- All allies except self
    ["random_ally_except"] = function() get_random_targets(allies,1,true) end,
    -- Random enemy
    ["random_enemy"] = function() get_random_targets(enemies,1) end,
  }
  setmetatable(lookup, { __index = function(_, ...) return function() end end})

  lookup[action_target]()

  return targets
end
--

event.wish("turn_start",function(queue)
    for _,entry in pairs(queue) do
--      entry.targets = combat.getTargets(entry.ent,entry.skill,entry.targets)
    end
  end)

function fc.attachData(ent,id,data)
  fc.ent_data[ent] = fc.ent_data[ent] or {}
  fc.ent_data[ent][id] = fc.ent_data[ent][id] or {}
  table.insert(fc.ent_data[ent][id], data)
end
function fc.detachData(ent,id,st)
  if not fc.ent_data[ent] or not fc.ent_data[ent][id] then return end
  for i,v in pairs(fc.ent_data[ent][id] or {}) do
    if v.name==st or not st then fc.ent_data[ent][id][i] = nil end
  end
  fc.ent_data[ent][id] = next(fc.ent_data[ent][id]) and fc.ent_data[ent][id] or nil
  fc.ent_data[ent] = next(fc.ent_data[ent]) and fc.ent_data[ent] or nil
end
function fc.pollData(ent,id,index,func)
  if not fc.ent_data[ent] then return end

  for i,t in pairs((fc.ent_data[ent][id] or {})) do
    if index then
      if t[index] then func(index,t[index],t) end
    else
      for i,v in pairs(v) do func(i,v,t) end
    end
  end
end
function fc.retrieveData(ent,id)
  if not fc.ent_data[ent] then return end
  return fc.ent_data[ent][id]
end
function fc.clearData(ent)
  fc.ent_data[ent] = nil
end
--

function fc.getEffect(id)
  return effects[id]
end
--

function fc.addEffect(effect,...)
  effect = Misc.tcopy(effects[effect])
  table.insert(fc.effects, effect)
  event.push("remove_effect",function(e)
      for i,v in pairs(fc.effects) do
        if v==(e or effect) then table.remove(fc.effects, i) break end
      end
    end)
  return effect.func and effect:func(...)
end
--

fc.exp_table = {}
for i=1,100 do
  fc.exp_table[i] = (math.floor(((i/1.75)*(i+8))^1.1024))
end
--
setmetatable(fc, {__index = states.combat, __call = function(_, ...) return fc.start(...) end})
return fc