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
-- 時間完全由存檔和按鍵決定，不讀現實時間（現實時鐘模式是 W64e）

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

-- 現在的季節：回傳代號、名字
function season(day)
  local s = SEASONS[((day or DAY) - 1) // DAYS_PER_SEASON % 4 + 1]
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
  return "第 " .. DAY .. " 天（" .. sname .. "）　" .. clock_text() .. " " .. pname .. (w and ("　" .. WEATHER_NAMES[w]) or "")
end

-- 時間往前走 n 分鐘：一分鐘一分鐘走，每個整點和半夜都會照順序結算（睡覺一次走好幾百分鐘也一樣）
function clock_add_minutes(n)
  for _ = 1, n do
    TIME = TIME + 1
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
