local ei = {}
local newDropdown = require("elements.dropdown")

local FONT_ = {
  fonts.game_maintext,
}

local scene
local page

local threshold_base = 1
local threshold_countdown = threshold_base

local mouse_is_down

local function validate_nonUTF8(str_table)
  for _,str in pairs(str_table) do
    for c in str:gmatch(".") do
      if c:byte() >= 128 then
        return false
      end
    end
  end
  return true
end
--

local function test_readonly()
  if scene[page].readonly then
    Misc.message("TextGame has set this page to Read-Only mode because it detected UTF-8 text.\nThis can be caused by a text editor replacing quotation marks and ellipses with special Unicode characters that TextGame is not equipped to handle.","ERROR")
    return true
  end
  return false
end
--

local function load_file(filepath,_is_dropped)
  local scene, insert, tags, required = {}, {}, {}, {}
  local page = 1
  for l in (_is_dropped and filepath:lines() or love.filesystem.lines(filepath)) do
    local ins_tag, ins_text = l:match("^%s*&(.-)%s*:%s*(.+)")
    if ins_tag then
      ins_tag = ins_tag:lower()
      insert[ins_tag] = insert[ins_tag] or {}
      table.insert(insert[ins_tag], ins_text)
    end
    -- Check for tags
    if l~=0 and l:lower():match("^!tags") then
      for w in l:lower():match("!tags:%s*(.+)"):gmatch("%s*([^,]+)") do
        table.insert(tags, w:gsub("^%s*(.-)%s*$","%1"):lower())
      end
      -- Check for requirements
--    elseif l~=0 and l:match("^![%S^!^?^%.]") then
    elseif l~=0 and l:match("^!require") then
--      for w in l:match("!(.+)"):gmatch("%s*([^,]+)") do
      for w in l:match("!require:%s*(.+)"):gmatch("%s*([^,]+)") do
        local i,v = w:match("(.-)%s*=%s*(.+)")
        required[i] = {}
        for m in v:gmatch("[^;]+") do
          table.insert(required[i], m:gsub("^%s*(.-)%s*$","%1"):lower())
        end
      end
    end
    if l ~= 0 then
      if not scene[page] then scene[page] = {} end
      local s = l:gsub("~$","")
      if (s~="" and #scene[page]==0) or #scene[page]>0 then table.insert(scene[page], s) end
      if l:sub(-1)=="~" and l:sub(-2,-2)~="\\" then page = page + 1 end
    end
  end
  while scene[#scene] and #scene[#scene] == 0 do table.remove(scene, #scene) end
  return scene, {insert=insert,tags=tags,required=required}
end
--

local function autoscroll()
  local h = FONT_[1]:getHeight()
  local yy = states.editor.text_area.y + 15 + (scene[page].vrow) * h
  local top = states.editor.text_area.y + 15
  local bottom = (states.editor.text_area.y + 15 + states.editor.text_area.h)
  if (yy + states.editor.scroller.y_offset + h) > (bottom) then
    local diff = yy - bottom
    states.editor.scroller:moveTo(diff+h)
  elseif (yy + states.editor.scroller.y_offset - h) < top then
    local diff = yy - top
    states.editor.scroller:moveTo(diff-h)
  end
end
--

local function get_alt_rows(col,row)
  col, row = col or scene[page].cursor, row or scene[page].row
  if not scene[page].wrapped[row] then return 1, 1 end
  local vrow = 1
  local subrow = 1
  local curr_y = 1
  local total_len = 0
  for i=1,row-1 do
    for ii=1,math.max(1,#(scene[page].wrapped[i] or {})) do
      curr_y = curr_y + 1
    end
  end
  local curr_y2 = 1
  for i=1,math.max(1,#scene[page].wrapped[row]) do
    local v = scene[page].wrapped[row][i] or ""
    total_len = total_len + #v
    if total_len >= col then
      vrow = curr_y
      subrow = curr_y2
      break
    end
    curr_y = curr_y + 1
    curr_y2 = curr_y2 + 1
  end
  return vrow, subrow
end
--

local function find_closest_char(x,y)
  local col, row
  local rh, cw = FONT_[1]:getHeight(), 0
  local curr_y = states.editor.text_area.y+15
  if y < curr_y then return 0, 1 end

  for i=1,#scene[page].wrapped do
    local curr_closest = math.huge
    local total_len = 0
    local cw = states.editor.text_area.x+15
    for ii=1,math.max(1, #scene[page].wrapped[i]) do
      local v = scene[page].wrapped[i][ii] or ""
      if y > curr_y and y < curr_y+rh then
        row = i
        local char_index = 0
        col = total_len+char_index
        if x < cw+FONT_[1]:getWidth(v:sub(1,1))/2 then break end
        for c in v:gmatch(".") do
          char_index = char_index + 1
          cw = cw + FONT_[1]:getWidth(c)
          if math.abs(x-cw) < curr_closest then
            curr_closest = math.abs(x-cw)
            col = total_len+char_index
          end
          if cw > x then break end
        end
        break
      end
      total_len = total_len+#v
      curr_y = curr_y + rh
    end
    if row then return col, row end
  end
  local last_row = #scene[page].text
  local last_col = #scene[page].text[last_row]
  if y > curr_y then return last_col, last_row end
end
--

function ei.update_wrapped()
  scene[page].wrapped = {}
  for i,v in pairs(scene[page].text) do _, scene[page].wrapped[i] = FONT_[1]:getWrap(scene[page].text[i], states.editor.text_area.w-30) end
end
--

function ei.set_cursor(c,bypass_shift,bypass_autoscroll)
  local col = c or scene[page].cursor
  threshold_countdown = threshold_base
  if (love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")) then
--    if c and not bypass_shift and c ~= scene[page].cursor then
    if c and not bypass_shift then
      if not scene[page].selecting then
        scene[page].selecting = {s={row=scene[page].row,col=scene[page].cursor},e={row=scene[page].row,col=col}}
      else
        scene[page].selecting.e.col = scene[page].selecting.e.col + (c-scene[page].cursor)
      end
      scene[page].selecting.e.col = math.clamp(0, scene[page].selecting.e.col, #scene[page].text[scene[page].row])
      return 
    end
  else
    scene[page].selecting = nil
  end

  scene[page].cursor = math.clamp(0, col, #scene[page].text[scene[page].row])
  scene[page].vrow, scene[page].subrow = get_alt_rows(scene[page].cursor,scene[page].row)

  scene[page].cursor_xy.x, scene[page].cursor_xy.y = ei.getXY(scene[page].cursor, scene[page].row)
  if not bypass_autoscroll then autoscroll() end
end
--

local history_limit = 200
function ei.add_history(state)
  scene, page = states.editor.share_locals()
  state = Misc.tcopy(state or scene[page])
  state.history, state.history_pointer = nil, nil

  if __.is_equal(state, scene[page].history[1] or {}) then return end

  if not scene[page].history_pointer then scene[page].history = {}
  elseif scene[page].history_pointer > 1 then scene[page].history = {scene[page].history[scene[page].history_pointer]} end

  table.insert(scene[page].history,1,state)
  table.remove(scene[page].history,history_limit+1)
  scene[page].history_pointer = 1
end
--
function ei.undo()
  if not scene[page].history_pointer or scene[page].history_pointer == math.min(#scene[page].history,history_limit) then return end
  scene[page].history_pointer = scene[page].history_pointer + 1
  for i,v in pairs(scene[page].history[scene[page].history_pointer]) do
    scene[page][i] = Misc.tcopy(v)
  end
  autoscroll()
end
--
function ei.redo()
  if not scene[page].history_pointer or scene[page].history_pointer == 1 then return end
  for i,v in pairs(scene[page].history[scene[page].history_pointer]) do
    scene[page][i] = Misc.tcopy(v)
  end
  scene[page].history_pointer = scene[page].history_pointer - 1
  autoscroll()
end
--
local ins_count = 0
function ei.insert_text(text,s,e)
  if scene[page].selecting then s, e = scene[page].selecting.s, scene[page].selecting.e end
  s = s or {col=scene[page].cursor, row=scene[page].row}
  e = e or {col=s.col, row=s.row}
  local start, finish = math.min(s.col,e.col), math.max(s.col,e.col)
  if scene[page].selecting then
    ei.erase_text(s,e)
    ei.insert_text(text)
  else
    scene[page].text[s.row] = scene[page].text[s.row]:sub(0,math.max(0,start)) .. text .. scene[page].text[s.row]:sub(finish+1)
  end
  scene[page].row = math.clamp(1, s.row, #scene[page].text)
  scene[page].selecting = nil
  ei.update_wrapped()
  scene[page].vrow, scene[page].subrow = get_alt_rows(s.col,scene[page].row)
  ei.set_cursor(start + #text, true)
  ins_count = ins_count + #text
  if ins_count >= 2 then
    ei.add_history()
    ins_count = 0
  end

  local ac = states.editor.autocomplete
  if text:match("^[%w_]$") then
    local proceed
    states.editor.keyboard_focus = 1
    if scene[page].text[s.row]:sub(start,start)=="#" then
      proceed = true
      ac.active = "replace"
    elseif scene[page].text[s.row]:sub(start,start)=="@" then
      proceed = true
      ac.active = "command"
    end
    if proceed or (ac.active and ac[ac.active.."_dropdown"].filter) then 
      local filter = (ac[ac.active.."_dropdown"].filter or "^")..text:match("^[%w_]$"):lower()
      local new_list = {}
      for i,v in pairs(ac[ac.active.."_orig_list"]) do
        if v:lower():match(filter) then table.insert(new_list,v) end
      end
      ac[ac.active.."_dropdown"] = newDropdown(new_list, function(i,v) local s, e = v:find(filter) return ei.insert_text(v:sub(e+1)) end, {instant=true,noclamp=true,alpha=0.9})
      local x, y = ei.getXY(s.col,s.row)
      if x and y then
        y = y + states.editor.scroller.y_offset
        ac[ac.active.."_dropdown"]:open(x, y+FONT_[1]:getHeight()/1.5)
        ac[ac.active.."_dropdown"].filter = filter
      end
      return
    end
  else
    ac.replace_dropdown:close()
    ac.command_dropdown:close()
    ac.replace_dropdown.filter = nil
    ac.command_dropdown.filter = nil
  end
end
--
local era_count = 0
function ei.erase_text(s,e)
  local set_cursor_to = nil
  local set_row_to = nil

  local function erase(s,e,row)
    if scene[page].text[row]==0 then return end
    local start, finish = math.min(s,e), math.max(s,e)
    local left, right = scene[page].text[row]:sub(0,math.max(0,start)), scene[page].text[row]:sub(finish+1)
    if s == e then
      if s >= #scene[page].text[row] then
        -- Delete key on final column function
        scene[page].text[row] = left .. (scene[page].text[row+1] or "")
        scene[page].text[row+1] = 0
      elseif s < 0 and row > 1 then
        -- Backspace on column 1 function
        scene[page].text[row] = 0
        set_cursor_to = #scene[page].text[row-1]
        scene[page].text[row-1] = scene[page].text[row-1] .. right
        set_row_to = row-1
      else
        -- Regular erase
        scene[page].text[row] = left .. right:sub(2)
      end
    else
      -- Erase range of columns in row
      scene[page].text[row] = left .. right
      set_cursor_to = finish-(finish-start)
    end
    ei.update_wrapped()
    era_count = era_count + (finish-start)
  end

  e = e or {col=s.col, row=s.row}
  local start_row, finish_row = math.min(s.row,e.row), math.max(s.row,e.row)

  if e.row==s.row then
    erase(s.col,e.col,s.row)
  else
    local left, right = "", ""
    local start, finish = s.row < e.row and s.col or e.col, e.row > s.row and e.col or s.col
    -- Finish Row
    right = scene[page].text[finish_row]:sub(finish+1)
    erase(0,finish,finish_row)
    if #scene[page].text[finish_row]==0 then scene[page].text[finish_row] = 0 end
    -- Start Row
    left = scene[page].text[start_row]:sub(0,start)
    erase(start,999999,start_row)
    if #scene[page].text[start_row]==0 then scene[page].text[start_row] = 0 end
    -- In-between Rows
    for r=start_row+1,finish_row-1 do
      scene[page].text[r] = 0
    end
    -- Stitch orphaned left/right chunks from multi-row erase
    if #left>0 and #right>0 then
      scene[page].text[start_row] = left .. right
      scene[page].text[finish_row] = 0
      set_cursor_to = #left
    end
  end

  local cursor = set_cursor_to or (s.row < e.row and s.col or e.col)

  for i=1,#scene[page].text do
    local v = scene[page].text[i]
    while scene[page].text[i] == 0 do
      table.remove(scene[page].text,i)
    end
  end
  if not next(scene[page].text) then table.insert(scene[page].text,"") end

  scene[page].row = math.clamp(1, set_row_to or start_row, #scene[page].text)
  scene[page].vrow, scene[page].subrow = get_alt_rows(cursor,start_row)
  scene[page].selecting = nil
  ei.update_wrapped()
  ei.set_cursor(cursor, true)
  autoscroll()

  states.editor.autocomplete.replace_dropdown:close()
  states.editor.autocomplete.command_dropdown:close()
  states.editor.autocomplete.replace_dropdown.filter = nil
  states.editor.autocomplete.command_dropdown.filter = nil
  states.editor.autocomplete.active = nil
end
--

function ei.getXY(col,row)
  if not scene[page].wrapped[row] then return end
  local xx, yy, tw
  local curr_y = states.editor.text_area.y+15
  local total_len = 0
  for i=1,row-1 do
    for ii=1,math.max(1,#(scene[page].wrapped[i] or {})) do
      curr_y = curr_y + FONT_[1]:getHeight()
    end
  end
  for i=1,math.max(1,#scene[page].wrapped[row]) do
    local v = scene[page].wrapped[row][i] or ""
    total_len = total_len + #v
    if total_len >= col then
      tw = FONT_[1]:getWidth(v:sub(1,#v))
      yy = curr_y
      xx = states.editor.text_area.x+15+FONT_[1]:getWidth(v:sub(1,col-(total_len-#v)))
      break
    end
    curr_y = curr_y + FONT_[1]:getHeight()
  end
  if xx and (xx >= (states.editor.text_area.x+15+tw) and xx >= (states.editor.text_area.x+states.editor.text_area.w-60)) then
    xx = states.editor.text_area.x+15
    yy = yy + FONT_[1]:getHeight()
  end
  return xx, yy, tw
end
--

function ei.import(filepath,_is_dropped)
  local f = filepath
  if _is_dropped then filepath = f:getFilename():match(".+[/\\](.-%.txt)$") end
  Timer.after(love.timer.getDelta(),function()
      local file, meta = load_file(f,_is_dropped)
      if file then notify{"white", "Viewing ", "yellow", filepath} states.editor.browser.close() else return end
      scene, page = states.editor.clear_scene(file[1])
      for i=2,#file do
        states.editor.new_page(i,file[i])
        scene[i].readonly = not validate_nonUTF8(file[i])
      end
      if _is_dropped then
        scene.filepath = ""
        scene.filename = filepath
      else
        scene.filepath, scene.filename = filepath:match("(.+)[/\\](.-%.txt)$")
      end
      page = states.editor.setpage(1)
      ei.update_wrapped()
      ei.add_history()
    end)
end
--
function ei.export(filepath,after,silent)
  after = after or function() end
  local notify = not silent and notify or function() end
  -- Aggregate data into text
  local final = ""
  for i,v in ipairs(scene) do
    if i>1 then final = final .. "\n\n" end
    final = final .. table.concat(v.text,"\n") .. (i<#scene and "~" or "")
  end
  -- Fix filepath
  if not filepath:match("%.txt$") then filepath = filepath..".txt" end

  local function save()
    if love.filesystem.write(filepath,final) then
      notify{"white", "Saved file as ", "green", filepath}
      scene.filepath, scene.filename = filepath:match("(.+)/(.-%.txt)$")
    else
      notify{"red", "ERROR: Could not save "..filepath}
    end
    states.editor.browser.close()
    after()
  end
  if love.filesystem.getInfo(filepath) then
    prompt("The file:\n"..filepath.."\nwill be overwritten. Is that okay?",{save},nil,"Overwrite File?")
  else
    save()
  end
end
--

local key_lookup = {
  ["return"] = function()
    local left, right = scene[page].text[scene[page].row]:sub(0,math.max(0,scene[page].cursor)), scene[page].text[scene[page].row]:sub(scene[page].cursor+1)
    scene[page].row = scene[page].row + 1
    scene[page].text[scene[page].row-1] = left
    table.insert(scene[page].text, scene[page].row, right)
    ei.update_wrapped()
    ei.set_cursor(0, true)
    ei.add_history()
  end,
  left = function()
    if scene[page].cursor == 0 then
      if scene[page].subrow == 1 and scene[page].row > 1 then
        scene[page].row = math.clamp(1, scene[page].row - 1, #scene[page].text)
        ei.set_cursor(#scene[page].text[scene[page].row])
      end
      return
    end
    ei.set_cursor(scene[page].cursor - 1)
  end,
  right = function()
    if scene[page].cursor == #scene[page].text[scene[page].row] then
      if scene[page].subrow == math.max(1,#scene[page].wrapped[scene[page].row]) and scene[page].row < #scene[page].text then
        scene[page].row = math.clamp(1, scene[page].row + 1, #scene[page].text)
        ei.set_cursor(0)
      end
      return
    end
    ei.set_cursor(scene[page].cursor + 1)
  end,
  up = function()
    ei.set_cursor(scene[page].cursor,nil,true)
    if (scene[page].subrow == 1 and scene[page].row == 1) or scene[page].selecting then return ei.set_cursor(0) end
    -- For within a row's subrows:
    if scene[page].subrow > 1 then
      ei.set_cursor(scene[page].cursor - #scene[page].wrapped[scene[page].row][scene[page].subrow-1])
    elseif scene[page].row > 1 then
      -- For trans-row movement:
      scene[page].row = math.clamp(1, scene[page].row - 1, #scene[page].text)
      local totalchar = 0
      for i=1, #scene[page].wrapped[scene[page].row]-1 do totalchar = totalchar + #scene[page].wrapped[scene[page].row][i] end
      ei.set_cursor(totalchar+scene[page].cursor)
    end
  end,
  down = function()
    ei.set_cursor(scene[page].cursor,nil,true)
    if (scene[page].subrow == #scene[page].wrapped[scene[page].row] and scene[page].row == #scene[page].text) or scene[page].selecting then return ei.set_cursor(#scene[page].text[scene[page].row]) end
    -- For within a row's subrows:
    if scene[page].subrow < #scene[page].wrapped[scene[page].row] then
      ei.set_cursor(scene[page].cursor + #scene[page].wrapped[scene[page].row][scene[page].subrow])
    else
      -- For trans-row movement:
      local totalchar = 0
      for i=1, #scene[page].wrapped[scene[page].row]-1 do totalchar = totalchar + #scene[page].wrapped[scene[page].row][i] end
      scene[page].row = math.clamp(1, scene[page].row + 1, #scene[page].text)
      ei.set_cursor(scene[page].cursor - totalchar)
    end
  end,
  home = function()
    local totalchar = 0
    for i=1, scene[page].subrow-1 do totalchar = totalchar + #(scene[page].wrapped[scene[page].row][i] or {}) end
    ei.set_cursor(totalchar)
  end,
  ["end"] = function()
    local totalchar = 0
    for i=1, scene[page].subrow do totalchar = totalchar + #(scene[page].wrapped[scene[page].row][i] or {}) end
    ei.set_cursor(totalchar)
  end,
  backspace = function()
    if scene[page].selecting then
      ei.erase_text(scene[page].selecting.s,scene[page].selecting.e)
      ei.add_history()
      return
    end
    if scene[page].cursor == 0 and scene[page].row == 1 then return end
    ei.erase_text({col=scene[page].cursor-1,row=scene[page].row},{col=scene[page].cursor-1,row=scene[page].row})
    ei.add_history()
  end,
  delete = function()
    if scene[page].selecting then
      ei.erase_text(scene[page].selecting.s,scene[page].selecting.e)
      ei.add_history()
      return
    end
    if scene[page].cursor == #scene[page].text[scene[page].row] and scene[page].row == #scene[page].text then return end
    ei.erase_text({col=scene[page].cursor,row=scene[page].row},{col=scene[page].cursor,row=scene[page].row})
    ei.add_history()
  end,
  tab = function()
    ei.insert_text("     ")
  end,
  a = function()
    if not (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then return end
    scene[page].selecting = {
      s = {col=0,row=1},
      e = {col=#scene[page].text[#scene[page].text],row=#scene[page].text}
    }
  end,
  c = function()
    if not (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then return end
    if not scene[page].selecting then return end
    local cb_text = ""
    local start, finish = scene[page].selecting.s.row < scene[page].selecting.e.row and scene[page].selecting.s.col or scene[page].selecting.e.col, scene[page].selecting.e.row > scene[page].selecting.s.row and scene[page].selecting.e.col or scene[page].selecting.s.col
    local start_row, finish_row = math.min(scene[page].selecting.s.row, scene[page].selecting.e.row), math.max(scene[page].selecting.s.row, scene[page].selecting.e.row)
    if start_row~=finish_row then
      cb_text = cb_text .. scene[page].text[start_row]:sub(start) .. "\n"
      for i = start_row+1, finish_row-1 do
        cb_text = cb_text .. scene[page].text[i]:sub(0,-1) .. "\n"
      end
      cb_text = cb_text .. scene[page].text[finish_row]:sub(0,finish)
    else
      local start, finish = math.min(scene[page].selecting.s.col,scene[page].selecting.e.col), math.max(scene[page].selecting.s.col,scene[page].selecting.e.col)
      cb_text = cb_text .. scene[page].text[start_row]:sub(start+1,finish)
    end
    love.system.setClipboardText(cb_text)
  end,
  v = function()
    if not (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then return end
  end,
  x = function()
    if not scene[page].selecting then return end
    ei.keypressed("c")
    ei.erase_text(scene[page].selecting.s,scene[page].selecting.e)
    ei.add_history()
  end,
  z = function()
    if not (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then return end
    return ei.undo()
  end,
  y = function()
    if not (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then return end
    return ei.redo()
  end,
  f = function()
    -- To-do: Create a real textbox module that shows as a pane when you Ctrl+F, just like ZeroBrane Studio does it. Enter/Return steps through each result.
    -- Ctrl+R splits the pane in two so you can type the search term and the replacement term right next to each other and step them independently. Again - ZeroBrane Studio.
    if not (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then return end
    input.show("Find:", nil, nil, function(txt)
        local s,e = nil, nil
        local row = nil
        for i,v in pairs(scene[page].text) do
          s,e = v:find(txt,0,true)
          if s and e then row = i break end
        end
        if row then
          s = s -1
          scene[page].row = row
          ei.set_cursor(s,true)
          scene[page].selecting = {
            s = {col=s,row=row},
            e = {col=e,row=row}
          }
        end
      end)
  end,
  r = function()
    return
--    if not (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then return end
  end,
  o = function()
    if not (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then return end
    return states.editor.browser.open(scene.filepath,1,scene)
  end,
  s = function()
    if not (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then return end
    return states.editor.browser.open(scene.filepath,2,scene)
  end,
}
setmetatable(key_lookup, { __call = function(t, ...) if type(t[...])=="function" then return t[...]() else return t[...] end end})
function ei.keypressed(key)
  if test_readonly() then return end
  key_lookup(key)
  ei.update_wrapped()
end
--
function ei.mousepressed(x,y,b)
  if not Misc.checkPoint(x,y,states.editor.text_area) then return end
  if test_readonly() then return end
  y = y-states.editor.scroller.y_offset

  if b==1 then
    local col, row = find_closest_char(x,y)
    scene[page].row = math.clamp(1, row or scene[page].row, #scene[page].text)
    ei.set_cursor(col)

    mouse_is_down = {row=scene[page].row, col=scene[page].cursor}
    ei.getXY(row or scene[page].row,col or scene[page].cursor)
    scene[page].selecting = nil
  end
  return true
end
--
function ei.mousereleased(x,y,b)
  y = y-states.editor.scroller.y_offset
  mouse_is_down = false
end
--
function ei.mousemoved(x,y,dx,dy)
  y = y-states.editor.scroller.y_offset
  if mouse_is_down then
    local col, row = find_closest_char(x,y)
    if not row or not col then return end
    if row~=mouse_is_down.row or col~=mouse_is_down.col then
      scene[page].selecting = {s={row=mouse_is_down.row,col=mouse_is_down.col},e={row=row,col=col}}
    end
  end
end
--
function ei.textinput(text)
  if test_readonly() then return end
  ei.insert_text(text)
  ei.set_cursor()
end
--
function ei.update(dt)
  local s, p = states.editor.share_locals()
  if p~=page then
    scene, page = s, p
    ei.update_wrapped()
  end
  if threshold_countdown <= 0 then
    event.grant("editor_input_threshold")
    threshold_countdown = threshold_base
  else
    threshold_countdown = threshold_countdown - 1 * dt
  end
end
--

return ei