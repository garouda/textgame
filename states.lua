local st = {}
for i,v in pairs(love.filesystem.getDirectoryItems("states")) do
  if v:sub(1,1):match("%w") then 
    v = v:sub(1,-5)
    st[v] = require("states."..v)
  end
end
--

return st