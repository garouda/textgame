local items = {}
local skillfunc = {}
local glow = lg.newImage("res/img/glow.png")
local commands = require("res.commands")
local list = {}

setmetatable(items, { __call = function(_, ...) if ... then return list[string.lower(...)] else return list end end})

function items.refresh()
  list = {}
  for n,d in pairs{"res/items"} do
    for i,v in pairs(love.filesystem.getDirectoryItems(d)) do
      local t = {}
      for l in love.filesystem.lines(d.."/"..v) do
        local key, value = l:match("(.+)%s*[:=]%s*(.+)")        
        if key and not l:match("^%s*//") then t[key:lower()] = Misc.autoCast(value) end
      end
      local cmds = t.func or ""

      t.name = t.name or v:gsub("%..+$","")
      t.desc = t.desc or "No description."
      t.icon = t.icon or "unknown"
      t.important = t.important or false
      t.rarity = tonumber(t.rarity) or 1
      t.value = t.value or math.floor(math.clamp(0, (t.value_mod or 1)*8*(t.rarity*3), 999999))
      t.max = tonumber(t.max) or 99
--      t.func = t.func and function() process.exec_cmd(cmds) end
      t.func = t.func and function() process(cmds) end
      if t.equip then
        local un_cmds = t.unequip_func
        t.unequip_func = function() process.exec_cmd(un_cmds) end
        t.stats = {}
        for i,v in pairs(player.stat) do
          t.stats[i] = t[i] or 0
          t[i] = nil
        end
        local skills = {}
        for s in (t.skill or t.skills or ""):gmatch(";*%s*([^;]+)%s*;*%s*") do table.insert(skills,s) end
        t.skills = skills
      end

      local id = t.name:lower()
      if list[id] and not list[v:gsub("%..+$",""):lower()] then id = v:gsub("%..+$",""):lower() end
      list[id] = t
    end
  end
end
--

items.icons = {}
for i,v in pairs(love.filesystem.getDirectoryItems("res/img/icons/item/")) do
  local filename, filetype = v:match("(.+)%.(.-)$")
  if __.any({"png","jpg"}, function(_,t) return filetype==t end) then items.icons[filename] = lg.newImage("res/img/icons/item/"..v) end
end
--

-- ?BVYGR Order (MaSt)
--items.raritycolors = {{0.6,0.6,0.6},{0.35,0.65,1},{0.835,0.5,0.92},{0.92,0.785,0.4},{0.72,0.92,0.15},{0.96,0.45,0.5}}
-- ?BVRYG Order (Shifted Rainbow)
items.raritycolors = {{0.6,0.6,0.6},{0.35,0.65,1},{0.835,0.5,0.92},{0.96,0.45,0.5},{0.92,0.785,0.4},{0.72,0.92,0.15}}

local sparkles = {}
for i=1,#items.raritycolors do
  sparkles[i] = particles.item_sparkle:clone()
  sparkles[i]:setSpeed(66+(i*4),99+(i*8))
  sparkles[i]:setEmissionRate(33+66*((i)/2))
end
local rotations = {}

items.updateIcons = function(dt)
  for i,v in pairs(items()) do
    sparkles[v.rarity]:update(dt)
    rotations[v] = (rotations[v] or 0) + (math.pi/3*math.max(0.3,v.rarity/5)) * dt
  end
end
items.drawIcon = function(item,x,y,w,h)
  local c = {lg.getColor()}
  local icon = items.icons[items(item).icon] or items.icons.unknown
  local alpha = c[4] or 1
  if not rotations[items(item)] then return end
  
  w, h = (w or icon:getWidth())/icon:getWidth(), (h or icon:getHeight())/icon:getHeight()

  items.raritycolors[items(item).rarity][4] = alpha*0.75
  lg.setColor(items.raritycolors[items(item).rarity])
  lg.draw(glow,x,y,rotations[items(item)],w,h,glow:getWidth()/2,glow:getHeight()/2)
  lg.draw(glow,x,y,-rotations[items(item)]*0.75,w,h,glow:getWidth()/2,glow:getHeight()/2)

  items.raritycolors[items(item).rarity][4] = alpha*(1-items(item).rarity*0.033)
  lg.setColor(items.raritycolors[items(item).rarity])
  lg.draw(sparkles[items(item).rarity],x,y,nil,w,h)

  lg.setColor(c[1],c[2],c[3],math.min(c[4], 0.8))
  lg.draw(icon,x,y,nil,w,h,icon:getWidth()/2,icon:getHeight()/2)
end
--
-- Equip slots - 1: Weapon; 2: Headgear; 3: Top; 4: Bottom; 5: Accessory


return items
--