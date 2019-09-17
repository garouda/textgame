local br = {}

local newScroller = require("elements.scroller")
local scroller
local selected
local mode

local folder_img = lg.newImage("res/img/browser_folder.png")
local file_img = lg.newImage("res/img/browser_file.png")
local newfile_img = lg.newImage("res/img/browser_newfile.png")

local function _action(v)
  local funcs = {
    function()
      if v.type==2 then
        br.open(v.filepath,mode)
      else
        if v.filename:match("%.jpg$") or v.filename:match("%.png$") then
          Gamestate.push(states.image,lg.newImage(v.filepath))
        elseif v.filename:match("%.txt$") then
          states.editor.input.import(v.filepath)
          br.close()
        end
      end
    end,
    function()
      if v.type==2 then
        br.open(v.filepath,mode)
      elseif v.type==3 then
        input.show("Name your new file.",nil,nil,function(filename) if states.editor.input.export(br.directory.."/"..filename) then br.close() end end)
      else
        if states.editor.input.export(v.filepath) then br.close() end
        if states.editor.input.export(v.filepath) then br.close() end
      end
    end,
  }
  funcs[mode]()
end
--

local FONT_ = {
  fonts.prompt,
  fonts.debug
}

br.box = {
  visible = false,
  w = screen_width*0.5,
  h = screen_height*0.75,
  buttons = {},
  dragging = nil,
  dragged_offset = {x=0,y=0},
}
br.box.x = screen_width/2-br.box.w/2
br.box.y = screen_height/2-br.box.h/2

local areas = {
  inner = {x=br.box.x+5, y=br.box.y+30, w=br.box.w-10, h=br.box.h-90},
  dock = {x=br.box.x+5, y=br.box.y+br.box.h-60, w=br.box.w-10, h=55},
  bar = {x=br.box.x, y=br.box.y, w=br.box.w, h=30},
}
--

br.directory = ""
br.toplevel = ""
br.directory_items = {}

br.box.buttons.select = newButton("Select", function() if not selected then return end _action(br.directory_items[selected]) end, areas.dock.x+areas.dock.w - (90+15), areas.dock.y+areas.dock.h/2 - 30/2, 90, 30, {font=FONT_[2], no_ripple=true})
br.box.buttons.close = newButton("X", function() return br.close() end, areas.bar.x+areas.bar.w-(areas.bar.h-8)-6, areas.bar.y+4, areas.bar.h-8, areas.bar.h-8, {font=FONT_[2], no_ripple=true})

local function load_directory()
  -- File types: 1=File, 2=Directory, 3=New File
  if not love.filesystem.getInfo(br.directory) then return end
  br.directory_items = love.filesystem.getDirectoryItems(br.directory)
  local folders = {}
  local files = {}
  for i,v in pairs(br.directory_items) do
    local info = love.filesystem.getInfo(br.directory.."/"..v)
    local e = {
      filename = v,
      filepath = br.directory.."/"..v,
      type = info.type=="file" and 1 or 2,
      img = info.type=="file" and file_img or folder_img,
    }
    if e.type==1 and (v:match("%.txt$") or v:match("%.jpg$") or v:match("%.png$")) or e.type==2 then
      table.insert(e.type==1 and files or folders, e)
    end
  end
  table.sort(folders, function(o,t) return o.filename<t.filename end)
  table.sort(files, function(o,t) return o.filename<t.filename end)
  for i,v in pairs(folders) do table.insert(files,i,v) end
  br.directory_items = files
  if br.directory:match("/") and br.directory~=br.toplevel then
    table.insert(br.directory_items, 1, {
        filename = "..",
        filepath = br.directory:match([[([^%?%"%\\:%*<>|]+)/]]) or br.directory,
        type = 2,
        img = folder_img,
      })
  end
  if mode==2 then
    table.insert(br.directory_items, {
        filename = "(New File)",
        type = 3,
        img = newfile_img,
      })
  end
end
--

local function autoscroll()
  if not selected then return end
  local h = FONT_[1]:getHeight()
  local yy = areas.inner.y + 15 + (selected) * h
  local top = areas.inner.y + 15
  local bottom = (areas.inner.y + 15 + areas.inner.h)
  if (yy + scroller.y_offset + h) > (bottom) then
    local diff = yy - bottom
    scroller:moveTo(diff+h)
  elseif (yy + scroller.y_offset - h) < top then
    local diff = yy - top
    scroller:moveTo(diff-h)
  end
end
--

function br.open(directory,m,scene,dir_is_toplevel)
  br.box.visible = true
  mode = m or 1
  selected = nil

  br.directory = directory~="" and directory or "res"
  if dir_is_toplevel then br.toplevel = br.directory end
  
  load_directory()

  if mode == 2 and scene then
    for i,v in pairs(br.directory_items) do
      if v.filename == scene.filename then selected = i end
    end
  end

  br.box.buttons.new_folder = mode==2 and newButton("New Folder", function() input.show("Name your new folder.", nil, nil, function(n) love.filesystem.createDirectory(br.directory.."/"..n) load_directory() end) end, br.box.buttons.select.x-15-125, br.box.buttons.select.y, 125, br.box.buttons.select.h, {font=FONT_[2], no_ripple=true}) or nil

  scroller = newScroller(0, 0, (#br.directory_items+1)*FONT_[1]:getHeight()-areas.inner.h, areas.inner.x+areas.inner.w-10, areas.inner.y+5, areas.inner.h-10, {colour={0,0,0}})
  autoscroll()
  br.box.dragged_offset = {x=0,y=0}
end
--
function br.close()
  selected = nil
  mode = nil
  br.box.visible = false
  br.toplevel = ""
end
--
function br.update(dt)
  if not br.box.visible then return end
  local mx,my = Misc.getMouseScaled()
  for i,v in pairs(br.box.buttons) do
    v:set_mouse_coords(mx - br.box.dragged_offset.x, my - br.box.dragged_offset.y)
    v:update(dt)
  end
  scroller:update(dt)
  br.box.buttons.select.label = selected and br.directory_items[selected].type~=2 and (mode==1 and "Open" or "Save") or "Select"
  return true
end
--

local function draw_bar()
  local bar = areas.bar
  lg.setFont(FONT_[2])
  lg.setColor(1,1,1)
  lg.printf(br.directory, bar.x, bar.y+bar.h/2-FONT_[2]:getHeight()/2, bar.w, "center")
end
--
local function draw_inner()
  local inner = areas.inner
  lg.setColor(1,1,1,0.85)
  lg.rectangle("fill",inner.x,inner.y,inner.w,inner.h)
  lg.setColor(0,0,0,0.5)
  lg.rectangle("line",inner.x+1,inner.y+1,inner.w-2,inner.h-2)

  lg.stencil(function() lg.rectangle("fill",inner.x,inner.y,inner.w,inner.h) end, "replace", 1)
  lg.setStencilTest("equal",1)
  lg.setFont(FONT_[1])
  lg.push() lg.translate(inner.x+15, scroller.y_offset+inner.y+15)
  for i,v in pairs(br.directory_items) do
    if selected == i then
      lg.setColor(0,0,0,0.9)
      lg.rectangle("fill",-15,0,inner.w,FONT_[1]:getHeight())
      lg.setColor(1,1,1)
    else
      lg.setColor(0,0,0)
    end
    lg.draw(v.img)
    lg.push() lg.translate(v.img:getWidth()+5)
    lg.print(v.filename)
    lg.pop()
    lg.translate(0, FONT_[1]:getHeight())
  end
  lg.pop()
  lg.setStencilTest()
end
--
local function draw_dock()
  local dock = areas.dock
  lg.setFont(FONT_[2])
  lg.setColor(1,1,1)
  lg.print("Select a file to "..(mode==1 and "open" or "save to")..".", dock.x+15, dock.y+dock.h/2-FONT_[2]:getHeight()/2+4)
end
--

function br.draw()
  if not br.box.visible then return end
--  lg.setColor(1,1,1,0.2)
--  lg.rectangle("fill",0,0,screen_width,screen_height)

  lg.push()
  lg.translate(br.box.dragged_offset.x,br.box.dragged_offset.y)

  lg.setColor(0.15,0.15,0.15,1)
  lg.rectangle("fill",br.box.x,br.box.y,br.box.w,br.box.h)
  lg.setColor(1,1,1,0.5)
  lg.rectangle("line",br.box.x,br.box.y,br.box.w,br.box.h)
  lg.setColor(0,0,0,0.66)
  lg.rectangle("line",br.box.x-2,br.box.y-2,br.box.w+4,br.box.h+4)

  draw_bar()
  draw_inner()
  draw_dock()

  for i,v in pairs(br.box.buttons) do v:draw() end
  scroller:draw()
  lg.pop()
end
--

function br.keypressed(key)
  if not br.box.visible then return end

  if keyset.up(key) then
    selected = selected and math.clamp(1, selected - 1, #br.directory_items) or 1
    autoscroll()
  elseif keyset.down(key) then
    selected = selected and math.clamp(1, selected + 1, #br.directory_items) or 1
    autoscroll()
  elseif keyset.confirm(key) and selected then
    _action(br.directory_items[selected])
  elseif keyset.back(key) then
    br.close()
  end
  scroller:keypressed(key)
  return true
end
--

function br.mousepressed(x,y,b)
  if not br.box.visible then return end
  if b~=1 then return true end
  x, y = x - br.box.dragged_offset.x, y - br.box.dragged_offset.y
  for i,v in pairs(br.box.buttons) do if v:mousepressed(x,y,b) then return true end end
  scroller:checkArea(x,y, {br.box.x,br.box.y,br.box.w,br.box.h})
  if Misc.checkPoint(x,y,areas.inner) then
    local any_selected
    for i,v in pairs(br.directory_items) do
      local y = y - scroller.y_offset
      local h = FONT_[1]:getHeight()
      local iy = areas.inner.y+15+(i-1)*FONT_[1]:getHeight()
      if y > iy and y < iy+h then
        any_selected = true
        if selected==i then
          _action(v)
        else
          selected = i
        end
      end
    end
    if not any_selected then selected = nil end
    return true
  end
  if Misc.checkPoint(x,y,areas.bar) then
    br.box.dragging = true
    return true
  end
  if Misc.checkPoint(x,y,areas.dock) then return true end
  br.close()
  return true
end
--

function br.mousereleased(x,y,b)
  if not br.box.visible then return end
  if b~=1 then return true end
  br.box.dragging = false
  x, y = x - br.box.dragged_offset.x, y - br.box.dragged_offset.y
  for i,v in pairs(br.box.buttons) do v:mousereleased(x,y,b) end
  return true
end
--

function br.touchmoved(id,x,y,dx,dy)
  if not br.box.visible then return end
  if br.box.dragging then
    br.box.dragged_offset.x = br.box.dragged_offset.x + dx
    br.box.dragged_offset.y = br.box.dragged_offset.y + dy
    return true
  end
  x, y = x - br.box.dragged_offset.x, y - br.box.dragged_offset.y
  scroller:touchmoved(id,x,y,dx,dy)
  return true
end
--
function br.wheelmoved(x,y)
  if not br.box.visible then return end
  x, y = x - br.box.dragged_offset.x, y - br.box.dragged_offset.y
  scroller:wheelmoved(x,y)
  return true
end
--

setmetatable(br, { __call = function(_, ...) return br.open(...) end})

return br