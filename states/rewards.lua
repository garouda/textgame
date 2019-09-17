local st = {}

local FONT_ = {
  fonts.rewards_large,
  fonts.rewards_medium,
  fonts.rewards_small,
}
st.flux = Flux.group()

local reward_ui = {}
reward_ui.title = {
  x = -screen_width/4,
  tx = 15,
  y = 0,
  w = screen_width,
  h = FONT_[1]:getHeight(),
  alpha = 0,
}
reward_ui.exp = {
  x = 0,
  y = 0,
  w = screen_width-15,
  h = FONT_[1]:getHeight(),
  alpha = 0,
}
reward_ui.party = {
  x = screen_width/8,
  y = reward_ui.title.y+reward_ui.title.h+30,
  iy = {
    25,
    25,
    25,
  },
  pad = 30,
  w = 0, -- See st:enter for formula
  h = screen_height/6,
  col = {
--    {1,0.75,0.2},
    {0,0,0},
    {0,0,0},
    {0,0,0},
  },
  alpha = {
    0,
    0,
    0,
  },
  start_exp_anim = false,
  levelup = {
    false,
    false,
    false,
  },
}
reward_ui.items = {
  x = 0,
  y = reward_ui.party.y+reward_ui.party.h+40,
  w = screen_width,
  h = screen_height/7,
  dim = 50,
  pad = 60,
  alpha = 0,
}
--
local proto_reward_ui = Misc.tcopy(reward_ui)
local party = {}
local orig_party = {}
local combat_exp = 0
local combat_exp_countup = 0
local level_up_effect = {
  particles.radial:clone(),
  particles.radial:clone(),
  particles.radial:clone(),
}
local done_button = newButton("Finish", function() st.prep_leave() end, screen_width/2-125/2, screen_height-screen_height/8-(15+50), 125, 50, {inactive=true})

local function exp_anim(dt)
  local seconds = 1
  for i,v in pairs(party) do
    if v.exp < orig_party[i].exp+combat_exp then
      v.exp = v.exp + combat_exp/seconds * dt
      v.visual_exp = v.visual_exp + combat_exp/seconds * dt
    end
    if v.visual_exp >= v.max_exp then
      v.visual_exp = math.max(0, v.visual_exp-v.max_exp)
      v.lvl = v.lvl + 1
      v.max_exp = v.real:expToLevelUp(v.lvl)
      reward_ui.party.levelup[i] = true
      reward_ui.party.col[i] = {1,0.75,0.2}
      st.flux:to(reward_ui.party.col[i], 0.66, {0,0,0})
      level_up_effect[i]:emit(250)
    end
  end
  combat_exp_countup = combat_exp_countup + combat_exp/seconds * dt
end
--

local function init_items(itemlist)
  local ui = reward_ui.items
  local function getX(i) return ui.x-ui.dim-((#ui-1)*(ui.dim*2+ui.pad))/2+(ui.dim*2+ui.pad)*(i-1) end
  for i,v in pairs(combat.globals.items) do
    ui[i] = {
      item = items(v),
      name = items(v).name,
      desc = items(v).desc,
      raritycolor = items.raritycolors[items(v).rarity],
      x = -screen_width/4,
      tx = getX(i),
    }
  end
  if #ui==0 then return end
  local subw = (ui[#ui].tx + ui.dim/2)
  for i,v in ipairs(ui) do
    v.tx = v.tx + screen_width/2 - subw/2 
    v.tip = {
      ({"white","blue","purple","yellow","red","green"})[v.item.rarity], v.name.."\n",
      "grey", "("..(v.item.func and "Use" or v.item.equip and "Equip" or "Etc")..")\n",
      "white", v.desc.."\n",
      "grey", v.item.stats and "--\n",
    }
    for stat,amount in pairs(v.item.stats or {}) do
      local col = {}
      local sign = (function() if tonumber(amount)>0 then return "+" else return "" end end)()
      local equipped_item = items((states.inventory.list[player.equipped[v.item.equip]] or {}).item or "nil")
      if tonumber(amount) > tonumber(equipped_item.stats[stat]) then
        col = {0.2,1,0.1}
      elseif tonumber(amount) < tonumber(equipped_item.stats[stat] or tonumber(amount)-1) then
        col = {1,0.2,0.1}
      else
        col = {0.65,0.65,0.65}
      end
      if tonumber(amount)~=0 then
        table.insert(v.tip, col)
        table.insert(v.tip, stat:upper().." "..sign..amount.."\n")
      end
    end
  end
end
--

local function skip()
  if not done_button.inactive then return end
  reward_ui.title.x = reward_ui.title.tx
  reward_ui.title.alpha = 1
  reward_ui.exp.alpha = 0.66
  for i,v in pairs(reward_ui.party.iy) do
    reward_ui.party.iy[i] = 0
    reward_ui.party.alpha[i] = 1
  end
  reward_ui.party.start_exp_anim = false
  for i,v in pairs(party) do
    v.exp = v.exp + combat_exp
    while v.exp >= v.max_exp do
      v.exp = math.max(0, v.exp-v.max_exp)
      v.lvl = v.lvl + 1
      v.max_exp = v.real:expToLevelUp(v.lvl)
      reward_ui.party.levelup[i] = true
    end
    reward_ui.party.col[i] = {0,0,0}
    level_up_effect[i]:reset()
  end
  combat_exp_countup = combat_exp
  reward_ui.items.alpha = 0.66
  for i,v in ipairs(reward_ui.items) do
    v.x = v.tx
    done_button.param.inactive = false
  end
  st.flux = Flux.group()
end
--

function st.prep_leave()
  Misc.fade(function()
      player:addExp(combat.globals.exp)
      for i,v in pairs(combat.allies) do
        v:addExp(combat.globals.exp)
      end
      for i,v in pairs(combat.globals.items) do inventory.add(v) end
      Gamestate.pop()
    end)
end
--

function st:enter()
  done_button.param.inactive = true
  states.combat.startWipe()
  combat_exp_countup = 0
  combat_exp = combat.globals.exp
  party = {
    player,
    combat.allies[1],
    combat.allies[2]
  }
  for i,v in pairs(party) do
    party[i] = {
      real = v,
      name = v.name,
      lvl = v.lvl,
      exp = v.exp,
      visual_exp = v.exp,
      max_exp = v:expToLevelUp(),
    }
  end
  orig_party = Misc.tcopy(party)
  reward_ui = Misc.tcopy(proto_reward_ui)
  init_items(combat.globals.items)

  local delay = 0
  -- Title and EXP anims
  st.flux:to(reward_ui.title, 0.8, { x = reward_ui.title.tx, alpha = 1 }):ease("quintout")
  st.flux:to(reward_ui.exp, 1, { alpha = 0.66 }):ease("quintout")
  delay = delay + 0.33
  -- Party anims
  for i,v in pairs(reward_ui.party.iy) do
    local time = 0.33
    st.flux:to(reward_ui.party.iy, time, {[i] = 0}):ease("quadout"):delay(delay)
    st.flux:to(reward_ui.party.alpha, time, {[i] = 1}):ease("quadout"):delay(delay):oncomplete(function() if i==#party then reward_ui.party.start_exp_anim = true end end)
    delay = delay + time
  end
  st.flux:to(reward_ui.items, 0.5, {alpha = 0.66}):ease("quadout"):delay(delay)
  delay = delay + 0.5
  for i,v in ipairs(reward_ui.items) do
    local time = 0.3
    st.flux:to(v, time, {x = v.tx}):ease("quadout"):delay(delay):oncomplete(function() if i==#reward_ui.items then done_button.param.inactive = false end end)
    delay = delay + time/4
  end
  if #combat.globals.items==0 then Timer.after(delay, function() done_button.param.inactive = false end) end
  reward_ui.party.w = (screen_width - (reward_ui.party.x*2) - (reward_ui.party.pad * 2)) / math.max(2, #party)
  if not next(combat.allies) then reward_ui.party.x = screen_width/2 - reward_ui.party.w/2 end
end
--

function st:update(dt)
  st.flux:update(dt)
  states.combat.updateWipe(dt)
  weather.update(dt)
  items.updateIcons(dt)
  done_button:update(dt)

  if reward_ui.party.start_exp_anim then
    exp_anim(dt)
    for i,v in pairs(level_up_effect) do v:update(dt) end
  end
  local mx,my = Misc.getMouseScaled()
  for i,v in ipairs(reward_ui.items) do
    local ui = reward_ui.items
    local y = screen_height/8 + ui.y + reward_ui.items.h/2 - ui.dim/2
    if mx > v.x-ui.dim/2 and mx < v.x+ui.dim/2 and my > y and my < y + ui.dim then
      event.grant("show_tooltip", v.tip, {skill=true, id=v.name})
    end
  end
end
--

local function draw_header()
  lg.setFont(FONT_[1])
  lg.setColor(1,1,1,reward_ui.title.alpha)
  lg.draw(squarrow, reward_ui.title.x, reward_ui.title.y+FONT_[1]:getHeight()/4)
  lg.draw(fadegradient, reward_ui.title.x, reward_ui.title.y+FONT_[1]:getHeight())
  lg.print("Result:", reward_ui.title.x+squarrow:getWidth(), reward_ui.title.y)
end
--

local function draw_exp()
  lg.setFont(FONT_[1])
  lg.setColor(0.8,0.8,0.8,reward_ui.exp.alpha)
  lg.printf("EXP: "..math.clamp(0, math.round(combat_exp_countup), combat_exp), reward_ui.exp.x, reward_ui.exp.y, reward_ui.exp.w, "right")
end
--

local function draw_party()
  local function text(i,v,xoff,yoff)
    lg.push() lg.translate(xoff or 0, yoff or 0)
    lg.setFont(FONT_[3])
    lg.print("Lvl. "..v.lvl, reward_ui.party.x, reward_ui.party.iy[i] + reward_ui.party.h/1.3 - FONT_[3]:getHeight())
    if reward_ui.party.levelup[i] then
      local col = {lg.getColor()}
      if col[1]~=0 then lg.setColor(1,0.75,0.2,col[4]) end
      lg.print("Level Up!", reward_ui.party.x + reward_ui.party.w/1.4, reward_ui.party.iy[i], math.pi/20)
      lg.setColor(col)
    end
    lg.setFont(FONT_[2])
    lg.printf(v.name, reward_ui.party.x, reward_ui.party.iy[i] + reward_ui.party.h/5, reward_ui.party.w, "center")
    lg.pop()
  end
  lg.push()
  lg.translate(0, reward_ui.party.y)
  for i,v in pairs(party) do
    lg.setColor(1,0.75,0.2,1*reward_ui.party.alpha[i])
    lg.draw(level_up_effect[i], reward_ui.party.x+reward_ui.party.w/2, reward_ui.party.iy[i]+reward_ui.party.h/2)

    lg.setColor(reward_ui.party.col[i][1],reward_ui.party.col[i][2],reward_ui.party.col[i][3],0.8*reward_ui.party.alpha[i])
    lg.draw(splotch, reward_ui.party.x, reward_ui.party.iy[i], nil, reward_ui.party.w/splotch:getWidth(), reward_ui.party.h/splotch:getHeight())

    lg.setColor(0, 0, 0, 0.8*reward_ui.party.alpha[i])
    for off=-2,2,4 do
      text(i,v,0,off)
      text(i,v,off,0)
    end
    lg.setColor(1,1,1,reward_ui.party.alpha[i])
    text(i,v)

    local exp_x = FONT_[3]:getWidth("Lvl. "..v.lvl) + 15
    lg.push() lg.translate(exp_x, reward_ui.party.h/1.3 - FONT_[3]:getHeight()/2)
    lg.setLineWidth(2)
    lg.setColor(0.35,0.35,0.35,1*reward_ui.party.alpha[i])
    lg.line(reward_ui.party.x, reward_ui.party.iy[i], reward_ui.party.x+reward_ui.party.w-(exp_x*1.5), reward_ui.party.iy[i])
    lg.setColor(1,0.75,0.2,1*reward_ui.party.alpha[i])
    lg.line(reward_ui.party.x,reward_ui.party.iy[i],reward_ui.party.x+((reward_ui.party.w-(exp_x*1.5))*(v.visual_exp/v.max_exp)),reward_ui.party.iy[i])
    lg.setLineWidth(1)
    lg.pop()

    lg.translate(reward_ui.party.w+reward_ui.party.pad, 0)
  end
  lg.pop()
end
--

local function draw_items()
  lg.setColor(0,0,0,reward_ui.items.alpha)
  lg.rectangle("fill", reward_ui.items.x, reward_ui.items.y, screen_width-reward_ui.items.x, reward_ui.items.h)
  if #reward_ui.items == 0 then
    lg.setFont(FONT_[1])
    lg.setColor(1,1,1,reward_ui.items.alpha/4)
    lg.printf("No Items", reward_ui.items.x, reward_ui.items.y, reward_ui.items.w,"center")
  end
  lg.setColor(1,1,1,reward_ui.items.alpha/2)
  lg.draw(fadeline, reward_ui.items.x, reward_ui.items.y-1)
  lg.draw(fadeline, reward_ui.items.x, reward_ui.items.y+reward_ui.items.h)

  for i,v in ipairs(reward_ui.items) do
    -- Draw the item sprites
    local alpha = reward_ui.items.alpha
    local raritycolor = {v.raritycolor[1],v.raritycolor[2],v.raritycolor[3],alpha}
    local dim = reward_ui.items.dim
    local x = v.x
    local y = reward_ui.items.y + reward_ui.items.h/2
    lg.setColor(1,1,1,alpha)
    items.drawIcon(v.name, x, y, dim, dim)
    lg.setColor(raritycolor)
    lg.rectangle("line",x-dim/2, y-dim/2, dim, dim, 5)
  end
end
--


function st:draw()
  weather.draw()
  lg.setColor(0,0,0,1)
  lg.rectangle("fill",0,0,screen_width,screen_height/8)
  lg.rectangle("fill",0,screen_height,screen_width,-screen_height/8)

  lg.push() lg.translate(0, screen_height/8)

  draw_header()
  draw_exp()
  draw_party()
  draw_items()

  lg.setColor(1,1,1)
  lg.pop()
  done_button:draw()
  states.combat.drawWipe()
end
--

function st:keypressed(key)
  if keyset.confirm(key) then skip() end
end
--

function st:keyreleased(key)
end
--

function st:mousepressed(x,y,b,t)
  if prompt.box.visible then return end
  skip()
  done_button:mousepressed(x,y,b)
end
--
function st:mousemoved(mx,my,dx,dy)
end
--

function st:mousereleased(x,y,b,t)
  if prompt.box.visible then return end
  done_button:mousereleased(x,y,b)
end
--

function st:leave()
end
--

return st