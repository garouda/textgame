local ripples = {}
local ripple_size_limit = 10

local function new(label,func,x,y,w,h,p)
  label = label or "???"
  local param = p or {}
  for i,v in pairs({
      font = fonts.element,
      movable = nil,
      no_ripple = nil,
      rep = nil,
      tip = nil,
      tip_timer = 0.75,
      tip_args = {},
      held_func = nil,
      inactive = false,
      visible = nil,
      no_bg = false,
      mobile_friendly = false,
      mouse_on = function() end,
      mouse_off = function() end,
      alpha = 1,
      target_alpha = 1,
      alpha_speed = 1,
      cols = {
        bg = {
          --Default
          {1,1,1,0.15},
          --Hovered
          {1,1,1,0.25},
          --Pressed
          {0.03,0.12,0.1,0.3},
        },
        fg = {
          --Default
          {1,1,1,0.75},
          --Hovered
          {1,1,1},
          --Pressed
          {1,1,1,0.4},
        },
      },
      inactive_cols = {
        bg = {
          --Default
          {0.2,0.2,0.2,0.25},
          --Hovered
          {0.2,0.2,0.2,0.25},
          --Pressed
          {0.2,0.2,0.2,0.25},
        },
        fg = {
          --Default
          {1,1,1,0.3},
          --Hovered
          {1,1,1,0.3},
          --Pressed
          {1,1,1,0.3},
        },
      },
      }) do
    if param[i]==nil then param[i] = v end
  end
  if param.visible==nil then param.visible = true end

  local ow, oh = w, h

  local func_r = function() end
  if type(func)=="table" then
    func_r = func[2] or func_r
    func = func[1]
  end
  func = func or function() end 

  if type(label)=="string" then
    w = w or param.font:getWidth(label)*1.75
    h = h or param.font:getHeight()+16
  else
    h = h or w or label:getHeight()
    w = w or label:getWidth()
  end

  x,y = math.floor(x), math.floor(y)

  local mouse_x, mouse_y = nil, nil
  local held_time = 0
  local hover_time = 0
  local mvtotal = 0
  local mvlimit = math.max(10, math.min(h,w)*0.75)
  local key_selected = false
  local mobile_selected_check

  local function set_label(self,s)
    self.label = s
    self.w = ow or param.font:getWidth(s)*1.75
    self.h = oh or param.font:getHeight()+16
  end

  local function ripple_update(self,dt)
    for i,v in pairs(ripples[self]) do
      ripples[self][i] = ripples[self][i] + ripple_size_limit * dt
      if ripples[self][i] >= ripple_size_limit then ripples[self][i] = nil end
      if #ripples[self] == 0 and (self.selected or self.key_selected) then ripples[self][i] = 0 end
    end
  end

  local selected_on_prev_frame

  local function set_mouse_coords(self,mx,my)
    mouse_x, mouse_y = mx, my
  end

  local function update(self,dt,x,y)
    if not ripples[self] then ripples[self] = {} end
    local xx,yy = self.x+(x or 0), self.y+(y or 0)
    local mx, my = Misc.getMouseScaled()
    mx, my = mouse_x or mx, mouse_y or my
    if self.param.inactive then ripple_update(self,dt) self.selected = false self.button_down = false return end
    if Misc.checkPoint(mx,my, xx,yy,self.w,self.h)
    and (not Gamestate.current().keyboard_focus or Gamestate.current().keyboard_focus == 0) then
      if not self.selected then self.param.mouse_on() end
      self.selected = true
      hover_time = hover_time + dt
    elseif not self.key_selected then
      if self.selected then self.param.mouse_off() end
      self.selected = false
      hover_time = 0
    end

    if not selected_on_prev_frame and (self.selected or self.key_selected) then table.insert(ripples[self],0) end

    ripple_update(self,dt)

    self.param.alpha = Misc.lerp(self.param.alpha_speed*dt, self.param.alpha, self.param.target_alpha)

    if not love.mouse.isDown(1) and not love.mouse.isDown(2) then self.button_down = false
    elseif self.selected or self.held_time >=0.75 then
      hover_time = 0
      self.held_time = self.held_time + 1 * dt
      if self.held_time >= 0.75 then
        if self.param.movable then
          if not self.coord_offset then self.coord_offset = {x=mx-self.x, y=my-self.y} end
          self.x = math.clamp(0, mx-self.coord_offset.x, screen_width-self.w)
          self.y = math.clamp(0, my-self.coord_offset.y, screen_height-self.h)
        elseif self.param.rep and self.param.held_func then
          self.param.held_func()
          self.held_time = 0.7
        elseif self.param.held_func then
          self.param.held_func()
          self.button_down = false
          self.held_time = 0
        end
      end
    elseif self.held_time < 0.75 then
      self.held_time = 0
    end
    if self.key_selected then self.selected = true end
    selected_on_prev_frame = self.selected
    if self.param.tip then
      self.param.tip_args.id = self.param.tip_args.id or self
      if hover_time > self.param.tip_timer then event.grant("show_tooltip", self.param.tip, self.param.tip_args) end
    end
  end
  local function draw(self,c,alpha)
    if not self.param.visible then return end
    local line_width = lg.getLineWidth()

    if self.param.inactive then c = c or self.param.inactive_cols end

    lg.setFont(self.param.font)
    local cols = Misc.tcopy(c or self.param.cols)
    local active_col = 1
    if self.selected then active_col=2 end
    if self.button_down then active_col=3 end

    cols.fg[active_col][4] = (cols.fg[active_col][4] or 1)*(alpha or self.param.alpha)
    if cols.bg then cols.bg[active_col][4] = (cols.bg[active_col][4] or 1)*(alpha or self.param.alpha) end

    if type(label)=="string" then
      if not self.param.no_bg then
        lg.setColor(cols.bg[active_col])
        lg.rectangle("fill",self.x+1,self.y+1,self.w-2,self.h-2,6,6)
        lg.setColor(0,0,0,cols.bg[active_col][4])
        lg.rectangle("line",self.x,self.y,self.w,self.h,6,6)
        lg.setColor(cols.bg[active_col])
        lg.rectangle("line",self.x-1,self.y-1,self.w+2,self.h+2,6,6)
      end
      lg.setColor(cols.fg[active_col])
--      lg.setColor(1,1,1)
      lg.print(self.label, self.x + self.w/2 - self.param.font:getWidth(self.label)/2, self.y+self.h/2-self.param.font:getHeight(self.label)/2)
--      lg.print(cols.fg[active_col][4], self.x + self.w/2 - self.param.font:getWidth(self.label)/2, self.y+self.h/2-self.param.font:getHeight(self.label)/2-2)
      lg.setLineWidth(1)

      if ripples[self] and not self.param.no_ripple and not self.param.no_bg then
        for i,v in pairs(ripples[self]) do
          lg.setColor(1,1,1,0.5*(1-v/ripple_size_limit))
          lg.rectangle("line",self.x-v,self.y-v,self.w+v*2,self.h+v*2,6,6)
        end
      end
    else
      lg.setColor(cols.fg[active_col])
      lg.draw(self.label,self.x,self.y,nil,w/self.label:getWidth(),h/self.label:getHeight())
    end
    if self.held_time > 1 and self.param.movable then
      lg.setColor(1,1,0,1)
      lg.setLineWidth(3)
      lg.rectangle("line",self.x,self.y,self.w,self.h)
    end
    lg.setLineWidth(line_width)
  end
  local function mousepressed(self,x,y,b,xo,yo)
    if self.param.inactive then return end
    self.button_down = false
    self.held_time = 0
    self.mvtotal = 0
    local xx, yy = self.x + (xo or 0), self.y + (yo or 0)
    if Misc.checkPoint(x,y, xx, yy, self.w, self.h) then
      self.button_down = true
      return true
    end
  end
  local function mousereleased(self,x,y,b,xo,yo)
    if self.param.inactive then return end
    local xx, yy = self.x + (xo or 0), self.y + (yo or 0)
    if Misc.checkPoint(x,y, xx, yy, self.w, self.h) then
      if self.button_down then
        if mobile_selected_check or not self.param.mobile_friendly or love.system.getOS()~="Android" then
          if b==1 and (not self.param.movable or self.held_time < 1) and self.mvtotal<=mvlimit then self.func() end
          if b==2 and (not self.param.movable or self.held_time < 1) and self.mvtotal<=mvlimit then self.func_r() end
        end
        self.button_down = false
        self.held_time = 0
        self.mvtotal = 0
        self.coord_offset = nil
        if self.param.mobile_friendly then mobile_selected_check = true end
      end
      return true
    end
    mobile_selected_check = false
    self.button_down = false
  end
  local function touchmoved(self,id,x,y,dx,dy)
    self.mvtotal = self.mvtotal + math.abs(dx)+math.abs(dy)
  end

  local button = {
    label=label,func=func,func_r=func_r,x=x,y=y,w=w,h=h,held_time=held_time,mvtotal=mvtotal,coord_offset=nil,selected=false,key_selected=false,param=param,
    update=update,draw=draw,mousepressed=mousepressed,mousereleased=mousereleased,touchmoved=touchmoved,set_label=set_label,set_mouse_coords=set_mouse_coords
  }
  setmetatable(button, {__index = function(_,i) return rawget(button.param, i) end})

  return button
end
--

return new
