local event = {}
-- IDs are strings that the requester or wisher knows to search for. "enemydied", "levelup", "newarea" etc.

local deaf

event.queue = {}
event.wishes = {}

function event.push(id,data)
  if deaf then return end
  if data then
    event.queue[id] = event.queue[id] or {}
    table.insert(event.queue[id],data)
  end

  -- Return any wishes with that ID
  return event.wishes[id] or {}
end
--

function event.pop(id,index)
  if deaf then return end
  if not event.exists(id) then return end
  local r = event.queue[id]
  r = table.remove(event.queue[id], ((index or 1)-1)%#event.queue[id]+1) or r
  if not next(event.queue[id]) then event.queue[id] = nil end
  return r
end
--

function event.poll(id)
  local t = event.queue[id] or {}
  return next, t
end
--

function event.exists(id)
  return event.queue[id]
end
--

function event.clear(...)
  local args = {...}
  for i=1,#args do event.queue[args[i]] = nil end
end
--

function event.wish(id,data,unique)
  if deaf then return end
  if type(id)=="string" then id = {id} end
  for i,v in pairs(id) do
    event.wishes[v] = event.wishes[v] or {}
    event.wishes[v][unique or #event.wishes[v]+1] =  data
  end
end
--

function event.peek(id,ind)
  return (event.wishes[id] or {})[ind]
end
--

function event.grant(id,...)
  if deaf then return end
  local ret_val
  if type(id)=="string" then id = {id}
    for i,v in ipairs(id) do
      for ii,v in pairs(event.wishes[v] or {}) do
        if type(v)=="function" then
          local args = {...}
          ret_val = v(unpack(args))
        end 
      end
    end
  end
  return ret_val
end
--

function event.endWish(unique)
  if deaf then return end
  for i,v in pairs(event.wishes) do
    v[unique] = nil
  end
end
--

function event.deafen() deaf = true end
function event.listen() deaf = false end

return event