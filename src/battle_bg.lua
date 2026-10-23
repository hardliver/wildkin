-- battle_bg.lua：戰鬥背景（2026-10-22 Neil：戰鬥畫面改版，隨地點、時間、天氣變化）
--
-- 地點：看戰鬥發生在哪張地圖（BG_OF_MAP）→ 草原、霧林、礦坑、海邊、火山、工廠六種
-- 時間、天氣：背景用自己的 11 個顏色（調色盤 242～252 號，圖片的顏色只到 230 號），
--   開戰時照「現在的時段、天氣」把這 11 個顏色算好（battle_bg_begin）。野伴的圖不受影響（照樣原色）
--   室內（礦坑、火山洞、工廠）不管時間和天氣
-- 雨、雪、花瓣：直接用地圖上的那一套（weather.lua 的 weather_draw、season.lua 的 season_weather_draw）
--
-- 畫法只用 rect 和整數：開戰時把整個背景算成一串長方形存起來，每幀只是照著畫（運算預算 W62）

-- 11 個角色 → 調色盤號碼
local SKY1, SKY2, FAR1, FAR2, NEAR1, NEAR2, GROUND1, GROUND2, GDOT, PLAT1, PLAT2 =
  250, 242, 243, 244, 245, 246, 251, 252, 247, 248, 249
local ROLES = { SKY1, SKY2, FAR1, FAR2, NEAR1, NEAR2, GROUND1, GROUND2, GDOT, PLAT1, PLAT2 }

-- 每種地點的 11 個顏色（順序同 ROLES）
local COLORS = {
  grass   = { {150,200,240}, {200,230,248}, {170,210,150}, {140,190,130}, {90,160,80}, {50,110,60},
              {176,216,128}, {158,202,114}, {130,180,100}, {150,205,110}, {100,160,80} },
  forest  = { {120,170,150}, {160,200,170}, {70,120,80}, {50,95,65}, {40,80,55}, {28,58,42},
              {120,165,95}, {108,152,86}, {80,125,70}, {110,160,90}, {70,115,60} },
  cave    = { {50,40,45}, {70,58,60}, {95,82,78}, {75,64,62}, {110,95,88}, {55,46,48},
              {140,120,100}, {128,110,92}, {100,85,72}, {155,135,112}, {110,92,78} },
  beach   = { {140,200,245}, {200,232,250}, {70,150,210}, {120,190,235}, {235,245,250}, {50,120,190},
              {240,220,160}, {228,206,146}, {200,175,120}, {245,228,175}, {205,180,125} },
  volcano = { {60,30,35}, {110,45,40}, {90,50,45}, {70,40,40}, {240,130,50}, {150,60,40},
              {110,80,70}, {98,72,64}, {70,50,48}, {125,92,80}, {85,62,56} },
  factory = { {90,96,110}, {120,126,140}, {150,156,168}, {110,116,130}, {230,190,60}, {50,50,55},
              {170,170,165}, {158,158,154}, {130,130,128}, {185,185,180}, {140,140,136} },
}
local INDOOR_BG = { cave = true, volcano = true, factory = true }

BG_OF_MAP = {
  camp = "grass", route1 = "grass", village = "grass", forest = "forest", mine = "cave",
  harbor = "beach", coast = "beach", volcano = "volcano", factory = "factory", office = "factory",
}

local bg = "grass"

local function mix(a, b, k)   -- a、b 混合，k/256 是 b 的比例
  return a + (b - a) * k // 256
end

-- 開戰時呼叫：決定背景、算好這次的顏色
function battle_bg_begin()
  bg = BG_OF_MAP[world.name] or "grass"
  local cols = COLORS[bg]
  local tr, tg, tb = 256, 256, 256
  local w = nil
  if not INDOOR_BG[bg] then
    -- 時間：地圖上的晝夜色調，只用一半（太暗看不清楚野伴的站台）
    local r, g, b = tint_at(TIME)
    tr, tg, tb = (r + 256) // 2, (g + 256) // 2, (b + 256) // 2
    w = weather_now()
  end
  local gray = 0          -- 天空、遠景往灰色靠多少（/256）
  if w == "cloudy" then gray = 110 elseif w == "rain" then gray = 150 elseif w == "storm" then gray = 190
  elseif w == "fog" then gray = 170 elseif w == "snow" then gray = 120 end
  local wr, wg, wb = weather_tint()
  for i, c in ipairs(cols) do
    local r, g, b = c[1], c[2], c[3]
    local k = gray
    if i > 6 then k = gray // 3 end          -- 地面、站台受天氣影響比較少
    if w == "fog" then r, g, b = mix(r, 225, k), mix(g, 228, k), mix(b, 230, k)
    elseif w == "snow" and i > 6 then r, g, b = mix(r, 235, 140), mix(g, 240, 140), mix(b, 248, 140)   -- 積雪
    else local y = (r * 3 + g * 6 + b) // 10; r, g, b = mix(r, y, k), mix(g, y, k), mix(b, y + 8, k) end
    r = r * tr // 256 * wr // 256
    g = g * tg // 256 * wg // 256
    b = b * tb // 256 * wb // 256
    pal(ROLES[i], clamp(r, 0, 255), clamp(g, 0, 255), clamp(b, 0, 255))
  end
  battle_bg_build()
end

-- ============================================================
-- 背景是「一串長方形」：開戰時算好存在 R（x, y, w, h, 顏色 五個一組），每幀照著畫
-- 2026-10-22：第一版每幀用迴圈一個一個畫圓弧，一幀 1100 多次繪圖呼叫、平均負載 100%。
-- 改成事先把同一列連在一起的部分合併成一條，每幀只剩 200 多個長方形
-- ============================================================
local R = {}
local function add(x, y, w, h, c)
  if w <= 0 or h <= 0 then return end
  R[#R + 1] = x; R[#R + 1] = y; R[#R + 1] = w; R[#R + 1] = h; R[#R + 1] = c
end

-- 一排半圓（樹叢、山丘、岩石）：底部對齊 y_base，半徑 r，間隔 step。
-- 每一列把重疊的部分合併成一段；row = 每幾列算一次（遠處的山丘 2 列一階，比較省）
-- outline：先畫外面大一圈的深色，再畫裡面
local function bumps(y_base, r, step, offset, c_out, c_in, row)
  row = row or 1
  local function spans(rr, grow)
    for dy = 0, rr, row do
      local list = {}
      local hw = 0
      while (hw + 1) * (hw + 1) + dy * dy <= rr * rr do hw = hw + 1 end
      for x = offset - r, SCREEN_W + r, step do
        local a, b = x - hw - grow, x + hw + grow
        local last = list[#list]
        if last and a <= last[2] + 1 then last[2] = math.max(last[2], b) else list[#list + 1] = { a, b } end
      end
      for _, sp in ipairs(list) do
        add(math.max(0, sp[1]), y_base - dy - row + 1 - grow, math.min(SCREEN_W - 1, sp[2]) - math.max(0, sp[1]) + 1, row, grow > 0 and c_out or c_in)
      end
    end
  end
  if c_out then spans(r, 1) end
  spans(r, 0)
end

local BUILD = {}
BUILD.grass = function()
  add(0, 0, SCREEN_W, 36, SKY1); add(0, 36, SCREEN_W, 34, SKY2)
  bumps(66, 18, 46, 10, nil, FAR1, 2)         -- 遠處的山丘（不畫外框、2 列一階）
  bumps(70, 9, 15, 4, NEAR2, NEAR1)           -- 樹叢
end
BUILD.forest = function()
  add(0, 0, SCREEN_W, 28, SKY1); add(0, 28, SCREEN_W, 42, SKY2)
  bumps(46, 16, 30, 0, nil, FAR1, 2)          -- 樹冠
  for x = 6, SCREEN_W, 30 do add(x, 44, 6, 26, NEAR2) end   -- 樹幹
  bumps(70, 8, 13, 6, NEAR2, NEAR1)           -- 灌木
end
BUILD.cave = function()
  add(0, 0, SCREEN_W, 70, FAR1)
  for y = 6, 66, 12 do                         -- 岩壁的石縫
    add(0, y, SCREEN_W, 1, FAR2)
    for x = (y // 12 % 2) * 20, SCREEN_W - 1, 40 do add(x, y - 11, 1, 11, FAR2) end
  end
  bumps(70, 7, 23, 8, NEAR2, NEAR1)           -- 地上的碎石堆
end
BUILD.beach = function()
  add(0, 0, SCREEN_W, 30, SKY1); add(0, 30, SCREEN_W, 20, SKY2)
  add(0, 50, SCREEN_W, 18, FAR1)              -- 海（浪在 battle_bg_draw 畫，會動）
  add(0, 67, SCREEN_W, 3, NEAR1)              -- 浪花
end
BUILD.volcano = function()
  add(0, 0, SCREEN_W, 40, SKY1); add(0, 40, SCREEN_W, 24, SKY2)
  bumps(64, 20, 52, 20, nil, FAR1, 2)         -- 岩壁
  add(0, 64, SCREEN_W, 3, NEAR1)              -- 熔岩的光
  add(0, 67, SCREEN_W, 3, NEAR2)
end
BUILD.factory = function()
  add(0, 0, SCREEN_W, 58, FAR1)
  for x = 0, SCREEN_W - 1, 40 do add(x, 0, 1, 58, FAR2) end   -- 鐵板的接縫
  add(0, 20, SCREEN_W, 1, FAR2)
  for x = 0, SCREEN_W - 1, 16 do               -- 黃黑警示條
    add(x, 58, 8, 10, NEAR1); add(x + 8, 58, 8, 10, NEAR2)
  end
  add(0, 68, SCREEN_W, 2, NEAR2)
end

function battle_bg_build()   -- battle_bg_begin 會呼叫（定義在這裡，所以不能用 local）
  R = {}
  BUILD[bg]()
  -- 地面不用畫：battle_bg_draw 先用地面色 cls（cls 比畫一個大長方形省很多）
  for y = 84, 180, 16 do add(0, y, SCREEN_W, 2, GROUND2) end   -- 地面淡淡的條紋
  for i = 1, 30 do                                              -- 小草、碎石
    local h = hash(i, 4711)
    add(h % 318, 70 + (h // 320) % 112, 2, 1, GDOT)
  end
end

-- 畫整個背景：整個畫面先塗地面色，再畫上面的天空、遠景
function battle_bg_draw()
  cls(GROUND1)
  for i = 1, #R, 5 do rect(R[i], R[i + 1], R[i + 2], R[i + 3], R[i + 4]) end
  if bg == "beach" then                       -- 浪慢慢往右
    local t = frame() // 12 % 32
    for y = 53, 64, 5 do
      for x = (y * 7 + t) % 32 - 32, SCREEN_W, 32 do rect(x, y, 10, 1, FAR2) end
    end
  end
end

-- 野伴腳下的站台：深色外框、邊、亮面
function battle_bg_platform(cx, cy, rx, ry, ellipse)
  ellipse(cx, cy, rx + 1, ry + 1, 0)
  ellipse(cx, cy, rx, ry, PLAT2)
  ellipse(cx, cy - 1, rx - 3, ry - 2, PLAT1)
end

-- 除錯用：背景有幾個長方形、總共幾個像素
function battle_bg_stats()
  local n, px = 0, 0
  for i = 1, #R, 5 do n = n + 1; px = px + R[i + 2] * R[i + 3] end
  return n, px
end
