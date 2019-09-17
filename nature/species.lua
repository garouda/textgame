local species = {
  list = {}
}
function species.refresh()
  local function new(obj)
    obj.mouth = obj.mouth or ""
    obj.feet = obj.feet or ""
    obj.feet_plural = obj.feet_plural or ""
    obj.skin = obj.skin or ""
    obj.skin_adj_ed = obj.skin_adj_ed or ""
    obj.skin_adj_y = obj.skin_adj_y or ""
    obj.species_attrib = obj.attrib or ""
    obj.species_attrib_ed = obj.attrib_ed or ""
    obj.sound_quiet = obj.sound_quiet or ""
    obj.sound_quiet_plural = obj.sound_quiet_plural or obj.sound_quiet.."s"
    obj.sound_loud = obj.sound_loud or ""
    obj.sound_loud_plural = obj.sound_loud_plural or obj.sound_loud.."s"
    if obj.hastail==nil then obj.hastail = false end

    obj.species_colors = Misc.tcopy(type(obj.colors)=="string" and {obj.colors} or obj.colors) or {"black","white","red","green","yellow","blue","brown","orange","purple"}
    obj.colors = nil

    obj.species_skills = obj.species_skills or {}
    return obj
  end

  species.list = {}
  for n,d in pairs{"res/species"} do
    for i,v in pairs(love.filesystem.getDirectoryItems(d)) do
      local t = {}
      for l in love.filesystem.lines(d.."/"..v) do
        local key, value = l:match("(.+)%s*[:=]%s*(.+)")
        if key then
          local mult = {}
          if value:find(";") then
            for w in value:gmatch(";*%s*([^;]+)%s*;*%s*") do table.insert(mult, w) end
          end
          if not l:match("^%s*//") then
            t[key:lower()] = next(mult) and mult or Misc.autoCast(value)
          end
        end
      end

      t = new(t)
      t.name = v:sub(1,-5):lower()

      species.list[t.name] = t
    end
  end
  setmetatable(species, { __index = function(t,i) return rawget(species.list, tostring(i):lower()) or rawget(species.list,"unknown") end})
end
--

return species