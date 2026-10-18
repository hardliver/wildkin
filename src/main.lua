-- main.lua：遊戲的進入點
--
-- M2：老苔站在營地中間，走過去按 A 會開始對話，最後問「是／否」。
-- M3：營地是一張 40 × 30 格的地圖（maps/camp.json），相機跟著主角捲動。
--     營地南邊的門通往草原小徑（maps/route1.json）。

-- 老苔：營地的管理員（Kenney Tiny Dungeon 第 84 格，紫袍白鬍子的老人）
local ELDER = { tile = 84, x = 19 * TILE, y = 11 * TILE }   -- 世界座標：營地空地的北邊
local TALK_RANGE = 24   -- 主角和老苔的距離在 24 像素內才能說話

local function near_elder()
  return world.name == "camp" and math.abs(player.x16 // 16 - ELDER.x) <= TALK_RANGE
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

-- 進入一張地圖：地圖本身交給 world，這張地圖特有的東西在這裡加
-- （W17 會改成從地圖的 NPC 物件自動產生）
local function enter_map(name)
  world_enter(name)
  if name == "camp" then world_add_blocker(ELDER) end   -- 老苔會擋路，不能穿過去
end

-- 剛換到新地圖時，主角可能站在門上：要先離開門，才能再觸發，不然會來回彈
local door_armed = true

local function check_door()
  local cx, cy = player_cell()
  local door = world_door_at(cx, cy)
  if not door then
    door_armed = true
    return
  end
  if not door_armed then return end
  door_armed = false
  transition_start(function()
    enter_map(door.to)
    player_place(door.tx, door.ty)
    world_follow(player.x16 // 16 + TILE // 2, player.y16 // 16 + TILE // 2)
  end)
end

function _init()
  enter_map("camp")
  player_init(19 * TILE, 15 * TILE)   -- 營地空地的中間
end

function _update()
  input_update()   -- 一定要最先呼叫：pressed() 要靠它判斷「剛按下」

  -- 轉場中：主角不能動
  if transition_active() then
    transition_update()
    return
  end

  -- 對話中：只處理對話，主角不能動
  if dialog_active() then
    dialog_update()
    return
  end

  player_update()
  if pressed(A) and near_elder() then talk_to_elder() end
  check_door()
  world_follow(player.x16 // 16 + TILE // 2, player.y16 // 16 + TILE // 2)   -- 跟著主角的中心點
end

function _draw()
  cls(0)
  world_draw()   -- 設定相機，畫地面和裝飾

  -- 老苔（會面向主角）和主角：都用世界座標。
  -- 比較下面（y 比較大）的後畫，才會蓋住上面的：主角站在老苔下方時蓋住老苔
  local function draw_elder() spr(IMG.dungeon, ELDER.tile, ELDER.x, ELDER.y, player.x16 // 16 < ELDER.x) end
  if world.name ~= "camp" then
    player_draw()
  elseif player.y16 // 16 >= ELDER.y then
    draw_elder()
    player_draw()
  else
    player_draw()
    draw_elder()
  end

  camera()           -- 介面固定在畫面上
  dialog_draw()
  transition_draw()  -- 轉場蓋在最上面
end
