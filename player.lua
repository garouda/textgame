local function create(p)
  local p = entity(p)
  p.exp = p.exp or 0
  if p.lvl >= 100 then p.exp = 0 end
  p.points = p.points or 0
  p.money = p.money or 0

  local update = p.update
  function p:update(dt)
    update(self,dt)
  end
--
  function p:expToLevelUp(lvl)
    lvl = lvl or self.lvl
    if lvl >= 100 then return math.huge end
    return combat.exp_table[lvl]
  end
--
  function p:addExp(exp)
    if self.lvl >= 100 then return end
    self.exp = self.exp + math.ceil(exp)
    while self.lvl < 100 and self.exp >= self:expToLevelUp() do
      self:levelUp()
    end
  end
--
  function p:addPoints(amt)
    self.points = self.points + math.abs(amt or 1)
    notify{"white", self.name.." gained ", "orange", amt, "white", " ability points!"}
  end
--
  function p:levelUp()
    if self.lvl >= 100 then self.exp = 0 return end
    self.exp = self.exp - self:expToLevelUp()
    self.lvl = self.lvl + 1
    self:setStat("def",self.stat["con"])
--    self:setStat("max_ap",math.floor(10+self.lvl/10))
    self:setStat("atk",self.lvl)
    self:setStat("mag",self.lvl)
    self.points = self.points + 3
    notify{"white", self.name.."'s level increased to ", "orange", self.lvl, "white", "!"}
    if self.lvl >= 100 then self.exp = 0 end
  end
--
  local _attack = p.attack
  function p:attack(mod,params, ent)
    local num = _attack(self, mod, params, ent)
    return num
  end
--
  local takeDamage = p.takeDamage
  function p:takeDamage(amount,params,attacker)
    amount = takeDamage(self, amount, params, attacker)
    return amount
  end
--
  function p:addSkill(name,from_equipment,silent)
    local list = from_equipment and self.equipment_skills or self.skills
    if not combat.skills[name] then return end
    for _,skill_list in pairs{self.skills, from_equipment and self.equipment_skills or nil} do
      for i,v in pairs(skill_list) do
        if v:lower() == name:lower() then return end
      end
    end
    if not silent then notify{"white", self.name.." acquired a new skill: ", "yellow", Misc.capitalize(name)} end
    table.insert(list, name)
    table.sort(list)
    if #p.active_skills < 4 and not __.detect(p.active_skills,function(_,v) return v==name end) then table.insert(p.active_skills, name) end
  end
--
  function p:removeSkill(name,from_equipment,silent)
    local list = from_equipment and self.equipment_skills or self.skills
    if not combat.skills[name] then return end
    local rem
    for i,v in pairs(list) do if name==v then table.remove(list,i) rem = true break end end
    if not rem then return end
    if not silent then notify{"white", self.name.." lost a skill: ", "red", Misc.capitalize(name)} end
    table.sort(list)
    for i,v in pairs(p.active_skills) do if name==v then table.remove(p.active_skills,i) break end end
  end
--
  function p:setSpecies(s)
    for i,skill in pairs((species[p.species] or {}).skills or {}) do 
      p:removeSkill(skill)
    end
    for i,skill in pairs((species[s] or {}).skills or {}) do 
      p:addSkill(skill)
    end
    p.species = s 
  end
--

  event.grant("playable_created",p)
  
  return p
end
--

event.wish("playable_created", function(p)
    -- Refresh boosts and skills from items that might have changed between updates
    p.boosts = {}
    p.equipment_skills = {}
    if next(states.inventory.list) then
      for kind,slot in pairs(p.equipped) do
        for i,v in pairs(items(states.inventory.list[slot].item).stats) do
          p:addBoost(i,v)
        end
        for i,v in pairs(items(states.inventory.list[slot].item).skills) do
          p:addSkill(v,true,true)
        end
      end
    end
    -- Refresh boosts and skills from passives that might have changed between updates
    --[[
  // to do
  --]]
  end)

return create