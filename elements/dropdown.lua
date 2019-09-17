local newScroller = require("elements.scroller")

local font = fonts.dropdown
local pad = 8
local ypad = 6
local max_entries = 8
local button_h = font:getHeight()

local function new(olist,func,param)
--  if not next(olist) then return end
  local list = Misc.tcopy(olist)
  param = param or {
    alpha = 1,
    noclamp = false,
  }
  func = func or function() end
  local x,y,w,h,th,mouse_on,origin,scroller
  local scrollshading
  local visible = false
  local cols = param["cols"] or {bg = {{1,1,1,0.13},{1,1,1,0.2},{0.03,0.12,0.1,0.3}},fg = {{1,1,1,0.75},{1,1,1},{1,1,1,0.5}}}
  local _self = {}

  local bh = button_h
  local max_height = max_entries
  scrollshading = {top=0,bottom=1}
  x, y = 0,0
  w, h = screen_width/8,0
  mouse_on = nil
  origin = {x=x,y=y}
  if love.system.getOS()=="Android" then
    w = w*1.66
    bh = bh*1.66
    max_height = max_height*0.75
  end
  th = (pad*2 + math.min(max_height, #olist) * (bh+ypad)) - (pad/2)
  for i,v in pairs(olist) do
    if font:getWidth(v)+pad*4+20 > w then w = font:getWidth(v)+pad*4+20 end
  end

  local function getSelectedButton()
    for i,v in pairs(list) do
      if v.selected then return i end
    end
    return nil
  end
--  
  local function open(self,mx,my)
    if self.visible then return end
    if not next(list) then return end
    scrollshading = {top=0,bottom=1}
    self.x, self.y = math.floor(mx or 0), math.floor(my or 0)
    self.h = 0
    mouse_on = nil
    origin = {x=self.x,y=self.y}
    if #olist > max_height then self.x, self.w = self.x-(25+pad), self.w+pad end
    if self.param.noclamp then
      self.x = origin.x
      self.y = origin.y
      self.th = math.min(self.th, screen_height - self.y - 10)
    else
      self.x = math.clamp(10, origin.x - self.w/2, screen_width-10 - self.w)
      self.y = math.clamp(10, origin.y, screen_height-10 - self.th)
    end
    self.scroller = newScroller(2, 0, (bh+ypad)*(#olist-1)-(self.th-(bh+pad*2)), self.x+self.w-pad, self.y+5, self.th-10)
    if #olist <= max_height then self:close() end 

    if param.instant then self.h = self.th end

    for i,v in pairs(olist) do
      local w = self.w-pad*2
      list[i] = newButton(Misc.capitalize(v),
        function() _self:close() return self.func(i,v) end,
        self.x+pad, self.y + pad + (bh+ypad) * (i-1), w, bh, {font=font, no_ripple=true, cols=cols, alpha=self.param.alpha, target_alpha=self.param.alpha})
    end
    self.visible = true
  end
--
  local function close(self)
    self.visible = false
  end
--

  local function update(self,dt)
    if not self.visible then return end
    _self = self
    self.h = Misc.lerp(12*dt, self.h, self.th)
    if self.scroller.y_offset_target < self.scroller.max then
      scrollshading.bottom = Misc.lerp(6*dt, scrollshading.bottom, 1)
    else
      scrollshading.bottom = Misc.lerp(6*dt, scrollshading.bottom, 0)
    end
    if self.scroller.y_offset_target > 0 then
      scrollshading.top = Misc.lerp(6*dt, scrollshading.top, 1)
    else
      scrollshading.top = Misc.lerp(6*dt, scrollshading.top, 0)
    end

    for i,v in pairs(self.list) do
      if v.y+v.h + self.scroller.y_offset > self.y and v.y + self.scroller.y_offset < self.y+self.h then
        v:update(dt,nil,self.scroller.y_offset)
      end
    end
    self.scroller:update(dt)
    return true
  end
  local function draw(self)
    if not self.visible then return end
    local x, y, w, h = math.floor(self.x),math.floor(self.y),math.floor(self.w),math.floor(self.h)

    lg.setColor(0,0,0,1*self.param.alpha)
    lg.rectangle("fill",x,y,w,h)
    lg.rectangle("line",x-1,y-1,w+2,h+2)
    lg.setColor(1,1,1,0.4*self.param.alpha)
    lg.rectangle("line",x,y,w,h)

    lg.stencil(function() lg.rectangle("fill",x,y,w,h) end, "replace", 1)
    lg.setStencilTest("equal",1)

    lg.push()
    lg.translate(0,self.scroller.y_offset)

    lg.setFont(font)
    for i,v in pairs(self.list) do
      if v.y+v.h + self.scroller.y_offset > self.y and v.y + self.scroller.y_offset < self.y+self.h then
        v:draw()
      end
    end
    lg.pop()
    lg.setColor(0,0,0,0.95*scrollshading.top*self.param.alpha)
    Misc.fadeline(x+w, y-h/4, math.pi/2, h/2, w)
    lg.setColor(0,0,0,0.95*scrollshading.bottom*self.param.alpha)
    Misc.fadeline(x+w, y+h-h/4, math.pi/2, h/2, w)
    self.scroller:draw()
    lg.setStencilTest()
    lg.setColor(1,0,0,1*self.param.alpha)
  end
  local function mousepressed(self,x,y,b,xo,yo)
    if not self.visible then return end
    local xx, yy = self.x, self.y
    if Misc.checkPoint(x,y, xx, yy, self.w, self.h) then
      mouse_on = true
      self.scroller:checkArea(x,y, {xx, yy, self.w, self.h})
      for i,v in pairs(self.list) do v:mousepressed(x,y,b,nil,self.scroller.y_offset) end
      return true
    end
    mouse_on = nil
  end
  local function mousereleased(self,x,y,b,xo,yo)
    if not self.visible then return end
    local xx, yy = self.x, self.y
    if Misc.checkPoint(x,y, xx, yy, self.w, self.h) then
      for i,v in pairs(self.list) do v:mousereleased(x,y,b,nil,self.scroller.y_offset) end
      return true
    end
    if not mouse_on then return false end
  end
  local function wheelmoved(self,x,y)
    if not self.visible then return end
    self.scroller:wheelmoved(x,y)
    return true
  end
  local function touchmoved(self,id,x,y,dx,dy)
    if not self.visible then return end
    self.scroller:touchmoved(id,x,y,dx,dy)
    for i,v in pairs(self.list) do v:touchmoved(id,x,y,dx,dy) end
    return true
  end

  local self = {list=list,x=x,y=y,w=w,h=h,th=th,cols=cols,font=font,visible=visible,func=func,param=param,scroller=scroller, open=open,close=close,update=update,draw=draw,mousepressed=mousepressed,mousereleased=mousereleased,wheelmoved=wheelmoved,touchmoved=touchmoved}
  
  self:open(0,0)
  self:close()
  return self
end
--

return new