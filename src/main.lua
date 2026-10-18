-- main.lua：遊戲的進入點
--
-- M1：主角在草地上走動。地圖、碰撞在 M3 才做，這裡先用隨機散布的花草當背景。

-- Kenney Tiny Town 的格子編號
local GRASS, TUFT, FLOWER = 0, 1, 2
local TREE_A, TREE_B = 16, 28

local COLS, ROWS = SCREEN_W // TILE, SCREEN_H // TILE   -- 20 × 15 格
local ground = {}   -- 每一格要畫哪個圖

function _init()
  -- 用 rnd 隨機鋪草地：每次開始都一樣（rnd 的種子固定），重新開始也一樣
  for i = 0, COLS * ROWS - 1 do
    local r = rnd(100)
    if r < 6 then ground[i] = FLOWER
    elseif r < 18 then ground[i] = TUFT
    else ground[i] = GRASS end
  end
  player_init(SCREEN_W // 2 - 8, SCREEN_H // 2 - 8)
end

function _update()
  player_update()
end

function _draw()
  -- 草地
  for row = 0, ROWS - 1 do
    for col = 0, COLS - 1 do
      spr(IMG.town, ground[row * COLS + col], col * TILE, row * TILE)
    end
  end

  -- 上方一排樹當邊框
  for col = 0, COLS - 1 do
    local t = col % 2 == 0 and TREE_A or TREE_B
    spr(IMG.town, GRASS, col * TILE, 0)
    spr(IMG.town, t, col * TILE, 0)
  end

  player_draw()
end
