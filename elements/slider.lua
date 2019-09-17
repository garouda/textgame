local lg = lg

local pointer_offset_max = 5

local function new(reference,min,max,x,y,w,param)
  param = param or {}
  local h = 36
  local dragger = 26

  local default = reference[1] or min+max/2
  if reference[2] then default = reference[1][reference[2]] end

  default = math.clamp(min,default,max)
  y = y + h/2 + 5

  local sub_x = x+(w-dragger)*((default-min)/(max-min))

  local cols = param["cols"] or {
    bg = {
      --Default
      {1,1,1,0.25},
      --Hovered
      {1,1,1,0.5},
      --Pressed
      {1,1,1,0.25},
    },
    fg = {
      --Default
      {1,1,1,0.5},
      --Hovered
      {1,1,1},
      --Pressed
      {1,1,1},
    },
  }

  local pointer_offset = 0
  local pointer_offset_dir = 1

  local function update(self,dt,x,y)
    local xx,yy = self.x+(x or 0), self.y+(y or 0)
    local mx, my = Misc.getMouseScaled()

    sub_x = self.x+(self.w-dragger)*((self.value-min)/(max-min))
  
    if Misc.checkPoint(mx,my, xx,yy-self.h/2,self.w,self.h) then
      self.selected = true
    else
      self.selected = false
    end

    if self.selected or self.held then
      pointer_offset = math.clamp(0, pointer_offset + (pointer_offset_max * pointer_offset_dir) * 4 * dt, pointer_offset_max)
      if (pointer_offset_dir == 1 and pointer_offset >= pointer_offset_max) or (pointer_offset_dir == -1 and pointer_offset <= 0) then
        pointer_offset_dir = pointer_offset_dir * -1
      end
    else
      pointer_offset = 0
      pointer_offset_dir = 1
    end

    if self.held then
      sub_x = math.clamp(self.x, mx-25/2, self.x+self.w-dragger)
      self.value = (max-min) * ((sub_x-self.x) / (self.w-dragger)) + min
    end

    reference[1][reference[2]] = self.value
  end
  local function draw(self)
    local line_width = lg.getLineWidth()
    local bg, fg = cols.bg[1], cols.fg[1]
    if self.selected then bg, fg = cols.bg[2], cols.fg[2] end
    if self.held then bg, fg = cols.bg[3], cols.fg[3] end
    self.y = math.floor(self.y)
    lg.setColor(bg)
    lg.setLineWidth(2)
    lg.line(self.x,self.y,self.x+self.w,self.y)
    lg.setLineWidth(1)
    Misc.fadeline(self.x, self.y-4, nil, self.w, 1)
    Misc.fadeline(self.x, self.y+3, nil, self.w, 1)
    lg.setColor(bg[1],bg[2],bg[3],bg[4]*2)
    lg.draw(squarrow,self.x-squarrow:getWidth()/2 + pointer_offset,self.y-squarrow:getHeight()/2, nil, -1,1, squarrow:getWidth()/2,0)
    lg.draw(squarrow,self.x+self.w - pointer_offset,self.y-squarrow:getHeight()/2)
    lg.setColor(fg)
    lg.rectangle("fill",math.floor(sub_x),math.floor(self.y-dragger/2),dragger,dragger, 8)
    lg.setColor(0.8,0.8,0.8,0.5)
    lg.rectangle("line",math.floor(sub_x),math.floor(self.y-dragger/2),dragger,dragger, 8)
    lg.setLineWidth(line_width)
  end
  local function mousepressed(self,x,y,b,xo,yo)
    self.held = false
    if b~=1 then return end
    local xx, yy = self.x + (xo or 0), self.y + (yo or 0)
    if Misc.checkPoint(x,y, xx, yy-self.h/2, self.w, self.h+self.h) then
      self.held = true
      return true
    end
  end
  local function mousereleased(self,x,y,b,xo,yo)
    if b~=1 then return end
    local xx, yy = self.x + (xo or 0), self.y + (yo or 0)
    if Misc.checkPoint(x,y, xx, yy-self.h/2, self.w, self.h+self.h) and self.held then
      self.held = false
      return true
    end
    self.held = false
  end

  return {value=default,x=x,y=y,w=w,h=h,total_w=w+squarrow:getWidth()*2,selected=false,held=false,reference=reference,    update=update,draw=draw,mousepressed=mousepressed,mousereleased=mousereleased}
end
--

return new