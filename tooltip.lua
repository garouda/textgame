local tt = {}

local font = fonts.tooltip
local last_id
tt.msg = nil
tt.alpha = 0
tt.w, tt.h = 0, 0

local colours = { 
  red = {0.9, 0.2, 0.04, 1},
  orange = {0.9,0.6,0.15, 1},
  yellow = {0.95,0.84,0.08, 1},
  green = {0, 0.8, 0.4, 1},
  blue = {0, 0.6, 1, 1},
  purple = {0.8,0.4,1, 1},
  pink = {1,0.6,0.9, 1},
  white = {1,1,1, 1},
  grey = {0.5,0.5,0.5, 1},
}

function tt.set(msg,args)
  msg = type(msg)=="table" and msg or {colours.white,tostring(msg)}
  args = args or {}
  args.id = args.id or msg
  tt.alpha = 2
  if args.id == last_id then return else last_id = args.id end
  tt.w = screen_width/4

  for i=2,#msg,2 do
    local v = msg[i]
    if type(v)=="string" then
      if args.ent then msg[i] = process.replace(v,args.ent) end
      if tt.w > font:getWidth(v)+20 then tt.w = font:getWidth(v)+20 end
    end
  end
  if args.skill then tt.w = screen_width/4 end
  
  for i=1,#msg,2 do if type(msg[i])=="string" then msg[i] = colours[msg[i]] or colours.white end end
  
  tt.msg = lg.newText(font)
  tt.msg:setf(msg, tt.w-10, "center")
  tt.h = tt.msg:getHeight()+10
end
--

function tt.update(dt)
  tt.alpha = tt.alpha - 15 * dt
  if tt.alpha <= 0 then tt.msg = nil last_id = nil end
end
--

function tt.draw()
  if tt.alpha > 0 and tt.msg then
    lg.setLineWidth(1)
    local mx,my = Misc.getMouseScaled()
    mx = math.clamp(0, mx, screen_width - tt.w-5)
    my = math.clamp(0, my - tt.h, screen_height - tt.h-5)
    lg.setColor(0,0,0,tt.alpha*1.1)
    lg.rectangle("fill", mx-2, my-2, tt.w+4, tt.h+4)
    lg.setColor(1,1,1,tt.alpha)
    lg.rectangle("line", mx, my, tt.w, tt.h)
    lg.setColor(1,1,1,tt.alpha*2)
    lg.draw(tt.msg, mx+5, my+5)
  end
end
--

return tt