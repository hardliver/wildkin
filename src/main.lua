-- main.lua：遊戲的進入點
--
-- M2：老苔站在營地中間，走過去按 A 會開始對話，最後問「是／否」。
-- M3：營地是一張 40 × 30 格的地圖（maps/camp.json），相機跟著主角捲動。
--     營地南邊的門通往草原小徑（maps/route1.json）。
--     NPC 和告示牌放在地圖的物件層（W17）：面對它按 A 就開始對話，NPC 會轉頭面向主角。
--     草原小徑的南邊通往苔石村（maps/village.json，W18）。
-- M4：戰鬥畫面在 battle_ui.lua（W25）。戰鬥中整個畫面交給它，地圖暫停。

PLAYER_NAME = "大志"   -- 主角的名字（W54 序章可以自己取）

-- 進入一張地圖：地圖本身交給 world，NPC 從地圖的物件建立
local function enter_map(name)
  world_enter(name)
  npc_load()
  gather_load()
  facility_load()
  bed_load()
  fire_load()        -- 營火（campfire.lua）ㄎㄨㄜ
  raft_load()        -- 木筏（raft.lua）
  block_load()
  ambient_enter()   -- 先整理好這張地圖的植物、草（ambient.lua，運算預算）
  butterflies_enter()
end

-- 換地圖、放好主角之後呼叫（遇敵要知道主角一開始站在哪一格）
local function after_place()
  encounter_enter()
  dark_enter()       -- 暗處（dark.lua）
  cutscene_enter_map()
end

-- 直接把主角放到某張地圖的第 (cx, cy) 格，面向 (dx, dy)（全滅回營地、之後的營火傳送用）。
-- 要在畫面全黑的時候呼叫（轉場的 on_middle 裡），玩家才看不到瞬間移動
function warp(name, cx, cy, dx, dy)
  enter_map(name)
  player_place(cx, cy)
  player.dir_x, player.dir_y = dx or 0, dy or 1
  after_place()
  world_follow(player.x16 // 16 + TILE // 2, player.y16 // 16 + TILE // 2)
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
    after_place()
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
    local g = gather_at(fx, fy)
    if g then
      gather_take(g)
      return
    end
    local f = facility_at(fx, fy)
    if f then
      facility_interact(f)
      return
    end
    local blk = block_at(fx, fy)
    if blk then
      block_interact(blk)
      return
    end
    local bed = bed_at(fx, fy)
    if bed then
      bed_interact(bed)
      return
    end
    local raft = raft_at(fx, fy)
    if raft then
      raft_interact(raft)
      return
    end
    local fire = fire_at(fx, fy)
    if fire then
      fire_interact(fire)
      return
    end
    local wb = workbench_at(fx, fy)
    if wb then
      workbench_interact(wb)
      return
    end
  end
end

-- 新遊戲：所有進度歸零，存檔欄位是 slot（標題畫面選的）
-- clock_mode：時間怎麼走（"game" 遊戲時鐘／"real" 現實時鐘，W64e）；省略是遊戲時鐘
function new_game(slot, clock_mode)
  SAVE_SLOT = slot
  PLAYER_NAME = "大志"
  party, BAG, RANCH = {}, {}, {}   -- 隊伍、背包都是空的：序章裡老苔給（scenes.lua 的 P2、P3）
  DEX = { seen = {}, caught = {} }
  FLAGS, FACILITY, GATHERED = {}, {}, {}
  DAY, PLAY_FRAMES = 1, 0
  TIME, TIME_SUB, LAST_FEED = 8 * 60, 0, nil   -- 第 1 天（春）早上 08:00（clock.lua）
  MONEY = 3000                      -- 優退金剩下的（商店 W55）
  SLEEP_DEBT, STIFF = 0, 0          -- 睡眠債、落枕（sleep.lua）
  CLOCK_MODE, REAL_LAST, REAL_MONTH = "game", nil, nil
  if clock_mode == "real" then clock_mode_set("real") end   -- 現實時鐘：從現在的時間開始（clock.lua）
  SEASON_NEWS = nil                 -- 新的一局不用提示「秋天到了」
  enter_map("camp")
  player_init(19 * TILE, 27 * TILE)   -- 營地南口（船靠岸之後走上來）
  player.dir_x, player.dir_y = 0, -1
  after_place()
  world_follow(player.x16 // 16 + TILE // 2, player.y16 // 16 + TILE // 2)
  -- 序章：黑畫面的開場、取名、老苔、選初始野伴（scenes.lua）
  cutscene_blackout(true)
  cutscene_start(SCENE.prologue)
end

-- 讀檔：s 是 game_read 讀回來的表格（savegame.lua）
function load_game(slot, s)
  SAVE_SLOT = slot
  game_apply(s)
  enter_map(s.map)
  player_init(0, 0)
  player.x16, player.y16 = s.x16, s.y16
  player.dir_x, player.dir_y = s.dx or 0, s.dy or 1
  player.facing_left = player.dir_x < 0
  door_armed = world_door_at(player_cell()) == nil   -- 存檔時站在門上：先離開門才會觸發
  after_place()
  world_follow(player.x16 // 16 + TILE // 2, player.y16 // 16 + TILE // 2)
  -- 現實時鐘：補算沒玩的這段時間（產出、飼料、換日），有什麼事就說一聲（day.lua）
  local away = away_settle()
  if away then dialog_open(away) end
end

function _init()
  title_open()   -- 標題畫面（title.lua）：繼續／新遊戲
end

function _update()
  input_update()   -- 一定要最先呼叫：pressed() 要靠它判斷「剛按下」

  -- 轉場中：主角不能動
  if transition_active() then
    transition_update()
    return
  end

  -- 標題畫面
  if title_active() then
    title_update()
    return
  end
  PLAY_FRAMES = PLAY_FRAMES + 1

  -- 戰鬥中：只處理戰鬥（戰鬥自己會處理對話框）
  if battle_scene_active() then
    battle_scene_update()
    return
  end

  -- 劇情（cutscene.lua；訓練家走過來、說話、開戰也是劇情）：自己處理對話框
  if cutscene_active() then
    cutscene_update()
    return
  end

  -- START 選單、背包……（screens.lua）
  if ui_active() then
    ui_update()
    return
  end

  -- 對話中：只處理對話，主角不能動
  if dialog_active() then
    dialog_update()
    return
  end

  heal_tip_check() -- 第一次受傷：提示帳篷可以回血（day.lua）
  if not dialog_active() then season_news_check() end   -- 換季的提示（season.lua）
  if not dialog_active() and not transition_active() then weather_check() end   -- 大志的膝蓋（weather.lua）
  if not dialog_active() and not transition_active() then sleep_check() end     -- 好睏的哈欠（sleep.lua）
  npc_schedule_check()   -- NPC 依時段、天氣出沒（npc.lua）
  if dialog_active() then return end
  clock_update()   -- 遊戲時鐘只在這裡走：上面那些（戰鬥、選單、對話、劇情、轉場）進行中都停住
                   -- （現實時鐘那段時間其實照走，回到這裡時一次補上，clock.lua）
  player_update()
  for _, n in ipairs(npcs) do npc_update(n) end
  if pressed(A) then interact() end
  if pressed(B) then player_toggle_bike() end   -- 菜籃車（player.lua）
  if pressed(START) then field_menu_open() return end
  if pressed(SELECT) then quest_open() return end   -- 任務日誌（quest.lua）
  check_door()
  if not transition_active() and not cutscene_check() and not trainer_check() then encounter_check() end
  world_follow(player.x16 // 16 + TILE // 2, player.y16 // 16 + TILE // 2)   -- 跟著主角的中心點
end

-- 主角、NPC、在設施工作的野伴依 y 排序後畫：比較下面（y 比較大）的後畫，才會蓋住上面的。
-- y 一樣時，主角最後畫（排序條件要完整，不然每次排出來的順序可能不同）
local function draw_actors()
  local list = {}
  for i, n in ipairs(npcs) do list[#list + 1] = { y = n.y, order = i, npc = n } end
  list[#list + 1] = { y = player.y16 // 16, order = 1000 }
  facility_actors(list)   -- 在設施工作的野伴（facility.lua）
  cutscene_actors(list)   -- 劇情裡暫時放的野伴（cutscene.lua）
  for i, e in ipairs(list) do e.order = e.order or i end
  table.sort(list, function(a, b)
    if a.y ~= b.y then return a.y < b.y end
    return a.order < b.order
  end)
  for _, e in ipairs(list) do
    if e.npc then npc_draw(e.npc) elseif e.draw then e.draw() else player_draw() end
  end
end

function _draw()
  -- 晝夜的顏色（clock.lua）：標題、戰鬥、會畫野伴圖的畫面用原色（那些圖也用同一組顏色，不然會跟著變暗）
  clock_tint(title_active() or battle_scene_active() or ui_draws_art() or cutscene_overlay_art() or indoor_map())
  if title_active() then
    title_draw()
  elseif battle_scene_active() then
    battle_scene_draw()
  else
    -- 不用 cls：地圖一定比畫面大，地面那一層會蓋滿整個畫面（省一次全畫面的清除，運算預算 W62）
    world_draw()   -- 設定相機，畫地面和裝飾
    draw_actors()  -- 世界座標
    tallgrass_front()    -- 草叢蓋住主角的腳
    facility_draw_top()  -- 剛蓋好的設施冒出的煙塵
    bed_draw_top()       -- 隊伍受傷時帳篷上的愛心（day.lua）
    fog_draw()           -- 霧林的霧（fog.lua）
    butterflies_draw()   -- 飛在大家上面
    cutscene_draw()      -- 劇情裡頭上的氣泡（！？…♪）
  end

  camera()           -- 介面固定在畫面上
  if not title_active() and not battle_scene_active() then
    dark_draw()            -- 礦坑的暗處：圓以外塗黑（dark.lua）
    season_weather_draw()  -- 花瓣、落葉、雪（season.lua）
    weather_draw()         -- 雨（weather.lua）
  end
  if not title_active() and not battle_scene_active() then cutscene_overlay_draw() end   -- 劇情的黑畫面、章節標題
  if not battle_scene_active() then ui_draw() end   -- 戰鬥中由戰鬥畫面自己畫
  dialog_draw()
  transition_draw()  -- 轉場蓋在最上面
end
