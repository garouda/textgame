local list = {}

local proto = {
  strength = {1},
  cost = 0,
  hits = 1,
  delay = 0,
  cooldown = 0,
  duration = 0,
  target = 1,
  chance = 1,
  type = 1,
}
--
local icons = {}

local function parseAttrib(attrib)
  local p = {}
  for l in attrib:gmatch("[^,]+") do
    p[l:gsub("[%[%]]",""):gsub("^%s*(.-)%s*$","%1")] = true
  end
  return p
end
--

local function refresh()
  list = {}
  local t = {}
  for n,d in pairs{"res/status"} do
    for i,statusfile in pairs(love.filesystem.getDirectoryItems(d) or {}) do
      for l in love.filesystem.lines(d.."/"..statusfile) do
        local name, desc = l:match("^(%w[^%~]+)(.*)")
        if name then
          name = name:gsub("^%s*(.-)%s*$","%1")
          if next(t) then list[t.name:lower()] = t end
          t = {name=name, desc=(desc or ""):sub(2,-1)}
        elseif l:sub(1,1)=="(" then
          for i,v in pairs(Misc.parseData(l:sub(2,-2))) do
            t[i] = v
          end
          icons[t.icon] = icons[t.icon] or lg.newImage("res/img/icons/status/"..t.icon..".png")
          t.icon = icons[t.icon]
        elseif (l~="" or not l:match("^%s*$")) and not l:match("^%s*//") then
          local s = {}
          local trig, value, attrib = l:match("(%b\"\")%s*%->%s*%[(.-)%]%s*(.*)")
          if not trig then break end
          s.id = trig:sub(2,-2)
          s.data = Misc.parseData(value)
          s.attrib = parseAttrib(attrib)
          -- Default values
          for i,v in pairs(proto) do
            s.data[i] = s.data[i] or Misc.tcopy(v)
          end
          -- Convert some values to table
          if type(s.data.strength)~="table" then s.data.strength = {s.data.strength} end
          if type(s.data.delay)~="table" then s.data.delay = {s.data.delay} end
          table.insert(t, s)
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