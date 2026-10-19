-- main.lua：遊戲的進入點
--
-- M2：老苔站在營地中間，走過去按 A 會開始對話，最後問「是／否」。
-- M3：營地是一張 40 × 30 格的地圖（maps/camp.json），相機跟著主角捲動。
--     營地南邊的門通往草原小徑（maps/route1.json）。
--     NPC 和告示牌放在地圖的物件層（W17）：面對它按 A 就開始對話，NPC 會轉頭面向主角。
--     草原小徑的南邊通往苔石村（maps/village.json，W18）。
-- M4：戰鬥畫面在 battle_ui.lua（W25）。戰鬥中整個畫面交給它，地圖暫停。

-- 進入一張地圖：地圖本身交給 world，NPC 從地圖的物件建立
local function enter_map(name)
  world_enter(name)
  npc_load()
  butterflies_enter()
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

-- 按 A：看主角面前有什麼。從近到遠（4～14 像素）找，最先碰到的那個：
-- 貼著站、或中間隔一點點空隙，都能說話；NPC 和告示牌在同一個距離時，NPC 優先
local function interact()
  for d = 4, 14, 2 do
    local fx, fy = player_front(d)
    local n = npc_at(fx, fy)
    if n then
      npc_face(n, player.x16 // 16 + TILE // 2)
      talk_to(n)
      return
    end
    local sign = world_sign_at(fx, fy)
    if sign then
      dialog_open(sign.text)
      return
    end
  end
end

function _init()
  -- 隊伍（暫時）：序章選初始野伴（W54）之前，先直接給一隻 Lv5 芽角羊
  party = { kin_new("01", 5) }
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

  -- 戰鬥中：只處理戰鬥（戰鬥自己會處理對話框）
  if battle_scene_active() then
    battle_scene_update()
    return
  end

  -- 對話中：只處理對話，主角不能動
  if dialog_active() then
    dialog_update()
    return
  end

  player_update()
  for _, n in ipairs(npcs) do npc_update(n) end
  if pressed(A) then interact() end
  check_door()
  world_follow(player.x16 // 16 + TILE // 2, player.y16 // 16 + TILE // 2)   -- 跟著主角的中心點
end

-- 主角和 NPC 依 y 排序後畫：比較下面（y 比較大）的後畫，才會蓋住上面的。
-- y 一樣時，主角最後畫（排序條件要完整，不然每次排出來的順序可能不同）
local function draw_actors()
  local list = {}
  for i, n in ipairs(npcs) do list[#list + 1] = { y = n.y, order = i, npc = n } end
  list[#list + 1] = { y = player.y16 // 16, order = #npcs + 1 }
  table.sort(list, function(a, b)
    if a.y ~= b.y then return a.y < b.y end
    return a.order < b.order
  end)
  for _, e in ipairs(list) do
    if e.npc then npc_draw(e.npc) else player_draw() end
  end
end

function _draw()
  if battle_scene_active() then
    battle_scene_draw()
  else
    cls(0)
    world_draw()   -- 設定相機，畫地面和裝飾
    draw_actors()  -- 世界座標
    butterflies_draw()   -- 飛在大家上面
  end

  camera()           -- 介面固定在畫面上
  dialog_draw()
  transition_draw()  -- 轉場蓋在最上面
end
