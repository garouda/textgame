local controls = {}
local index = 1
setmetatable(controls, { __newindex = function(t,i,v) index = index + 1 rawset(t,i,v) end})

controls.confirm = {map={'return', 'e', 'space'},index=index,desc="Makes selections and advances text."}
controls.back = {map={'escape', 'q', 'backspace'},index=index,desc="Exits out of menus and opens the pause menu."}
controls.up = {map={'up', 'w'},index=index,desc="Directional keys for navigating menus."}
controls.left = {map={'left', 'a'},index=index,desc="Directional keys for navigating menus."}
controls.down = {map={'down', 's'},index=index,desc="Directional keys for navigating menus."}
controls.right = {map={'right', 'd'},index=index,desc="Directional keys for navigating menus."}
controls.scrolldown = {map={'pagedown', 'kp3'},index=index,desc="Scroll down in certain menus."}
controls.scrollup = {map={'pageup', 'kp9'},index=index,desc="Scroll up in certain menus."}
controls.inventory = {map={'i','1'},index=index,desc="Opens the Inventory page while in-game."}
controls.stats = {map={'t','2'},index=index,desc="Opens the Stats page while in-game."}
controls.explore = {map={'x','3'},index=index,desc="Opens the Explore window while in-game."}
controls.history = {map={'h','4'},index=index,desc="Opens the History page while in-game."}
controls.quicksave = {map={'f5'},index=index,desc="Press this hotkey twice to quickly save the game to Slot 1."}
controls.editor = {map={'f2'},index=index,desc="Opens the scene editor."}
controls.credits = {map={'f1'},index=index,desc="View the credits page."}

for i,v in pairs(controls) do
  setmetatable(controls[i], { __call = function(t,key,allow)
        for i,v in pairs(v.map) do
          if type(v)=="string" then
            if key==v or allow or (key=="kpenter" and v=="return" or v=="return" and key=="kpenter") then
              return true
            end
          end
        end
        return false
      end})
end
--
return controls
