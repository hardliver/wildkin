-- main.lua：遊戲的進入點
--
-- 目前是開發起點：還沒有圖片和文字（引擎的 M1、M2 完成後才有），
-- 先用方塊代表主角，確認建置流程和操作都正常。

local LEFT, RIGHT, UP, DOWN = 0, 1, 2, 3
local A, B, START, SELECT = 4, 5, 6, 7

local TILE = 16
local player = {}

function _init()
  -- 位置用「放大 16 倍的整數」存，搖桿推一點就能慢慢走
  player.x16 = (SCREEN_W // 2 - TILE // 2) * 16
  player.y16 = (SCREEN_H // 2 - TILE // 2) * 16
end

function _update()
  local lx, ly = stick(0, 0)
  if lx == 0 and ly == 0 then
    if btn(0, LEFT)  then lx = -127 end
    if btn(0, RIGHT) then lx =  127 end
    if btn(0, UP)    then ly = -127 end
    if btn(0, DOWN)  then ly =  127 end
  end
  player.x16 = player.x16 + lx * 24 // 127   -- 最快每幀 1.5 像素
  player.y16 = player.y16 + ly * 24 // 127
  player.x16 = math.max(0, math.min(player.x16, (SCREEN_W - TILE) * 16))
  player.y16 = math.max(0, math.min(player.y16, (SCREEN_H - TILE) * 16))
end

function _draw()
  cls(3)   -- 深綠色草地

  -- 格線：之後會換成 Kenney Tiny Town 的地圖
  for x = 0, SCREEN_W, TILE do rect(x, 0, 1, SCREEN_H, 11) end
  for y = 0, SCREEN_H, TILE do rect(0, y, SCREEN_W, 1, 11) end

  rect(player.x16 // 16, player.y16 // 16, TILE, TILE, 7)
end
