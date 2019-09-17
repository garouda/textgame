local lg = lg

local function new(default,min,max,x,y,h,param)
  param = param or {}
  local w = 36
  max = math.max(0, max)
  min = math.min(min, max)
  local dragger = math.clamp(screen_height/10, h * (h/(h+max)), h)
  
  local no_draw = param["no_draw"]

  default = math.clamp(min,default,max)

  local sub_y = y+(h-dragger)*((default-min)/(max-min))
  local alpha = 0
  local col = param["colour"] or {1,1,1,alpha}
  local mvtotal = 0
  local old_offset = default

  local function update(self,dt,ox,oy)
    if not self.visible then return end
    if not love.mouse.isDown(1) and not next(love.touch.getTouches()) then self.touch = nil self.mvtotal = 0 end

    self.value = Misc.lerp(10*dt, self.value, self.y_offset_target)
    self.y_offset = -self.value

    if math.floor(self.y_offset) ~= old_offset then
      old_offset = math.floor(self.y_offset)
      self.alpha = math.clamp(0, self.alpha + 10 * dt, 1)
    else
      self.alpha = math.clamp(0, self.alpha - 2 * dt, 1)
    end

    local xx,yy = self.x+(ox or 0), self.y+(oy or 0)
    local mx,my = Misc.getMouseScaled()
    
    if Misc.checkPoint(mx,my, xx-self.w/2,yy,self.w,self.h) then
      self.selected = true
    else
      self.selected = false
    end
    sub_y = math.clamp(self.y, y+(h-dragger)*((self.value-min)/(self.max-min)), self.y+self.h-dragger)
--    self.value = math.clamp(min,self.value,self.max)
    col[4] = self.alpha*0.4
  end
  local function draw(self)
    if not self.visible or self.no_draw then return end
    local line_width = lg.getLineWidth()
    self.y = math.floor(self.y)
    lg.setColor(col)
    lg.rectangle("fill",math.floor(self.x-3),math.floor(sub_y),6,dragger, 8)
    lg.setColor(0.8,0.8,0.8,col[4])
    lg.setLineWidth(1)
    lg.rectangle("line",math.floor(self.x-3),math.floor(sub_y),6,dragger, 8)
    lg.setLineWidth(line_width)
  end
  local function keypressed(self,key,allow)
    if not self.visible then return end
    if keyset.scrolldown(key) or allow=="down" and keyset.down(key) then
      self.y_offset_target = math.clamp(self.min, self.y_offset_target + (1 * screen_height/10), self.max)
    elseif keyset.scrollup(key) or allow=="up" and keyset.up(key) then
      self.y_offset_target = math.clamp(self.min, self.y_offset_target - (1 * screen_height/10), self.max)
    end
  end
  local function wheelmoved(self,x,y,dx,dy)
    if not self.visible then return end
    self.y_offset_target = math.clamp(self.min, self.y_offset_target - (y * screen_height/10), self.max)
  end
  local function touchmoved(self,id,x,y,dx,dy)
    if not self.visible then return end
    if not self.touch then return end
    self.mvtotal = self.mvtotal + math.abs(dx)+math.abs(dy)
    self.y_offset_target = math.clamp(self.min, self.y_offset_target-dy, self.max)
  end
  local function checkArea(self,x,y,area)
    if not self.visible then return end
    area[1], area[2], area[3], area[4] = area[1] or area.x, area[2] or area.y, area[3] or area.w, area[4] or area.h
    if x>area[1] and x<area[1]+area[3] and y>area[2] and y<area[2]+area[4]
    then
      self.touch = true
    else
      self.touch = nil
      self.mvtotal = 0 
    end
  end
  local function moveTo(self,y)
    if not self.visible then return end
    y = y or self.y_offset_target
    self.y_offset_target = math.clamp(self.min, y, self.max)
  end
  local function snapTo(self,y)
    if not self.visible then return end
    y = y or self.y_offset_target
    self.value = y
    self.y_offset = -y
    self.y_offset_target = y
  end
  local function setMax(self,n)
    self.max = math.max(0, n)
    dragger = math.clamp(screen_height/10, h * (h/(h+self.max)), h)
    default = math.clamp(min,default,self.max)
    sub_y = y+(h-dragger)*((default-min)/(self.max-min))
    self:moveTo(self.y_offset_target)
  end

  return {value=default,x=x,y=y,w=w,h=h,min=min,max=max,alpha=alpha,mvtotal=mvtotal,y_offset=0,y_offset_target=0,touch=nil,selected=false,held=false,visible=true,no_draw=no_draw,    update=update,draw=draw,keypressed=keypressed,wheelmoved=wheelmoved,touchmoved=touchmoved,checkArea=checkArea,moveTo=moveTo,snapTo=snapTo,setMax=setMax,}
end
--

return new