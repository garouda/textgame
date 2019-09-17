--[[
Copyright (c) 2010-2013 Matthias Richter

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

Except as contained in this notice, the name(s) of the above copyright holders
shall not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
]]--

local function __NULL__() end

-- default gamestate produces error on every callback
local state_init = setmetatable({leave = __NULL__},
  {__index = function() error("Gamestate not initialized. Use Gamestate.switch()") end})
local stack = {state_init}

local GS = {}

GS.wipevars = {img=nil,a=0,x=0,y=0}
local wm = {
  fade = function(t)
    GS.wipevars = {img=nil,a=255}
    GS.wipevars.img = lg.newImage(lg.newScreenshot())
    flux.to(GS.wipevars, 0.5, {a=0}):ease("quadout")
  end,
  slideleft = function(t)
    GS.wipevars = {x=0}
    flux.to(GS.wipevars, 0.5, {x=-screen_width}):ease("quadout")
  end,
  slideright = function(t)
    GS.wipevars = {x=0}
    GS.wipevars.img = lg.newImage(lg.newScreenshot())
    flux.to(GS.wipevars, 0.5, {x=screen_width}):ease("quadout")
  end,
  slideup = function(t)
    GS.wipevars = {x=0, y=0}
    GS.wipevars.img = lg.newImage(lg.newScreenshot())
    flux.to(GS.wipevars, 0.5, {y=-screen_height}):ease("quadout")
  end,
  slidedown = function(t)
    GS.wipevars = {x=0, y=0}
    GS.wipevars.img = lg.newImage(lg.newScreenshot())
    flux.to(GS.wipevars, 0.5, {y=screen_height}):ease("quadout")
  end,
  popoutdown = function(t)
    GS.wipevars = {x=0, y=0}
    GS.wipevars.img = lg.newImage(lg.newScreenshot())
    flux.to(GS.wipevars, 0.7, {y=screen_height}):ease("backinout")
  end,
}
function GS.wipe(m,t)
  m = m or wm["fade"]
  t = t or nil
  return wm[m](t)
end
--
function GS.new(t) return t or {} end -- constructor - deprecated!

function GS.switch(to, ...)
  assert(to, "Missing argument: Gamestate to switch to")
  assert(to ~= GS, "Can't call switch with colon operator")
  local pre = stack[#stack]
  ;(pre.leave or __NULL__)(pre)
  ;(to.init or __NULL__)(to)
  to.init = nil
  stack[#stack] = to
  collectgarbage()
  return (to.enter or __NULL__)(to, pre, ...)
end

function GS.push(to, ...)
  assert(to, "Missing argument: Gamestate to switch to")
  assert(to ~= GS, "Can't call push with colon operator")
  local pre = stack[#stack]
  ;(to.init or __NULL__)(to)
  to.init = nil
  stack[#stack+1] = to
  collectgarbage()
  return (to.enter or __NULL__)(to, pre, ...)
end

function GS.pop(...)
  if not (#stack > 1) then return end
  local pre, to = stack[#stack], stack[#stack-1] 
  stack[#stack] = nil
  ;(pre.leave or __NULL__)(pre)
  collectgarbage()
  return (to.resume or __NULL__)(to, pre, ...)
end

function GS.current()
  return stack[#stack]
end

local all_callbacks = {
  'draw', 'errhand', 'focus', 'keypressed', 'keyreleased', 'mousefocus',
  'mousepressed', 'mousereleased', 'quit', 'resize', 'textinput',
  'threaderror', 'update', 'visible', 'gamepadaxis', 'gamepadpressed',
  'gamepadreleased', 'joystickadded', 'joystickaxis', 'joystickhat',
  'joystickpressed', 'joystickreleased', 'joystickremoved'
}

function GS.registerEvents(callbacks)
  local registry = {}
  callbacks = callbacks or all_callbacks
  for _, f in ipairs(callbacks) do
    registry[f] = love[f] or __NULL__
    love[f] = function(...)
      registry[f](...)
      return GS[f](...)
    end
  end
end

-- forward any undefined functions
setmetatable(GS, {__index = function(_, func)
      return function(...)
        return (stack[#stack][func] or __NULL__)(stack[#stack], ...)
      end
    end})

return GS
