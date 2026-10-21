-- day.lua：換日、帳篷睡覺（W46；W64c 改成遊戲時鐘）
--
-- 營地有主角的帳篷（地圖物件 type = "bed"，2×2 格、擋路）。面對它按 A：
--   傍晚、晚上 →「要睡到明天早上嗎？」→ 畫面暗下來（Zzz……）→ 時間快轉到 06:00 → 報告睡覺時的產出
--   其他時間 →「小睡一下」：過 1 小時
--   兩種都會讓隊伍全部恢復（HP、招式次數、狀態）
-- 換日不用睡覺：clock.lua 走到半夜就呼叫 day_change。設施的產出每小時進背包（facility_hour）。
-- 不用真實時間：結果完全由存檔和按鍵決定（design.md）

local BED_SPRITE = 6   -- facilities.png 第 6 格：帳篷
local beds = {}

function bed_load()
  beds = {}
  for _, o in ipairs(world.objects) do
    if o.type == "bed" then
      beds[#beds + 1] = { cx = o.x, cy = o.y, x = o.x * TILE, y = o.y * TILE }
      for dy = 0, 1 do
        for dx = 0, 1 do mset(world.map, "solid", o.x + dx, o.y + dy, 1) end
      end
    end
  end
end

function bed_at(px, py)
  local cx, cy = px // TILE, py // TILE
  for _, b in ipairs(beds) do
    if cx >= b.cx and cx <= b.cx + 1 and cy >= b.cy and cy <= b.cy + 1 then return b end
  end
  return nil
end

function bed_draw()
  for _, b in ipairs(beds) do spr(IMG.facilities, BED_SPRITE, b.x, b.y) end
end

-- 隊伍裡有沒有受傷的（HP 沒滿、倒下）
function party_hurt()
  for _, k in ipairs(party) do
    if k.hp < kin_max_hp(k) then return true end
  end
  return false
end

-- 帳篷上的愛心氣泡：隊伍有受傷的就冒出來，上下輕輕跳，告訴玩家「來這裡休息」
-- （Neil 回饋：不知道帳篷可以回血；很多玩家不喜歡全滅的感覺）
local HEART = { ".##.##.", "#######", "#######", ".#####.", "..###..", "...#..." }
function bed_draw_top()
  if #beds == 0 or not party_hurt() then return end
  local bob = (frame() // 20) % 2
  for _, b in ipairs(beds) do
    local x, y = b.x + 9, b.y - 14 - bob
    rect(x - 1, y - 1, 15, 12, 0)          -- 氣泡：黑框、白底
    rect(x, y, 13, 10, 7)
    rect(x + 5, y + 10, 3, 2, 0)          -- 氣泡的小尾巴
    pset(x + 6, y + 10, 7)
    for r, row in ipairs(HEART) do
      for c = 1, #row do
        if row:sub(c, c) == "#" then pset(x + 2 + c, y + 1 + r, 8) end
      end
    end
  end
end

-- 第一次受傷到一半以下時提示一次：帳篷可以回血（main.lua 在主角能自由走動時呼叫）
function heal_tip_check()
  if FLAGS.tip_heal or not FLAGS.starter then return end
  for _, k in ipairs(party) do
    if k.hp * 2 < kin_max_hp(k) then
      FLAGS.tip_heal = true
      dialog_open("（野伴受傷了。\n回新芽營地的帳篷休息，隨時都能全部回滿。）" ..
        "\f（帳篷上冒出愛心，就是野伴需要休息的意思。\n苔石村的旅店也可以休息。）")
      return
    end
  end
end

-- 換日（clock.lua 走到半夜 24:00 時呼叫；不用睡覺也會換日，照幻獸帕魯）
--   1. DAY + 1：野外的採集點重新長出來
--   2. 派駐的野伴吃飼料（facility_feed），結果記在 LAST_FEED，睡醒時報告
--   3. 派駐的野伴恢復（工作的野伴不會受傷，只是保險）
LAST_FEED = LAST_FEED or nil
function day_change()
  GATHERED = {}   -- 全部都能再撿（順便讓存檔不要越存越大）
  local before = season()
  DAY = DAY + 1
  if season() ~= before then SEASON_NEWS = season() end   -- 換季：等主角能動時提示（season.lua）
  local workers, hungry = facility_feed()
  LAST_FEED = { day = DAY, workers = workers, hungry = hungry }
  for _, fac in pairs(FACILITY) do
    for _, k in ipairs(fac.workers) do kin_heal(k) end
  end
end

-- 背包裡每樣東西有幾個（睡前、睡後比較，就知道睡覺時設施產出了什麼）
local function bag_copy()
  local t = {}
  for k, n in pairs(BAG) do t[k] = n end
  return t
end

-- 睡前和睡後的背包差：「木材 +3、莓果 +1」（飼料是被吃掉的，另外報告）
local function gained_text(before)
  local keys = {}
  for k, n in pairs(BAG) do
    if k ~= "feed" and n > (before[k] or 0) then keys[#keys + 1] = k end
  end
  table.sort(keys, function(a, b) return DATA.items[a].sort < DATA.items[b].sort end)
  local parts = {}
  for _, k in ipairs(keys) do parts[#parts + 1] = DATA.items[k].name .. " +" .. (BAG[k] - (before[k] or 0)) end
  return table.concat(parts, "、")
end

local function heal_all()
  for _, k in ipairs(party) do kin_heal(k) end
  FLAGS.slept = true   -- 任務日誌：睡過一覺
end

-- 睡到隔天早上 06:00（全黑的時候呼叫），回傳早上要說的話
local function sleep_to_morning()
  local before, day0 = bag_copy(), DAY
  local gathered_any = next(GATHERED) ~= nil
  clock_add_minutes(minutes_until(6))
  TIME_SUB = 0
  heal_all()
  local _, sname = season()
  local lines = { "天亮了，第 " .. DAY .. " 天（" .. sname .. "）。\n野伴們都恢復精神了！" }
  local got = gained_text(before)
  if got ~= "" then lines[#lines + 1] = "睡覺的時候，設施做好了：\n" .. got end
  local f = LAST_FEED
  if f and f.day > day0 and f.workers > 0 then
    local fed = f.workers - f.hungry
    if fed > 0 then lines[#lines + 1] = "派駐的野伴吃掉了飼料 ×" .. fed .. "。" end
    if f.hungry > 0 then
      lines[#lines + 1] = "飼料不夠！有 " .. f.hungry .. " 隻野伴今天要餓著肚子工作，\n產量少一半。（飼料可以在工作台做）"
    end
  end
  if gathered_any then lines[#lines + 1] = "野外的採集點又長出來了。" end
  if SEASON_NEWS then
    lines[#lines + 1] = season_news_text(SEASON_NEWS)   -- 睡覺時換季：早上一起說
    SEASON_NEWS = nil
  end
  return table.concat(lines, "\n")
end

-- 白天小睡：過 1 小時、隊伍恢復
local function nap()
  clock_add_minutes(60)
  heal_all()
  return "睡了一個小時，現在 " .. clock_text() .. "。\n野伴們都恢復精神了！"
end

-- 除錯用（debug.lua 的「睡到明天早上」）
function dbg_next_day()
  if title_active() then title_close(); new_game(1) end
  dialog_open(sleep_to_morning())
end

-- 床：傍晚、晚上才能睡到早上（帕魯只有晚上能睡）；其他時間只能小睡一下
function bed_interact(b)
  local p = time_period()
  local night = (p == "evening" or p == "night")
  local ask = night and "要睡到明天早上嗎？" or ("現在 " .. clock_text() .. "，還不太睏。\n要小睡一下嗎？（過 1 小時）")
  dialog_ask(ask, { "睡覺", "不要" }, function(c)
    if c ~= 1 then return end
    dialog_open(PLAYER_NAME .. "鑽進睡袋。\n腰發出了「喀」的一聲。", function()
      local after
      transition_start(function() after = night and sleep_to_morning() or nap() end, false,
        { hold = night and 90 or 45, caption = "Zzz……", on_end = function() dialog_open(after) end })
    end)
  end)
end
