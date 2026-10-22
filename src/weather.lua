-- weather.lua：天氣（W64f，2026-10-22 Neil）
--
-- 每個時段（早上、白天、傍晚、晚上）一種天氣：晴天、陰天、下雨、起霧、雷雨（夏）、下雪（冬）。
-- 天氣只由「第幾天、第幾個時段」算出來（hash），不用 rnd、不用存檔：同一天同一時段一定一樣。
--   ‧ 機率看季節（WEATHER_ODDS）；霧只在早上（FOG_ODDS）；雷雨只在白天、傍晚，其他時段變下雨
--   ‧ 一半的機會延續上一個時段的天氣，不會一直跳來跳去
-- 室內（舊礦坑、火山洞，dark.lua 的 indoor_map）沒有天氣：weather_now() 回傳 nil
--
-- 天氣影響：
--   ‧ 畫面：雨絲、雪、霧團（weather_draw）、整體變暗（weather_tint，clock.lua 的 clock_tint 用）
--   ‧ 遭遇：encounters.json 每一筆可以設 "weather": { "rain": 3 }（那種天氣權重乘幾倍，0 = 不出現）
--   ‧ 戰鬥：下雨、雷雨時水招 ×1.5、火招 ×0.5；晴天反過來（battle.lua 的 weather_power）
--   ‧ 大志的膝蓋：下一個時段要下雨時，膝蓋會痠（一定準），提前說一聲（weather_check）

WEATHER_NAMES = { sunny = "晴天", cloudy = "陰天", rain = "下雨", fog = "起霧", storm = "雷雨", snow = "下雪" }

local WEATHER_ODDS = {
  spring = { { "sunny", 45 }, { "cloudy", 30 }, { "rain", 25 } },
  summer = { { "sunny", 50 }, { "cloudy", 10 }, { "rain", 15 }, { "storm", 25 } },
  autumn = { { "sunny", 45 }, { "cloudy", 35 }, { "rain", 20 } },
  winter = { { "sunny", 30 }, { "cloudy", 35 }, { "snow", 35 } },
}
-- 早上起霧的機率（%）：下雨、下雪的早上不起霧
local FOG_ODDS = { spring = 25, summer = 10, autumn = 30, winter = 20 }

local function base_pick(day, pi)
  local odds = WEATHER_ODDS[season(day)]
  local total = 0
  for _, o in ipairs(odds) do total = total + o[2] end
  local r = hash(day * 4 + pi, 4242) % total
  for _, o in ipairs(odds) do
    if r < o[2] then return o[1] end
    r = r - o[2]
  end
  return "sunny"
end

local function fit(w, pi)
  if w == "storm" and (pi == 1 or pi == 4) then return "rain" end
  return w
end

-- 第 day 天第 pi 個時段（1 早上、2 白天、3 傍晚、4 晚上）的天氣
function weather_at(day, pi)
  local w = base_pick(day, pi)
  if hash(day * 4 + pi, 777) % 2 == 0 then                -- 延續上一個時段
    if pi > 1 then w = base_pick(day, pi - 1) else w = base_pick(day - 1, 4) end
  end
  w = fit(w, pi)
  if pi == 1 and (w == "sunny" or w == "cloudy") and hash(day, 4343) % 100 < FOG_ODDS[season(day)] then w = "fog" end
  return w
end

-- 現在是第幾天的第幾個時段（05 點以前算前一天的晚上）
local function period_index(t)
  t = t or TIME
  local pi = #PERIODS
  for i, q in ipairs(PERIODS) do
    if t >= q[1] then pi = i end
  end
  local day = DAY
  if t < PERIODS[1][1] then day = day - 1 end
  return day, pi
end

local function next_period(day, pi)
  if pi < #PERIODS then return day, pi + 1 end
  return day + 1, 1
end

-- 現在的天氣（室內回傳 nil）
-- DEBUG_WEATHER：除錯用，固定成某種天氣（debug.lua 的按鈕）
function weather_now()
  if indoor_map() then return nil end
  if DEBUG_WEATHER then return DEBUG_WEATHER end
  return weather_at(period_index())
end

-- 下一個時段的天氣（不管室內外）
function weather_next()
  return weather_at(next_period(period_index()))
end

local function wet(w) return w == "rain" or w == "storm" end

-- ============================================================
-- 戰鬥：招式威力的天氣倍率（回傳分子，分母 2）
-- ============================================================
function weather_power(w, move_type)
  if wet(w) then
    if move_type == "water" then return 3 end
    if move_type == "fire" then return 1 end
  elseif w == "sunny" then
    if move_type == "fire" then return 3 end
    if move_type == "water" then return 1 end
  end
  return 2
end

-- 戰鬥開始時說的話（沒有就 nil）
local BATTLE_TEXT = {
  rain = "正在下雨。\n水招變強了，火招變弱了。",
  storm = "雷雨交加！\n水招變強了，火招變弱了。",
  sunny = "陽光很強。\n火招變強了，水招變弱了。",
}
function weather_battle_text(w) return w and BATTLE_TEXT[w] end

-- ============================================================
-- 大志的膝蓋（一定準）
-- ============================================================
-- 每個時段開始時看一次：現在沒下雨、下一個時段會下雨 → 說一聲
local knee_done = nil
local KNEE = {
  "（膝蓋有點痠……\n等一下應該會下雨。）",
  "（膝蓋又在痠了。\n比氣象預報還準。）",
  "（這個膝蓋……\n待會兒一定下雨。）",
}
function weather_check()
  local day, pi = period_index()
  local key = day * 4 + pi
  if knee_done == key then return end
  knee_done = key
  if not FLAGS.starter then return end                  -- 序章一開始不要插話
  if wet(weather_at(day, pi)) then return end
  if not wet(weather_at(next_period(day, pi))) then return end
  dialog_open(KNEE[hash(key, 9) % #KNEE + 1])
end
-- 睡醒、讀檔之後：這個時段已經說過了（醒來的報告自己會說）
function weather_check_skip()
  local day, pi = period_index()
  knee_done = day * 4 + pi
end

-- 睡醒的報告用：「外面是陰天。」＋（今天之後會下雨的話）膝蓋
function weather_wake_text()
  local w = weather_at(period_index())
  local s = "外面是" .. WEATHER_NAMES[w] .. "。"
  if w == "rain" then s = "外面在下雨。" elseif w == "storm" then s = "外面雷雨交加。" elseif w == "snow" then s = "外面在下雪。" elseif w == "fog" then s = "外面起霧了。" end
  if not wet(w) and wet(weather_next()) then s = s .. "\n膝蓋痠痠的……等一下應該會下雨。" end
  return s
end

-- ============================================================
-- 畫面
-- ============================================================
-- 整體變暗多少（256 = 不變），clock_tint 乘上去
local TINT = { cloudy = { 230, 230, 236 }, rain = { 200, 205, 220 }, storm = { 175, 180, 200 },
               fog = { 236, 236, 240 }, snow = { 240, 244, 256 } }
function weather_tint()
  local w = weather_now()
  local t = w and TINT[w]
  if not t then return 256, 256, 256 end
  return t[1], t[2], t[3]
end

-- 雨絲（畫面座標）：每一條的位置只由「第幾條」和 frame() 決定
local function rain_draw(n, speed)
  local t = frame()
  for i = 1, n do
    local h = hash(i, 31)
    local period = 50 + h % 30
    local p = (t * speed + h) % period
    local y = p * (SCREEN_H + 24) // period - 12
    local x = (h // 5 + p // 3) % (SCREEN_W + 20) - 10
    local c = (h % 3 == 0) and 7 or 6
    rect(x, y, 1, 4, c)                                      -- 斜斜的一條：兩段 1×4（省繪圖呼叫）
    rect(x - 1, y + 4, 1, 4, c)
  end
end

function weather_draw()
  local w = weather_now()
  if w == "rain" then rain_draw(45, 3)
  elseif w == "storm" then rain_draw(75, 4) end
end

-- 季節的飄落物（season.lua）要不要畫：下雨、雷雨時不畫花瓣落葉；雪只有下雪時才畫
-- 回傳要用哪一季的樣子（nil = 不畫）：下雪一定是雪花
function weather_fall(s)
  local w = weather_now()
  if w == "snow" then return "winter" end
  if s == "winter" or wet(w) then return nil end
  return s
end

-- 起霧：任何室外地圖都畫霧團（fog.lua）
function weather_fog_count()
  if weather_now() == "fog" then return 18 end
  return 0
end
