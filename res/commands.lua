local commands = {
  all = {},
  sorted = {
    output = {},
    prompt = {},
    flags = {},
    world = {},
    player = {},
    logic = {},
    visual = {},
    system = {}
  },
}

local c = commands.sorted.output
-- Manipulate page/output
c.change = function(p) event.push("change",p) end
c.block = function(p) out.block = true end -- Prevents page flips from going any further. Can only be reset by out.change and @unblock.
c.unblock = function(p) out.block = false end
c.skip = function(p) event.push("skip",true) end
c.capitalize = function(p) return Misc.capitalize(p[1]) end
c.upper = function(p) return p[1]:upper() end
c.lower = function(p) return p[1]:lower() end
c.finish = function(p) event.push("finish_output",true) end

local c = commands.sorted.prompt
-- Prompt the player
c.choice = function(p) event.push("choice", table.concat(p,"|")) end
c.input = function(p) event.push("input", {p[1], p[2], p[3]}) return "" end
c.shop = function(p) event.push("shop",p) end
c.combat = function(p) if Gamestate.current()==states.combat then return combat.start(unpack(p)) end event.push("combat",p) end

local c = commands.sorted.flags
-- Flags
c.setflag = function(p) if p[2] == "nil" then flags[p[1]]=nil else flags[p[1]] = (p[2] or 0) end end
c.getflag = function(p) return flags[p[1]] end
c.incflag = function(p) flags[p[1]] = flags[p[1]] + (p[2] or 1) end
c.clearflag = function(p) c.setflag{p[1],"nil"} end
c.gettempflag = function(p) return flags["~~"..p[1]] end
c.settempflag = function(p) p[1] = "~~"..p[1] if p[2] == "nil" then flags[p[1]]=nil else flags[p[1]] = (p[2] or 0) end end
c.inctempflag = function(p) p[1] = "~~"..p[1] flags[p[1]] = flags[p[1]] + (p[2] or 1) end
c.cleartempflag = function(p) c.setflag{"~~"..p[1],"nil"} end

local c = commands.sorted.world
-- World information
c.location = function(p) out.location = p[1] or "" end
c.speaker = function(p) event.push("speaker", p[1]) end
c.checkpoint = function(p) out.checkpoint = out.to end
c.addexplore = function(p) states.explore.addArea(unpack(p)) end
c.removeexplore = function(p) states.explore.removeArea(unpack(p)) end
c.getspeciesattribute = function(p) return (species[p[1]] or {})[(p[2] or ""):lower()] end

local c = commands.sorted.player
-- Player information
c.setplayername = function(p) player.name = Misc.capitalize(p[1] or "Unknown") end
c.setplayerspecies = function(p) player:setSpecies(p[1]) end
c.setplayercolor = function(p) player.skin_col = p[1] end
c.addally = function(p) if combat.newAlly(p[1]) then return p[2] else return p[3] end end
c.addallyspecial = function(p) combat.newAlly(p[1],Misc.parseData(p[2])) end
c.removeally = function(p) for i,v in pairs(combat.allies) do if v.name:lower()==p[1]:lower() then combat.removeAlly(i) end end end
c.hasally = function(p) if __.detect(combat.allies,function(i,v) return v.name:lower()==p[1]:lower() end) then return p[2] end return p[3] end
c.addskill = function(p) player:addSkill(p[1]) end
c.removeskill = function(p) player:removeSkill(p[1]) end
c.hasskill = function(p) if __.detect(player:getSkills(),function(i,v) return v:lower()==p[1]:lower() end) then return p[2] end return p[3] end
c.additem = function(p) inventory.add(unpack(p)) end
c.removeitem = function(p) inventory.destroy(unpack(p)) end
c.getitemindex = function(p) return inventory.contains(p[1]) end
c.hasitem = function(p) if inventory.contains(p[1]) then return p[2] else return p[3] end end
c.addmoney = function(p) player.money = player.money + tonumber(p[1] or 0) end
c.addpoints = function(p) player:addPoints(tonumber(p[1])) end
c.playerstat = function(p) return player:getStat(p[1]:lower()) end
c.takedamage = function(p) player:takeDamage(tonumber(p[1])) end
c.recoverhp = function(p) player:recoverHP(tonumber(p[1])) end

local c = commands.sorted.logic
-- Logic commands
c.compare = function(p)
  local a,op,b = p[1]:match("(.-)%s*([=><]+)%s*(.+)")
  op = Misc.getOpFunc(op)
  a = (type(a)=="string" and Misc.autoCast(process.exec_cmd(a:lower())) or a)
  b = (type(b)=="string" and Misc.autoCast(process.exec_cmd(b:lower())) or b)
  if type(b)=="string" then
    for d in b:gmatch("(%d+)[/,;]*") do
      if op(a,d) then return p[2] or true end
    end
  end
  return op(a,b) and (p[2] or true) or (p[3] or false) or nil
end
--
c.isequal = function(p)
  return c.compare{tostring(p[1]).."=="..tostring(p[2]),p[3],p[4]}
end
c.isless = function(p)
  return c.compare{p[1].."<"..p[2],p[3],p[4]}
end
c.isgreater = function(p)
  return c.compare{p[1]..">"..p[2],p[3],p[4]}
end
c.indexwith = function(p)
  local ind = type(p[1])=="string" and Misc.autoCast(process.exec_cmd(p[1])) or p[1]
  for i,v in pairs(__.rest(p or {})) do
    if c.isequal({ind,i}) then return v end
  end
  if p then return p[#p] end
end
c.random = function(p) for i,v in pairs(p) do p[i] = type(p[i])=="string" and Misc.autoCast(process.exec_cmd(p[i])) or p[i] end return math.random(unpack(p)) end
c.isplural = function(p) if p[1]:sub(-1):lower() == "s" then return p[2] else return p[3] end end

local c = commands.sorted.visual
-- Effects and visuals
c.color = function(p) if Gamestate.current()~=states.game then p[4] = 0 end Misc.setBG(unpack(p)) end
c.background = function(p) bgimage(p[1]) end
c.weather = function(p) weather.set(unpack(p)) end
c.indoors = function(p) weather.restrict() end
c.outdoors = function(p) weather.release() end
c.flash = function(p) Misc.flash(unpack(p)) end
c.shake = function(p) Misc.shake(unpack(p)) end

local c = commands.sorted.system
-- System stuff
c.seticon = function(p) event.push("override_icon",p) icon_bar.set(unpack(p))end
c.notify = function(p) notify(p[1],true) end
c.message = function(p) Timer.after(love.timer.getDelta(), function() Misc.message(p) end) end
c["nil"] = function(p) end -- Sometimes you just need something that does nothing :O am i right fellas
c.func = function(p) return assert(loadstring(p[1]))() end

---------------------------------------------------------------

for i,v in pairs(commands.sorted) do
  for id,cmd in pairs(v) do
    commands.all[id] = cmd
  end
end
--
commands.all._get_sorted_list = function() return commands.sorted end

return commands.all