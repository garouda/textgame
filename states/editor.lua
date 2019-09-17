local st = {}

local FONT_ = {
  fonts.game_maintext,
}

st.input = require("editor_input")
st.browser = require("editor_browser")

local newDropdown = require("elements.dropdown")
local newScroller = require("elements.scroller")

st.keyboard_focus = 0

local buttons = {}
local page_buttons = {}
local new_page_button = {}
local held_page
local held_page_movement = 0
local dropdowns = {}
st.flux = Flux.group()
local base_font = lg.newFont()

local scene
local page

st.header_area = {
  x = 0,
  y = 0,
  w = screen_width,
  h = screen_height/15
}
local header_img = {
  new = love.graphics.newImage("res/img/editor_headernew.png"),
  open = love.graphics.newImage("res/img/editor_headeropen.png"),
  save = love.graphics.newImage("res/img/editor_headersave.png"),
}
--

st.text_area = {
--  w = screen_width/1.15,
  w = screen_width/1.33,
  h = FONT_[1]:getHeight()*10+15,
}
--st.text_area.x = screen_width/2-st.text_area.w/2
st.text_area.x = 30
st.text_area.y = st.header_area.y+st.header_area.h+15
--
local cursor_alpha = 1
local old_page_height = 0
event.wish("editor_pageheight_changed", function(height)
    st.scroller:setMax(height-st.text_area.h)
  end)
--

local function init_autocomplete()
  st.keyboard_focus = 0
  local replace_list = __.keys(process.getReplacementList(player))
  table.sort(replace_list)
  
  local commands = require("res.commands")
  local command_list = {}
  for _,v in pairs(commands._get_sorted_list()) do
    for i,v in pairs(v) do
      table.insert(command_list,i)
    end
  end
  table.sort(command_list)

  local function selectButton(list,index)
    local dd = st.autocomplete[st.autocomplete.active.."_dropdown"]
    for i,v in pairs(list) do
      if i == index then
        if v.key_selected then return end
        v.key_selected = true
        local diff1 = ((v.y+v.h)-(dd.y+8)-dd.scroller.y_offset_target) - (dd.h-(8*2))
        local diff2 = (v.y)-(dd.y+8*2) - dd.scroller.y_offset_target
        local diff = 0
        if diff1 > 0 then diff = diff1 elseif diff2 < 0 then diff = diff2 end
        dd.scroller:moveTo(dd.scroller.y_offset_target+diff)
      else
        v.key_selected = false
        v.selected = false
      end
    end
  end
--
  local function getSelectedButton(list)
--  if lerping then return nil end
    for i,v in pairs(list) do
      if v.selected then return i end
    end
    return nil
  end
--

  st.autocomplete = {
    replace_orig_list = replace_list,
    command_orig_list = command_list,
    replace_dropdown = newDropdown(replace_list, function(i,v) return st.input.insert_text(v) end, {instant=true, noclamp=true, alpha=0.5}),
    command_dropdown = newDropdown(command_list, function(i,v) return st.input.insert_text(v) end, {instant=true, noclamp=true, alpha=0.5}),
    active = nil,
    update = function(self,dt)
      if not self.active then return end
      selectButton(self[self.active.."_dropdown"].list, st.keyboard_focus)
      self[self.active.."_dropdown"]:update(dt)
      if self[self.active.."_dropdown"].visible then return true end
    end,
    draw = function(self)
      if not self.active then return end
      self[self.active.."_dropdown"]:draw()
      if self[self.active.."_dropdown"].visible then return true end
    end,
    keypressed = function(self,key)
      if not self.active then return end
      if not self[self.active.."_dropdown"].visible then return end
      local selected = getSelectedButton(self[self.active.."_dropdown"].list) or st.keyboard_focus
      if __.any({"backspace", "left", "right", "escape"}, function(_,v) return key==v end) then
        self[self.active.."_dropdown"]:close()
        self[self.active.."_dropdown"].filter = nil
        return true
      elseif key== "up" then
        st.keyboard_focus = math.max(1, selected - 1)
        return true
      elseif key=="down" then
        st.keyboard_focus = math.min(selected + 1, #self[self.active.."_dropdown"].list)
        return true
      elseif (key=="tab" or key=="return") and self[self.active.."_dropdown"].list[st.keyboard_focus] then
        self[self.active.."_dropdown"].list[st.keyboard_focus]:func()
        self[self.active.."_dropdown"]:close()
        self[self.active.."_dropdown"].filter = nil
        return true
      elseif key=="pageup" then
        self:wheelmoved(0,1)
        return true
      elseif key=="pagedown" then
        self:wheelmoved(0,-1)
        return true
      end
    end,
    mousepressed = function(self,x,y,b)
      if not self.active then return end
      if self[self.active.."_dropdown"]:mousepressed(x,y,b) then return true end
      self[self.active.."_dropdown"]:close()
      self[self.active.."_dropdown"].filter = nil
    end,
    mousereleased = function(self,x,y,b)
      if not self.active then return end
      if self[self.active.."_dropdown"]:mousereleased(x,y,b) then return true end
    end,
    wheelmoved = function(self,x,y)
      if not self.active then return end
      if self[self.active.."_dropdown"]:wheelmoved(x,y) then return true end
    end,
  }
end
--

local function init_ui_reactors()
  -- Dropdowns
  local commands = require("res.commands")
  local command_list = commands._get_sorted_list()

  local dropdownfunc = function(i,v) return st.input.insert_text("@"..v.."()") end
  for i,v in pairs(command_list) do
    local keys = __.keys(v)
    table.sort(keys)
    dropdowns["c_"..i] = newDropdown(keys, dropdownfunc)
  end

  local top_keys = __.keys(command_list)
  table.sort(top_keys)
  dropdowns.c = newDropdown(top_keys, function(i,v) return dropdowns["c_"..v]:open(dropdowns.c.x+dropdowns.c.w/2,dropdowns.c.y) end)

  -- Buttons
  local hx = st.header_area.x+15
  local function getX(w)
    local x = hx
    hx = hx + w + 20
    return x
  end
  local sw = (screen_width-20)-(st.text_area.x+st.text_area.w+20)
  local sh = 50
  local sy = st.text_area.y
  local function getY(h)
    local y = sy
    sy = sy + (h or sh) + 15
    return y
  end
  ---- Sidebar
  table.insert(buttons, newButton("Commands", function() dropdowns.c:open(Misc.getMouseScaled()) end, st.text_area.x+st.text_area.w+15, getY(), sw, sh))
  table.insert(buttons, newButton("Backgrounds", function()
        st.browser.open("res/img/backgrounds",1,scene,true)
      end, st.text_area.x+st.text_area.w+15, getY(), sw, sh))
  table.insert(buttons, newButton("Icons", function()
        st.browser.open("res/img/icons",1,scene,true)
      end, st.text_area.x+st.text_area.w+15, getY(), sw, sh))
  table.insert(buttons, newButton("Play", function()
        local name = scene.filename:match("^(.-).txt") or ""
        local path = scene.filepath .."/".. name
        if name and path:match("^res/text/scenes") then
          Misc.fade(function() Gamestate.pop() out.change(path:match("^res/text/scenes/(.+)")) end, 0.3)
        else
          notify{"white", "The scene must be saved somewhere in ", "pink", "res/text/scenes/", "white", " to play it."}
        end
      end, st.text_area.x+st.text_area.w+15, getY(), sw, sh))
  table.insert(buttons, newButton("Exit", function()
      end, screen_width-sw-15, screen_height-sh-15, sw, sh))
  ---- Header
  table.insert(buttons, newButton(header_img.new, function() st.clear_scene() end, getX(header_img.new:getWidth()), st.header_area.y+st.header_area.h/2-header_img.new:getHeight()/2, nil, nil, {header=true}))
  table.insert(buttons, newButton(header_img.open, function() st.browser.open(scene.filepath,1,scene) end, getX(header_img.open:getWidth()), st.header_area.y+st.header_area.h/2-header_img.open:getHeight()/2, nil, nil, {header=true}))
  table.insert(buttons, newButton(header_img.save, function() st.browser.open(scene.filepath,2,scene) end, getX(header_img.save:getWidth()), st.header_area.y+st.header_area.h/2-header_img.save:getHeight()/2, nil, nil, {header=true}))

  new_page_button = newButton(love.graphics.newImage("res/img/editor_newpage.png"), function() end, 0, 0)

  st.scroller = newScroller(0, 0, 0, st.text_area.x+st.text_area.w-15, st.text_area.y+15, st.text_area.h-30)
  st.panner = newScroller(0, 0, 0, 0, 0, st.text_area.w-30)

  init_autocomplete()
end
--

local function drawHeader()
  s, p = s or scene, p or page
  if not s[p] or not next(s[p].text) then return end

  lg.setFont(base_font)
  lg.stencil(function() lg.rectangle("fill", st.header_area.x, st.header_area.y, st.header_area.w, st.header_area.h) end, "replace", 1)

  lg.setColor(0,0,0,0.75)
  lg.rectangle("fill", st.header_area.x, st.header_area.y, st.header_area.w, st.header_area.h)
  lg.setColor(1,1,1,0.15)
  lg.rectangle("fill", st.header_area.x, st.header_area.y+st.header_area.h, st.header_area.w, 2)

  lg.setStencilTest("equal",1)
  lg.setFont(base_font)
  lg.setColor(1,1,1)
  lg.printf(scene.filepath..(#scene.filepath>0 and "/" or "")..scene.filename, st.header_area.x, st.header_area.y+st.header_area.h/2-base_font:getHeight()/2, st.header_area.w-15, "right")
  lg.setStencilTest()
end
--

local function drawPage(s,p)
  s, p = s or scene, p or page
  if not s[p] or not next(s[p].text) then return end

  lg.setFont(FONT_[1])
  lg.stencil(function() lg.rectangle("fill", st.text_area.x, st.text_area.y, st.text_area.w, st.text_area.h, 10, 10) end, "replace", 1)

  lg.push()
  lg.translate(0, st.scroller.y_offset)

  lg.setStencilTest("equal",1)
  local x = st.text_area.x+15
  local y = st.text_area.y+15
  local h = FONT_[1]:getHeight()

  local _, row_highlight_y = st.input.getXY(0,s[p].row)
  lg.setColor(1,1,1,0.1)
  lg.rectangle("fill", st.text_area.x, row_highlight_y, st.text_area.w, h*#s[p].wrapped[s[p].row])

  for i=1,#s[p].wrapped do
    lg.setColor(1,1,1)
    for ii=1,math.max(1, #(s[p].wrapped[i] or {})) do
      local v = (s[p].wrapped[i] or {})[ii] or ""
      if (y+st.scroller.y_offset) < (st.text_area.y+st.text_area.h) and (y+h+st.scroller.y_offset) > (st.text_area.y) then
        lg.print(v,x,y)
      end
      y = y+h
    end
  end
  if y ~= old_page_height then old_page_height = y event.grant("editor_pageheight_changed", y) end

  local cursor_x, cursor_y = s[p].cursor_xy.x or 0, s[p].cursor_xy.y or 0
  lg.setColor(1,1,1,math.round(cursor_alpha))
  lg.line(cursor_x, cursor_y+5, cursor_x, cursor_y+(FONT_[1]:getHeight()-3))
  lg.setStencilTest()

  if s[p].selecting then
    local x1,y1,w1 = st.input.getXY(s[p].selecting.s.col, s[p].selecting.s.row)
    local x2,y2,w2 = st.input.getXY(s[p].selecting.e.col, s[p].selecting.e.row)
    if x1 and x2 and y1 and y2 then
      local min_y, max_y = math.min(y1,y2), math.max(y1,y2)
      lg.setStencilTest("equal",1)
      for y = min_y, max_y, FONT_[1]:getHeight() do
        local w = x2-x1
        local x = x1
        if (y+st.scroller.y_offset) < (st.text_area.y+st.text_area.h) and (y+FONT_[1]:getHeight()+st.scroller.y_offset) > (st.text_area.y) then
          if y~=y1 and y~=y2 then
            x = st.text_area.x+15
            w = (st.text_area.w-30)
          else
            if y==y2 then
              if y1<y2 then
                x = st.text_area.x+15
                w = x2 - (st.text_area.x+15)
              elseif y1>y2 then
                x = x2
                w = (st.text_area.x+15+st.text_area.w-30) - x2
              end
            elseif y==y1 then
              if y1<y2 then
                x = x1
                w = (st.text_area.x+15+st.text_area.w-30) - x1
              elseif y1>y2 then
                x = st.text_area.x+15
                w = x1 - (st.text_area.x+15)
              end
            end
          end
          lg.setColor(1,0.9,0.3,0.3)
          lg.rectangle("fill",x,y,w,FONT_[1]:getHeight())
        end
      end
      lg.setStencilTest()
    end
  end

  lg.pop()
end
--
local function create_thumbnail(s,p)
--  local factor = 6
  local factor = st.text_area.h/((screen_height-15)-(st.text_area.y+st.text_area.h+15))
  local w, h = st.text_area.w/factor, st.text_area.h/factor
  local x, y = 15/factor, 15/factor
  local canv = lg.newCanvas(w,h)
  lg.setCanvas({canv,stencil=true})
  local sx, sy = Misc.toGame()
  lg.push() lg.scale(1/sx, 1/sy)
  lg.stencil(function() lg.rectangle("fill",x+2,y+2,w-8,h-8) end, "replace", 1)
  lg.setColor(0,0,0,0.55)
  lg.rectangle("fill", x, y, w, h)
  lg.setColor(1,1,1)
  lg.rectangle("line", x, y, w-4, h-4)
  lg.setStencilTest("equal", 1)
  local yy = y
  for i,v in pairs(s[p].wrapped) do
    for i=1,math.max(1,#v) do
      local vrow = v[i] or ""
      local ww = FONT_[1]:getWidth(vrow)/factor
      lg.setColor(1,1,1,0.85)
      lg.rectangle("fill", x, yy, ww, FONT_[1]:getHeight()/factor)
      yy = yy + FONT_[1]:getHeight()/factor
    end
  end
  lg.setFont(FONT_[1])
  local x, y = x+w/2-FONT_[1]:getWidth(p)/2, y+h/2-FONT_[1]:getHeight()/2-4

  for o=-1,1,2 do
    for m=1,3 do
      local o = o*m
      lg.setColor(0,0,0,0.75/m)
      lg.print(p, x+o, y)
      lg.print(p, x, y+o)
    end
  end
  lg.setColor(1,1,1)
  lg.print(p, x, y)

  lg.setStencilTest()
  lg.pop()
  lg.setCanvas()
  return lg.newImage(canv:newImageData())
end
--

event.wish("editor_input_threshold", function() if not page_buttons[page] then return end page_buttons[page].label = create_thumbnail(scene,page) end)

function st.pageflip(dir) return st.setpage(page + (dir or 1)) end
function st.setpage(p)
  page = math.clamp(1, p, #scene)
  if page_buttons[page] then
    st.panner:moveTo(page_buttons[page].x-st.text_area.x-(st.text_area.w/2-page_buttons[page].w/2))
  end
  return page
end
function st.clear_scene(text)
  scene = {
    filepath = "",
    filename = "Untitled"
  }
  page = 1
  page_buttons = {}
  st.new_page(1,text)
  return scene, page
end
--
function st.new_page(ind,text)
  ind = ind or page+1
  table.insert(scene, ind, {text=text or {""}, row=1, vrow=1, subrow=1, cursor=0, cursor_xy={x=0,y=0}, selecting=nil, wrapped={}, history={}, commands={}})
  setmetatable(scene[ind].text, { __index = function() return "" end})
  setmetatable(scene[ind].wrapped, { __index = function() return setmetatable({}, { __index = function() return "" end}) end})
  st.setpage(ind)
  st.input.add_history()
  st.input.set_cursor(0)
  st.input.update_wrapped()

  local thumb = create_thumbnail(scene,page)
  table.insert(page_buttons, ind, newButton(thumb, {function() st.setpage(ind) end, function() st.remove_page(ind) end}, (st.text_area.x+new_page_button.label:getWidth()) + (thumb:getWidth()+30) * (ind-1), st.text_area.y+st.text_area.h+15, thumb:getWidth(), thumb:getHeight()))
  local max_x = (st.text_area.x+new_page_button.label:getWidth()) + (thumb:getWidth()+30) * (#page_buttons-1)
  st.panner:setMax(max_x+thumb:getWidth() - st.text_area.w - st.text_area.x + new_page_button.label:getWidth())

  if ind < #page_buttons then
    for i=ind+1,#page_buttons do
      local v = page_buttons[i]
      v.label = create_thumbnail(scene,i)
      v.func = function() st.setpage(i) end
      v.func_r = function() st.remove_page(i) end
    end
  end

  st.panner:moveTo(page_buttons[ind].x-st.text_area.x-(st.text_area.w/2-page_buttons[ind].w/2))

  return page
end
--
function st.remove_page(ind,silent)
  local function delete()
    table.remove(scene, ind)
    table.remove(page_buttons, ind)

    if #scene==0 then st.new_page(1) end

    local max_x = (st.text_area.x+new_page_button.label:getWidth()) + (page_buttons[1].label:getWidth()+30) * (#page_buttons-1)
    st.panner:setMax(max_x+page_buttons[1].label:getWidth() - st.text_area.w - st.text_area.x + new_page_button.label:getWidth())

    if ind < #page_buttons+1 then
      for i=ind,#page_buttons do
        local v = page_buttons[i]
        v.label = create_thumbnail(scene,i)
        v.func = function() st.setpage(i) end
        v.func_r = function() st.remove_page(i) end
      end
    end

    page = math.clamp(1, page, #scene)
  end

  if not silent and (#scene[ind].text>1 or scene[ind].text[1]~="") then
    prompt("Delete page #"..ind.."?",{delete},nil,"Confirm Delete")
  else
    delete()
  end
end
--

function st:share_locals() return scene, page end
--
function st:init()
  init_ui_reactors()
  st.clear_scene()
end
--
function st:enter()
  local path = "res/text/scenes/"..out.to..".txt"
  input.close()
  choices.close()
  if scene.filepath and scene.filepath.."/"..scene.filename == path then return end
  st.clear_scene(st.input.import(path))
end
--
function st:update(dt)
  input.update(dt)
  cursor_alpha = (cursor_alpha + 1.5 * dt) % 1
  local freeze_button_update
  for i,v in pairs(dropdowns) do
    v:update(dt)
    freeze_button_update = freeze_button_update or v.visible
  end
  if not freeze_button_update then
    for i,v in pairs(buttons) do
      v:update(dt)
    end
  end
  new_page_button.x = -new_page_button.label:getWidth()
  new_page_button.y = -new_page_button.label:getHeight()
  
  local mx,my = Misc.getMouseScaled()
  mx = mx - st.panner.y_offset
  -- Before 1st page
  if page_buttons[1] then
    local v = page_buttons[1]
    if mx < v.x and mx > v.x-30 and my > v.y and my < v.y+v.h then
      new_page_button.x = v.x-30
      new_page_button.y = v.y+v.h/2-new_page_button.label:getHeight()/2
      new_page_button.func = function() st.new_page(1) end
      new_page_button._INDEX = 1
    end
  end
  -- After each page
  for i,v in pairs(page_buttons) do
    v.x = Misc.lerp(10*dt, v.x, (st.text_area.x+new_page_button.label:getWidth()) + (v.w+30) * (i-1))
    v:update(dt,st.panner.y_offset)
    if mx > v.x+v.w and mx < v.x+v.w+30 and my > v.y and my < v.y+v.h then
      new_page_button.x = v.x+v.w
      new_page_button.y = v.y+v.h/2-new_page_button.label:getHeight()/2
      new_page_button.func = function() st.new_page(i+1) end
      new_page_button._INDEX = i+1
    end
  end
  new_page_button:update(dt,st.panner.y_offset)

  st.autocomplete:update(dt)

  st.scroller:update(dt)
  st.panner:update(dt)

  st.browser.update(dt)
  st.input.update(dt)
end
--
function st:draw()
  lg.push() lg.translate(st.text_area.x, st.text_area.y)
  lg.setColor(0,0,0,0.55)
  lg.rectangle("fill", 0, 0, st.text_area.w, st.text_area.h, 10, 10)
  lg.rectangle("line", -2, -2, st.text_area.w+4, st.text_area.h+4, 10, 10)
  lg.setColor(1,1,1,1/3)
  lg.rectangle("line", -1, -1, st.text_area.w+2, st.text_area.h+2, 10, 10)
  lg.pop()

  drawPage()
  drawHeader()
  st.scroller:draw()
  for i,v in pairs(buttons) do
    v:draw()
  end

  lg.stencil(function() lg.rectangle("fill",st.text_area.x, page_buttons[1].y, st.text_area.w, page_buttons[1].h) end, "replace", 1)
  lg.setStencilTest("equal",1)
  lg.push() lg.translate(st.panner.y_offset,0)
  for i,v in pairs(page_buttons) do
    if (v.x+v.w) + st.panner.y_offset >= st.text_area.x and v.x + st.panner.y_offset < st.text_area.x+st.text_area.w then
      v:draw(nil,i==page and 1.5 or 0.5)
    end
  end
  new_page_button:draw()
  lg.pop()
  lg.setStencilTest()

  if held_page and held_page_movement >= 10 then
    local mx, my = Misc.getMouseScaled()
    lg.push()
    lg.translate(-page_buttons[held_page].x + mx - page_buttons[held_page].w/2,-page_buttons[held_page].y + my - page_buttons[held_page].h/2)
    page_buttons[held_page]:draw(nil,1.5)
    lg.pop()
  end

  st.autocomplete:draw()

  for i,v in pairs(dropdowns) do v:draw() end
  st.browser.draw()
  input.draw()
end
--
function st:keypressed(key)
  if input.keypressed(key) or input.box.visible then return end
  if st.browser.keypressed(key) then return end
  if st.autocomplete:keypressed(key) then return end
  cursor_alpha = 0.5
  st.scroller:keypressed(key)
  st.input.keypressed(key)
  if keyset.editor(key) then return Misc.fade(function() Gamestate.pop() end, 0.3) end
end
--
function st:mousepressed(x,y,b,t)
  held_page = nil
  held_page_movement = 0
  if input.mousepressed(x,y,b,t) or input.box.visible then return end
  if st.browser.mousepressed(x,y,b) then return end
  if st.autocomplete:mousepressed(x,y,b) then return end
  cursor_alpha = 0.5
  local return_after_dropdowns
  for i,v in pairs(dropdowns) do
    if v:mousepressed(x,y,b) then return end
    if v.visible then v:close() return_after_dropdowns = true end
  end
  if return_after_dropdowns then return end
  for i,v in pairs(buttons) do if v:mousepressed(x,y,b) then return end end
  if Misc.checkPoint(x,y,{st.text_area.x,page_buttons[1].y,st.text_area.w,page_buttons[1].h}) then
    for i,v in pairs(page_buttons) do
      if v:mousepressed(x,y,b,st.panner.y_offset) then 
        held_page = i
        return
      end
    end
    if new_page_button:mousepressed(x,y,b,st.panner.y_offset) then return end
  end
  st.input.mousepressed(x,y,b,st.scroller.y_offset)
end
--
function st:mousereleased(x,y,b,t)
  if input.mousereleased(x,y,b,t) or input.box.visible then return end
  if st.browser.mousereleased(x,y,b) then return end
  if st.autocomplete:mousereleased(x,y,b) then return end
  for i,v in pairs(buttons) do v:mousereleased(x,y,b) end
  for i,v in pairs(page_buttons) do
    if v:mousereleased(x,y,b,st.panner.y_offset) and held_page and held_page~=i then
      local i_text = Misc.tcopy(scene[i].text)
      local h_text = Misc.tcopy(scene[held_page].text)
      st.remove_page(i,true)
      st.new_page(i, h_text)
      st.remove_page(held_page,true)
      st.new_page(held_page, i_text)
      st.setpage(i)
    end
  end
  if held_page and new_page_button.x > 0 and held_page~=new_page_button._INDEX then
    st.new_page(new_page_button._INDEX,scene[held_page].text)
    if new_page_button._INDEX < held_page then held_page = held_page + 1 end
    st.remove_page(held_page,true)
    if new_page_button._INDEX >= held_page then st.setpage(new_page_button._INDEX-1) end
  end
  new_page_button:mousereleased(x,y,b,st.panner.y_offset)
  for i,v in pairs(dropdowns) do v:mousereleased(x,y,b) end
  st.input.mousereleased(x,y,b)
  held_page = nil
  held_page_movement = 0
end
--
function st:mousemoved(x,y,dx,dy)
  st.input.mousemoved(x,y,dx,dy)
  if held_page then held_page_movement = held_page_movement + (math.abs(dx) + math.abs(dy)) end
end
--
function st:wheelmoved(x,y)
  if st.browser.wheelmoved(x,y) then return end
  if st.autocomplete:wheelmoved(x,y) then return end
  local return_after_dropdowns
  for i,v in pairs(dropdowns) do if v:wheelmoved(x,y) then return_after_dropdowns = true end end
  if return_after_dropdowns then return end

  local mx, my = Misc.getMouseScaled()
  if Misc.checkPoint(mx,my,st.text_area) then st.scroller:wheelmoved(x,y) end
  if Misc.checkPoint(mx,my,{st.text_area.x,page_buttons[1].y,st.text_area.w,page_buttons[1].h}) then st.panner:wheelmoved(x,y) end
end
--
function st:touchmoved(id,x,y,dx,dy)
  if st.browser.touchmoved(id,x,y,dx,dy) then return end
  local return_after_dropdowns
  for i,v in pairs(dropdowns) do if v:touchmoved(id,x,y,dx,dy) then return_after_dropdowns = true end end
  if return_after_dropdowns then return end
end
--
function st:textinput(text)
  if input.textinput(st.browser.box.visible and (text:match("([^%?%\"%\\:%*<>|]+)") or "") or text) then return end
  if st.browser.box.visible or prompt.box.visible then return end
  return st.input.textinput(text)
end
--
function st:leave()
end
--

return st