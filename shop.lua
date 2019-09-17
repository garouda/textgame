local shop = {visible=false}

local list_of_shops = {}
local identity

local textbubble = require("textbubble")

local box = {
  x=screen_width/8,
  y=screen_height/3,
  w=screen_width*0.75,
  h=screen_height/3,
  alpha = 0,
  talpha = 0,
}
local slot = {
  y=box.y+box.h/2,
  dim=80,
  pad=0,
}
local FONT_ = {
  fonts.shop_prices,
  fonts.shop_funds,
  fonts.bmenu_category,
}
local priceboard = lg.newImage("res/img/transition.png")
local soldout = lg.newImage("res/img/soldout.png")
local info_delay = 0
local selected
local mouse_on
local closing
local namex

local visual_funds
local funds_overlay = 0

local fg_ui = {}
local textbubbles = {}
local list = {}
local item_buttons = {}

local function getList(s)
  local t = {}
  if list_of_shops[s[1]] then
    return list_of_shops[s[1]]
  end
  if not s[2] then return t end
  for i in s[2]:gmatch(";*%s*([^;]+)%s*;*%s*") do
    local item, stock = i:match("([^%*]+)%s*%**([%-%d%.]*)")
    item = item:gsub("^%s*(.-)%s*$","%1")
    local name = (items(item) or {}).name
    if name~="nil" and name~=nil then
      table.insert(t, {item=item, stock=tonumber(stock) or -1})
    end
  end
  return __.slice(t,1,6)
end
--

local function getSlotX(i) return box.x+box.w/2-((#list-1)*(slot.dim+slot.pad))/2+(slot.dim+slot.pad)*(i-1) end
--
local function flashFunds()
  Timer.script(function(wait)
      for i=1,2 do
        funds_overlay = 1
        wait(0.05)
        funds_overlay = 0
        wait(0.05)
      end
    end)
end
--

local function buy(i)
  for i,v in pairs(textbubbles) do v:close() end
  local value = items(list[i].item).value
  if player.money - value < 0 then
    flashFunds()
    return
  end
  if list[i].stock~=0 and inventory.add(list[i].item) then
    player.money = math.max(0, player.money - value)
    list[i].stock = (list[i].stock>0) and (list[i].stock - 1) or list[i].stock
  end
  if #list==0 then shop.close() end
end
--

local canvas
local function draw_lines()
  canvas = nil
  collectgarbage()
  canvas = lg.newCanvas(screen_width,screen_height)
  lg.setCanvas(canvas)
  lg.clear()
  lg.push()
  local sx, sy = Misc.toGame()
  lg.scale(1/sx, 1/sy)
  lg.setLineWidth(5)
  for i=1,screen_width/4 do
    lg.line((-screen_width/2)+15*(i-1), screen_height, 15*(i-1), 0)
  end
  lg.setLineWidth(1)
  lg.pop()
  lg.setCanvas()
end
--
draw_lines()
event.wish({"window_reset"}, draw_lines)

local done_button = newButton("Done", function() shop.close() end, screen_width/2-125/2, box.y+box.h+15, 125, 50)
local old_button_update = done_button.update
done_button.update = function(self,dt)
  old_button_update(self,dt)
  self.y = box.y+box.h+15
end
--
done_button.draw = function(self)
  local x,y,w,h = self.x, self.y, self.w, self.h
  local alpha = box.alpha/1.5
  if self.selected then alpha = (1+2/3)*box.alpha end
  lg.setLineWidth(2)
  lg.setColor(0,0,0,alpha)
  lg.rectangle("fill",x,y,w,h, 5)
  lg.setColor(1,1,1,alpha)
  lg.rectangle("line",x,y,w,h, 5)
  lg.setColor(0,0,0,alpha)
  lg.rectangle("line",x-1,y-1,w+2,h+2, 5)
  lg.setFont(fonts.element)
  lg.setColor(1,1,1,alpha*2)
  lg.print(self.label,x+w/2-fonts.element:getWidth(self.label)/2, y+h/2-fonts.element:getHeight()/2)
  if self.button_down then
    lg.setColor(1,1,1,box.alpha/4)
    lg.rectangle("fill",x,y,w,h, 5)
  end
  lg.setLineWidth(1)
end
--
local sell_button = Misc.tcopy(done_button)
sell_button.func = function() Gamestate.push(states.inventory,true) end
sell_button.x = sell_button.x + sell_button.w/2 + 5
done_button.x = done_button.x - done_button.w/2 - 5
sell_button.label = "Sell"

function shop.open(s)
  box.alpha = 0
  box.talpha = 0.9
  box.y = screen_height/3
  box.ty = screen_height/4
  namex = 0
  slot.pad = box.w/18
  visual_funds = player.money
  shop.visible = true
  closing = false
  identity = s[1]
  list = getList(s)
  list_of_shops[identity] = list
  if #list==0 then shop.close() end
  fg_ui = {
    done_button,
    sell_button,
    newButton("?", function() Misc.tutorial("shop") end, screen_width-30-15, 15, 30,30)
  }
  for i,v in pairs(list) do
    item_buttons[i] = newButton(v.item, function() buy(i) end, getSlotX(i)-slot.dim/2, 0, slot.dim, slot.dim, {mobile_friendly=true,visible=false})
  end
end
--
function shop.close()
  closing = true
  for i,v in pairs(textbubbles) do
    v:close()
    textbubbles[i] = nil
  end
  box.ty = screen_height/3
  box.talpha = -0.1
  list_of_shops[identity] = list
  out.next()
end
--
function shop.getShopList() return list_of_shops end
function shop.setShopList(l) list_of_shops = l or list_of_shops end
--

function shop.update(dt)
  if not shop.visible then return end
  box.y = Misc.lerp(6*dt, box.y, box.ty)
  box.alpha = Misc.lerp(5*dt, box.alpha, box.talpha)
  namex = Misc.lerp(9*dt, namex, 1)
  slot.y = box.y+box.h/2.4
  if box.alpha < 0 then shop.visible = false end
  items.updateIcons(dt)
  visual_funds = Misc.lerp(6*dt, visual_funds, player.money)
  for i,v in pairs(fg_ui) do v:update(dt) end
  textbubble.update(dt)

  selected = nil

  if closing then return end

  for i,v in pairs(list) do
    local mx, my = Misc.getMouseScaled()
    local x = getSlotX(i)
    local y = slot.y
    if mx > x-slot.dim/2 and mx < x + slot.dim/2 and my > y-slot.dim/2 and my < y + slot.dim/2 then
      selected = i
      if not textbubbles[i] and info_delay==0 then
        local info = items(v.item).name.."\n"..items(v.item).desc.."\n"
        for i,v in pairs(items(v.item).stats or {}) do if v~=0 then info = info.."("..Misc.capitalize(i:gsub("_"," "))..": "..v..")\n" end end
        textbubbles[i] = textbubble.new(info,x,y,-1)
      end
    else
      if textbubbles[i] then textbubbles[i]:close() textbubbles[i] = nil end
    end
    item_buttons[i].y = slot.y-slot.dim/2
    item_buttons[i]:update(dt) 
  end
  if not selected then info_delay = 1/4 else info_delay = math.max(0, info_delay - dt) end
end
--

function shop.draw()
  if not shop.visible then return end

  lg.setColor(0,0,0,0.5*box.alpha)
  lg.draw(canvas)

  lg.setFont(FONT_[3])
  lg.setColor(1,1,1,box.alpha)
  lg.print(out.location, screen_width/6-(screen_width/6-30)*namex, screen_height-FONT_[3]:getHeight()-15)

  local x,y,w,h = box.x, box.y, box.w, box.h
  lg.setLineWidth(2)
  lg.setColor(0,0,0,box.alpha)
  lg.rectangle("fill",x,y,w,h, 5)
  lg.setColor(1,1,1,box.alpha)
  lg.rectangle("line",x,y,w,h, 5)
  lg.setColor(0,0,0,box.alpha)
  lg.rectangle("line",x-1,y-1,w+2,h+2, 5)
  -- Draw player's money
  if true then
    local x,y = x+w, y-(FONT_[2]:getHeight()+10)
    local money = player.name.."'s Funds: G$"..math.round(visual_funds)
    lg.setFont(FONT_[2])
    local m_w = FONT_[2]:getWidth(money)+20
--    local x,y = x+w, y+h
    lg.setColor(0,0,0,box.alpha)
    lg.rectangle("fill",x-m_w,y,m_w,FONT_[2]:getHeight()+10, 5)
    lg.setColor(1,1,1,box.alpha)
    lg.rectangle("line",x-m_w,y,m_w,FONT_[2]:getHeight()+10, 5)
    lg.setColor(0,0,0,box.alpha)
    lg.rectangle("line",x-m_w-1,y-1,m_w+2,FONT_[2]:getHeight()+10+2, 5)
    lg.setColor(1,1,1,(1+2/3)*box.alpha)
    lg.print(money,x-(m_w-10),y+5)
    lg.setColor(1,0.25,0.3,box.alpha*funds_overlay)
    lg.rectangle("fill",x-m_w,y,m_w,FONT_[2]:getHeight()+10, 5)
    lg.setLineWidth(1)
  end

  for i,v in pairs(list) do
    -- Draw the item sprites and priceboards
    local raritycolor = {items.raritycolors[items(v.item).rarity][1],items.raritycolors[items(v.item).rarity][2],items.raritycolors[items(v.item).rarity][3],box.alpha}
    local x = getSlotX(i)
    local y = slot.y
    if selected == i then lg.setColor(1,1,1,1.25*box.alpha) else lg.setColor(1,1,1,box.alpha*0.75) end
    if mouse_on == i then lg.setColor(0.4,0.4,0.4,1.25*box.alpha) end
    items.drawIcon(v.item, x, y)--, slot.dim, slot.dim)
    if selected == i then raritycolor[4] = box.alpha else raritycolor[4] = box.alpha/3 end
    lg.setColor(raritycolor)
    if mouse_on == i then lg.setColor(0.4,0.4,0.4,2*box.alpha) end
    lg.rectangle("line",x-slot.dim/2, y-slot.dim/2, slot.dim, slot.dim, 5)
    lg.setColor(0,0,0,(1+2/3)*box.alpha)
    lg.draw(priceboard, x-(slot.dim+25)/2, y+slot.dim/2, -0.15, (slot.dim+10)/priceboard:getWidth()*1.15, (slot.dim/2)/priceboard:getHeight()*1.05)
    local price_col = {}
    if selected == i then price_col = {1,1,1,1.25*box.alpha} else price_col = {1,1,1,0.55*box.alpha} end
    if mouse_on == i then price_col[1],price_col[2],price_col[3] = price_col[1]*0.4,price_col[2]*0.4,price_col[3]*0.4 end
    if items(v.item).value > player.money then price_col[2],price_col[3] = price_col[2]/2, price_col[3]/2 end
    lg.setColor(price_col)
    lg.draw(priceboard, x-(slot.dim+20)/2, y+slot.dim/2, -0.15, (slot.dim+10)/priceboard:getWidth()*1.1, (slot.dim/2)/priceboard:getHeight())
    if list[i].stock == 0 then
      lg.setColor(0.8,0.3,0.3,1*box.alpha)
      lg.draw(soldout, x-slot.dim/2, y-slot.dim/2)
    end
    lg.setColor(0,0,0,(1+2/3)*box.alpha)
    lg.setFont(FONT_[1])
    local comma_value = Misc.comma_value(items(v.item).value)
    lg.print("G$"..comma_value, x-FONT_[1]:getWidth("G$"..comma_value)/2, y+slot.dim/2)
  end

  for i,v in pairs(fg_ui) do v:draw() end
  
  textbubble.draw()

  lg.setColor(1,1,1)
end
--

function shop.keypressed(key)
  if not shop.visible then return end
  if keyset.back(key) then shop.close() end
  return true
end
--

function shop.mousepressed(x,y,b,t)
  if not shop.visible then return end
  if prompt.box.visible then return true end
  local mx, my = x,y
  mouse_on = nil
  for i,v in pairs(list) do
    local x = getSlotX(i)
    local y = slot.y
    if mx > x-slot.dim/2 and mx < x + slot.dim/2 and my > y-slot.dim/2 and my < y + slot.dim/2
    and v.stock ~= 0
    and selected == i then
      mouse_on = i
    end
  end
  for i,v in pairs(item_buttons) do if list[i].stock~=0 then v:mousepressed(x,y,b) end end
  for i,v in pairs(fg_ui) do v:mousepressed(x,y,b) end
  return true
end
--

function shop.mousereleased(x,y,b,t)
  if not shop.visible then return end
  if prompt.box.visible then return true end
  local mx, my = x,y
  for i,v in pairs(item_buttons) do v:mousereleased(x,y,b) end
  for i,v in pairs(fg_ui) do v:mousereleased(x,y,b) end
  textbubble.mousereleased(x,y,b,t)
  mouse_on = nil
  return true
end
--

return shop