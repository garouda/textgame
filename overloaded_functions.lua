--Save my fingers some work
lg = love.graphics

--local oldGraphicsDraw = lg.draw
--function lg.draw(drawable,x,y,r,sx,sy,ox,oy,kx,ky)
--  return oldGraphicsDraw(drawable,math.floor(x or 0),math.floor(y or 0),r,sx,sy,ox,oy,kx,ky)
--end


local oldGraphicsPrint = lg.print
function lg.print(text,x,y,r,sx,sy,ox,oy,kx,ky)
--  return oldGraphicsPrint(text,math.floor(x or 0),math.floor(y or 0),r,sx,sy,ox,oy,kx,ky)
  return oldGraphicsPrint(text,x,y,r,sx,sy,ox,oy,kx,ky)
end
--

local oldGraphicsPrintf = lg.printf
function lg.printf(text,x,y,limit,align,r,sx,sy,ox,oy,kx,ky)
--  return oldGraphicsPrintf(text,math.floor(x or 0),math.floor(y or 0),limit,align,r,sx,sy,ox,oy,kx,ky)
  return oldGraphicsPrintf(text,x,y,limit,align,r,sx,sy,ox,oy,kx,ky)
end
--

local oldGraphicsTranslate = lg.translate
function lg.translate(dx,dy)
--  return oldGraphicsTranslate(math.floor(dx),math.floor(dy or 0))
  return oldGraphicsTranslate(dx,dy or 0)
end
--