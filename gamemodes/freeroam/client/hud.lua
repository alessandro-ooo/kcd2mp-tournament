-- freeroam's client half: the world clock at the top right, in the game's own typeface, drawn in the player's
-- game with the client API's UI functions. The game's calendar is the server's, and the server keeps every client's
-- in step with it, so nothing has to cross the wire for the clock. A script the server sends runs in
-- the sandbox: https://docs.kcd-mp.com/lua/client/getting-started/

local MARGIN_X, MARGIN_Y = 40, 24   -- from the right and the top edge, in the 1080-row UI space

local function world_clock()
  -- the game's hour of the day as a fraction (13.5 = half past one)
  local hours = Calendar and Calendar.GetWorldHourOfDay and Calendar.GetWorldHourOfDay() or 0
  local h = math.floor(hours) % 24
  local m = math.floor((hours - math.floor(hours)) * 60 + 0.5)
  if m == 60 then h, m = (h + 1) % 24, 0 end
  return string.format("%02d:%02d", h, m)
end

local shown = nil

local function tick()
  local w = GetScreenSize()                 -- the width follows the screen's shape; the height is 1080
  local text = world_clock()
  if text ~= shown then
    shown = text
    SetUiText("clock", text)
    SetUiPos("clock", w - MARGIN_X, MARGIN_Y)
  end
  Script.SetTimer(1000, tick)               -- one shot: armed again every second
end

local w = GetScreenSize()
CreateUiText("clock", w - MARGIN_X, MARGIN_Y, world_clock(), COLOR_GOLD, 0.8, UI_ALIGN_RIGHT)
shown = world_clock()
Script.SetTimer(1000, tick)
