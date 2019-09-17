require("libs.tserial")
local newPlayer = require("player")
local sv = {}

local function save(wt,name)
  local suffix = ""
  if not wt then suffix = ".sv" end
  wt = wt or {
    player = __.reject(player, function(i,v) return type(v) == "function" end),
    allies = {},
    inventory = states.inventory.list,
    inventory_maximum = states.inventory.maximum,
    save_date = os.date("%b.%d, %Y"),
    save_time = os.date("%X"),  
    explore_nav = states.explore.getNavList(),
    ui_pos = {
      choice=choices.box.basey,
      input={x=input.box.basex, y=input.box.basey}
    },
    chosen = choices.chosen,
    chosen_n = choices.chosen_n,
    input = input.result,
    last_src = out.last_src,
    subpage = out._subpage,
    flags = flags,
    icon_bar = icon_bar.getVisible(),
    src = out.to,
    pg = out.pg,
    location = out.location,
    checkpoint = out.checkpoint,
    bg = Misc.background_color,
    weather = weather.get(),
    weather_restricted = weather.restricted,
    shops = shop.getShopList(),
    background = bgimage.get().name,
    history = states.history.texts,
    version = game_version,
  }
  if wt.ui_pos and out.buttons["Next"] then wt.ui_pos.next = {x=out.buttons["Next"].x, y=out.buttons["Next"].y} end
  if wt.allies then
    for i,v in pairs(combat.allies) do
      table.insert(wt.allies, __.reject(v, function(i,v) return type(v) == "function" end))
    end
  end
  ----------------------------------------------------------------------------------
  ----------------------------------------------------------------------------------

  local sf = Tserial.pack(__.reject(wt, function(i,v) return type(v) == "function" end),nil,true)
  name = name or "save_" .. states.files.selected+6*(states.files.page-1)
  name = name..suffix
  love.filesystem.remove(name)
  love.filesystem.write(name,sf)

  states.files.reload()
end
setmetatable(sv, { __call = function(_, ...) return save(...) end})
--

local quicksave_hotkey_counter = 0
local quicksave_hotkey_timer
function sv.quick()
  if quicksave_hotkey_timer then Timer.cancel(quicksave_hotkey_timer) end
  quicksave_hotkey_timer = Timer.after(3, function() quicksave_hotkey_counter = 0 end)
  notify.clear()
  quicksave_hotkey_counter = (quicksave_hotkey_counter + 1) % 2
  if quicksave_hotkey_counter == 0 then
    notify{"green", "Quicksave", "white", "Game saved to Slot 1."}
    save(nil,"save_"..settings.quicksave_slot)
  else
    local keys = ""
    for i,v in pairs(keyset.quicksave.map) do keys = keys..(i>1 and " or "..v:upper() or v:upper()) end
    notify{"green", "Quicksave", "white", ": Press "..keys.." again to save to Slot 1."}
  end
end
--

local function update_old_allies()
  for _,ent in pairs(combat.allies) do
    local new_ent = combat.getAlly(ent.internal_name or ent.name, ent) or {}
    if not next(new_ent) then print("update_old_allies failed: Ally named "..tostring(ent.name).." has no matching internal_name or name field.") end
    for field,val in pairs(new_ent) do
      if type(val)=="table" and type(ent[field])=="table" then
        for i,v in pairs(val) do
          ent[field][i] = ent[field][i] or v
        end
      else
        ent[field] = type(ent[field])==type(val) and ent[field] or val
      end
    end
  end
end
--

local function resolve_version_differences(sf)
end
--

function sv.load(num)
  num = num or 1
  if not states.files.list then states.files.reload() end
  local sf = states.files.list[num]
  if not sf then return end
  --------[[[[
  -- Legacy save file support so people don't crash
  sf.history = sf.history or {}
  --------]]]]
  Misc.fade(function()
      if Gamestate.current() == states.files then Gamestate.pop() end
      Gamestate.switch(states.game)
      __.extend(flags,sf.flags)
      player = newPlayer(sf.player)
      for i,v in pairs(sf.allies) do combat.allies[i] = newPlayer(v) end
      update_old_allies()
      for i,v in pairs(sf.icon_bar) do icon_bar.set(i,v) end
      states.explore.setNavList(sf.explore_nav)
      states.inventory.list = sf.inventory
      states.inventory.maximum = sf.inventory_maximum
      if out.buttons["Next"] and sf.ui_pos.next then out.buttons["Next"].x, out.buttons["Next"].y = sf.ui_pos.next.x, sf.ui_pos.next.y end
      choices.box.basey = sf.ui_pos.choice
      input.box.basex, input.box.basey = sf.ui_pos.input.x, sf.ui_pos.input.y
      Misc.setBG(unpack(sf.bg))
      weather.set(sf.weather,0)
      weather.restricted = sf.weather_restricted or weather.restricted
      bgimage.set(sf.background)
      shop.setShopList(sf.shops)
      choices.chosen_n = sf.chosen_n
      choices.chosen = sf.chosen
      input.result = sf.input
      states.history.texts = __.first(sf.history,#sf.history-1)
      out._subpage = sf.subpage and sf.subpage-1 or nil
      out.last_src = sf.last_src
      out.to = sf.src
      out.location = sf.location
      out.checkpoint = sf.checkpoint
      resolve_version_differences(sf)

      out.pg = sf.pg
      if not out.load(sf.src or {})[sf.pg] then 
        sf.pg = 1
        if not out.load(sf.src or {})[sf.pg] then sf.src = sf.checkpoint end
      end
      if out.change(sf.src, nil, sf.pg) and #out.put == 0 then
        out._subpage = nil
        out.change(sf.src,false,1)
      end
    end)
  return true
end
--

function sv.delete(num)
  num = num+6*(states.files.page-1)
  for i,v in pairs(love.filesystem.getDirectoryItems("/")) do
    local m = v:match("(%d+)%.sv")
    if m and tonumber(m)==num then
      states.files.list[num] = nil
      return love.filesystem.remove(v)
    end
  end
end
--

return sv