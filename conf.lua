local sizes = {
  {w=960,h=540},
  {w=1280,h=720},
  {w=1600,h=900},
  {w=1920,h=1080},
}

function love.conf(t)
  local s_file = love.filesystem.read("settings")
  local window_size = s_file and tonumber(s_file:match("window_size.-=([^,])")) or 1
  local vsync = s_file and tonumber(s_file:match("vsync.-=([^,])")) or 1
  local fullscreen = s_file and tonumber(s_file:match("fullscreen.-=([^,])")) or 0
  local fullscreen_type = s_file and tonumber(s_file:match("fullscreen_type.-=([^,])")) or 1

  t.identity = "TextGame"                    -- The name of the save directory (string)
  t.version = "11.1"               -- The LÖVE version this game was made for (string)
  t.console = false                  -- Attach a console (boolean, Windows only)
  t.externalstorage = true           -- True to save files (and read from the save directory) in external storage on Android (boolean) 

  t.window.title = "TextGame"         -- The window title (string)
  t.window.icon = "res/img/icon.png"  -- Filepath to an image to use as the window's icon (string)
  t.window.width = sizes[window_size].w               -- The window width (number)
  t.window.height = sizes[window_size].h               -- The window height (number)
  t.window.fullscreen = (fullscreen == 1)         -- Enable fullscreen (boolean)
  t.window.fullscreentype = ({"desktop","exclusive"})[fullscreen_type] -- Choose between "desktop" fullscreen or "exclusive" fullscreen mode (string)
  t.window.vsync = vsync               -- Enable vertical sync (boolean)
  t.window.display = 1                -- Index of the monitor to show the window in (number)
  t.window.x = nil                    -- The x-coordinate of the window's position in the specified display (number)
  t.window.y = nil                    -- The y-coordinate of the window's position in the specified display (number)
  t.window.resizable = true          -- Let the window be user-resizable (boolean)
  t.window.minwidth = 960               -- Minimum window width if the window is resizable (number)
  t.window.minheight = 540              -- Minimum window height if the window is resizable (number)
  t.window.highdpi = false

  t.modules.audio = false              -- Enable the audio module (boolean)
  t.modules.event = true              -- Enable the event module (boolean)
  t.modules.graphics = true           -- Enable the graphics module (boolean)
  t.modules.image = true              -- Enable the image module (boolean)
  t.modules.joystick = false           -- Enable the joystick module (boolean)
  t.modules.keyboard = true           -- Enable the keyboard module (boolean)
  t.modules.math = true               -- Enable the math module (boolean)
  t.modules.mouse = true              -- Enable the mouse module (boolean)
  t.modules.physics = false           -- Enable the physics module (boolean)
  t.modules.sound = false              -- Enable the sound module (boolean)
  t.modules.system = true             -- Enable the system module (boolean)
  t.modules.timer = true              -- Enable the timer module (boolean), Disabling it will result 0 delta time in love.update
  t.modules.touch = true              -- Enable the touch module (boolean)
  t.modules.video = false              -- Enable the video module (boolean)
  t.modules.window = true             -- Enable the window module (boolean)
  t.modules.thread = false             -- Enable the thread module (boolean)
end