-- main.lua：遊戲的進入點
--
-- M2：老苔站在營地中間，走過去按 A 會開始對話，最後問「是／否」。
-- M3：營地是一張 40 × 30 格的地圖（maps/camp.json），相機跟著主角捲動。

-- 老苔：營地的管理員（Kenney Tiny Dungeon 第 84 格，紫袍白鬍子的老人）
local ELDER = { tile = 84, x = 19 * TILE, y = 11 * TILE }   -- 世界座標：營地空地的北邊
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
  world_enter(MAP.camp)
  world_add_blocker(ELDER)            -- 老苔會擋路，不能穿過去
  player_init(19 * TILE, 15 * TILE)   -- 營地空地的中間
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
  world_follow(player.x16 // 16 + TILE // 2, player.y16 // 16 + TILE // 2)   -- 跟著主角的中心點
end

function _draw()
  cls(0)
  world_draw()   -- 設定相機，畫地面和裝飾

  -- 老苔（會面向主角）和主角：都用世界座標。
  -- 比較下面（y 比較大）的後畫，才會蓋住上面的：主角站在老苔下方時蓋住老苔
  local function draw_elder() spr(IMG.dungeon, ELDER.tile, ELDER.x, ELDER.y, player.x16 // 16 < ELDER.x) end
  if player.y16 // 16 >= ELDER.y then
    draw_elder()
    player_draw()
  else
    player_draw()
    draw_elder()
  end

  camera()        -- 介面固定在畫面上
  dialog_draw()   -- 最後畫，蓋在所有東西上面
end
