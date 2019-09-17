local ef = {}

ef[0] = {
  func = function(self)
  end,
  update = function(self,dt)
  end,
  background = function(self)
  end,
  draw = function(self)
  end,
}
--

for ii,effect in pairs(ef) do
  if ii~=0 then
    setmetatable(effect, {__index = function(t,i)
          return rawget(t,i) or rawget(ef[0],i)
        end})
  end
end
setmetatable(ef, {__index = function(t,i) if not rawget(t,i:lower()) then return rawget(t,0) end return rawget(t,i:lower()) end})
return ef