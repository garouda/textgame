local hp = {}
local box = {
  x=screen_width,
  tx=screen_width,
  y=screen_height/4,
  w=screen_width/5,
  h=24+20
}
local FONT_ = {
  fonts.debug,
}

local init
local active
local time = 0
local overlay
local colors = {{1,0.5,0.4},{0.5,1,0.4},alpha=0}
local difference = box.w-20
local amount = 0
local smooth_hp

function hp.init() init = true end

function hp.show(col,a)
  col = col or 1
  time = 1.25
  box.x = screen_width - box.w - 15
  box.tx = box.x
  colors.alpha = 1
  overlay = col
  amount = a
  if col == 2 then a = math.clamp(0, player:getStat("max_hp")-player.hp, player:getStat("max_hp")) end
  local adj_hp = col==1 and player.hp+a or player.hp-a
  difference = math.max(0,(box.w-20)*(adj_hp/player:getStat("max_hp")))
  smooth_hp = adj_hp
  active = true
end
--
function hp.hide()
  box.tx = screen_width*1.2
  active = false
end
--

function hp.update(dt)
  box.x = Misc.lerp(5*dt, box.x, box.tx)
  if time <= 0 then
    if active then hp.hide() end
    return
  end
  time = time - dt
  difference = Misc.lerp(6*dt, difference, math.max(0,(box.w-20)*(player.hp/player:getStat("max_hp"))))
  colors.alpha = Misc.lerp(3*dt, colors.alpha, 0)
  smooth_hp = Misc.lerp(6*dt, smooth_hp, player.hp)
end
--

function hp.draw()
  local x,y,w,h = box.x, box.y, box.w, box.h
  if box.x >= screen_width then return end
  lg.setLineWidth(2)
  lg.setColor(0,0,0,0.6)
  lg.rectangle("fill",x,y,w,h, 5)
  lg.setColor(1,1,1,0.6)
  lg.rectangle("line",x,y,w,h, 5)
  lg.setColor(0,0,0,0.6)
  lg.rectangle("line",x-1,y-1,w+2,h+2, 5)

  if true then
    lg.setLineWidth(1)
    lg.setFont(FONT_[1])
    local width = difference
    local height = 24
    local x, y = x + 10, y + 10
    -- HP bar
    lg.setColor(0.3,0.2,0.2,1)
    lg.rectangle("fill",x,y,w-20,height)
    ---- the "behind" part that lowers slowly with lerp
    lg.setColor(1,0.8,0.8,0.3)
    lg.rectangle("fill",x,y,difference,height)
    ---- the red part, display HP with no lerping
    lg.setColor(0.55,0.2,0.2,1)
--    lg.rectangle("fill",x,y,width,height)
    lg.rectangle("fill",x,y,width,height)
    ---- subtle top and bottom lines, for definition
    lg.setColor(1,1,1,0.3)
    lg.line(x,y,x+width,y)
    lg.setColor(0.1,0.1,0.2,0.6)
    lg.line(x,y+height,x+width,y+height)
    local smooth_hp = math.round(smooth_hp)
    for o=-2,2,4 do
      lg.setColor(0,0,0,0.5)
      lg.printf("HP: "..smooth_hp.."/"..player:getStat("max_hp"), x+o,y+(height/2-FONT_[1]:getHeight()/2), w-20, "center")
      lg.printf("HP: "..smooth_hp.."/"..player:getStat("max_hp"), x,y+(height/2-FONT_[1]:getHeight()/2)+o, w-20, "center")
    end
    lg.setColor(1,1,1,0.9)
    lg.printf("HP: "..smooth_hp.."/"..player:getStat("max_hp"), x,y+(height/2-FONT_[1]:getHeight()/2), w-20, "center")
  end
  local r,g,b = unpack(colors[overlay])
  lg.setColor(r,g,b,colors.alpha*0.66)
  lg.rectangle("fill",x,y,w,h, 5)
  lg.setColor(r,g,b,colors.alpha*3)
  lg.printf((overlay==2 and "+" or "-")..amount, x,y-h/1.5+(h/1.5)*(colors.alpha), w, "center")
  lg.setLineWidth(1)
end
--

return hp