-- day.lua：換日、帳篷睡覺（W46；W64c 改成遊戲時鐘）
--
-- 營地有主角的帳篷（地圖物件 type = "bed"，2×2 格、擋路）。面對它按 A →「要睡幾個小時？」（1～24）
--   → 畫面暗下來（Zzz……）→ 時間快轉 → 報告現在幾點、睡覺時的產出。隊伍全部恢復（HP、招式次數、狀態）
--   旅店、海岸阿婆的小屋也用同一個 rest_open
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

-- 睡 hours 小時（全黑的時候呼叫），回傳醒來要說的話：現在幾點、睡覺時設施做了什麼、飼料、換季
local function sleep_hours(hours)
  local before, day0 = bag_copy(), DAY
  local gathered_any = next(GATHERED) ~= nil
  clock_add_minutes(hours * 60)
  TIME_SUB = 0
  heal_all()
  local _, sname = season()
  local _, pname = time_period()
  local lines = { "睡了 " .. hours .. " 個小時。\n現在是第 " .. DAY .. " 天（" .. sname .. "）" .. clock_text() .. " " .. pname .. "。",
                  "野伴們都恢復精神了！" }
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
  if gathered_any and DAY > day0 then lines[#lines + 1] = "野外的採集點又長出來了。" end
  if SEASON_NEWS then
    lines[#lines + 1] = season_news_text(SEASON_NEWS)   -- 睡覺時換季：醒來一起說
    SEASON_NEWS = nil
  end
  return table.concat(lines, "\f")
end

-- 醒來會是什麼時候：「第 3 天 06:00 早上」
local function wake_text(hours)
  local t = TIME + hours * 60
  local day = DAY + t // (24 * 60)
  t = t % (24 * 60)
  local _, pname = time_period(t)
  return "醒來：第 " .. day .. " 天 " .. clock_text(t) .. " " .. pname
end

-- 休息（W64c 改，2026-10-22 Neil：白天晚上都可以自己選睡幾個小時）
-- 帳篷、苔石旅店、港灣旅店、海岸阿婆的小屋共用。opts：
--   before：開始睡之前說的話（「大志鑽進睡袋。」）；after：醒來報告之後多說的話（「腰痠沒有回復。」）
-- 一開始停在 1 小時（2026-10-22 Neil）；上下 ±10、左右 ±1，下面會顯示醒來是幾點
function rest_open(opts)
  opts = opts or {}
  amount_pick("要睡幾個小時？", 24,
    function(n) return "睡 " .. n .. " 小時" end,
    function(n) return wake_text(n) end,
    function(n)
      local function go()
        local report
        transition_start(function() report = sleep_hours(n) end, false,
          { hold = math.min(90, 30 + n * 5), caption = "Zzz……",
            on_end = function() dialog_open(report .. (opts.after and ("\f" .. opts.after) or "")) end })
      end
      if opts.before then dialog_open(opts.before, go) else go() end
    end, "睡覺", 1)
end

-- 除錯用（debug.lua 的「睡到明天早上」）
function dbg_next_day()
  if title_active() then title_close(); new_game(1) end
  dialog_open(sleep_hours(minutes_until(6) // 60))
end

-- 帳篷
function bed_interact(b)
  rest_open({ before = PLAYER_NAME .. "鑽進睡袋。\n腰發出了「喀」的一聲。" })
end
