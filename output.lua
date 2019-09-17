local op = {}

local newScroller = require("elements.scroller")

local scenes
local scene_directory
local choice
local scroller
local static
local canvases
local narrtween
local pause_delay
local pause_indices
local pause_index
local page_time_elapsed
local narbox
local h
local _
local fullwrap
local FONT_ = {
  fonts.game_maintext,
  fonts.game_location,
  fonts.game_narrator,
}
--
local blinker = {
  img = love.graphics.newImage("res/img/squarrow.png"),
  alpha = 1,
  dir = -1,
}
blinker.x = screen_width-blinker.img:getWidth()*0.8-30
blinker.y = screen_height-blinker.img:getHeight()*0.8-30

op.box = {}

event.wish("output_changed", function() event.clear("ignore_out_metadata") end)

local prior_narrator
function op.setNarrator(narrator)
  if narrator==op.narrator then return end
  prior_narrator = op.narrator
  op.narrator = narrator
  if narrator then
    narbox.x=-50
    narbox.a=0
--    op.box.y_orig = op.box.y
--    op.box.h_orig = op.box.h
    op.box.y = narbox.y + narbox.h
    op.box.h = op.box.h - narbox.h
    if narrtween then narrtween:stop() end
    narrtween = Flux.to(narbox,0.3,{x=0,a=0.35}):ease("quadout")
  else
    op.box.y = op.box.proto.y or narbox.y
    op.box.h = op.box.proto.h or narbox.h
    if narrtween then narrtween:stop() end
    narrtween = Flux.to(narbox,0.5,{x=-5,a=0}):ease("quadout")
  end
end
--

function op.setChoice(ch)
  choice = ch or choice
end
--

local function register_pauses(text)
  if type(text)~="string" then return end
  pause_indices = setmetatable({}, {__index = function() return {index=0,time=0} end})
  pause_index = 0
  local delays = {
    [":"] = 9/op.speed,
    [","] = 9/op.speed,
    [";"] = 12/op.speed,
    ["-"] = 12/op.speed,
    ["."] = 18/op.speed,
    ["!"] = 18/op.speed,
    ["?"] = 18/op.speed,
  }
  for p,d in pairs(delays) do
    local search_index = 0
    local _,e = text:find(p, search_index, true)
    while e do
      local nextchar = text:sub(e+1 ,e+1)
      local time = d
      if nextchar:match("[\"'%.%"..p.."]") then
        e = e+1
        nextchar = text:sub(e+1,e+1)
      end
      if nextchar:match("[\"%)'%w%"..p.."]") then time = 0 end
      table.insert(pause_indices, {index=e, time=time})
      search_index = e+1
      _,e = text:find(p, search_index, true)
    end
  end
  table.sort(pause_indices, function(o,t) return o.index < t.index end)
-- if there is " or ' or . after p then consider that as the match instead
-- if the same p is repeated immediately after then ignore the match
-- if the next character is " or ) or %w then ignore the match
end
--

local android_choice_cols = {fg={{0,0,0,0},{0,0,0,0},{0,0,0,0}},bg={{0,0,0,0},{0,0,0,0},{0,0,0,0}}}
local android_next_cols = {fg={{1,1,1,0.5},{1,1,1,0.5},{1,1,1,0.6}},bg={{1,1,1,0.08},{1,1,1,0.08},{1,1,1,0.2}}}
function op.initButtons()
  if #op.buttons > 0 then return end
  choice = choice or choices
  if love.system.getOS()=="Android" then
    op.buttons["Next"] = newButton("Next",
      function()
        love.system.vibrate(0.1)
        Misc.action()
      end,
      screen_width-(screen_width/5-15)-5,screen_height-screen_height/4-15,screen_width/5-15,screen_height/4, {cols=android_next_cols, movable=true, no_ripple=true})
  end
end
--
function op.setFontSize(size)
  fonts.game_maintext = lg.newFont("res/fonts/Neuton-Regular.ttf",size or 28)
  FONT_[1] = fonts.game_maintext
  event.grant("font_size_changed")
end
--

function op.load(s,dirs)
  choice = choice or choices
  local directories = dirs or scene_directory
  local d = Misc.exists(s,directories)
  local scene
  if d then
    scene = {insert={},tags = {},required={}}
    local temp = ""
    local folder_name = directories[d]
    for l in love.filesystem.lines(folder_name..s..".txt") do
      local ins_tag, ins_text = l:match("^%s*&(.-)%s*:%s*(.+)")
      if l:match("^%s*//") then
        l=""
      elseif ins_tag then
        ins_tag = ins_tag:lower()
        scene.insert[ins_tag] = scene.insert[ins_tag] or {}
        table.insert(scene.insert[ins_tag], ins_text)
        l=""
      end
      -- Check for tags
      if l:lower():match("^!tags") then
        for w in l:lower():match("!tags:%s*(.+)"):gmatch("%s*([^,]+)") do
          table.insert(scene.tags, w:gsub("^%s*(.-)%s*$","%1"):lower())
        end
        l = ""
      end
      -- Check for requirements
      if l:match("^!require") then
        for w in l:match("!require:%s*(.+)"):gmatch("%s*([^,]+)") do
          local par,op,val = w:match("(.-)%s*([=><]+)%s*(.+)")
          op = Misc.getOpFunc(op)
          scene.required[par] = {}
          for m in val:gmatch("[^;]+") do
            table.insert(scene.required[par], function(par) return op(par, m:gsub("^%s*(.-)%s*$","%1"):lower()) end)
          end
        end
        l = ""
      end
      if l == "" and temp == "" then
        -- Do nothing
      else
        -- Properly concatenate linebreaks
        temp = temp..l.."\n"
        -- Check if line ends in page-end symbol - snip off and insert
        if l:sub(-1)=="~" and l:sub(-2,-2) ~= "\\" then
          table.insert(scene, temp)
          temp = ""
        end
      end
    end
    if temp~="" then table.insert(scene, temp) end
    -- Make a temporary table to keep track of indices to delete so we can safely pop entries from the real scene
    local marked = {}
    -- Detect choice clusters and allocate them to a table
    local cn_index
    for i,p in ipairs(scene) do
      local cn = tonumber(p:match("^%s*<(%d+)>"))
      if cn then
        if type(scene[cn_index])~="table" then
          cn_index = i
          scene[cn_index] = {}
        else
          table.insert(marked,i-#marked)
        end
        scene[cn_index][cn] = scene[cn_index][cn] or {}
        table.insert(scene[cn_index][cn], p)
      else
        cn_index = nil
      end
    end
    -- Remove pages that were marked for deletion
    for _,v in pairs(marked) do table.remove(scene, v) end
  end
  return scene
end
--

local function on_complete()
  if event.exists("choice") then choice.open(event.pop("choice")) end
  if event.exists("input") then input.show(unpack(event.pop("input") or {0})) end
  if event.exists("shop") then shop.open(event.pop("shop")) end

  if op.done then return end
  if op.src[op.pg] == nil then return op.next() end
  scroller:moveTo(scroller.max)
  blinker.alpha = 1
end
--

local function drawNarrator()
  lg.setColor(0,0,0,narbox.a)
--  lg.rectangle("fill", narbox.x, narbox.y, narbox.w, narbox.h)
  lg.rectangle("fill", narbox.x, 0, narbox.w, narbox.y+narbox.h)
  lg.setColor(1,1,1,narbox.a*5)
  lg.setFont(FONT_[3])
  local text = op.narrator or prior_narrator or ""
  lg.print(text..":", math.floor(narbox.x+15), math.floor(narbox.y+2))
end
--

local function drawText()
  if #fullwrap*h == 0 then return end
  local function draw(text,x,y)
    lg.setFont(FONT_[1])
    for o=-1,1,2 do
      for m=1,3 do
        local o = o*m
        lg.setColor(0,0,0,0.75/m)
        lg.print(text, x+o, y)
        lg.print(text, x, y+o)
      end
    end  
    lg.setColor(1,1,1)
    lg.print(text, x, y)
  end
  local texturesize = love.graphics.getSystemLimits().texturesize
  local max_canvas_height
  for i=0, op.box.h, h do
    max_canvas_height = i
  end
  max_canvas_height = math.min(max_canvas_height, texturesize*0.8)

  if settings.outline_canvas_prerender==0 then
    draw(op.put,0,0)
  else
    for i=0, #fullwrap*h, max_canvas_height do
      table.insert(canvases, {canvas=lg.newCanvas(screen_width, max_canvas_height), y=i})
    end
    for i,text in pairs(fullwrap) do
      i = i-1
      local canv = math.floor(((i) * h) / (max_canvas_height))+1
      lg.setCanvas({canvases[canv].canvas,stencil=true})
      local sx, sy = Misc.toGame()
      lg.push() lg.scale(1/sx, 1/sy)

      local x, y = op.box.x, ((i) * h) % (max_canvas_height)

      draw(text,x,y)

      lg.pop()
      lg.setCanvas()
    end
  end
end
--
function op.drawLocation()
  lg.setLineWidth(1)
  lg.setColor(0,0,0,0.95)
  lg.rectangle("fill", 0, 0, screen_width, screen_height/25)
  lg.setColor(0,0,0,0.35)
  lg.rectangle("fill", 0, 0, screen_width, screen_height/25+4)
  lg.setColor(1,1,1,0.15)
  lg.line(0, screen_height/25, screen_width, screen_height/25)
  lg.setColor(1,1,1)
  lg.setFont(FONT_[2])
  lg.print(op.location,math.floor(screen_width/2-FONT_[2]:getWidth(op.location)/2),2)
end
--

function op.update(dt)
  if event.pop("skip") then return op.next(nil,op.chosen_n,true) end
  if event.exists("change") then return op.change(unpack(event.pop("change"))) end
  if event.exists("combat") then return combat(unpack(event.pop("combat"))) end
  if not op.put or #op.put==0 then return end
  
  if event.pop("finish_output") then op.progress = #op.put end

  page_time_elapsed = page_time_elapsed + dt

  op.pause()

  scroller:update(dt)

  if Misc.fade.lerping then return end

  pause_delay = pause_delay - dt
  if pause_delay <= 0 then op.hold = false end

  local _, wrapped = FONT_[1]:getWrap(op.put:sub(1, math.floor(op.progress)),op.box.w)
  if static.h ~= #wrapped*h then
    static.h = #wrapped*h
    static.c = #wrapped
    scroller:setMax(#wrapped*h-op.box.h+h)

    -- Automatically scroll down when long outputs trail offscreen.
    if op.box.y+15+(#wrapped*h)-scroller.y_offset_target >= op.box.y+op.box.h and not op.done then
      scroller.visible = true
      scroller.alpha = 1
      local height = h
      if op.narrator then height = h + narbox.h end
      if scroller.y_offset_target >= scroller.max-h then
        scroller:moveTo(scroller.y_offset_target + height*15)
      end
    end
  end

  if op.hold then return end
  if op.progress < #op.put then
    op.done = false
    op.progress = math.min(op.progress + op.speed * dt, #op.put)
  else
    op.progress=#op.put
    on_complete()
    op.done = true
  end
  if op.done then
    blinker.alpha = (blinker.alpha + 1 * dt) % 2
  end
end
--

local function draw_debug()
end
--

function op.draw()
  if not op.put or #op.put==0 then return draw_debug() end

  if op.done and not choice.visible then
    lg.setColor(1,1,1,math.abs(blinker.alpha-1)*0.75)
    lg.draw(blinker.img, blinker.x, blinker.y, nil, 0.8)
  end

  local text = string.sub(op.put, 1, math.floor(op.progress))
  local _, wrapped = FONT_[1]:getWrap(op.put:sub(1, math.floor(op.progress)),op.box.w)
  local x, y = op.box.x, op.box.y+15
  if op.narrator then y = y+15 end
  lg.setFont(FONT_[1])

  -- There are two ways of getting text to gradually print onto the screen. I am using the most convoluted method possible.
  -- The reason I don't just stick with the one line of lg.print() that would perfectly replace all this is because of text outlines.
  -- I won't use shaders for it, as I found they are uncompatible with lots of mobile devices.
  -- The other, more pragmatic method of getting text outlines (simply printing the text multiple times) is undeniably a waste of draw calls.
  -- So here we are, using canvases and stencil buffered rectangles. Since a canvas (frame buffer/render to texture) only takes up one draw call, this is actually faster than the other two listed methods. With linear texture filtering, it actually looks quite nice and gets the job done.

  lg.stencil(function()
      if not op.done then
        -- Mask that moves with each new character
        lg.rectangle("fill", op.box.x+FONT_[1]:getWidth(wrapped[static.c] or ""), op.box.y+15+#wrapped*h-h+scroller.y_offset, screen_width, h)
        -- Mask that moves with each new line
        lg.rectangle("fill", 0, math.min(op.box.y+op.box.h, op.box.y+15+static.h+scroller.y_offset), screen_width, op.box.y+15+#fullwrap*h)
      end
      -- Mask that covers the bottom icons.
      lg.rectangle("fill", 0, screen_height-screen_height/7.5, screen_width, screen_height/7.5+5)
    end, "replace", 1)
  lg.setStencilTest("equal", 0)
  lg.push()
  lg.translate(0, (op.box.y+op.box.tpad+15)+scroller.y_offset)
  lg.setColor(1,1,1)
  if settings.outline_canvas_prerender==0 then
    drawText()
  else
    for i,v in pairs(canvases) do
      lg.draw(v.canvas, 0, v.y)
    end
  end
  lg.pop()
  lg.setStencilTest()

  lg.setColor(1,1,1)
  drawNarrator()

  draw_debug()

  scroller:draw()
end
--

function op.keypressed(key)
  if Misc.fade.lerping or not op.put or #op.put==0 then return end
  if keyset.confirm(key) then return Misc.action() end

  for i,v in pairs{pageup=keyset.up(key), pagedown=keyset.down(key)} do
    if v then return scroller:keypressed(i) end
  end
  scroller:keypressed(key)
end
--
function op.mousepressed(x,y,b,t)
  if b~=1 or Misc.fade.lerping or not op.put or #op.put==0 then return end

  scroller:checkArea(x,y, {op.box.x,op.box.y,op.box.w,op.box.h})

  if input.visible then return end
end
--
function op.mousereleased(x,y,b,t)
  if b~=1 or not op.put or #op.put==0 then return end

  if x > op.box.x and y > op.box.y and y < op.box.y + op.box.h and x < op.box.x + op.box.w
  and (scroller.mvtotal or 0) < 5
  and not input.visible
  and not choice.visible
  and love.system.getOS()~="Android" then Misc.action() end

end
--

function op.wheelmoved(x,y)
  if not op.put or #op.put==0 then return end
  scroller:wheelmoved(x,y)
end
--
function op.touchmoved(id,x,y,dx,dy)
  if not op.put or #op.put==0 then return end
  scroller:touchmoved(id,x,y,dx,dy)
end
--

function op.next(pg,cn,force)
  if not force then
    if input.box.visible and input.result=="" then return end
    if choice.lerping or choice.box.a ~= 0 then return end
    if page_time_elapsed < 0.2 then return end
    if op.progress < #op.put then
      op.progress = #op.put
      return
    end
    if event.exists("input") or event.exists("choice") or event.exists("shop") then return end
  end
  if op.block then return Gamestate.push(states.explore) end

  pg = pg or op.pg + 1
  
  if op._subpage then
    op._subpage = op._subpage + 1
    if op._subpage > #op._subtable and next(op._subtable) then op._subpage = nil end
  end
  if not op._subpage or not next(op._subtable) then
    op.pg = math.clamp(1, pg, #op.src)
  end

  -- Check if we're in a choice table
  if type(op.src[op.pg])=="table" then
    if cn then
      op._subtable = Misc.tcopy(op.src[op.pg][cn]) or {""}
      op._subpage = op._subpage or 1
    else
      op.next(nil,nil,true)
    end
  end
  if op._subpage and op._subtable[op._subpage] then
    op.src[op.pg] = op._subtable[op._subpage]
  end

  if Gamestate.current()==states.game and pg >= #op.src+1 and not op._subpage then return Gamestate.push(states.explore) end

  if type(op.src[op.pg])=="function" then
    return op.src[op.pg]()
  end

  event.clear("speaker")
  
  -- Convert the page into an error message if a UTF-8 character is encountered.
  for c in op.src[op.pg]:gmatch(".") do
    if c:byte() >= 128 then
      op.src[op.pg] = "!!ERROR!!\nUTF-8 text has prevented this page from loading.\nThis can be caused by a text editor replacing quotation marks and ellipses with special Unicode characters that TextGame cannot render.\nReplace all of these special characters with standard ASCII and try again.\nIf trouble persists, ask for help in the Discord."
      break
    end
  end

  local processed, raw, half_raw, eval = process(op.src[op.pg])
  if not raw then
    return op.next(nil,cn)
  end
  if #half_raw<=2 then
    if (op.pg<#op.src or (op._subpage and op._subpage < #op._subtable)) then
      return op.next(nil,cn,true)
    elseif pg == #op.src then
      op.put = op.src[op.pg]
    else
      op.next(op.pg-1,cn,true)
      op.progress = #op.put
    end
  end
  states.explore.updateList()
  if event.exists("change") or event.exists("combat") then return end
  if not op.disable_checkPref and not op.checkPreferences(op.to) then event.push("skip",true) end
  if #processed>1 then
    op.put = processed
  else
    if not eval then
      event.push("skip",true)
      return
    else
      return nil
    end
  end
  op.setNarrator(event.pop("speaker"))
  op.progress = 0
  op.hold = false
  op.done = false
  page_time_elapsed = 0
  op.put_backup = op.put
  h = FONT_[1]:getHeight()*FONT_[1]:getLineHeight()
  _, fullwrap = FONT_[1]:getWrap(op.put,op.box.w)
  op.put = table.concat(fullwrap,"\n")
  register_pauses(op.put)
  scroller = newScroller(0, 0, h, screen_width-30, screen_height/8, screen_height-(screen_height/8*2))
  scroller.visible = false
  op.last_text = processed
  event.grant("pageflip",op.put_backup)
end
--

function op.change(to,fade,pg,cn)
  local src = op.load(to)
  local pop
  if not src then return end
  assert(next(src) and src[1]~="", "The intended output '"..to.."' is either empty or improperly formatted.")

  if Gamestate.current() == states.explore then pop = true end

  local function func()
    if pop then Gamestate.pop() end 
    event.clear("choice","input","shop","override_icon")
    if op.to ~= to then
      -- Only if the src is actually changing
      op._subpage = nil
      op._subtable = nil
      for i,v in pairs(flags) do if i:sub(1,2)=="~~" then flags[i] = nil end end
      for i=1,4 do if i~=3 then icon_bar.set(i, true) end end
    else
      if (pg or 1) ~= op.pg then
        op._subpage = nil
        op._subtable = nil
      end
    end
    op.block = false
    op.last_src = op.to
    op.to = to
    op.src = Misc.tcopy(src)
    process.setSrc(op.src)
    if tostring(pg):lower() == "next" then pg = op.pg + 1
    elseif tostring(pg):match("[%+%-]") then pg = op.pg + tonumber(pg) end
    pg = math.clamp(1, pg or 1, #op.src)
    op.next(pg or 1,cn or choice.chosen_n,true)
    event.grant("output_changed")
  end

  if fade then
    if type(fade)=="boolean" or type(fade)=="string" then fade = 1 end
    Misc.fade(function()
        func()
      end, fade)
  else
    func()
  end
  return true
end
--

function op.pause()
  if type(op.put)~="string"
  or op.progress >= #op.put
  or op.hold
  then return end

  local curr = pause_indices[pause_index]
  if op.progress >= curr.index then
    op.progress = curr.index
    op.hold = true
    pause_delay = curr.time
    pause_index = pause_index + 1
    if pause_indices[pause_index].index==0 then pause_indices[pause_index]={index=#op.put, time=0} end
  end
end
--

function op.checkPreferences(scene,ent)
  return true
end
--

function op.clear()
  static = {h=0, w=0, c=0}
  canvases = {}
  op.src = {""}
  op.pg = 0
  op.put = ""
  op.put_backup = op.put
  op.progress = 0
  op.hold = false
  op.done = false
  op.block = false
  op.location = ""
  op._subtable = {}
  op._subpage = nil

  event.endWish("output")
end
--

function op._initialize()
  scenes = {}
  choice = require("choices")
  scroller = nil
  op.buttons = {}
  op.initButtons()
  scene_directory = {"res/text/scenes/"}
  static = {h=0, w=0, c=0}
  canvases = {}
  narrtween = nil
  pause_delay = 0
  pause_indices = nil
  pause_index = 0
  blinker = {
    img = lg.newImage("res/img/squarrow.png"),
    alpha = 1,
    dir = -1,
  }
  blinker.x = screen_width-blinker.img:getWidth()*0.8-30
  blinker.y = screen_height-blinker.img:getHeight()*0.8-30
  page_time_elapsed = 0

  op.clear()
  op.to = ""
  op.checkpoint = ""
  op.speed = 40
  op.box.x = 30
  op.box.y = screen_height/25
  op.box.w = screen_width-60
  op.box.h = screen_height-screen_height/8-screen_height/20-15
  op.box.tpad = 0
  narbox = {
    x=-50,
    y=screen_height/25,
    w=screen_width,
    h=screen_height/16,
    a=0,
  }
  
  op.box.proto = Misc.tcopy(op.box)

  h = FONT_[1]:getHeight()*FONT_[1]:getLineHeight()
  _, fullwrap = FONT_[1]:getWrap(op.put,op.box.w)
  op.put = table.concat(fullwrap,"\n")  
end
--

if Misc.uptime == 0 or Misc._out_source_modifier then
  local mod = Misc._out_source_modifier
  op._initialize()
  event.wish({"pageflip", "output_changed", "window_reset"}, function()
      static = {h=0, w=0, c=0}
      canvases = {}
      drawText()
    end, nil)
  --
  event.wish("font_size_changed", function()
      h = FONT_[1]:getHeight()*FONT_[1]:getLineHeight()
      _, fullwrap = FONT_[1]:getWrap(op.put_backup,op.box.w)
      op.put = table.concat(fullwrap,"\n")
      register_pauses(op.put)
      scroller = newScroller(0, 0, h, screen_width-30, screen_height/8, screen_height-(screen_height/8*2))
      static = {h=0, w=0, c=0}
      canvases = {}
      drawText()
    end, nil)
end
--

return op