local f = {}
setmetatable(f, {__index = function(t,i) if i==nil then return nil end return rawget(f,i) or 0 end})
return f