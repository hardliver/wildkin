-- season.lua：季節的樣子（W64d）
--
-- 季節怎麼算在 clock.lua（7 天一季：春→夏→秋→冬）。這裡負責「看起來」：
--   1. 地圖換色：草、樹、草叢的綠色，夏天深一點、秋天變橘黃、冬天變白（像積雪）
--      不用另外畫圖：和異色（shiny.lua）一樣，算出換色表，畫地圖時用 dpal 換
--      只換 Kenney 地圖圖片和草叢圖片裡的綠色；角色、設施、介面都不換
--   2. 飄落物：春天花瓣、秋天落葉、冬天雪花（畫面座標，畫在角色上面）
--   3. 換季時提示一次（day.lua 的 day_change 設 SEASON_NEWS）
-- 遭遇表的季節倍率在 encounter.lua（W64c 就做好了）

local SEASON_IMAGES = { "town", "tallgrass" }

-- 整數 RGB → HSV（h 0～359、s 0～255、v 0～255），和 shiny.lua 同一套算法
local function hsv(r, g, b)
  local mx, mn = math.max(r, g, b), math.min(r, g, b)
  local d = mx - mn
  local s = (mx == 0) and 0 or d * 255 // mx
  local h = 0
  if d > 0 then
    if mx == r then h = (60 * (g - b) // d) % 360
    elseif mx == g then h = 60 * (b - r) // d + 120
    else h = 60 * (r - g) // d + 240 end
  end
  return h % 360, s, mx
end

local function rgb(h, s, v)
  local c = v * s // 255
  local x = c * (60 - math.abs(h % 120 - 60)) // 60
  local m = v - c
  local r, g, b
  if h < 60 then r, g, b = c, x, 0
  elseif h < 120 then r, g, b = x, c, 0
  elseif h < 180 then r, g, b = 0, c, x
  elseif h < 240 then r, g, b = 0, x, c
  elseif h < 300 then r, g, b = x, 0, c
  else r, g, b = c, 0, x end
  return r + m, g + m, b + m
end

-- 可以換成的顏色：所有圖片用過的（調色盤不能新增顏色）
local cands = nil
local function nearest(r, g, b)
  if not cands then
    cands = {}
    local seen = {}
    for _, img in pairs(IMG) do
      for _, c in ipairs(imgcolors(img)) do
        if not seen[c] then
          seen[c] = true
          local cr, cg, cb = palget(c)
          cands[#cands + 1] = { c, cr, cg, cb }
        end
      end
    end
  end
  local best, bd = nil, nil
  for _, c in ipairs(cands) do
    local dr, dg, db = c[2] - r, c[3] - g, c[4] - b
    local d = 2 * dr * dr + 4 * dg * dg + 3 * db * db
    if not bd or d < bd then best, bd = c[1], d end
  end
  return best
end

-- 每一季把一個綠色 (h, s, v) 變成什麼顏色
local CHANGE = {
  summer = function(h, s, v) return h, math.min(255, s * 9 // 8), v * 7 // 8 end,       -- 深一點、濃一點
  autumn = function(h, s, v)                                                         -- 亮的（草地）偏黃、暗的（樹葉）偏橘紅
    -- Kenney 地圖只有 4 種綠：最暗的 (71,159,74) 只用在樹葉上，其他是草地
    if v > 160 then return 72, s, v end                          -- 草地：黃綠（不能太黃，不然和泥土路分不出來）
    return 18, math.min(255, s + 60), math.min(255, v + 30)
  end,
  winter = function(h, s, v) return h, s // 2, math.min(255, v + 30) end,             -- 結霜：淡淡帶綠的白
}

local maps = {}
function season_map(s)
  if not CHANGE[s] then return nil end
  if maps[s] then return maps[s] end
  local m = {}
  for _, name in ipairs(SEASON_IMAGES) do
    if IMG[name] then
      for _, c in ipairs(imgcolors(IMG[name])) do
        local r, g, b = palget(c)
        local h, sat, v = hsv(r, g, b)
        if h >= 65 and h <= 170 and sat >= 50 then        -- 綠色（草、樹葉）
          m[c] = nearest(rgb(CHANGE[s](h, sat, v)))
        end
      end
    end
  end
  maps[s] = m
  return m
end

-- ============================================================
-- 整張地圖換色（W70）：火山洞借舊礦坑的 Tiny Dungeon 圖塊，灰磚換成暗紅、棕色的地換成焦黑
-- 鐵輪工廠、社長室（W73）：灰磚換成冷冷的藍灰、棕色的地換成水泥灰
-- ============================================================
-- 和季節一樣：只換 Tiny Dungeon 圖片裡的顏色，換成遊戲已經有的顏色裡最接近的。有換色的地圖不跟季節變
local RECOLOR = {
  volcano = function(h, s, v)
    if s < 60 then return 8, 150, v * 3 // 4 end            -- 灰的（磚牆、石頭）→ 暗紅
    return 4, math.min(255, s + 20), v * 5 // 8              -- 棕的（地面）→ 焦黑帶紅
  end,
  factory = function(h, s, v)
    if s < 60 then return 215, 50, v end                       -- 灰的（磚牆）→ 藍灰
    return 30, 25, v * 3 // 4                                  -- 棕的（地面、木頭）→ 水泥灰
  end,
}
RECOLOR.office = RECOLOR.factory
-- 快取用換色函式當鍵（不是地圖名字）：社長室和工廠用同一個函式，算一次就好
local recolor_maps = {}
local function recolor_map(name)
  local f = RECOLOR[name]
  if recolor_maps[f] then return recolor_maps[f] end
  local m = {}
  for _, c in ipairs(imgcolors(IMG.dungeon)) do
    local r, g, b = palget(c)
    local h, s, v = hsv(r, g, b)
    if v > 40 and not (r > 200 and g < 120) then        -- 太暗的（外框）、紅色的（火把）不換
      m[c] = nearest(rgb(f(h, s, v)))
    end
  end
  recolor_maps[f] = m
  return m
end

-- 畫地圖之前呼叫：照現在的季節（或這張地圖的換色）設好；畫角色、設施之前呼叫 season_dpal(false) 還原
function season_dpal(on)
  local m = nil
  if on then
    if RECOLOR[world.name] then m = recolor_map(world.name) else m = season_map(season()) end
  end
  if m then dpal(m) else dpal() end
end

-- ============================================================
-- 飄落物（畫面座標）
-- ============================================================
-- 每一顆的位置只由「第幾顆」和 frame() 決定（用 hash，不用 rnd：rnd 是遊戲邏輯用的）

local FALL = {
  spring = { n = 10, speed = 3, sway = 5, colors = { 14, 15, 7 }, size = 2 },      -- 花瓣：粉紅、淡桃、白
  autumn = { n = 14, speed = 2, sway = 8, colors = { 9, 4, 10 }, size = 2 },       -- 落葉：橘、褐、黃
  winter = { n = 36, speed = 2, sway = 3, colors = { 7, 7, 6 }, size = 1 },        -- 雪花
}

function season_weather_draw()
  if indoor_map() then return end      -- 礦坑裡不下雪（dark.lua）
  local which = weather_fall(season())   -- 下雨不飄花瓣；雪只有下雪的時段才下（weather.lua）
  local f = which and FALL[which]
  if not f then return end
  local t = frame()
  for i = 1, f.n do
    local h = hash(i, 77)
    local period = 240 + h % 160                       -- 飄完一趟要幾幀
    local p = (t * f.speed // 2 + h) % period
    local y = p * (SCREEN_H + 20) // period - 10
    local x = (h // 7 + (t // 3) % SCREEN_W + isin_small(t + h, f.sway)) % SCREEN_W
    local c = f.colors[h % #f.colors + 1]
    if f.size == 1 then
      pset(x, y, c)
      if h % 3 == 0 then pset(x + 1, y, c) end
    else
      local flip = ((t // 10 + h) % 2 == 0)
      rect(x, y, 2, 1, c)
      rect(flip and x + 1 or x, y + 1, 2, 1, c)
    end
  end
end

-- 小小的左右擺動（-a～a），用整數三角波
function isin_small(t, a)
  local k = t % 64
  local w = (k < 32) and k or (64 - k)               -- 0～32～0
  return (w - 16) * a // 16
end

-- ============================================================
-- 換季提示
-- ============================================================
SEASON_NEWS = SEASON_NEWS or nil

local NEWS = {
  spring = "春天到了。\n草地上開滿了小花。",
  summer = "夏天到了。\n樹葉的顏色變深了。",
  autumn = "秋天到了。\n葉子開始變黃，霧林的菇好像變多了。",
  winter = "冬天到了。\n草地蓋上了一層薄薄的霜。",
}

function season_news_text(s)
  return "（" .. NEWS[s] .. "）"
end

-- 主角能自由走動時呼叫（main.lua）：半夜換季之後提示一次
function season_news_check()
  if not SEASON_NEWS then return end
  local s = SEASON_NEWS
  SEASON_NEWS = nil
  dialog_open(season_news_text(s))
end
