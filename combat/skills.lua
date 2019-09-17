local list = {}

local proto = {
  effect = "",
  strength = 1,
  cost = 0,
  hits = 1,
  delay = 0.05,
  cooldown = 1,
  duration = 0,
  target = 1,
  accuracy = 0.95,
}
--

local function getActions(action)
  local a = {}
  local function check_condition(ent,target,skill)
    return (not skill.condition) or Misc.parse_formula(skill.condition,ent,target)
--    return true
  end
  --
  a.attack = function(ent,target,param,skill,iteration,sk)
    if not check_condition(ent,target,skill) then return end
    local strength = param.strength or skill.strength
    strength = strength[iteration] or strength[#strength]
    skill.result = ent:attack(strength, param, target)
  end
  a.heal = function(ent,target,param,skill,iteration,sk)
    if not check_condition(ent,target,skill) then return end
    local strength = param.strength or skill.strength
    strength = strength[iteration] or strength[#strength]
    skill.result = target:recoverHP(ent:attack(strength,{max=true,get_only=true,flat=param.flat}, target),param)
  end
  a.status = function(ent,target,param,skill,iteration,sk)
    if not check_condition(ent,target,skill) then return end
    if Misc.roll(skill.chance or 1) then target:addStatus(skill.type,param,skill,ent) end
  end
  a.summon = function(ent,target,param,skill,iteration,sk)
    if not check_condition(ent,target,skill) then return end
    if param.simulation then
      ent.summons = (ent.summons or 0) + 1
      return
    end
    if ent.isEnemy then
      if not combat(skill.name) then return end
      combat.enemies[#combat.enemies].summon = true
    else
      if not combat.newAlly(skill.name,{summon=true}) then return notify(ent.name.."'s summon failed! Party is already full.") end
    end
  end
  a.dismiss = function(ent,target,param,skill,iteration,sk)
    if not check_condition(ent,target,skill) then return end
    if param.simulation then
--      target.dismissed = true
      target.hp = 0
      return
    end
    local info = combat.info.getByEnt(target) or combat.enemy_info.getByEnt(target)
    info.dismiss()
  end
  a["nil"] = function(ent,target,param,skill,iteration,sk)
  end
  return a[action]
end
--

local function action_base(a,sk)
  local action_type = getActions(a.action)
  return function(ent,targets,param,action_index,upper_wait)
    if a.opt.target == 0 then targets = {ent} end
    if not targets then return end
    param = Misc.tcopy(param) or {}
    for i,v in pairs(a.attrib) do
      if param[i]==nil then param[i] = v end
    end
    for i,v in pairs(param.strength or {}) do
      if a.opt.strength[i] then param.strength[i] = v*a.opt.strength[i] end
    end
    if a.parent and a.parent.opt.result then
      param.flat = true
      param.strength = {}
      for i,v in pairs(a.opt.strength) do
        param.strength[i] = v*a.parent.opt.result
      end
    end
    local delay = param.simulation and {0} or a.opt.delay
    if ent == player then combat.addEffect(a.opt.effect) end
    if not param.accurate and a.name=="attack" then
      if Misc.roll(1-a.opt.accuracy) then param.strength = {0} end
    end
    local lim = math.max(a.opt.hits, #a.opt.strength, #((type(a.opt.stat)=="table" and a.opt.stat) or {}), 1)
    combat.timer:script(function(wait)
        if (a.name=="status" or a.name=="dismiss" or a.name=="summon") and a.parent and a.parent.name=="attack" and a.parent.opt.result == 0 then
--          if not param.simulation then combat.globals.wait = false end
          return
        end
--        if not param.simulation then combat.globals.wait = true end
        for i = 1, lim do
          a.opt.strength[i] = a.opt.strength[i] or a.opt.strength[#a.opt.strength]

          for _,target in pairs(targets) do
            if (ent.isEnemy and combat.retrieveData(target,"ai_ignore")) then
              if not param.simulation and action_index==1 and i==1 and (ent.isEnemy and combat.retrieveData(target,"ai_ignore")) then
                combat.log("#self readies to attack #target, but halts in confusion.",ent,target)
              end
            else
              if not param.simulation and action_index==1 and i==1 then combat.log(sk.log[math.random(#sk.log)] or nil, ent, target) end
              action_type(ent,target,param,a.opt,i,sk)
            end
          end

          local delay = delay[i] or delay[#delay]
          if delay > 0 and not param.simulation then
            wait(delay)
          end
          combat.globals.hits_dealt = combat.globals.hits_dealt + 1
        end
      end)
    if not param.simulation and upper_wait then
      for i=1, lim do
        upper_wait(delay[i] or delay[#delay])
      end
    end
  end
end
--

local function parseAttrib(attrib)
  local p = {}
  for l in attrib:gmatch("[^,]+") do
    p[l:gsub("[%[%]]",""):gsub("^%s*(.-)%s*$","%1"):lower()] = true
  end
  return p
end
--

local function refresh()
  list = {}
  local t = {}
  for n,d in pairs{"res/skills"} do
    for i,skillfile in pairs(love.filesystem.getDirectoryItems(d) or {}) do
      for l in love.filesystem.lines(d.."/"..skillfile) do
        local name, desc = l:match("^([_%w][^%~]+)(.*)")
        if name then
          name = name:gsub("^%s*(.-)%s*$","%1")
          desc = desc:gsub("^%s*(.-)%s*$","%1")
          if next(t) then list[t.name:lower()] = t end
          t = {name=name, desc=(desc or ""):sub(3), log={}, actions={}}
        elseif l:sub(1,1)=="\"" then
          for w in l:gmatch([["(.-)"]]) do
            t.log[#t.log+1] = w
          end
        elseif l:sub(1,1)=="(" then
          for i,v in pairs(Misc.parseData(l:sub(2,-2))) do
            t[i] = v
          end
        elseif l~="" and not l:match("^%s*//") then
          local sign, action, opt, attrib = l:match("([|%-])>%s*(%w[^%[^%]]+)(.-)]%s*(.*)")
          attrib = parseAttrib(attrib)
          action = action:gsub("^%s*(.-)%s*$","%1")
          opt = Misc.parseData(opt)

          -- Default values
          for i,v in pairs(proto) do opt[i] = opt[i] or Misc.tcopy(v) end

          if action:lower()=="status" or action:lower()=="dismiss" then opt.hits = 0 end

          -- Convert some values to table
          if type(opt.strength)~="table" then opt.strength = {opt.strength} end
          if type(opt.delay)~="table" then opt.delay = {opt.delay} end
          -- Top-level only these two values
          for _,v in pairs{"cost","cooldown"} do
            local p = opt[v]
            if type(t[v])=="table" then t[v] = __.reduce(p, 0, function(memo,_,v) return memo+v end) end
            if type(p)=="table" then p = __.reduce(p, 0, function(memo,_,v) return memo+v end) end
            t[v] = (t[v] and opt[v]) and t[v] or opt[v] or nil
          end

          local a = {name=action:lower(), parent=(sign=="-" and next(t.actions)) and t.actions[#t.actions] or nil, action=action:lower(), opt=opt, attrib=attrib}
          a.action = action_base(a,t)          
          table.insert(t.actions, a)
        end
      end
      if next(t) then list[t.name:lower()] = t end
    end
  end
  setmetatable(list, {
      __index = function(t,i) if not i then return {} end return rawget(t,i:lower()) end,
      __call = function(t,i) return t[i] end
    })
  return list
end
--

return refresh