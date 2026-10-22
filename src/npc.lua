-- npc.lua：地圖上的 NPC
--
-- NPC 放在地圖的物件層（Comet Studio 的地圖編輯器 → 物件 → NPC），每個有：
--   name：名字（程式裡用，英文）
--   tile：圖（地圖格子編號，見 world_spr）
--   talk：對話編號（talk.lua 的 TALK 表格裡找）
-- 進入地圖時，world_enter 之後呼叫 npc_load()，就會把這張地圖的 NPC 都建立起來。
--
-- NPC 預設面向右邊（Kenney 的角色圖都是面向右）。主角跟它說話時，它會轉頭面向主角。

npcs = {}

function npc_load()
  npcs = {}
  for _, o in ipairs(world.objects) do
    if o.type == "npc" and not trainer_gone(o) then
      local n = {
        name = o.name,
        tile = o.tile,
        talk = o.talk,
        x = o.x * TILE,         -- 圖的左上角（世界座標）；和主角、world_blocked 用一樣的規則
        y = o.y * TILE,
        face_left = false,
        seed = hash(o.x, o.y, 7),   -- 東張西望的節奏，每個人錯開
        talked = -10000,            -- 上次跟主角說話是第幾幀
        trainer = o.trainer,        -- 訓練家的編號（data/trainers.json），一般 NPC 是 nil
        look = o.look,              -- 訓練家面向哪邊（up／down／left／right）
      }
      if o.look == "left" then n.face_left = true end
      npcs[#npcs + 1] = n
      world_add_blocker(n)      -- NPC 會擋路，不能穿過去
    end
  end
  npc_schedule_check(true)
end

-- ============================================================
-- 依時段、天氣出沒（W71i，2026-10-22 Neil）
-- ============================================================
-- NPC_HOURS[名字或對話編號] = function(時段, 天氣) return 在不在 end（天氣在室內是 nil）。沒寫的 NPC 一直都在。
-- 不在的 NPC：n.away = true，不畫、不擋路、不能說話。時段或天氣一變就重新看一次
NPC_HOURS = NPC_HOURS or {}
local schedule_key = nil

function npc_schedule_check(force)
  local p = time_period()
  local w = weather_now()
  local key = DAY .. p .. tostring(w)
  if not force and key == schedule_key then return end
  schedule_key = key
  for _, n in ipairs(npcs) do
    local f = NPC_HOURS[n.name] or (n.talk and NPC_HOURS[n.talk])   -- 先用名字找（訓練家的 talk 都是 "trainer"）
    local away = (f and not f(p, w)) and true or false
    if away ~= (n.away or false) then
      n.away = away
      if away then world_remove_blocker(n) else world_add_blocker(n) end
    end
  end
end

-- 世界座標 (px, py) 這一點在哪個 NPC 身上（沒有回傳 nil）。
-- 用整張圖的 16 × 16 範圍判斷，不只是腳：主角站在 NPC 上方往下看時，前方那一點會落在 NPC 的頭上
function npc_at(px, py)
  for _, n in ipairs(npcs) do
    if not n.away and px >= n.x and px < n.x + TILE and py >= n.y and py < n.y + TILE then return n end
  end
  return nil
end

-- 轉頭面向世界座標 x（通常是主角的中心）
function npc_face(n, x)
  n.face_left = x < n.x + TILE // 2
  n.talked = frame()
end

-- 東張西望：每 4 秒左右有機會轉向另一邊。剛說完話的 10 秒內一直看著主角
local LOOK_EVERY, LOOK_AFTER_TALK = 240, 600

function npc_update(n)
  if n.trainer and not trainer_defeated(n) then return end   -- 訓練家盯著自己的方向，不東張西望
  local f = frame()
  if f - n.talked < LOOK_AFTER_TALK then return end
  if (f + n.seed) % LOOK_EVERY == 0 and hash(f // LOOK_EVERY, n.seed) % 3 == 0 then
    n.face_left = not n.face_left
  end
end

-- 從地圖上拿掉（訓練家打完走掉）
function npc_remove(n)
  for i, m in ipairs(npcs) do
    if m == n then table.remove(npcs, i) break end
  end
  world_remove_blocker(n)
end

function npc_draw(n)
  if n.away then return end
  world_spr(n.tile, n.x, n.y, n.face_left)
end
