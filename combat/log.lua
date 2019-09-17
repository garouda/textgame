local log = {}
setmetatable(log, { __call = function(_, ...) return log.insert(...) end})

local FONT_ = {
  fonts.combat_log,
}
local alpha = 1
local dir = 1
local time = 0
local squarrow = {
  img = squarrow,
  alpha = 1
}
local after_func
local active_ent, active_target

log.list = {}
log.font = FONT_[1]
log.box = {
  x=screen_width/9,
  y=screen_height-screen_height/2,
  h=0,
  th=0,
}
log.box.w = screen_width-log.box.x*2
log.box.by = screen_height/2
log.box.ty = log.box.by
local proto = Misc.tcopy(log.box)

local function replace(text,ent,target)
  for var in text:gmatch("#([%w_]+)") do
    var = var:lower()
    local public = {}
    local list = {}
    for i,v in pairs{["self"]=ent, ["target"]=target} do
      local pub = process.getReplacementList(v)
      for k,v in pairs(species[v.species]) do pub[i..k] = v end
      list[i] = pub
    end
    if var:match("target") then public = list.target else public = list.self end
    local p = tostring(public[var])

    while p==nil or p=="nil" or p=="" do
      var = var:sub(1,-2)
      if #var==0 then return text end
      p = public[var]
    end

    local s, e = text:find("#"..Misc.sanitize(var))
    if not s then return text end

    -- Correct capitalization, and a/an regarding vowels
    if text:sub(s-4, e):match("[%?%!%.]") or #text:sub(s-4, e) < 4 then p = Misc.capitalize(p)
    elseif var~="self" and var~="selfspecies" and var~="target" and var~="targetspecies" then p = p:lower() end
    local _vowel = __.any({"a","e","i","o","u"}, function(_,l) return l == p:sub(1,1):lower() end)
    text = text:gsub("(%w*)([aA])(n?)%s"..Misc.sanitize(var).."([%A^_])", function(a,b,c,d)
        if a=="" then
          if _vowel then c = "n" else c = "" end
          return a..b..c.." "..p..d
        end
      end, 1):gsub("#"..var, p, 1)
  end
  return text
end
--

function log.insert(msg,ent,target,after)
  if not msg or type(msg)=="table" and not next(msg) then
    return (after and after() or nil)
  end
  if type(msg)~="table" then msg = {msg} end

  log.list = {}
  active_ent, active_target = ent, target

  for i,m in pairs(msg) do
    local l = {}
    for p in m:gmatch(";*%s*([^;]+)%s*;*%s*") do
      p = ent and replace(p,active_ent,active_target) or p
      local _, wrapped = log.font:getWrap(p,log.box.w*(3/4))
      l[#l+1] = table.concat(wrapped,"\n")
    end
    table.insert(log.list, {alpha=0, msg = l})
  end
  log.list[#log.list].after = after or function() end

  log.set()
end
--

function log.set()
  log.box.th = screen_height/6
  log.box.by = proto.by
  log.box.ty = log.box.by
  alpha = 0
  time = combat.auto and states.combat.mode=="turn" and 0.5 or math.huge
  dir = 1
  log.visible = true
  log.list[1].msg[1] = process.exec_cmd(log.list[1].msg[1])
end
--

function log.update(dt)
  alpha = math.clamp(0, alpha + dir * 5 * dt, 1)

  log.box.y = Misc.lerp(16*dt, log.box.y, log.box.ty-log.box.th/2)
  log.box.h = Misc.lerp(16*dt, log.box.h, log.box.th)

  squarrow.alpha = (squarrow.alpha - dt * 1.5) % 1

  time = math.max(0, time - dt)
  if time == 0 then
    log.close()
  end
end
--

function log.draw()
  if log.box.h <= 3 or not log.list[1] then return end
  local active_msg = log.list[1].msg[1]
  lg.setColor(0,0,0,1/4*alpha)
  lg.rectangle("fill", 0, 0, screen_width, screen_height)
  lg.setColor(0,0,0,2/3*alpha)
  lg.rectangle("fill", log.box.x, log.box.y, log.box.w, log.box.h, 5, 5)
  lg.setColor(1,1,1,2/3*alpha)
  lg.rectangle("line", log.box.x, log.box.y, log.box.w, log.box.h, 5, 5)

  lg.stencil(function()   lg.rectangle("fill", log.box.x+2, log.box.y+2, log.box.w-4, log.box.h-4, 5, 5) end, "replace", 1)
  lg.setStencilTest("equal", 1)

  local txt_w, wrapped = FONT_[1]:getWrap(active_msg, log.box.w*(3/4))
  local text_height = #wrapped

  lg.setColor(1,1,1,squarrow.alpha*alpha)
  lg.draw(squarrow.img, log.box.x+log.box.w/2+txt_w/2+10, log.box.y+log.box.h/2-(squarrow.img:getHeight()*0.75)/2, nil, 0.75,0.75)

  lg.setFont(FONT_[1])
  local function print_msg(msg,xo,yo)
    return lg.printf(msg, log.box.x+log.box.w*(1/8)+(xo or 0), (log.box.y+log.box.h/2-FONT_[1]:getHeight()/2-(FONT_[1]:getHeight()/2)*(text_height-1))+(yo or 0), log.box.w*(3/4), "center")
  end
  for o=-1,1,2 do
    for _,a in pairs({0.3,0.1,0.1}) do
      lg.setColor(1,1,1,a*alpha)
      print_msg(active_msg,o)
      print_msg(active_msg,nil,o) 
    end
  end
  lg.setColor(1,1,1,1*alpha)
  print_msg(active_msg)
  lg.setStencilTest()
end
--

function log.keypressed(key)
  if log.box.h <= log.box.th*0.95 then return end
  if keyset.confirm(key) then log.close() end
end
--
function log.mousepressed(x,y,b,t)
  if log.box.h <= log.box.th*0.95 then return end
  log.close()
end
--

function log.close(instant)
  dir = -1
  log.visible = false
  log.box.th = 0
  log.box.ty = log.box.by+15
  if instant then
    log.box.h = 0
    log.box.y = log.box.ty
  end
  if #log.list>0 and #log.list[1].msg>1 then
    table.remove(log.list[1].msg, 1)
    log.set()
    return
  elseif #log.list>1 then
    table.remove(log.list, 1)
    log.set()
    return
  end
  if next(log.list) and log.list[1].after then
    local f = log.list[1].after
    log.list[1].after = nil
    f()
  end
  if #log.list==1 and not log.list[1].after then
    local f = event.pop("after_combat_log")
    if f then return f() end
  end
end
--

function log.toggle()
  dir = dir * -1
end
--

function log.clear()
  log.list = {}
end
--

return log