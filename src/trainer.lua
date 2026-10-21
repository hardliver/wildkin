-- trainer.lua：訓練家（W31）
--
-- 地圖上的 NPC 加欄位 trainer = "rival1"（data/trainers.json 的編號），就變成訓練家；
-- look = "up"／"down"／"left"／"right" 是他面向哪邊（看得到那個方向的 sight 格）。
--
-- 流程（用 cutscene.lua 的劇情工具寫，照順序）：
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

function trainer_defeated(n)
  return FLAGS["trainer_" .. n.trainer] == true
end

-- npc_load 用：打贏過、而且會走掉的訓練家，不再出現
function trainer_gone(o)
  return o.trainer and FLAGS["trainer_" .. o.trainer] and DATA.trainers[o.trainer].leave
end

-- 訓練家的隊伍（cutscene.lua 的 fight 用）
function trainer_party(t)
  local list = {}
  for _, p in ipairs(t.party) do
    local no = p.species
    if no == "rival" then no = COUNTER[party[1].no] or "03" end
    list[#list + 1] = kin_new(no, p.level)
  end
  return list
end

-- 台詞裡的 {name} 換成主角的名字
local function fmt(text)
  return (text:gsub("{name}", PLAYER_NAME))
end

-- 訓練家的流程：用劇情腳本的工具寫（cutscene.lua）
local function run_trainer(n, walk_over)
  local t = DATA.trainers[n.trainer]
  face("player", n)
  if walk_over then
    emote(n, "!")
    walk_to(n, "player")
  end
  face(n, "player")
  say(t.name .. "：" .. fmt(t.intro))
  if t.reply then say(PLAYER_NAME .. "：" .. fmt(t.reply)) end   -- 主角回一句（阿穗第 2 戰）
  if t.intro2 then say(t.name .. "：" .. fmt(t.intro2)) end
  if fight(n.trainer) == "lose" then
    wiped_out()
    return
  end
  say(t.name .. "：" .. fmt(t.win))
  if t.money then                              -- 獎金
    MONEY = MONEY + t.money
    say(PLAYER_NAME .. "拿到了 " .. money_text(t.money) .. "獎金。")
  end
  if t.gift then give(t.gift, 1) end          -- 打贏送的東西（阿穗的便當）
  if t.bye then say(t.name .. "：" .. fmt(t.bye)) end
  if t.leave then
    -- 走掉：往主角的反方向走 3 格，然後從地圖上消失
    local px, py = player.x16 // 16, player.y16 // 16
    local dir = "down"
    if n.y < py then dir = "up" end
    if n.x ~= px and math.abs(n.x - px) > math.abs(n.y - py) then dir = (n.x > px) and "right" or "left" end
    walk(n, dir, 3)
    npc_remove(n)
  end
end

-- 直接跟訓練家說話（main.lua 的 interact）：還沒打過就開打，打過了說 after
function trainer_talk(n)
  if trainer_defeated(n) then
    dialog_open(DATA.trainers[n.trainer].name .. "：" .. fmt(DATA.trainers[n.trainer].after))
  else
    cutscene_start(function() run_trainer(n, false) end)
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

-- 每幀呼叫（主角移動之後）：被看到就開始訓練家的劇情
function trainer_check()
  for _, n in ipairs(npcs) do
    if n.trainer and not trainer_defeated(n) and sees(n) then
      return cutscene_start(function() run_trainer(n, true) end)
    end
  end
  return false
end
