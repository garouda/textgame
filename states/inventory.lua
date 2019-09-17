local st = {}
local newDropdown = require("elements.dropdown")
local newScroller = require("elements.scroller")
items = require("items")
st.keyboard_focus = 0
st.selected = 0

st.list = {}

st.limit = 60
local row_max = st.limit/10
local base = {}
local slot_dim = screen_height/7
--local slot_dim = 80
base.slots={
  x=screen_width/2-((slot_dim+16)*row_max)/2+16/2, y=slot_dim, w=slot_dim, h=slot_dim, pad=16
}
base.name={
  x=0, y=base.slots.y+(base.slots.pad+base.slots.h)*3, w=screen_width, h=screen_height/12
}
base.desc={
  x=0, y=base.name.y+base.name.h, w=screen_width, h=screen_height-(base.name.y+base.name.h)
}
--
local funds = 0
local sellmode
local holdtime = 0
local grabbed_item = -1
local holding
local slide = {x=0, y=0}
local lerping
local mouse_on = {up=nil,down=nil}
local bar = lg.newImage("res/img/inv_bar.png")
local border_offset = 0
local border_offset_dir = 1
local fg_ui = {}
local released_touch_on_item = 0
local scroller
local dropdown = newDropdown({"Date", "Rarity", "Value", "Type"},function(i,v) return st.sort(i) end)

local FONT_ = {
  fonts.inventory_titles,
  fonts.inventory_amounts,
  fonts.inventory_names,
  fonts.inventory_descs,
  fonts.inventory_boosts,
  fonts.inventory_boosts_bold,
}

local function get_selected()
  local x,y = Misc.getMouseScaled()
  y = y - scroller.y_offset
  local sx, sy, sww = base.slots.x, base.slots.y, (base.slots.w+base.slots.pad)
  local lim = st.limit-1
  local y_o = -1
--  if y >= (base.name.y - scroller.y_offset) then return st.selected end
  for i=0,lim do
    if i%row_max==0 then y_o = y_o + 1 end
    local ix = (sx + sww * i) - (sww*y_o*row_max)
    local iy = sy + (base.slots.w+base.slots.pad) * (y_o)
    local iw = base.slots.w
    local ih = base.slots.h
    if x > ix and y > iy and x < ix + base.slots.w and y < iy + base.slots.h then
      st.selected = i+1
    end
  end

  return st.selected
end
--
local function set_selected(s)
  local sx, sy, sww = base.slots.x, base.slots.y, (base.slots.w+base.slots.pad)
  local lim = st.limit
  local y_o = -1
  local slots = {}
  for i=1,lim do
    if (i-1)%row_max==0 then y_o = y_o + 1 end
    local ix = (sx + sww * (i-1)) - (sww*y_o*row_max)
    local iy = sy + (base.slots.w+base.slots.pad) * (y_o)
    local iw = base.slots.w
    local ih = base.slots.h
    slots[i] = {x=ix,y=iy,w=iw,h=ih}
  end
  s = math.clamp(1, s, st.limit)

  local diff1 = ((slots[s].y+slots[s].h)-(base.slots.y)-scroller.y_offset_target) - (base.slots.y+(base.slots.h*2+base.slots.pad*2))
  local diff2 = (slots[s].y)-(base.slots.y) - scroller.y_offset_target
  local diff = 0
  if diff1 > 0 then diff = diff1 elseif diff2 < 0 then diff = diff2 end
  scroller.y_offset_target:moveTo(scroller.y_offset_target+diff)

  st.selected = s

  return st.selected
end
--

local function attempt_discard(i)
  if items(st.list[i].item).important then
    notify{items.raritycolors[items(st.list[i].item).rarity], items(st.list[i].item).name, "white", " cannot be discarded."}
  else
    prompt('Are you sure you want to discard '..st.list[i].no..' "'..items(st.list[i].item).name..'"?', {function() st.destroy(i,st.list[i].no) end})
  end
end
--
local function drop_grabbed(t)
  if grabbed_item <= 0 then return end
  t = t or get_selected()
  if t == 0 then
    t = grabbed_item
    attempt_discard(t)
  end
  st.move(grabbed_item, t)
  grabbed_item = -1
end
--

function st.add(id,num)
  id = id:lower()
  if not items(id) then return end
  num = num or 1
  local time = os.time()
  local notification_text = {"white", "You obtained ", items.raritycolors[items(id).rarity], items(id).name, "white", "!"}

  for i,v in pairs(st.list) do
    if v.item==id and v.no<(items(id).max or 99) then
      v.no=v.no+num
      notify(notification_text)
      return true
    end
  end
  for i=1, st.limit do
    if not st.list[i] then
      st.list[i] = {item=id,no=num,time=time}
      notify(notification_text)
      return true
    end
  end
  if #st.list == 0 then st.list[1] = {item=id,no=num,time=time}
    notify(notification_text)
    return true
  end

  notify{"Your bag is too full."}
  return false
end
--
function st.use(index,no_destroy)
  if not st.list[index] then return end
  items(st.list[index].item).func()
  if not no_destroy then st.destroy(index) end
end
--
function st.sell(index,amount)
  if not st.list[index] then return end
  amount = amount or 1
  if items(st.list[index].item).important then
    return notify("["..(items(st.list[index].item).name.."](color: %f,%f,%f; bold)[ cannot be sold.](white)"):format(unpack(items.raritycolors[items(st.list[index].item).rarity])))
  end
  prompt('Sell "'..items(st.list[index].item).name..' x'..amount..' for G$'..math.ceil(items(st.list[index].item).value*(2/3)*amount)..'?',
    {function()
        player.money = player.money + math.ceil(items(st.list[index].item).value*(2/3)) * amount
        st.destroy(index,amount)
      end})
end
--
function st.destroy(index,amount)
  if st.list[index] then
    if player.equipped[items(st.list[index].item).equip]==index then st.setEquip(index) end
    st.list[index].no = st.list[index].no - (amount or 1)
    if st.list[index].no <= 0 then st.list[index] = nil end
  end
end
--
function st.setEquip(index)
  local kind = items(st.list[index].item).equip
  if player.equipped[kind] then
    -- If any equipment of this type is already equipped
    for i,v in pairs(items(st.list[player.equipped[kind]].item).stats) do
      player:removeBoost(i,v)
    end
    for i,v in pairs(items(st.list[player.equipped[kind]].item).skills) do
      player:removeSkill(v,true)
    end
  end
  if player.equipped[kind]==index then
    -- If the specific item in this inventory slot is already equipped
    player.equipped[kind] = nil
    if items(st.list[index].item).unequip_func then items(st.list[index].item).unequip_func() end
    return
  end
  player.equipped[kind]=index
  for i,v in pairs(items(st.list[index].item).stats) do
    player:addBoost(i,v)
  end
  for i,v in pairs(items(st.list[index].item).skills) do
    player:addSkill(v,true)
  end
  if items(st.list[index].item).func then items(st.list[index].item).func() end
end
--
function st.move(index,target)
  local temp_ = Misc.tcopy(st.list[index])
  local equip = {items(st.list[index].item).equip, items((st.list[target] or {}).item).equip}
  equip = {player.equipped[equip[1]]==index and equip[1] or nil, player.equipped[equip[2]]==target and equip[2] or nil}
  if equip[1] then player.equipped[equip[1]] = target end
  if equip[2] then player.equipped[equip[2]] = index end
  st.list[index] = Misc.tcopy(st.list[target])
  st.list[target] = temp_
end
--
function st.contains(item)
  item = tostring(item)
  for i,v in pairs(st.list) do if v.item:lower() == item:lower() then return i end end
  return nil
end
--
function st.get(index)
  return items((st.list[index] or {}).item)
end
--
function st.sort(method)
  method = method or 1
  local _equipped = {}
  for i,v in pairs(player.equipped) do _equipped[i] = st.list[v] end
  local sorts = {
    -- Transfer items to a new table so that the list condenses, eliminating blank spaces between items
    function()
      -- Sort by Date
      local temp = {}
      for i,v in pairs(st.list) do table.insert(temp, v) st.list[i] = nil end
      st.list = temp
      return table.sort(st.list,function(f,s) return f.time < s.time end)
    end,
    function()
      -- Sort by Rarity
      local temp = {}
      for i,v in pairs(st.list) do table.insert(temp, v) st.list[i] = nil end
      st.list = temp
      return table.sort(st.list,function(f,s) return items(f.item).rarity > items(s.item).rarity end)
    end,
    function()
      -- Sort by Value
      local temp = {}
      for i,v in pairs(st.list) do table.insert(temp, v) st.list[i] = nil end
      st.list = temp
      return table.sort(st.list,function(f,s) return items(f.item).value > items(s.item).value end)
    end,
    function()
      -- Sort by Type (Equip, Usable, and Misc)
      local temp = {}
      for i,v in pairs(st.list) do if items(v.item).equip then table.insert(temp, v) st.list[i] = nil end end
      table.sort(temp, function(f,s) return items(f.item).equip < items(s.item).equip end)
      for i,v in pairs(st.list) do if items(v.item).func and not items(v.item).equip then table.insert(temp, v) st.list[i] = nil end end
      for i,v in pairs(st.list) do if not items(v.item).func and not items(v.item).equip then table.insert(temp, v) st.list[i] = nil end end
      st.list = temp
    end,
  }
  sorts[method]()
  -- Correct stored indices for equipped items
  for i,v in pairs(st.list) do
    if items(v.item).equip then
      for ii,vv in pairs(_equipped) do
        if v==vv then player.equipped[ii] = i end
      end
    end
  end
end
--
function st.clear()
  st.list = {}
end
--

function st:init()
  fg_ui["Return"] = newButton("Return", function() self.prep_leave() end, 30, screen_height-screen_height/6.5, 125, 50)
  fg_ui["Sort"] = newButton("Sort", function() dropdown:open(screen_width-125/2-30, screen_height/6.5+25) end, screen_width-125-15, screen_height/6.5, 125, 50)
  fg_ui["?"] = newButton("?", function() Misc.tutorial("inventory") end, screen_width-30-15, screen_height/6.5+50+15, 30,30)
  scroller = newScroller(0, 0, ((st.limit-row_max*3)/row_max)*(base.slots.pad+base.slots.w), screen_width*(4/5), base.slots.y, 3*(base.slots.pad+base.slots.w)-base.slots.pad)
end
--
function st:enter(_,sell)
  sellmode = sell
  lerping = true
  scroller:snapTo(screen_height/10)
  scroller:moveTo(0)
  slide.tween = Flux.to(slide, 0.3, {x=-screen_width-1}):ease("quadout"):oncomplete(function() lerping = false end)
  funds = player.money
end
--

local old_isDown = love.mouse.isDown
function st:update(dt)
  love.mouse.isDown = old_isDown
  if lerping then
    love.mouse.isDown = function()
      return false
    end
  end

  items.updateIcons(dt)

  if prompt.box.visible then return end

  funds = Misc.lerp(5*dt, funds, player.money)

  if dropdown:update(dt) then return end
  scroller:update(dt)

  for i,v in pairs(fg_ui) do v:update(dt) end

  if st.keyboard_focus==0 then
    st.selected = 0
    if get_selected()==0 then get_selected(true) end
  end

  if holding then holdtime = holdtime + dt else drop_grabbed() end
  if holdtime >=1 and sellmode then
    st.sell(st.selected,st.list[st.selected].no)
    holdtime = 0
    holding = false
    mouse_on.down = nil
  end
end
--
function st:draw()
  if slide.x > -screen_width and Gamestate.current() == states.inventory then
    lg.push()
    lg.translate(slide.x,slide.y)
    states.game.draw()
    lg.pop()
  end
  lg.push()
  lg.translate(math.floor(slide.x+1)+screen_width,slide.y)

  lg.setLineWidth(2)

  -- Item Slot
  lg.stencil(function() lg.draw(bar) lg.rectangle("fill",0,base.name.y,screen_width,screen_height-base.name.y) end, "increment", 1)
  lg.setStencilTest("less",1)
  lg.push() lg.translate(0,scroller.y_offset)
  local y_o = -1
  for i=0,st.limit-1 do
    if i % row_max == 0 then y_o = y_o + 1 end
    local w = (base.slots.pad+base.slots.w)

    lg.setColor(0,0,0,0.15)
    local x,y = (base.slots.x+16+w*i)-(w*y_o*row_max)+base.slots.w-32+1, base.slots.y+16+w*y_o+(base.slots.h-32)/2
    if (i+1) % row_max ~= 0 then Misc.fadeline(x, y, nil, base.slots.w-32, 2) end
    if i+1 <= st.limit-row_max then Misc.fadeline(x-(base.slots.w-32)/2, y+(base.slots.h-32)/2, math.pi/2, base.slots.w-32, 2) end

    if y + base.slots.h + scroller.y_offset > base.slots.y and y + scroller.y_offset < base.name.y + base.slots.h/2 then

      lg.setColor(0,0,0,0.7)
      if st.list[i+1] and i+1~=grabbed_item then
        lg.rectangle("fill", (base.slots.x+w*i)-(w*y_o*row_max), base.slots.y+w*y_o, base.slots.w, base.slots.h, 12, 12)
        lg.setColor(1,1,1)
        items.drawIcon(st.list[i+1].item, (base.slots.x+w*i)-(w*y_o*row_max)+base.slots.w/2, base.slots.y+w*y_o+base.slots.h/2, base.slots.w*(2/3), base.slots.h*(2/3))
        if i+1 == mouse_on.down and i+1 == st.selected then
          lg.setColor(0,0,0,0.4)
          lg.rectangle("fill", (base.slots.x+w*i)-(w*y_o*row_max), base.slots.y+w*y_o, base.slots.w, base.slots.h, 12, 12)
        end
        if i+1 == st.selected then
          lg.setColor(1,1,1)
          lg.rectangle("line", (base.slots.x+w*i)-(w*y_o*row_max), base.slots.y+w*y_o, base.slots.w, base.slots.h, 12, 12)
        end
        if st.list[i+1].no > 1 then
          lg.setColor(1,1,1)
          lg.setFont(FONT_[2])
          lg.print("x"..st.list[i+1].no, (base.slots.x+w*i)-(w*y_o*row_max)+base.slots.w-FONT_[2]:getWidth("x"..st.list[i+1].no)-5, base.slots.y+w*y_o+5)
        end
        if st.list[i+1] and player.equipped[items(st.list[i+1].item).equip]==i+1 then
          lg.setColor(0,0,0)
          lg.rectangle("fill", (base.slots.x+w*i)-(w*y_o*row_max), base.slots.y+w*y_o+base.slots.h-FONT_[2]:getHeight(), FONT_[2]:getWidth("Equipped")+2, FONT_[2]:getHeight())
          lg.setColor(1,1,1)
          lg.setLineWidth(1)
          lg.rectangle("line", (base.slots.x+w*i)-(w*y_o*row_max), base.slots.y+w*y_o+base.slots.h-FONT_[2]:getHeight(), FONT_[2]:getWidth("Equipped")+2, FONT_[2]:getHeight())
          lg.setLineWidth(2)
          lg.setColor(1,1,1)
          lg.setFont(FONT_[2])
          lg.print("Equipped", (base.slots.x+w*i)-(w*y_o*row_max)+2, base.slots.y+w*y_o+base.slots.h-FONT_[2]:getHeight())
        end
      else
        lg.setColor(0,0,0,0.45)
        lg.rectangle("fill", (base.slots.x+16+w*i)-(w*y_o*row_max), base.slots.y+16+w*y_o, base.slots.w-32, base.slots.h-32, 12, 12)
        lg.setColor(1,1,1,0.08)
        lg.rectangle("line", (base.slots.x+16+w*i)-(w*y_o*row_max), base.slots.y+16+w*y_o, base.slots.w-32, base.slots.h-32, 12, 12)
        if i+1==st.selected then
          lg.setColor(1,1,1)
          lg.rectangle("line", (base.slots.x+16+w*i)-(w*y_o*row_max), base.slots.y+16+w*y_o, base.slots.w-32, base.slots.h-32, 12, 12)
        end
      end
    end
  end
  lg.pop()
  lg.setStencilTest()

  -- Name Box
  lg.setColor(0,0,0)
  Misc.fadeline(base.name.x, base.name.y, nil, nil, base.name.h)
  lg.setColor(1,1,1,0.5)
  Misc.fadeline(base.name.x, base.name.y)

  -- Description Box
  Misc.fadeline(base.desc.x, base.desc.y)
  lg.setColor(0,0,0,0.25)
  lg.rectangle("fill", base.desc.x, base.desc.y, base.desc.w, base.desc.h)

  -- Print name and desc
  if st.selected > 0 and st.list[st.selected] and st.selected~=grabbed_item then
    local i = items(st.list[st.selected].item)
    local type = i.func and "Use" or i.equip and "Equip" or "Etc"
    lg.setFont(FONT_[3])
    local r,g,b = unpack(items.raritycolors[i.rarity])
    lg.setColor(r+0.1,g+0.1,b+0.1)
    lg.printf(i.name, base.name.x, base.name.y+3, base.name.w, "center")
    lg.setFont(FONT_[6])
    lg.setColor(1,1,1,1/2)
    lg.print("("..type..")", base.name.x+base.name.w/2+FONT_[3]:getWidth(i.name)/2+20, base.name.y+12)
    lg.print("G$"..math.ceil(i.value*(2/3)), base.name.x+base.name.w/2-FONT_[3]:getWidth(i.name)/2-FONT_[6]:getWidth("G$"..math.ceil(i.value*(2/3)))-20, base.name.y+12)
    lg.setFont(FONT_[4])
    local w = screen_width/5
    local _, _wrap = FONT_[4]:getWrap(i.desc, base.desc.w-w*2)
    lg.setColor(1,1,1)
    lg.printf(i.desc, base.desc.x+w, base.desc.y+base.desc.h/2-(FONT_[4]:getHeight()/2*#_wrap), base.desc.w-w*2, "center")
    -- Display stat boosts if any
    if i.stats then
      local len = 0
      for _,_ in pairs(i.stats) do if tonumber(_)~=0 then len = len + 1 end end
      local ind = 0
      for k,v in pairs(i.stats) do
        if tonumber(v)~=0 then
          local sign = (function() if tonumber(v)>0 then return "+" else return "" end end)()
          local equipped_item = items((st.list[player.equipped[i.equip]] or {}).item or "nil")
          -- change color & font based on stat gain or loss
          lg.setFont(FONT_[6])
          if tonumber(v) > tonumber(equipped_item.stats[k]) then lg.setColor(0.2,1,0.1)
          elseif tonumber(v) < tonumber(equipped_item.stats[k] or tonumber(v)-1) then lg.setColor(1,0.2,0.1)
          else
            lg.setFont(FONT_[5])
            lg.setColor(0.65,0.65,0.65)
          end
          lg.printf(k:upper().." "..sign..v, base.desc.w-w, base.desc.y+base.desc.h/2-lg.getFont():getHeight()/2-(lg.getFont():getHeight()*ind)+(lg.getFont():getHeight()/2*(len-1)), w, "center")
          ind = ind + 1
        end
      end
    end
  end

  -- Print currency
  local currency = "Funds: G$"..Misc.comma_value(math.round(funds))
  lg.stencil(function() lg.rectangle("fill",0,0,screen_width,22.5) end, "replace", 1)
  lg.setStencilTest("equal", 0)
  lg.setColor(0,0,0,0.6)
  lg.rectangle("fill", screen_width-32-FONT_[4]:getWidth(currency), -8, FONT_[4]:getWidth(currency)+64, 32+FONT_[4]:getHeight()+16, 12)
  lg.setColor(0,0,0,0.35)
  lg.rectangle("fill", screen_width-32-FONT_[4]:getWidth(currency)-4, -4, FONT_[4]:getWidth(currency)+64, 32+FONT_[4]:getHeight()+16, 16)
  lg.setFont(FONT_[4])
  lg.setColor(1,1,1,0.8)
  lg.printf(currency, 0, 32, screen_width-16, "right")
  lg.setStencilTest()

  for i,v in pairs(fg_ui) do v:draw() end

-- Grabbed item
  if st.list[grabbed_item] then
    local mx,my = Misc.getMouseScaled()
    items.drawIcon(st.list[grabbed_item].item, mx, my, base.slots.w*(2/3), base.slots.h*(2/3))
  end

  lg.setColor(1,1,1,0.7)
  lg.draw(bar,0,0,nil,screen_width/bar:getWidth(),1)
  lg.setColor(1,1,1,0.35)
  lg.stencil(function() lg.rectangle("fill",screen_width-36-FONT_[4]:getWidth(currency),22,screen_width,screen_height) end, "replace", 1)
  lg.setStencilTest("equal", 0)
  lg.draw(bar,0,4,nil,screen_width/bar:getWidth(),1)
  lg.setStencilTest()
  lg.setColor(1,1,1)
  lg.setFont(FONT_[1])
  lg.printf("Inventory", 0, 8, screen_width, "center")

  dropdown:draw()
  scroller:draw()

  lg.pop()

  lg.setLineWidth(1)
  lg.setColor(1,1,1)
end
--

function st:prep_leave()
  lerping = true
  prompt.close()
  Flux.to(slide, 0.3, {x=0}):ease("quadout"):oncomplete(Gamestate.pop)
end
--
function st:keypressed(key)
  if lerping then return end

  if grabbed_item>=0 then return end

  st.keyboard_focus = 1    
  if keyset.left(key) then
    if (st.selected-1)%(st.limit/10)==0 or st.selected == 1 then
      set_selected(st.selected + st.limit/10 - 1)
    else
      set_selected(st.selected-1)
    end
  end
  if keyset.right(key) then
    if (st.selected)%(st.limit/10)==0 then
      set_selected(st.selected - st.limit/10 + 1)
    else
      set_selected(st.selected+1)
    end
  end
  if keyset.up(key) then
    if st.selected >= 1 and st.selected <= (st.limit/10) then st.selected = st.selected+st.limit end
    set_selected(st.selected-(st.limit/10))
  end
  if keyset.down(key) and st.selected <=st.limit*2+1 then
    if st.selected > st.limit-(st.limit/10) and st.selected <= st.limit then set_selected(st.selected-(st.limit-(st.limit/10))) return end
    set_selected(st.selected+(st.limit/10))
  end
  if keyset.confirm(key) and st.selected <= st.limit and st.list[st.selected] then
    if sellmode then
      st.sell(st.selected)
    else
      if items(st.list[st.selected].item).equip then
        st.setEquip(st.selected)
      elseif items(st.list[st.selected].item).func then
        prompt('Use "'..items(st.list[st.selected].item).name..'"?',{function() st.use(st.selected) end})
      end
    end
  end
  if keyset.back(key) or keyset.inventory(key) then
    self.prep_leave()
  end
  if key=="delete" and st.list[st.selected] then
    attempt_discard(st.selected)
  end
  if key=="0" then self.sort() end
end
--

local mvtotal = 0
function st:mousemoved(x,y,dx,dy)
  if lerping or prompt.box.visible then return end
  if holding then mvtotal = mvtotal + math.abs(dx)+math.abs(dy) end
  if mvtotal>=15 and mouse_on.down==st.selected and mouse_on.down>0 and grabbed_item<0 and st.list[mouse_on.down] then
    grabbed_item = mouse_on.down
    mvtotal = 0
  end
end
--

function st:mousepressed(x,y,b,t)
  if lerping then return end
  if b==3 then return end
  if prompt.box.visible then return end
  if dropdown.visible and not dropdown:mousepressed(x,y,b) then return dropdown:close() end
  if b==2 then return self.prep_leave() end
  scroller:checkArea(x,y, {0,0,screen_width,screen_height})
  for i,v in pairs(fg_ui) do v:mousepressed(x,y,b) end
  st.keyboard_focus = 0
  mouse_on.down = get_selected()
  holding = true
  holdtime = 0
end
--
function st:mousereleased(x,y,b,t)
  if prompt.box.visible or lerping then mouse_on.down = nil return end
--  mouse_on.up = st.selected
  mouse_on.up = get_selected()
--  if st.selected > 0 and holdtime < 1 and mouse_on.down == mouse_on.up and st.list[st.selected] then
  if b==1 and mouse_on.down == mouse_on.up and st.list[st.selected] and mvtotal < 15 then
    if (released_touch_on_item==st.selected or love.system.getOS()~="Android") then
      if grabbed_item > 0 then drop_grabbed(grabbed_item) end
      if sellmode then
        st.sell(st.selected)
      else
        if items(st.list[st.selected].item).equip then
          st.setEquip(st.selected)
        elseif items(st.list[st.selected].item).func then
          prompt('Use "'..items(st.list[st.selected].item).name..'"?',{function() st.use(st.selected) end})
        end
      end
    end
  end
  if t then released_touch_on_item = st.selected end
  for i,v in pairs(fg_ui) do v:mousereleased(x,y,b) end
  mouse_on.down = nil
  holding = false
  holdtime = 0
  mvtotal = 0
  dropdown:mousereleased(x,y,b)
end
--
function st:wheelmoved(x,y)
  if dropdown:wheelmoved(x,y) then return end
  if scroller:wheelmoved(x,y) then return end
end
--
function st:touchmoved(id,x,y,dx,dy)
  if lerping or prompt.box.visible then return end
  if dropdown:touchmoved(id,x,y,dx,dy) then return end
  if grabbed_item<=0 and scroller:touchmoved(id,x,y,dx,dy) then return end
end
--
function st:leave()
  slide.tween:stop()
  slide.x,slide.y = 0,0
  scroller:snapTo(0)
  lerping = false
  st.keyboard_focus = 0
  mouse_on.down = nil
  mouse_on.up = nil
  holding = false
end
--

inventory = {add=st.add, use=st.use, destroy=st.destroy, setEquip=st.setEquip, move=st.move, contains=st.contains, get=st.get, clear=st.clear}
return st