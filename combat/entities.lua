local entity = {}
entity.__index = entity

local ai_pattern = require("combat.ai_patterns")

local function lvl_to_atk(value)
  return math.round(Misc.smooth(value, 100, 0, 50))
end
--
local function lvl_to_mag(value)
  return math.round(Misc.smooth(value, 100, 0, 50))
end
--
local function con_to_hp(value)
  return math.round(Misc.smooth(value, 99, 100, math.pi*1500))
end
--
local function con_to_def(value)
  return math.round(Misc.smooth(value, 99, 1, 100))
end
--
local function agi_to_avoid(value)
  return math.round(Misc.smooth(value, 99, 5, 30))
end
--
local function agi_to_speed(value)
  return math.round(Misc.smooth(value, 99, 1, 100))
end
--
local function luk_to_crit_damage(value)
  return math.round(Misc.smooth(value, 99, 50, 200))
end
--
local function luk_to_crit_rate(value)
  return math.round(Misc.smooth(value, 99, 10, 50))
end
--

function entity.new(object,is_enemy)
  local obj = setmetatable(Misc.tcopy(object) or {}, entity)
  obj.name = obj.name or "???"
  obj.species = obj.species or "unknown"
  obj.lvl = obj.lvl or 1
  obj.stat = obj.stat or {}
  for i,v in pairs{"str","int","agi","con","luk"} do
    obj.stat[v] = math.max(1, obj.stat[v] or obj[v] or 1)
    obj[v] = nil
  end
--  obj.stat.atk = obj.stat.atk or 0
  obj.stat.atk = lvl_to_atk(obj.lvl)
--  obj.stat.mag = obj.stat.mag or 0
  obj.stat.mag = lvl_to_mag(obj.lvl)
  obj.stat.def = con_to_def(obj.stat.con+obj.lvl-1)
  obj.stat.max_hp = math.floor(con_to_hp(obj.stat.con) * (obj.hp_modifier or 1))
  obj.stat.crit_rate = luk_to_crit_rate(obj.stat.luk)
  obj.stat.crit_damage = luk_to_crit_damage(obj.stat.agi)
  obj.stat.avoid = agi_to_avoid(obj.stat.agi)
  obj.stat.speed = obj.stat.speed or agi_to_speed(obj.stat.agi)
  obj.stat.max_ap = 8
  obj.stat.resistance = obj.stat.resistance or {
    fire = 1,
    ice = 1,
    lightning = 1,
  }
  obj.ap_regen = obj.ap_regen or 4
  obj.boosts = {}
  obj.hp = obj.hp or obj.stat.max_hp
  obj.hp_modifier = obj.hp_modifier or 1
  obj.ap = obj.ap or obj.ap_regen
  obj.skills = obj.skills or {}
  obj.active_skills = obj.active_skills or {}
  obj.equipment_skills = obj.equipment_skills or {}
  obj.damage_taken = {}
  obj.statuses = obj.statuses or {}
  obj.cooldowns = obj.cooldowns or {}
  obj.attached_data = obj.attached_data or {}

  obj.equipped = obj.equipped or {}

  obj.skin_col = obj.skin_col or 1

  local species_skills = (species[obj.species] or {}).skills or {}
  for i,skill in pairs(species_skills) do if not __.detect(obj.skills, function(_,v) return v==skill end) then table.insert(obj.skills,skill) end end
  for i,v in pairs(Misc.tcopy(obj.skills)) do if not combat.skills(v) then table.remove(obj.skills,i) end end
  for i,v in pairs(Misc.tcopy(obj.active_skills)) do if not combat.skills(v) then table.remove(obj.active_skills,i) end end
  table.sort(obj.skills)
  return obj
end
--
function entity:addBoost(stat,amt,time)
  if amt == 0 or not amt then return end
  local topstat, substat = stat:match("([%w_]+)%/*([%w_]*)")
  stat = substat~="" and topstat.."_"..substat or stat
  self.boosts[stat] = self.boosts[stat] or {}
  table.insert(self.boosts[stat], {amt=amt,time=time or -1})
end
--
function entity:removeBoost(stat,amt)
  if amt == 0 or not amt then return end
  local topstat, substat = stat:match("([%w_]+)%/*([%w_]*)")
  stat = substat~="" and topstat.."_"..substat or stat
  if not self.boosts[stat] then return end
  for i,v in pairs(self.boosts[stat]) do
    if v.amt == amt then self.boosts[stat][i] = nil end
  end
  if not next(self.boosts[stat]) then self.boosts[stat] = nil end
end
--
function entity:removeSkillBoosts()
  for i,v in pairs(self.statuses) do if v.time >= 0 then self:removeStatus(v.name) end end
end
--
function entity:getStat(stat,substat)
  local final = self.stat[stat] or self[stat]
  local boosts = self.boosts[stat] or {}
  if not final then return end
  if stat=="max_hp" then final = con_to_hp(self:getStat("con"))*self.hp_modifier end
  if substat then 
    final = final[substat]
    boosts = self.boosts[stat.."_"..substat] or {}
  end
  for i,v in pairs(boosts) do final = final + v.amt end

  local stat_add = 0
  local stat_sub = 0
  local stat_mult = 1
  local stat_div = 1
  combat.pollData(self, "add_stat", stat, function(_,v) stat_add = stat_add + v end)
  combat.pollData(self, "subtract_stat", stat, function(_,v) stat_sub = stat_add + v end)
  combat.pollData(self, "multiply_stat", stat, function(_,v) stat_mult = stat_add + v end)
  combat.pollData(self, "divide_stat", stat, function(_,v) stat_div = stat_add + v end)

  final = ((final * stat_mult) / stat_div + stat_add - stat_sub)

  return math.max(0,final)
end
--
function entity:setStat(stat, value)
  if not value or not self.stat[stat] then return false end
  for i,v in pairs{"str","int","agi","con","luk"} do if stat==v then value = math.min(99,value) end end
  if stat=="atk" then
    value = lvl_to_atk(value)
  elseif stat=="mag" then
    value = lvl_to_mag(value)
  elseif stat=="con" then
--    local old_fraction = self.hp/self:getStat("max_hp")
    self:setStat("max_hp", con_to_hp(value))
    self:setStat("def", con_to_def(value))
--    self.hp = math.ceil(self:getStat("max_hp")*old_fraction)
    self.hp = math.ceil(self:getStat("max_hp"))
  elseif stat=="agi" then
    self:setStat("avoid", agi_to_avoid(value))
    self:setStat("speed", agi_to_speed(value))
  elseif stat=="luk" then
    self:setStat("crit_rate", luk_to_crit_rate(value))
    self:setStat("crit_damage", luk_to_crit_damage(value))
  elseif stat=="def" then
    value = value+self.lvl-1
  end
  self.stat[stat] = math.round(value,3)
  return true
end
--
function entity:incStat(stat, value)
  return self:setStat(stat,self.stat[stat]+(value or 1))
end
--
function entity:getSkills()
  local total = {}
  for i,v in pairs(self.skills) do table.insert(total,v) end
  for i,v in pairs(self.equipment_skills) do table.insert(total,v) end
  return total
end
--
function entity:update(dt,ai)
  for i,v in pairs(self.cooldowns) do
    self.cooldowns[i] = math.max(0, v - 1)
    if self.cooldowns[i] <= 0 then
      self.cooldowns[i] = nil
      if self==player then event.grant("cooldown_finished",i) end
    end
  end
  for i,v in pairs(self.boosts) do
    for ii,vv in pairs(v) do
      if vv.time == 0 then
        self:removeBoost(i,vv.amt)
      elseif vv.time > 0 then
        self.boosts[i][ii].time = math.max(0, vv.time - 1)
      end
    end
  end
  for i,v in pairs(self.statuses) do
    if v.time == 0 then
      self:removeStatus(v.name)
    elseif v.time > 0 then
      v.time = math.max(0, v.time - 1)
    end
  end
  self:useAP(-self.ap_regen)
end
--

function entity:useAP(amount,test)
  amount = amount or 0
  combat.pollData(self, "ap_use", "add", function(_,v) amount = amount + v end)
  combat.pollData(self, "ap_use", "amount", function(_,v) amount = v end)
  if test then return self.ap>=amount, math.max(0,amount) end 
  local pass = false
  if (self.ap-amount) < 0 then pass = true end
  local flash = true
  if combat.info.getByEnt(self) then combat.info.getByEnt(self).flashAP(not pass,math.abs(amount)) end
  if pass then return false end
  self.ap = math.clamp(0, math.floor(self.ap-amount), self:getStat("max_ap"))
  return true
end
--

function entity:attack(mod,param,ent)
  ent = ent or player
  param = param or {}
  mod = mod or 1
  local variance = 1

  if type(mod)=="string" then mod = Misc.parse_formula(mod,self,ent) end

  if not param.nocrit and (param.crit or Misc.roll(self:getStat("crit_rate")/100)) then
    param.crit, param.accurate = true, true
    mod = mod + (self:getStat("crit_damage")/100)
  end
  if param.min then
    variance = 0.9
  elseif param.max then
    variance = 1.1
  elseif param.average then
    variance = 1
  else
    variance = math.random(90,110)/100
  end

  local primary, secondary
  if param.magic then primary, secondary, variance = self:getStat("int"), self:getStat("mag"), 1
  else primary, secondary = self:getStat("str"), self:getStat("atk") end
  primary, secondary = primary + 3, secondary + 3

  local modify_finaldamage = 1
  combat.pollData(self, "modify_finaldamage", "amount", function(_,v) modify_finaldamage = modify_finaldamage * v end)

  local num = math.ceil(((param.flat and mod) or (primary*2+math.max(1,secondary*3)) * mod * variance / 2) * modify_finaldamage)

  if param.get_only then return num end
  if next(ent) then num = ent:takeDamage(num, param, self) end
  return num
end
--

function entity:skill(skill,targs,param)
  skill = skill:lower()
  local sk = combat.skills[skill]
  if not sk then return false end
  local targets = {}
  param = param or {}
  combat.timer:script(function(wait)
      if not param.simulation then combat.globals.wait = true end
      for i,v in pairs(sk.actions) do
        if type(v.opt.target)~="number" then
          targets = combat.getTargets(self,v.opt.target,param.simulation_lists)
        else
          targets = targs
        end
        if not param.simulation then
          v.action(self,targets,param,i,wait)
          if i<#sk.actions then wait(0.25) end
        else
          v.action(self,targets,param,i)
        end
      end
      if not param.simulation then combat.globals.wait = false end
    end)
  return true
end
--
function entity:addStatus(status,param,skill,from)
  if not status then return end
  for i,v in pairs(self.statuses) do if v.name == status then return end end
  param, skill, from = param or {}, skill or {}, from or self
  local st = Misc.tcopy(combat.status(status))
  if not st then return end
  for i,v in ipairs(st) do
    local param = param or {}
    event.grant("entity_status",st,self)
    v.data.strength = param.strength or v.data.strength
    for i,p in pairs(param) do
      v.data[i] = v.data[i] or p
    end
    for i,p in pairs(v.attrib) do
      v.data[i] = v.data[i] or p
    end
    for i,p in pairs(skill) do
      v.data[i] = v.data[i] or p
    end
    v.data.from = from
    v.data.name = status
    if param.simulation then
      if v.id:match("skill") then
        local param = {no_ap=true, accurate=true, no_cd=true}
        for i,v in pairs(v.data) do param[i] = param[i] or v end
        local from, target = (v.data.target==0 and self) or v.data.from, (v.data.target==0 and v.data.from) or self
        from:skill(v.data.skill, {target}, param)
      end
    else
      combat.attachData(self,v.id,v.data)
    end
  end
  table.insert(self.statuses, {name=status:lower(), time=skill.duration or param.duration or -1})
  return true
end
--
function entity:hasStatus(status)
  for i,v in pairs(self.statuses) do
    if v.name==status:lower() then return v.time end
  end
end
function entity:removeStatus(status)
  if not status then return end
  local ind
  for i,v in pairs(self.statuses) do
    if v.name==status:lower() then ind = i break end
  end
  if not ind then return end
  self.statuses[ind] = nil
  local st = combat.status(status)
  if not st then return end
  for i,v in pairs(combat.retrieveData(self,"on_expire") or {}) do
    if status:lower()==(v.status_name or ""):lower() and v.skill then self:skill(v.skill,{self}) end
  end
  for i,v in pairs(st) do
    event.grant("entity_endstatus",st,self)
    combat.detachData(self,v.id,status)
    self.hp = math.clamp(0,self.hp,self:getStat("max_hp"))
  end
  return true
end
--

local recently_hit_timer
function entity:takeDamage(amount,param,attacker)
  if self.hp <= 0 then return amount end
  if Misc.fade.lerping then return amount end
  param = param or {}

  if param.fatal then self.hp = 0 return self:getStat("max_hp"), self:die() end

  -- Roll evasion
  if not param.accurate or param.inaccurate then
    if Misc.roll(self:getStat("avoid")/100) or param.inaccurate then
      amount = 0
    end
  end

  -- Apply damage reduction
  if amount>1 and not param.pierce then
    local reduction = math.min(amount/2, self:getStat("def"))
    amount = math.max(1, amount - reduction)
    -- Elemental damage reduction
    if not param.no_element then
      for i,v in pairs(self.stat.resistance) do
        if param[i] then
          local mod = combat.retrieveData(self,"modify_"..i) and __.reduce(combat.retrieveData(self,"modify_"..i), 0, function(memo,_,v) return memo+v.amount end) or 1
          amount = math.max(1, amount * v * mod)
        end
      end
    end
  end
  if amount < 0 then return self:recoverHP(math.round(-amount)) end

  if not param.special and attacker then
    for _,d in pairs(combat.retrieveData(self,"take_damage") or {}) do
      if d.skill then
        local param = {no_ap=true, accurate=true, no_cd=true, special=true}
        for i,v in pairs(d) do param[i] = param[i] or v end
        local from, target = (d.target==0 and self) or d.from, (d.target==0 and attacker) or self
        from:skill(d.skill, {target}, param)
      end
      if d.fatal then
        amount = self:getStat("max_hp")
        self.hp = 0
      end
    end
  end

  combat.pollData(self, "take_damage", "amount", function(_,v,t)
      amount = (v<1 and v>0 and amount*v) or v
    end)

  -- Clamp the damage
  amount = math.ceil(math.clamp(0,amount,9999))
  -- Here's the hp reduction
  self.hp = math.clamp(0,self.hp - amount,self:getStat("max_hp"))
  -- Push it into damage_taken so we can keep track of the damage for use
  table.insert(self.damage_taken,1,{d=amount,a=1,x=math.random(-5,5),y=math.random(-5,5),g=1})
  if amount == 0 then return amount end

  event.grant("entity_hit",amount,param,self)
  combat.pollData(attacker, "deal_damage", "skill", function(_,v) attacker:skill(v,{self}) end)

  if self.hp <= 0 then self:die() end
  return amount
end
--
function entity:recoverHP(amount,param)
  param = param or {}
--  if self.hp >= self:getStat("max_hp") then return amount end
  if param.percent or (amount < 1 and amount > 0) then amount = self:getStat("max_hp")*amount
  elseif amount < 0 then amount = self:getStat("max_hp") end
  event.grant("entity_heal", math.round(amount), self)
  table.insert(self.damage_taken,1,{d=-amount,a=1,x=math.random(-5,5),y=math.random(-5,5),g=1})
  if param.simulation then
--    self.hp = self.hp + amount
    self.hp = math.floor(math.clamp(0, self.hp + amount, self:getStat("max_hp")))
  else
    self.hp = math.floor(math.clamp(0, self.hp + amount, self:getStat("max_hp")))
  end
  return amount
end
--

function entity:die()
  event.grant("entity_defeat", self)
end
--

setmetatable(entity, { __call = function(_, ...) return entity.new(...) end})

return entity