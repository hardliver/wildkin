-- clock.lua：遊戲時鐘、時段、季節、晝夜的顏色（W64c）
--
-- 規則（content.md「晝夜與季節／定案」）：
--   現實 1 秒 = 遊戲 1 分鐘（1 分鐘 = 1 小時，一天 24 分鐘，和阿爾宙斯一樣）
--   只有在地圖上自由走動時才走；戰鬥、選單、對話、劇情、轉場時停住（main.lua 的 _update 決定）
--   每到整點：設施產出一小時份（facility_hour）
--   半夜 24:00：自動換日（day.lua 的 day_change）——照幻獸帕魯，不用睡覺也會換日
--   時段：早上 05–12、白天 12–19、傍晚 19–21、晚上 21–05
--   季節：7 天一季，春→夏→秋→冬（第 1–7 天春）
--
-- 記錄（存檔一起存）：TIME = 今天第幾分鐘（0～1439），TIME_SUB = 這一分鐘過了幾幀（0～59）
-- 遊戲時鐘：時間完全由存檔和按鍵決定，不讀現實時間。現實時鐘模式（W64e）見這個檔案最後面

FRAMES_PER_MINUTE = 60
TIME = TIME or 8 * 60
TIME_SUB = TIME_SUB or 0

-- 時段：從幾點開始、代號、名字（照時間排好）
PERIODS = {
  { 5 * 60, "morning", "早上" },
  { 12 * 60, "day", "白天" },
  { 19 * 60, "evening", "傍晚" },
  { 21 * 60, "night", "晚上" },
}

-- 現在的時段：回傳代號、名字（05 點以前算前一天的晚上）
function time_period(t)
  t = t or TIME
  local p = PERIODS[#PERIODS]
  for _, q in ipairs(PERIODS) do
    if t >= q[1] then p = q end
  end
  return p[2], p[3]
end

SEASONS = { { "spring", "春" }, { "summer", "夏" }, { "autumn", "秋" }, { "winter", "冬" } }
DAYS_PER_SEASON = 7

-- 現實時鐘的季節照月份：春 3–5 月、夏 6–8、秋 9–11、冬 12–2（SEASONS 的第幾個）
local MONTH_SEASON = { 4, 4, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4 }

-- 現在的季節：回傳代號、名字
-- 現實時鐘模式看現實的月份（day 不用）；遊戲時鐘看第幾天
function season(day)
  local i
  if CLOCK_MODE == "real" and REAL_MONTH then
    i = MONTH_SEASON[REAL_MONTH]
  else
    i = ((day or DAY) - 1) // DAYS_PER_SEASON % 4 + 1
  end
  local s = SEASONS[i]
  return s[1], s[2]
end

-- 「08:05」
function clock_text(t)
  t = t or TIME
  return string.format("%02d:%02d", t // 60, t % 60)
end

-- 「第 3 天（春）　14:20 白天」
function clock_long_text()
  local _, sname = season()
  local _, pname = time_period()
  local w = weather_now()
  return "第 " .. DAY .. " 天（" .. sname .. "）　" .. clock_text() .. " " .. pname .. (w and ("　" .. WEATHER_NAMES[w]) or "") ..
    "\n" .. PLAYER_NAME .. "：" .. sleep_status_text()
end

-- 時間往前走 n 分鐘：一分鐘一分鐘走，每個整點和半夜都會照順序結算（睡覺一次走好幾百分鐘也一樣）
function clock_add_minutes(n)
  for _ = 1, n do
    TIME = TIME + 1
    sleep_minute()                               -- 睡眠債、落枕（sleep.lua）
    if TIME % 60 == 0 then facility_hour() end   -- 剛過完的這一小時的產出
    if TIME >= 24 * 60 then
      TIME = 0
      day_change()
    end
  end
end

-- 每幀呼叫（只在地圖上自由走動時）
function clock_tick()
  TIME_SUB = TIME_SUB + 1
  if TIME_SUB >= FRAMES_PER_MINUTE then
    TIME_SUB = 0
    clock_add_minutes(1)
  end
end

-- main.lua 每幀呼叫（只在地圖上自由走動時）：遊戲時鐘就走一幀；現實時鐘每秒對一次時
local real_wait = 0
function clock_update()
  if CLOCK_MODE ~= "real" then
    clock_tick()
    return
  end
  real_wait = real_wait - 1
  if real_wait > 0 then return end
  real_wait = FRAMES_PER_MINUTE      -- 1 秒後再讀（只要分鐘，不必每幀讀）
  if not realclock_sync(false) then
    clock_add_minutes(1)             -- 沒有時間來源：這 1 秒照遊戲時鐘走（60 幀 = 1 遊戲分鐘）
  end
end

-- 從現在走到下一次的 h 點整，要幾分鐘（剛好 h 點整就是 24 小時後）
function minutes_until(h)
  local n = (h * 60 - TIME) % (24 * 60)
  if n == 0 then n = 24 * 60 end
  return n
end

-- ============================================================
-- 晝夜的顏色：用 paltint 把圖片用的顏色（16～243）整片乘上一個倍率
-- ============================================================
-- 介面用 0～15 號色（框、字），不受影響；戰鬥背景、野伴球用 244 以後，也不受影響。
-- 下面是幾個時間點的倍率（256 = 原色），中間的時間依比例算：交界會慢慢變，不會一下子跳過去。

local TINT = {
  { 0,       140, 150, 205 },   -- 晚上：暗、偏藍
  { 4 * 60,  140, 150, 205 },
  { 6 * 60,  256, 246, 214 },   -- 早上：偏淡黃
  { 11 * 60, 256, 250, 226 },
  { 12 * 60, 256, 256, 256 },   -- 白天：原色
  { 18 * 60, 256, 256, 256 },
  { 19 * 60 + 30, 256, 196, 150 },   -- 傍晚：偏橘
  { 20 * 60 + 30, 236, 178, 156 },
  { 22 * 60, 140, 150, 205 },
  { 24 * 60, 140, 150, 205 },
}

function tint_at(t)
  for i = 1, #TINT - 1 do
    local a, b = TINT[i], TINT[i + 1]
    if t >= a[1] and t < b[1] then
      local d, k = b[1] - a[1], t - a[1]
      return a[2] + (b[2] - a[2]) * k // d, a[3] + (b[3] - a[3]) * k // d, a[4] + (b[4] - a[4]) * k // d
    end
  end
  return 256, 256, 256
end

local last_tint = nil
-- 每幀畫面開始時呼叫：neutral = true 時用原色（戰鬥、標題、選單畫面：那些畫面上的野伴圖也用這些顏色）
-- 只有倍率改變時才真的呼叫 paltint（一遊戲分鐘才變一次）
function clock_tint(neutral)
  local r, g, b = 256, 256, 256
  if not neutral then
    r, g, b = tint_at(TIME)
    local wr, wg, wb = weather_tint()                      -- 陰天、下雨暗一點（weather.lua）
    r, g, b = r * wr // 256, g * wg // 256, b * wb // 256
    -- 營地有發電機在發電（W70）：晚上的暗只剩一半，而且偏暖色（燈泡的光）
    if world.name == "camp" and camp_lit() and r < 256 then
      r, g, b = (r + 256) // 2, (g + 240) // 2, (b + 200) // 2
    end
  end
  local key = r * 1000000 + g * 1000 + b
  if key == last_tint then return end
  last_tint = key
  paltint(16, 228, r, g, b)
end

-- ============================================================
-- 現實時鐘模式（W64e）
-- ============================================================
-- 新遊戲時選，START 選單的「設定」可以改（content.md「晝夜與季節」）。
--   CLOCK_MODE = "game"（遊戲時鐘，預設）／"real"（現實時鐘）
-- 現實時鐘：
--   ‧ TIME 跟著現實的時、分（引擎的 clock()）；戰鬥、選單裡也照走，回到地圖時補上
--   ‧ 每過一次半夜一樣 DAY + 1、採集點重生；季節看現實的月份（MONTH_SEASON）
--   ‧ 沒玩的時候也照走：讀檔時補算離開的這段時間（產出、飼料、換日），最多 24 小時（REAL_MAX_AWAY）；
--     沒玩的時候算大志在睡覺（還睡眠債）。休息不能快轉時間（day.lua 的 rest_open）
--   ‧ 沒有時間來源（clock() 是 nil，例如主機沒有 RTC）：那段時間照遊戲時鐘走，不會卡住
-- 記錄（存檔）：CLOCK_MODE；REAL_LAST = 上一次對時是「1970 年起第幾分鐘」；REAL_MONTH = 現實的月份

CLOCK_MODE = CLOCK_MODE or "game"
REAL_LAST = REAL_LAST or nil
REAL_MONTH = REAL_MONTH or nil
REAL_MAX_AWAY = 24 * 60   -- 離開再久，最多補算幾分鐘（Neil 2026-10-22：先固定 24 小時，之後可以改成看倉庫）

-- 對時：讀現實的時間，把遊戲時間補到現在。
-- offline = true：這段時間大志不在遊戲裡（讀檔時），算他在睡覺
-- 回傳：有補算的分鐘、超過上限沒補算的分鐘；沒有時間來源回傳 nil
function realclock_sync(offline)
  local c = clock()
  if not c then return nil end
  local now = c.time // 60
  local season_before = season()
  REAL_MONTH = c.month
  local gap = 0
  if REAL_LAST and now > REAL_LAST then gap = now - REAL_LAST end
  -- REAL_LAST 只往前不往後：時鐘往回調的話，要等現實時間追上原本的位置才會再產出
  -- （不然「調回去、再調回來」就能一直刷離開的產出）
  if not REAL_LAST or now > REAL_LAST then REAL_LAST = now end
  local skipped = 0
  if gap > REAL_MAX_AWAY then
    -- 超過上限的部分：日期照走（第幾天要對），但不結算產出、飼料
    skipped = gap - REAL_MAX_AWAY
    gap = REAL_MAX_AWAY
    local t = TIME + skipped
    DAY = DAY + t // (24 * 60)
    TIME = t % (24 * 60)
  end
  if gap > 0 then
    if offline then sleep_begin() end   -- 睡眠債用「睡覺」的算法（sleep.lua）
    clock_add_minutes(gap)
    if offline then sleep_stop() end
  end
  -- 對齊現實的時、分：平常本來就一樣；時鐘往回調、或除錯指令改過時間，在這裡拉回來
  TIME, TIME_SUB = c.hour * 60 + c.min, 0
  if season() ~= season_before then SEASON_NEWS = season() end   -- 換月換季：等主角能動時提示
  return gap, skipped
end

-- 換時鐘模式（新遊戲、START 選單的設定）。要換成現實時鐘、但這台機器沒有時間來源，回傳 false
function clock_mode_set(mode)
  local season_before = season()
  if mode == "real" then
    if not clock() then return false end
    CLOCK_MODE = "real"
    REAL_LAST = nil         -- 換過來的這一刻不算離開，不補算
    realclock_sync(false)
  else
    CLOCK_MODE = "game"     -- 日期、時間從現在接著走
  end
  if season() ~= season_before then SEASON_NEWS = season() end
  real_wait = 0
  return true
end

-- 「3 小時 20 分鐘」「1 天 2 小時」
function duration_text(minutes)
  local d, h, m = minutes // (24 * 60), minutes // 60 % 24, minutes % 60
  if d > 0 then return d .. " 天" .. (h > 0 and (" " .. h .. " 小時") or "") end
  if h > 0 then return h .. " 小時" .. (m > 0 and (" " .. m .. " 分鐘") or "") end
  return m .. " 分鐘"
end
