-- trainer.lua：訓練家（W31）
--
-- 地圖上的 NPC 加欄位 trainer = "rival1"（data/trainers.json 的編號），就變成訓練家；
-- look = "up"／"down"／"left"／"right" 是他面向哪邊（看得到那個方向的 sight 格）。
--
-- 流程（照順序寫在一個 coroutine 裡，和戰鬥演出一樣）：
--   被看到 → 頭上冒「！」→ 走到主角面前 → 開戰前的台詞 → 戰鬥（不能逃）
--   → 打贏：輸了的台詞，記在 FLAGS 裡（之後只會說 after 那句）；leave = true 的會自己走掉
--   → 打輸：全滅回營地（W29）
--
-- 發現主角的規則：
--   1. 面向的方向、同一欄（或同一列）、sight 格以內，中間沒有牆
--   2. notice 格以內（任何方向）一定發現。劇情上一定要打的（阿穗）用這個擋住路口，
--      自由移動的遊戲裡，只靠「視線」很容易從旁邊繞過去

FLAGS = FLAGS or {}   -- 劇情旗標：打贏過的訓練家、之後的劇情進度（W49 存檔時一起存）

local DIR = { up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 } }
local COUNTER = { ["01"] = "03", ["03"] = "05", ["05"] = "01" }   -- 剋制主角初始野伴的那一隻

local co = nil        -- 正在跑的訓練家流程
local bubble = nil    -- 頭上冒「！」的 NPC

function trainer_defeated(n)
  return FLAGS["trainer_" .. n.trainer] == true
end

-- npc_load 用：打贏過、而且會走掉的訓練家，不再出現
function trainer_gone(o)
  return o.trainer and FLAGS["trainer_" .. o.trainer] and DATA.trainers[o.trainer].leave
end

local function build_party(t)
  local list = {}
  for _, p in ipairs(t.party) do
    local no = p.species
    if no == "rival" then no = COUNTER[party[1].no] or "03" end
    list[#list + 1] = kin_new(no, p.level)
  end
  return list
end

-- ============================================================
-- coroutine 裡用的工具
-- ============================================================

local function wait(n)
  for _ = 1, n do coroutine.yield() end
end

local function say(text)
  dialog_open(text)
  while dialog_active() do coroutine.yield() end
end

-- NPC 走一段（每幀 1 像素，像 GB 的走路速度）
local function walk(n, dx, dy, pixels)
  for _ = 1, pixels do
    n.x, n.y = n.x + dx, n.y + dy
    if dx ~= 0 then n.face_left = dx < 0 end
    n.walking = true
    coroutine.yield()
  end
  n.walking = false
end

-- 走到主角旁邊（停在隔壁那一格）
local function approach(n)
  local tx, ty = player.x16 // 16, player.y16 // 16
  local dx, dy = tx - n.x, ty - n.y
  if math.abs(dx) >= math.abs(dy) then
    local s = dx > 0 and 1 or -1
    walk(n, s, 0, math.max(math.abs(dx) - TILE, 0))
  else
    local s = dy > 0 and 1 or -1
    walk(n, 0, s, math.max(math.abs(dy) - TILE, 0))
  end
end

local function battle(n)
  local t = DATA.trainers[n.trainer]
  local result = nil
  battle_scene_start(build_party(t), { wild = false, trainer = t.name, flash = true }, function(r) result = r end)
  while result == nil or transition_active() do coroutine.yield() end
  return result
end

local function run_trainer(n, walk_over)
  local t = DATA.trainers[n.trainer]
  -- 主角轉向訓練家
  local px, py = player.x16 // 16, player.y16 // 16
  if math.abs(n.x - px) >= math.abs(n.y - py) then
    player.dir_x, player.dir_y = (n.x > px) and 1 or -1, 0
    player.facing_left = n.x < px
  else
    player.dir_x, player.dir_y = 0, (n.y > py) and 1 or -1
  end
  if walk_over then
    bubble = n
    wait(40)
    bubble = nil
    approach(n)
  end
  npc_face(n, px + TILE // 2)
  say(t.name .. "：" .. t.intro)
  local result = battle(n)
  if result == "lose" then
    wiped_out()
    return
  end
  FLAGS["trainer_" .. n.trainer] = true
  say(t.name .. "：" .. t.win)
  if t.leave then
    -- 走掉：往主角的反方向走 3 格，然後從地圖上消失
    local ax, ay = 0, 1
    if n.y > py then ax, ay = 0, 1 elseif n.y < py then ax, ay = 0, -1 end
    if n.x ~= px and math.abs(n.x - px) > math.abs(n.y - py) then ax, ay = (n.x > px) and 1 or -1, 0 end
    walk(n, ax, ay, TILE * 3)
    npc_remove(n)
  end
end

-- ============================================================
-- 給 main.lua 用的
-- ============================================================

function trainer_running()
  return co ~= nil
end

function trainer_update()
  if dialog_active() then dialog_update() end
  local ok, err = coroutine.resume(co)
  if not ok then error(err) end
  if coroutine.status(co) == "dead" then co = nil end
end

-- 直接跟訓練家說話（main.lua 的 interact）：還沒打過就開打，打過了說 after
function trainer_talk(n)
  if trainer_defeated(n) then
    dialog_open(DATA.trainers[n.trainer].name .. "：" .. DATA.trainers[n.trainer].after)
  else
    co = coroutine.create(function() run_trainer(n, false) end)
  end
end

-- 這個訓練家看不看得到主角
local function sees(n)
  local t = DATA.trainers[n.trainer]
  local ncx, ncy = n.x // TILE, n.y // TILE
  local pcx, pcy = player_cell()
  -- 規則 2：靠得很近
  if math.max(math.abs(pcx - ncx), math.abs(pcy - ncy)) <= t.notice then return true end
  -- 規則 1：面向的方向、一直線
  local d = DIR[n.look or "down"]
  for i = 1, t.sight do
    local cx, cy = ncx + d[1] * i, ncy + d[2] * i
    if mget(world.map, "solid", cx, cy) ~= 0 then return false end
    if cx == pcx and cy == pcy then return true end
  end
  return false
end

-- 每幀呼叫（主角移動之後）
function trainer_check()
  for _, n in ipairs(npcs) do
    if n.trainer and not trainer_defeated(n) and sees(n) then
      co = coroutine.create(function() run_trainer(n, true) end)
      return true
    end
  end
  return false
end

-- 「！」氣泡（在角色之後畫，世界座標）
function trainer_draw()
  if not bubble then return end
  local x, y = bubble.x + 3, bubble.y - 14
  rect(x, y, 10, 12, 0)
  rect(x + 1, y + 1, 8, 10, 7)
  rect(x + 4, y + 2, 2, 5, 8)
  rect(x + 4, y + 8, 2, 2, 8)
end
