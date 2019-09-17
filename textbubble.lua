local textbubble = {list = {}}
textbubble.__index = textbubble
setmetatable(textbubble, {__call = function(_, ...) return textbubble.new(...) end})
local bubble = {
  l =lg.newImage("res/img/bubble left.png"),
  r =lg.newImage("res/img/bubble right.png"),
  c =lg.newImage("res/img/bubble centre.png"),
}

local FONT_ = {
  fonts.textbubble,
}
local freeze_update
--
function textbubble.new(text,x,y,timer)
  local params = {
    text = "",
    text_out = "",
    table = {},
    progress = 0,
    index = 1,
    speed = 30,
    dir = 1,
    box = {
      x=10,
      y=10,
      w=0,
      h=0,
      a=0.9,
      xoff = 15,
      yoff = 15,
    },
    visible = true,
    lerping = false,
    timer = 0,
  }
  local m = setmetatable(params or {}, textbubble)
  if type(text)=="string" then m.table = {text} else m.table = text end
  m.box.x, m.box.y = x or screen_width/2, y or screen_height/2--enemy_info.box.y+enemy_info.box.h
  m.box.ox = m.box.x
  m.text = m.table[m.index]

  m.flux = Flux.group()

  local ww = FONT_[1]:getWidth(m.text)+m.box.xoff*2
  local hh = FONT_[1]:getHeight(m.text)
  local mwidth, wrapped = FONT_[1]:getWrap(m.text,screen_width/3)
  m.text = table.concat(wrapped,"\n")

  m.timer = timer or 1 + #wrapped

  local t = {
    w=math.max(mwidth+m.box.xoff*2, bubble.l:getWidth()*2),
    h=(hh*#wrapped)+m.box.yoff*2
  }
  t.x=m.box.x-t.w/2

  if m.box.y-20-t.h < 0 then
    m.dir = 1
    t.y=m.box.y
  else
    m.dir = 2
    t.y=m.box.y-t.h
  end

  m.lerping = true
  m.flux:to(m.box, 0.2, t):ease("quadout"):oncomplete(function() m.lerping = false end)
  textbubble.list[1] = m
  return m
end
--

function textbubble:close()
  self.lerping = true
  self.flux:to(self.box, 0.2, {a=0}):ease("quadout"):oncomplete(function() table.remove(textbubble.list,1) end)
end
--

function textbubble:next(i)
  self.text_out = ""
  if (not i and self.index + 1 > #self.table) or (i and i > #self.table) then return self:close() end
  self.index = i or self.index + 1
  self.progress = 0
  self.text = self.table[self.index]
  local prev_h = self.box.h
  local ww = FONT_[1]:getWidth(self.text)+self.box.xoff*2
  local hh = FONT_[1]:getHeight(self.text)
  local mwidth, wrapped = FONT_[1]:getWrap(self.text,screen_width/3)
  self.text = table.concat(wrapped,"\n")  
  self.box.w = math.max(mwidth+self.box.xoff*2, bubble.l:getWidth()*2)
  self.box.h = (hh*#wrapped)+self.box.yoff*2
  self.box.x = self.box.ox-self.box.w/2
  self.box.y = self.box.y - (math.max(prev_h,self.box.h)-math.min(prev_h,self.box.h))
  self.timer = 1 + #wrapped

  return self.table[self.index]
end
--

function textbubble.update(dt)
  for i,v in pairs(textbubble.list) do
    local self = v
    self.flux:update(dt)
    if not self.lerping then
      self.text_out = self.text:sub(0,self.progress)
      if math.floor(self.progress) == #self.text then
        if self.timer > 0 then self.timer = math.max(0, self.timer - 1 * dt) end
        if self.timer == 0 then
          self:next()
          break
        end
      end
      self.progress = #self.text
    end
  end
  if freeze_update then return true end
end
--

function textbubble.draw()
  for i,v in pairs(textbubble.list) do
    local self = v
    lg.push()
    local x, y = math.floor(math.clamp(50, self.box.x+self.box.w/2, screen_width-50)), math.floor(self.box.y)

    -- Draw the tail
    lg.setColor(0,0,0,self.box.a/2)
    if self.dir == 1 then
      lg.translate(0,20)
      lg.polygon("fill",{x,y-20,x+15,y,x-9,y})
    else
      lg.translate(0,-20)
      lg.polygon("fill",{x,y+self.box.h+20,x+15,y+self.box.h,x-9,y+self.box.h})
    end

    --[[OUTLINE]]
    lg.setColor(1,1,1,self.box.a/2)
    if self.dir == 1 then
      lg.polygon("line",{x,y-20,x+15,y+1,x-9,y+1})
      lg.stencil(function() lg.polygon("fill",{x,y-20,x+15,y+1,x-9,y+1}) end, "replace", 1)
    else
      lg.polygon("line",{x,y+self.box.h+20,x+15,y+self.box.h-1,x-9,y+self.box.h-1})
      lg.stencil(function() lg.polygon("fill",{x,y+self.box.h+20,x+15,y+self.box.h-1,x-9,y+self.box.h-1}) end, "replace", 1)
    end
    lg.setStencilTest("equal", 0)
    x, y = math.floor(math.clamp(10, self.box.x, screen_width-self.box.w-10)), math.floor(math.clamp(0, self.box.y, screen_height-self.box.h))
    lg.setColor(1,1,1,self.box.a/2)
    lg.draw(bubble.l,x-1,y-1,nil,1,(self.box.h+2)/bubble.l:getHeight())
    -- Stretch the centre piece (it's 1px wide)
    lg.draw(bubble.c,x+bubble.l:getWidth()-1,y-1,nil,(self.box.w+2)-bubble.l:getWidth()-bubble.r:getWidth(),(self.box.h+2)/bubble.c:getHeight())
    lg.draw(bubble.r,x+self.box.w-bubble.r:getWidth()+1,y-1,nil,1,(self.box.h+2)/bubble.r:getHeight())
    lg.setStencilTest()
    --[[OUTLINE]]

    lg.setColor(0,0,0,self.box.a)
    lg.draw(bubble.l,x,y,nil,1,self.box.h/bubble.l:getHeight())
    -- Stretch the centre piece (it's 1px wide)
    lg.draw(bubble.c,x+bubble.l:getWidth(),y,nil,self.box.w-bubble.l:getWidth()-bubble.r:getWidth(),self.box.h/bubble.c:getHeight())
    lg.draw(bubble.r,x+self.box.w-bubble.r:getWidth(),y,nil,1,self.box.h/bubble.r:getHeight())

    lg.setFont(FONT_[1])
    lg.setColor(0.88,0.88,0.88,self.box.a)
    lg.print(self.text_out, x+self.box.xoff, y+self.box.yoff)
    lg.pop()
  end
end
--

function textbubble.mousereleased(x,y,b,t)
  for i,v in pairs(textbubble.list) do
    local self = v
    if self.dir == 1 then y = y - 20 else y = y + 20 end
    if x > self.box.x and x < self.box.x + self.box.w and y > self.box.y and y < self.box.y+self.box.h then
      self:next()
      return true
    end
  end
end
--

function textbubble.clear()
  textbubble.list = {}
end
--

return textbubble