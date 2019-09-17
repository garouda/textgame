local lg = lg

local check = lg.newImage("res/img/check.png")
local ripples = {}
local ripple_size_limit = 10

local FONT_ = {
  fonts.element
}

local function new(labels,tabl,value,x,y,param)
  param = param or {}
  if type(labels)=="string" then labels = {labels} end
  assert(tabl[value],"tabl[value] of newSelect() cannot be nil.")

  pad = param["pad"] or 50--80
  local just = param["just"]
  local no_blank = param["no_blank"]
  local no_ripple = param["no_ripple"]
  local h = FONT_[1]:getHeight()+16
  local xs = {}
  local w = 0
  for i,v in pairs(labels) do
    if w < FONT_[1]:getWidth(v)+65 then w = FONT_[1]:getWidth(v)+65 end
  end
  for i,v in pairs(labels) do
    if just=="right" then xs[#xs+1] = x - w + (w+pad)*(i-1) + (w + pad/2)*(#labels-1)
    elseif just=="left" then xs[#xs+1] = x + (w+pad)*(i-1) - (pad/2)*(#labels-1)
    else xs[#xs+1] = x - w/2 + (w+pad)*(i-1) - (w/2 + pad/2)*(#labels-1) end
  end

  local alpha = param["alpha"] or 1

  local cols = param["cols"] or {
    bg = {
      --Default
      {1,1,1,0.15},
      --Hovered
      {1,1,1,0.25},
      --Pressed
      {0,0,0,0.4},
    },
    fg = {
      --Defaults
      {1,1,1,1},
      --Hovered
      {1,1,1,1},
      --Pressed
      {1,1,1,0.5},
    },
  }

  local visible = true

  local function update(self,dt,x,y)
    if not self.visible then return end
    ripples[self] = ripples[self] or {}
    local has_already_selected
    local mx,my = Misc.getMouseScaled()
    for i,v in pairs(labels) do
      if not love.mouse.isDown(1) then self.button_down = 0 end
      local xx,yy = xs[i]+(x or 0), self.y+(y or 0)

      ripples[self][i] = ripples[self][i] or {}

      if not no_ripple then
        for r,_ in pairs(ripples[self][i]) do
          ripples[self][i][r] = ripples[self][i][r] + ripple_size_limit * dt
          if ripples[self][i][r] >= ripple_size_limit then ripples[self][i][r] = nil end
          if #ripples[self][i] == 0 and self.selected==i then ripples[self][i][r] = 0 end
        end
      end

      if Misc.checkPoint(mx,my, xx,yy,w,self.h) and not has_already_selected then
        if self.selected ~= i then table.insert(ripples[self][i],0) end
        self.selected = i
        has_already_selected = true
      end
    end
    if not has_already_selected then self.selected = 0 end
  end
  local function draw(self)
    if not self.visible then return end
    local line_width = lg.getLineWidth()
    lg.setFont(FONT_[1])
    for i,v in pairs(labels) do
      local bg, fg = self.cols.bg[1], self.cols.fg[1]
      if self.selected==i then bg, fg = self.cols.bg[2], self.cols.fg[2] end
      if self.button_down==i then bg, fg = self.cols.bg[3], self.cols.fg[3] end

      lg.setColor(bg[1],bg[2],bg[3],bg[4]*self.alpha)
      lg.rectangle("fill",xs[i],self.y,w,self.h,6,6)
      lg.setColor(0,0,0,bg[4]*self.alpha)
      lg.rectangle("line",xs[i],self.y,w,self.h,6,6)
      lg.setColor(fg[1],fg[2],fg[3],fg[4]*self.alpha)
      lg.printf(v,xs[i]+45,self.y+self.h/2-FONT_[1]:getHeight(v)/2,w-50,"center")
      lg.setColor(0,0,0,bg[4]*3*self.alpha)
      lg.rectangle("fill",xs[i]+12,self.y+11,25,25,5,5)
      lg.setColor(1,1,1,bg[4]/2*self.alpha)
      lg.rectangle("line",xs[i]+12,self.y+11,25,25,5,5)

      if ripples[self] and ripples[self][i] and not no_ripple then
        for r,v in pairs(ripples[self][i]) do
          lg.setColor(1,1,1,0.5*(1-v/ripple_size_limit)*self.alpha)
          lg.rectangle("line",xs[i]-v,self.y-v,self.w+v*2,self.h+v*2,6,6)
        end
      end

      if not value then
        if tabl[v]==1 then
          lg.setColor(1,0.3,0.4,self.alpha)
          lg.draw(check,xs[i]+16,self.y+3)
        end
      else
        if tabl[value]==i then
          lg.setColor(1,0.3,0.4,self.alpha)
          lg.draw(check,xs[i]+16,self.y+3)
        end
      end

    end
    lg.setLineWidth(line_width)
  end
  local function mousepressed(self,x,y,b,xo,yo)
    if not self.visible then return end
    self.button_down = false
    if b~=1 then return end
    for i,v in pairs(labels) do
      local xx, yy = xs[i] + (xo or 0), self.y + (yo or 0)
      if Misc.checkPoint(x,y, xx, yy, w, self.h) then
        self.button_down = i
        return true
      end
    end
  end
  local function mousereleased(self,x,y,b,xo,yo)
    if not self.visible then return end
    if b~=1 then return end
    for i,v in pairs(labels) do
      local xx, yy = xs[i] + (xo or 0), self.y + (yo or 0)
      if Misc.checkPoint(x,y, xx, yy, w, self.h) and self.button_down == i then
        self.button_down = 0

        if not value then
          if tabl[v] == 1 then
            if not self.no_blank then tabl[v] = 0 end
          else
            tabl[v] = 1
          end
        else
          if tabl[value] == i then
            if not self.no_blank then tabl[value] = 0 end
          else
            tabl[value] = i
          end
        end
        
        self:value_set()

        return true
      end
    end
    self.button_down = 0
  end
  local function value_set(self) end

  return {
    labels=labels,x=math.floor(x),y=math.floor(y),w=w,h=h,selected=0,no_blank=no_blank,cols=cols,value=value,alpha=alpha,visible=visible,
    value_set=value_set,update=update,draw=draw,mousepressed=mousepressed,mousereleased=mousereleased
  }
end
--

return new
