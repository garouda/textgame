local skillinfo = {}

local element_icon = {
  fire = lg.newImage("res/img/icons/status/flamed-leaf.png"),
  ice = lg.newImage("res/img/icons/status/snowflake-1.png"),
  lightning = lg.newImage("res/img/icons/status/power-lightning.png"),
}
skillinfo.element_icon = element_icon
local info_icons = {
  strength = lg.newImage("res/img/damage_icon.png"),
  cost = lg.newImage("res/img/apcost_icon.png"),
  cooldown = lg.newImage("res/img/cooldown_icon.png"),
  type = lg.newImage("res/img/star_icon.png"),
}

local FONT_ = {
  fonts.planning_info_big,
  fonts.planning_info_small,
  fonts.planning_info_med,
}
--

local active
local skill
local zoom = 1.15
local ent
local ent_index
local box = {
  x = 0,
  y = 0,
  tx = 0,
  ty = 0,
  w = ((screen_width)/4.5)*2+20+15,
--  w = (screen_width/zoom)/2,
  h = screen_height/4,
  r = 15,
  alpha = 0,
  talpha = 0,
}
box.x = (screen_width/zoom)-box.w-30
box.y = screen_height/2-box.h/2+15
box.ox, box.oy = box.x, box.y
--
local information = {}
local info_x = 0
local info_w = 0
local info_pad = 10
local elements = {}

skillinfo.box = box

local function draw_box()
  lg.setColor(0.05,0,0,0.9*box.alpha)
  lg.rectangle("fill", box.x, box.y, box.w, box.h,box.r)
  lg.setColor(1,1,1,box.alpha/2)
  lg.rectangle("line", box.x+1, box.y+1, box.w-2, box.h-2,box.r)
  lg.setColor(0,0,0,box.alpha/1.5)
  lg.rectangle("line", box.x, box.y, box.w, box.h,box.r)
end
--

function skillinfo.reset()
  box.x = box.ox
  box.y = box.oy
  box.tx = box.x
  box.ty = box.y
  box.talpha = 0
  box.alpha = 0
  active = false
end
--

function skillinfo.open(e,sk)
  if active then return end
  skill = combat.skills(sk)
  ent = (type(e)=="table" and e) or (e and combat.info.list[e].ent) or ent
  ent_index = e or ent_index
  box.talpha = 1
  active = true
  box.x = box.ox
  box.tx = box.ox
  box.ty = box.oy
  information = {}
  info_w = 0
  elements = {}

  local flattened_skill = {}
  for a,v in pairs(skill.actions) do
    for i,v in pairs(v.attrib) do elements[i] = v end
    for i,vv in pairs(v.opt) do
      local t = vv
      if type(t)=="table" then
        if ((v.name == "attack" and v.opt.target~=0) or v.name == "heal") then
          flattened_skill[i] = flattened_skill[i] or {}
          flattened_skill[i][a] = vv
        end
      else
        if i=="type" then
--          local chance = v.opt.chance and " ( "..tostring(v.opt.chance*100).."%)" or ""
          flattened_skill[i] = (flattened_skill[i] and flattened_skill[i].." + " or "") .. Misc.capitalize(t)-- .. chance
        elseif i=="hits" then
          if ((v.name == "attack" and v.opt.target~=0) or v.name == "heal") then
            flattened_skill[i] = flattened_skill[i] or {}
            flattened_skill[i][a] = t
          end
        else
          flattened_skill[i] = (flattened_skill[i] or t)
        end
      end
    end
  end
  if flattened_skill.strength then
    local strength_perc = 0
    local strength_flat = 0
    for i,v in pairs(flattened_skill.hits or {}) do
      local attrib = (skill.actions[i]).attrib or {}
      for h = 1, v do
        local str = flattened_skill.strength[i][math.min(h,#flattened_skill.strength[i])]
        if type(str)=="string" then strength_perc = nil break end
        if attrib.flat then 
          strength_flat = strength_flat + str
        else
          strength_perc = strength_perc + str
        end
      end
    end
    strength_perc = strength_perc and math.round(ent:attack(strength_perc,{get_only=true,nocrit=true,accurate=true,min=true})+strength_flat).."~"..math.round(ent:attack(strength_perc,{get_only=true,nocrit=true,accurate=true,max=true})+strength_flat) or "???"
    flattened_skill.strength = strength_perc
  else
    flattened_skill.strength = "--"
  end
  for _,i in pairs{"strength","cost","cooldown","type"} do
    local t = {icon=info_icons[i], val=flattened_skill[i]}
    if t.val then
      table.insert(information, t)
      info_w = info_w + t.icon:getWidth()+info_pad
      info_w = info_w + FONT_[3]:getWidth(t.val)+info_pad
    end
  end
  info_x = box.w/2 - info_w/2
end
--

function skillinfo.close()
  box.x = box.ox
  box.y = screen_height/2
  box.talpha = 0
  box.alpha = 0
  active = false
end
--

function skillinfo.update(dt)
  box.alpha = Misc.lerp(4*dt, box.alpha, box.talpha)
  box.x = Misc.lerp(10*dt, box.x, box.tx)
  box.y = Misc.lerp(10*dt, box.y, box.ty)
  return true
end
--

function skillinfo.draw(no_bg)
  if not active then return end
  if not no_bg then draw_box() end

  local info_alpha = box.alpha
  local on_cooldown = ent.cooldowns[skill.name:lower()]

  if on_cooldown then info_alpha = info_alpha*0.1 end

  lg.push()
  lg.translate(box.w-10,10)
  for i,_ in pairs(elements) do
    if element_icon[i] then
      local scale = 0.9
      local w, h = element_icon[i]:getWidth()*scale, element_icon[i]:getHeight()*scale
      lg.translate(-(w+2))
      lg.setColor(1,1,1,info_alpha/2)
      lg.rectangle("line", box.x, box.y, w, h)
      lg.setColor(1,1,1,info_alpha*0.66)
      lg.draw(element_icon[i],box.x,box.y,0,scale)
    end
  end
  lg.pop()

  lg.push()
  lg.setFont(FONT_[1])
  lg.setColor(1,1,1,info_alpha)
  lg.translate(0,10)
  lg.printf(skill.name, box.x+15, box.y, box.w-30, "center")
  lg.translate(0,FONT_[1]:getHeight()+2)
  lg.setColor(1,1,1,info_alpha/1.5)
  Misc.fadeline(box.x+box.w/2, box.y, nil, FONT_[1]:getWidth(skill.name)+box.w/4, 1, true)
  lg.translate(0,2)

  lg.stencil(function() lg.rectangle("fill", box.x, box.y, box.w, FONT_[2]:getHeight()*2) end,"replace",1)
  lg.setStencilTest("equal",1)
  lg.setFont(FONT_[2])
  lg.setColor(1,1,1,0.8*info_alpha)
  lg.printf(skill.desc~="" and skill.desc or "No description.", box.x+30, box.y, box.w-60, "center")
  lg.translate(0,FONT_[2]:getHeight()*2)

  lg.stencil(function() lg.rectangle("fill", box.x+2, box.y, box.w-4, box.h) end,"replace",1)
  lg.setFont(FONT_[3])
  lg.translate(info_x)
  lg.setColor(1,1,1,0.8*info_alpha)
  for _,v in pairs(information) do
    lg.draw(v.icon, box.x, box.y)
    lg.translate(v.icon:getWidth()+info_pad)
    lg.print(v.val, box.x, box.y+1)
    lg.translate(FONT_[3]:getWidth(v.val)+info_pad)
  end
  lg.pop()
  lg.setStencilTest()

  if on_cooldown then
    lg.setFont(FONT_[1])
    lg.setColor(1,0,0,1*box.alpha)
    lg.printf(skill.name.."\ncan't be used for "..on_cooldown.." more turn"..(on_cooldown>1 and "s" or "")..".", box.x, box.y-8+box.h/2-FONT_[1]:getHeight(), box.w, "center")
  end

  return true
end
--

setmetatable(skillinfo, { __index = function(_, ...) return function() end end})
return skillinfo