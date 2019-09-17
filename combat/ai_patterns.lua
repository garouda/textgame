local orig_ent
local orig_allies = {}
local allies = orig_allies
local orig_foes = {}
local foes = orig_foes
local orig_target_list = {}
local target_list = orig_target_list
local init = {}

local ai_hints = {
  allies = {
    hp = 1,
    ap = 0,
    statuses = 1,
    summons = 1,
  },
  foes = {
    hp = 10,
    ap = 0,
    statuses = 1,
    summons = 1,
  }
}

local function init_sandbox(e)
  if combat.enemy_info.getByEnt(e) then
    orig_allies, orig_foes = combat.enemies, __.map(combat.info.list, function(i,v) return v.ent end)
  else
    orig_allies, orig_foes = __.map(combat.info.list, function(i,v) return v.ent end), combat.enemies
  end

  init = {
    allies = {},
    foes = {}
  }
  for i,list in pairs{allies=orig_allies,foes=orig_foes} do
    for ii,v in pairs(list) do
      init[i][ii] = {
        hp=v.hp,
        ap=v.ap,
        statuses = Misc.tcopy(v.statuses),
      }
    end
  end
end
local function reset_sandbox()
  for i,v in pairs(init.allies) do for ii,v in pairs(v) do allies[i][ii] = Misc.tcopy(v) end end
  for i,v in pairs(init.foes) do for ii,v in pairs(v) do foes[i][ii] = Misc.tcopy(v) end end
end
--

local function get_score(skill)
  local a_score = {
    hp = 1,
    ap = 1,
    statuses = 1,
    summons = 1,
  }
  local f_score = Misc.tcopy(a_score)

  for i,v in pairs(allies) do
    a_score.hp = a_score.hp - ((init.allies[i].hp - v.hp) / math.max(1, init.allies[i].hp)) * ai_hints.allies.hp
    a_score.ap = a_score.ap - ((init.allies[i].ap - v.ap) / math.max(1, init.allies[i].ap)) * ai_hints.allies.ap
    for _,s in pairs(v.statuses) do
      local amt = combat.status(s.name).type == "pos" and 1 or -1
      if __.detect(init.allies[i].statuses, function(_,v) return v.name==s.name end) then amt = 0 end
      a_score.statuses = a_score.statuses + (amt * ai_hints.allies.statuses)
    end
    a_score.summons = a_score.summons + ((v.summons or 0) * ai_hints.allies.summons)
  end
  for i,v in pairs(foes) do
    f_score.hp = f_score.hp - ((init.foes[i].hp - v.hp) / math.max(1, init.foes[i].hp)) * ai_hints.foes.hp
    f_score.ap = f_score.ap - ((init.foes[i].ap - v.ap) / math.max(1, init.foes[i].ap)) * ai_hints.foes.ap
    for _,s in pairs(v.statuses) do
      local amt = combat.status(s.name).type == "pos" and 1 or -1
      if __.detect(init.foes[i].statuses, function(_,v) return v.name==s.name end) then amt = 0 end
      f_score.statuses = f_score.statuses + (amt * ai_hints.foes.statuses)
    end
    f_score.summons = f_score.summons + ((v.summons or 0) * ai_hints.foes.summons)
  end

-- Lower scores are less valuable, higher scores more valuable
  local s1, s2 = 1, 1
  for i,v in pairs(a_score) do
    s1 = s1 * (a_score[i])
    s2 = s2 * (f_score[i])
  end
  local score = s1+(s1-s2)
  local reverse_score = s2+(s2-s1)
  return score, reverse_score
end
--

local function eval_skill_on_target(ent,skill,target)
--  Disregard certain aspects so agent doesn't have bias around uncertain info (such as accuracy)
--  End-of-turn effects are already simulated by default with the Simulation param
  local param = {
    simulation=true,
    accurate=true,
    simulation_lists = {allies=allies,foes=foes},
--    no_element=true,
  }

  ent:skill(skill,{target},param)

  local score, reverse_score = get_score(skill)

  if combat.retrieveData(orig_ent,"reverse_ai") and ent~=target then
    score = reverse_score
  end
  local real_target
  for i,v in pairs(target_list) do if target==v then real_target = orig_target_list[i] end end
  if real_target and combat.retrieveData(real_target,"ai_ignore") then score = -math.huge end

  reset_sandbox()

  return score
end
--

local function simulate(ent,skills,targets)
  local function find_target(skill)
    local maxima_target = {
      target = nil,
      score = -math.huge
    }
    for i,target in pairs(targets) do
      local curr_score = eval_skill_on_target(ent,skill,target)
      -- the one commented out has 50% rng, might have weird results  
--    if curr_score and (not maxima_target.score or curr_score > maxima_target.score or (curr_score == maxima_target.score and Misc.roll(0.5)))
      --
      if curr_score and curr_score >= maxima_target.score
      and not target.ai_ignore then
        maxima_target = {
          target = target,
          score = curr_score
        }
        maxima_target.target = __.detect(allies, function(_,v) return v==target end) and orig_allies[i] or orig_foes[i-#allies]
      end
--      print(ent.name,skill,target.name,maxima_target.score)
    end
    return maxima_target
  end
  --
  local function find_skill()
    local maxima_skill = {
      action = nil,
      score = -math.huge,
    }
    for _,skill in pairs(skills) do
      if ent:useAP(combat.skills[skill].cost,true) and not ent.cooldowns[skill] then
        local ft = find_target(skill)
        local target, curr_score = ft.target, ft.score
        if curr_score and (not maxima_skill.score or (curr_score > maxima_skill.score) or (curr_score == maxima_skill.score and Misc.roll(0.5))) then
          maxima_skill = {
            action = {skill=skill,target=target},
            score = curr_score
          }
        end
      end
    end
    return maxima_skill
  end
  --
  local result 

  result = find_skill()
--  if ent.ap < ent:getStat("max_ap") and (result.score == 1 or result.score < 1) then
  if (result.score == 1 or result.score < 1) then
    result.action = 0
  end
  return result.action, result.score
end
--

local function determine(e)
  target_list = {}
  orig_target_list = {}
  orig_ent = e
  init_sandbox(e)
  allies, foes = Misc.tcopy(orig_allies), Misc.tcopy(orig_foes)

  local ent
  for i,v in pairs(orig_allies) do
    if v==e then
      ent = allies[i]
      break
    end
  end
  if not ent then return end
  if (combat.retrieveData(orig_ent,"attempt_action") or {}).disable then return end

  for _,v in pairs{allies,foes} do
    for _,v in pairs(v) do
      table.insert(target_list, v)
    end
  end
  for _,v in pairs{orig_allies,orig_foes} do
    for _,v in pairs(v) do
      table.insert(orig_target_list, v)
    end
  end

  local skills = Misc.tcopy(next(ent.active_skills) and ent.active_skills or ent:getSkills())
  if next(skills) then table.insert(skills,"strike") end

  event.deafen()
  local decision = simulate(ent,skills,target_list)
  event.listen()

  if decision==0 then return 0 end
  if not decision or not decision.skill or not decision.target then return end

  local function get_new_target(targ)
    local new
    if combat.info.getByEnt(e) then
      if combat.info.getByEnt(targ) then
        new = orig_allies[math.random(1,#orig_allies)]
      else
        new = orig_foes[math.random(1,#orig_foes)]
      end
    else
      if combat.info.getByEnt(targ) then
        new = orig_foes[math.random(1,#orig_foes)]
      else
        new = orig_allies[math.random(1,#orig_allies)]
      end
    end
    return new
  end

  for i,v in pairs(orig_target_list) do if v==decision.target then target_list[i].ai_ignore = true end end

  local targets = {decision.target}

  local max_targets = -math.huge
  local common = combat.info.getByEnt(e) and (combat.info.getByEnt(decision.target) and orig_allies or orig_foes) or (combat.info.getByEnt(decision.target) and orig_foes or orig_allies)
  for i,v in pairs(combat.skills(decision.skill).actions) do
    if type(v.opt.target)=="number" and v.opt.target > max_targets then max_targets = v.opt.target end
  end
  if max_targets > 1 and #common >= max_targets then
    local add_target
    while #targets < max_targets and (not add_target or __.detect(targets, function(_,v) return v==common end)) do
      add_target = common[math.random(1,#common)]
    end
    table.insert(targets,add_target)
  end

  e.cooldowns[decision.skill] = combat.skills(decision.skill).cooldown > 0 and combat.skills(decision.skill).cooldown or nil
  e:useAP(combat.skills(decision.skill).cost)

  return {ent=e, skill=decision.skill, targets=targets}
end
--


return determine