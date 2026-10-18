-- main.lua：遊戲的進入點
--
-- M1：主角在草地上走動。地圖、碰撞在 M3 才做，這裡先用隨機散布的花草當背景。
-- M2：老苔站在畫面中間，走過去按 A 會開始對話，最後問「是／否」。

-- Kenney Tiny Town 的格子編號
local GRASS, TUFT, FLOWER = 0, 1, 2
local TREE_A, TREE_B = 16, 28

local COLS, ROWS = SCREEN_W // TILE, SCREEN_H // TILE   -- 20 × 15 格
local ground = {}   -- 每一格要畫哪個圖

-- 老苔：營地的管理員（Kenney Tiny Dungeon 第 84 格，紫袍白鬍子的老人）
local ELDER = { tile = 84, x = 152, y = 72 }
local TALK_RANGE = 24   -- 主角和老苔的距離在 24 像素內才能說話

local function near_elder()
  return math.abs(player.x16 // 16 - ELDER.x) <= TALK_RANGE
     and math.abs(player.y16 // 16 - ELDER.y) <= TALK_RANGE
end

local function talk_to_elder()
  dialog_ask(
    "你就是新來的拓荒者吧？我是新芽營地的管理員，大家都叫我老苔。" ..
    "\f這座雲根島上住著許多野生的生物，\n我們叫牠們「野伴」。" ..
    "\f牠們會幫忙種田、砍樹，\n也會陪你一起冒險。" ..
    "\f那麼，你準備好出發了嗎？",
    { "是", "否" },
    function(choice)
      if choice == 1 then
        dialog_open("很好！先到營地外的草原小徑看看吧。\n小心草叢裡的野伴。")
      else
        dialog_open("沒關係，準備好了再來找我。")
      end
    end)
end

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
  input_update()   -- 一定要最先呼叫：pressed() 要靠它判斷「剛按下」

  -- 對話中：只處理對話，主角不能動
  if dialog_active() then
    dialog_update()
    return
  end

  player_update()
  if pressed(A) and near_elder() then talk_to_elder() end
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

  -- 老苔（會面向主角）和主角
  spr(IMG.dungeon, ELDER.tile, ELDER.x, ELDER.y, player.x16 // 16 < ELDER.x)
  player_draw()

  dialog_draw()   -- 最後畫，蓋在所有東西上面
end
