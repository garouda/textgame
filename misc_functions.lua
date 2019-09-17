local misc = {}

misc.background_color = {0,0,0}
misc.background_color_add = {0,0,0}
local bg_flux
function misc.setBG(h,s,v,spd)
  spd = spd or 5
  h, s, v = h or misc.background_color[1], s or misc.background_color[2], math.max(0.15,v or misc.background_color[3])
  if misc.fade.lerping then spd = 0 end
  if spd ~= 0 then
    if bg_flux then bg_flux:stop() end
    if misc.background_color[2] == 0 then misc.background_color[1] = h end
    bg_flux = Flux.to(misc.background_color, spd, {h,s,v}):ease("quintout")
  else
    misc.background_color = {h,s,v}
  end
  event.grant("bg_color_changed")
end
--

function misc.gbd(weights)
  -- Categorical/Generalized Bernoulli Distribution
  local total_weight = __.reduce(weights, 0, function(total,_,v) return total+v end)
  local max = __.max(weights)
  for i,v in pairs(weights) do
    weights[i] = v/total_weight
  end
  return weights
end
--

function misc.roll(t)
  if type(t)~="table" then t = {t} end
  local r = math.random()
  table.sort(t)
  for i,v in pairs(t) do
    if r < v then return i,v end
    r = r - v
  end
end
--

function misc.exists(s,dirs)
  if type(dirs)~="table" then dirs = {dirs} end
  for d=1,#dirs do
    local rd = love.filesystem.getRealDirectory(dirs[d]..tostring(s)..".txt")
    if rd then return d, dirs[d]..s..".txt" end
  end
  return nil
end
--

function misc.tcopy(obj, seen)
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
  local s = seen or {}
  local res = setmetatable({}, getmetatable(obj))
  s[obj] = res
  for k, v in pairs(obj) do res[misc.tcopy(k, s)] = misc.tcopy(v, s) end
  return res
end
--
function misc.tswap(tbl,ind1,ind2)
  local temp = misc.tcopy(tbl[ind1])
  tbl[ind1] = misc.tcopy(tbl[ind2])
  tbl[ind2] = temp
  return tbl
end
--
function misc.tshuffle(tbl) -- suffles numeric indices
  local len, random = #tbl, math.random
  for i = len, 2, -1 do
    local j = random(1, i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
  return tbl
end
--

-- Written by Eike Decker @ https://github.com/zet23t/
-- sorts arr in a stable manner via a simplified mergesort
-- the simplification is to avoid the dividing step and just start
-- merging arrays of size=1 (which are sorted by definition)
function misc.msort(arr, goes_before)
  local n = #arr
  local step = 1
  local fn = goes_before or function(a,b) return a < b end
  local tab1,tab2 = arr, {}
  -- tab1 is sorted in buckets of size=step
  -- tab2 will be sorted in buckets of size=step*2
  while step < n do
    for i=1,n,step*2 do
      -- for each bucket of size=step, merge the results
      local pos,a,b = i, i, i + step
      local e1,e2 = b-1, b+step-1
      -- e1= end of first bucket, e2= end of second bucket
      if e1 >= n then 
        -- end of our array, just copy the sorted remainder
        while a <= e1 do 
          tab2[a],a = tab1[a], a+1
        end
        break 
      elseif 
      e2 > n then e2 = n 
      end
      -- merge the buckets
      while true do
        local va,vb = tab1[a], tab1[b]
        if fn(va,vb) then
          tab2[pos] = va
          a = a + 1
          if a > e1 then 
            -- first bucket is done, append the remainder
            pos = pos + 1
            while b <= e2 do tab2[pos],b,pos = tab1[b], b + 1,pos+1 end
            break 
          end
        else
          tab2[pos] = vb
          b = b + 1
          if b > e2 then
            -- second bucket is done, append the remainder
            pos = pos + 1
            while a <= e1 do tab2[pos],a,pos = tab1[a], a + 1,pos+1 end
            break
          end
        end
        pos = pos + 1
      end
    end
    step = step * 2
    tab1,tab2 = tab2,tab1
  end	
  -- copy sorted result from temporary table to input table if needed
  if tab1~=arr then 
    for i=1,n do arr[i] = tab1[i] end 
  end
  return arr
end

function misc.findClosest(arr,target)
  local function getClosest(ind1,ind2,target)
    if (target - arr[ind1] >= arr[ind2] - target) then return arr[ind2], ind2 else return arr[ind1], ind1 end
  end
  local n = #arr
  if target <= arr[1] then
    return arr[1], 1
  end
  if target >= arr[n] then
    return arr[n], n
  end
  local i, j, mid = 1, n, 0
  while i < j do 
    mid = math.floor((i + j) / 2)
    if arr[mid] == target then
      return arr[mid], mid
    end
    if target < arr[mid] then 
      if mid > 0 and target > arr[mid - 1] then
        return getClosest(mid - 1, mid, target)
      end
      j = mid
    else
      if mid < n and target < arr[mid + 1] then
        return getClosest(mid, mid + 1, target)
      end
      i = mid + 1
    end
  end

  return arr[mid], mid
end
--

function misc.getOpFunc(op)
  local operators = {
    ["="] = function(a,b) return a==b end,
    ["=="] = function(a,b) return a==b end,
    [">="] = function(a,b) return a>=b end,
    ["<="] = function(a,b) return a<=b end,
    [">"] = function(a,b) return a>b end,
    ["<"] = function(a,b) return a<b end,
  }
  return operators[op]
end
--

function misc.lerp(norm, min, max) if norm and min and max then return min + (max - min) * norm else return 0 end end
function misc.cerp(t,a,b) local f=(1-math.cos(t*math.pi))*.5 return a*(1-f)+b*f end
function misc.smooth(num, max, initial, target) return ((num-1) / (max-1)) * (target-initial) + initial end
--

function math.clamp(min, val, max) return math.max(min, math.min(val, max)) end

function misc.pgram(mode,x,y,w,h,offset)
  return lg.polygon(mode, x,y, x+offset,y+h, x+offset+w,y+h, x+w,y)
end
--

function misc.fadeline(x,y,r,w,h,center)
  return lg.draw(fadeline, x, y, r, (w or screen_width)/fadeline:getWidth(), h or 1, center and fadeline:getWidth()/2 or nil)
end
--

function misc.HSV(h, s, v, a)
  if s <= 0 then return v,v,v,a end
  h, s, v = h*6, s, v
  local c = v*s
  local x = (1-math.abs((h%2)-1))*c
  local m,r,g,b = (v-c), 0,0,0
  if h < 1     then r,g,b = c,x,0
  elseif h < 2 then r,g,b = x,c,0
  elseif h < 3 then r,g,b = 0,c,x
  elseif h < 4 then r,g,b = 0,x,c
  elseif h < 5 then r,g,b = x,0,c
  else              r,g,b = c,0,x
  end
  return (r+m),(g+m),(b+m), a
end

function misc.checkRect(o,t)
  local x1,y1,w1,h1 = o[1],o[2],o[3],o[4]
  local x2,y2,w2,h2 = t[1],t[2],t[3],t[4]
  return x1 < x2+w2 and
  x2 < x1+w1 and
  y1 < y2+h2 and
  y2 < y1+h1
end
--
function misc.checkPoint(px,py,x,y,w,h)
  if type(x)=="table" then
    y = x.y or x[2]
    w = x.w or x[3]
    h = x.h or x[4]
    x = x.x or x[1]
  end
  return px > x and py > y and px < x+w and py < y+h
end
--

function misc.action(args)
  out.next()
end
--
misc.action_backup = misc.action

function misc.toGame(x,y)
  local sx, sy = lg.getWidth()/screen_width, lg.getHeight()/screen_height
  if not x then return sx, sy end
  return x/sx, y/sy
end
--

function misc.getMouseScaled()
  local mx, my = love.mouse.getPosition()
  mx, my = misc.toGame(mx,my)
  return mx, my 
end
--

function misc.recursive_retrieve(dir,t,filetype) 
  t = t or {}
  for i,v in ipairs(love.filesystem.getDirectoryItems(dir)) do
    local file = dir.."/"..v
    local info = love.filesystem.getInfo(file)
    if info.type=="file" and (not filetype or file:match("%."..filetype.."$")) then
      table.insert(t,file)
    elseif info.type=="directory" then
      misc.recursive_retrieve(file, t, filetype)
    end
  end
  return t
end
--
function misc.capitalize(t)
  t = tostring(t):gsub("(%w)([%w'%-]*)", function(o,t) return o:upper()..t:lower() end)
  return t
end
--
function misc.sanitize(t)
  return tostring(t):gsub("([%(%)%[%]%%%.%+%-%?%*%$%^])","%%%0")
end
--
function misc.comma_value(n) -- credit http://richard.warburton.it
  local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
  return left..(num:reverse():gsub('(%d%d%d)','%1,'):reverse())..right
end
--
function misc.truncate(text,font,w)
  local curr = ""
  for char in text:gmatch(".") do
    if font:getWidth(curr..char.."...") >= w then curr = curr.."..." break end
    curr = curr..char
  end
  return curr
end
--
function misc.autoCast(text)
  local t = text:lower()
  if t:find("^[%-%d%.]+$") and not t:find("%a") then return tonumber(text)
  elseif t == "true" then return true
  elseif t == "false" then return false
  elseif t == "" or t == "nil" then return nil end
  return text
end
--
function misc.parseData(data)
  local p = {}
  for l in data:gmatch("[^,]+") do
    local mult = {}
    local key, value = l:match("([^%[]-)%s*[:=]%s*([^%]]+)")
    key, value = key or "", value or ""
    key = key:gsub("^%s*(.-)%s*$","%1"):lower()

    if value:find(";") then
      for w in value:gmatch(";*%s*([^;]+)%s*;*%s*") do
        mult[key] = mult[key] or {}
        table.insert(mult[key], misc.autoCast(w))
      end
    end
    p[key] = mult[key] or misc.autoCast(value)
  end
  return p
end
--

function misc.parse_formula(formula,self,target)
  formula = tostring(formula)
  -- Replace names
  local lookup = {["self"]=self, ["target"]=target}
  for n in formula:gmatch("[%a_]+") do
    local e = n:match("([^_]+)_")
    local s = n:match(".-_(.+)$")
    formula = formula:gsub(n, (lookup[e] and s and lookup[e]:getStat(s) or n))
  end
  return assert(loadstring("return "..formula))()
end
--

misc.flash = {alpha=0,lerping=false}
local function flash(time,a)
  if misc.flash.lerping then return end
  time = time or 0.25
  misc.flash.alpha = a or 1
  misc.flash.lerping = true
  event.grant("flash")
  return Flux.to(misc.flash, time, {alpha=0}):ease("quadout"):oncomplete(function() misc.flash.lerping = false end)
end
--
setmetatable(misc.flash, { __call = function(_, ...) return flash(...) end})

misc.fade = {alpha=1,lerping=false}
local function fade(func,time)
  time = time or 0.5
  func = func or function() end
  misc.fade.lerping = true

  assert(type(time)=="number", "Misc.fade - A "..type(time).." was passed as the 'time' argument. The 'time' argument must be a number.")

  return Flux.to(misc.fade, time, {alpha=1}):ease("quadout"):oncomplete(function() func() Timer.after(time*0.66, function() misc.fade.lerping = false end) end):after(time, {alpha=0}):ease("quadout")
end
--
setmetatable(misc.fade, { __call = function(_, ...) return fade(...) end})

misc.shake = {h=0,v=0, base_a=0,base_t=0, tween=nil}
local function shake(amp,time)
  amp, time = amp or 5, time or 0.6
  if amp+time < misc.shake.base_a*misc.shake.base_t
  and amp~=0 and time~=0 then return end
  if misc.shake.tween then misc.shake.tween:stop() end
  misc.shake.base_a, misc.shake.base_t = amp, time
  misc.shake.h, misc.shake.v = amp, amp
  misc.shake.tween = Flux.to(misc.shake, time, {h=0,v=0}):ease("quadinout")
  love.system.vibrate(time/2)
end
--
setmetatable(misc.shake, { __call = function(_, ...) return shake(...) end})

misc.debug = function(...) for i,v in pairs{...} do love.window.showMessageBox("DEBUG",tostring(v)) end end
misc.message = function(msg,title) return prompt(msg or "",nil,{"OK"},title) end
misc.WIP = function() return misc.message("This feature isn't ready yet.") end
misc.tutorial = function(tut) return misc.message(misc.tutorial_messages[tut],"Tutorial") end
misc.changelog = function(funcs)
  local changelog = love.filesystem.read("changelog.txt")
  return prompt("Version "..game_version.."\n"..changelog, funcs or {}, {"OK"}, "Changelog")
end

misc.tutorial_messages = {
  inventory = {"Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "Proin pharetra vitae ligula et sagittis. Cras sed tincidunt risus. Aenean eu imperdiet ex, quis semper sem.", "Vestibulum tempor eleifend felis, sed feugiat dolor malesuada rutrum. Phasellus mi mauris, convallis sed purus id, bibendum euismod neque.", "Pellentesque ut cursus orci. Ut porttitor tempus tellus, ut cursus diam malesuada sit amet."},
  files = {"Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "Proin pharetra vitae ligula et sagittis. Cras sed tincidunt risus. Aenean eu imperdiet ex, quis semper sem.", "Vestibulum tempor eleifend felis, sed feugiat dolor malesuada rutrum. Phasellus mi mauris, convallis sed purus id, bibendum euismod neque.", "Pellentesque ut cursus orci. Ut porttitor tempus tellus, ut cursus diam malesuada sit amet."},
  shop = {"Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "Proin pharetra vitae ligula et sagittis. Cras sed tincidunt risus. Aenean eu imperdiet ex, quis semper sem.", "Vestibulum tempor eleifend felis, sed feugiat dolor malesuada rutrum. Phasellus mi mauris, convallis sed purus id, bibendum euismod neque.", "Pellentesque ut cursus orci. Ut porttitor tempus tellus, ut cursus diam malesuada sit amet."},
  stats_1 = {"Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "Proin pharetra vitae ligula et sagittis. Cras sed tincidunt risus. Aenean eu imperdiet ex, quis semper sem.", "Vestibulum tempor eleifend felis, sed feugiat dolor malesuada rutrum. Phasellus mi mauris, convallis sed purus id, bibendum euismod neque.", "Pellentesque ut cursus orci. Ut porttitor tempus tellus, ut cursus diam malesuada sit amet."},
  stats_2 = {"Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "Proin pharetra vitae ligula et sagittis. Cras sed tincidunt risus. Aenean eu imperdiet ex, quis semper sem.", "Vestibulum tempor eleifend felis, sed feugiat dolor malesuada rutrum. Phasellus mi mauris, convallis sed purus id, bibendum euismod neque.", "Pellentesque ut cursus orci. Ut porttitor tempus tellus, ut cursus diam malesuada sit amet."},
  stats_3 = {"Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "Proin pharetra vitae ligula et sagittis. Cras sed tincidunt risus. Aenean eu imperdiet ex, quis semper sem.", "Vestibulum tempor eleifend felis, sed feugiat dolor malesuada rutrum. Phasellus mi mauris, convallis sed purus id, bibendum euismod neque.", "Pellentesque ut cursus orci. Ut porttitor tempus tellus, ut cursus diam malesuada sit amet."},
  stats_4 = {"Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "Proin pharetra vitae ligula et sagittis. Cras sed tincidunt risus. Aenean eu imperdiet ex, quis semper sem.", "Vestibulum tempor eleifend felis, sed feugiat dolor malesuada rutrum. Phasellus mi mauris, convallis sed purus id, bibendum euismod neque.", "Pellentesque ut cursus orci. Ut porttitor tempus tellus, ut cursus diam malesuada sit amet."},
  explore = {"Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "Proin pharetra vitae ligula et sagittis. Cras sed tincidunt risus. Aenean eu imperdiet ex, quis semper sem.", "Vestibulum tempor eleifend felis, sed feugiat dolor malesuada rutrum. Phasellus mi mauris, convallis sed purus id, bibendum euismod neque.", "Pellentesque ut cursus orci. Ut porttitor tempus tellus, ut cursus diam malesuada sit amet."},
}
--

misc.screenshot_txt = {1,1,1,0}

misc.uptime = 0

misc._loadfile_out = love.filesystem.load("output.lua")
misc._loadfile_choices = love.filesystem.load("choices.lua")
misc._out_source_modifier = false

function misc.populate_data()
  local changelog = love.filesystem.read("changelog.txt")
  misc.changelog()
end
--

return misc