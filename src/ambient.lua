-- ambient.lua：讓世界「活」起來的小動作
--
--   呼吸：角色站著不動時，上半身每隔一陣子抬高 1 像素（吸氣）再放下
--   風：一陣一陣的風從左往右吹過地圖，經過的樹梢往右歪 1 像素、草叢翻動
--   蝴蝶：草地上飛來飛去的小蝴蝶
--
-- 這些都只是「看起來」的東西，不影響遊戲：
--   不用 rnd()：rnd 是遊戲共用的亂數，蝴蝶多抽一次，之後遇到的野伴就會不一樣。
--   改用 hash()：把幾個整數（幀數、位置、編號）攪在一起，得到看起來很亂、但每次都一樣的數字。
--   所以畫面怎麼動，只由「第幾幀」和「在哪裡」決定，重播、各平台都一樣。

-- ============================================================
-- 小工具
-- ============================================================

-- 把三個整數攪成 0～65535 之間的數字。同樣的輸入一定得到同樣的結果
function hash(a, b, c)
  local h = a * 73856093 ~ (b or 0) * 19349663 ~ (c or 0) * 83492791
  h = h ~ (h >> 13)
  h = h * 1274126177
  return (h >> 16) & 0xffff
end

-- 整數版的 sin：一圈分成 32 格，回傳 -8～8。不用 math.sin（小數在不同平台可能差一點點）
local SIN = { 0, 2, 3, 4, 6, 7, 7, 8, 8, 8, 7, 7, 6, 4, 3, 2,
              0, -2, -3, -4, -6, -7, -7, -8, -8, -8, -7, -7, -6, -4, -3, -2 }
function isin(i)
  return SIN[i % 32 + 1]
end

-- ============================================================
-- 呼吸
-- ============================================================
-- 每個角色的呼吸週期是 150 幀（2.5 秒），其中 50 幀上半身抬高 1 像素。
-- seed 讓每個人的節奏錯開，不會整個村子一起吸氣

local BREATH_PERIOD, BREATH_IN = 150, 50

function breath_lift(seed)
  return (frame() + seed) % BREATH_PERIOD < BREATH_IN and 1 or 0
end

-- 畫一個 16 × 16 的角色，上半身抬高 lift 像素：
--   上半部（第 0～8 列）畫在 y - lift，下半部（第 8～15 列）畫在原位。
--   第 8 列畫了兩次，剛好補上中間的空隙 → 身體看起來被「撐高」了一點，腳不動
function draw_body(img, n, x, y, flip, lift)
  if lift == 0 then
    spr(img, n, x, y, flip)
    return
  end
  local sx, sy = (n % 12) * 16, (n // 12) * 16   -- Kenney 的兩張圖都是一列 12 格
  sspr(img, sx, sy, 16, 9, x, y - lift, 16, 9, flip)
  sspr(img, sx, sy + 8, 16, 8, x, y + 8, 16, 8, flip)
end

-- ============================================================
-- 風
-- ============================================================
-- 風是一道從左往右移動的「波」：每 300 幀（5 秒）吹過一陣。
-- 世界座標 x 的地方，在 frame × 2 - x 落在 0～40 之間時，正被風吹到。
-- 減去 x：右邊的東西比較晚被吹到，看起來風在移動

local GUST_PERIOD = 300 * 2   -- 一陣風走完一圈的「距離」（frame × 2 為單位）
local GUST_WIDTH = 40         -- 一陣風有多寬（像素）

-- 世界座標 x 這裡的風：被吹到回傳 1，沒有回傳 0
function wind_at(x)
  return (frame() * 2 - x) % GUST_PERIOD < GUST_WIDTH and 1 or 0
end

-- ============================================================
-- 植物：地圖的 plants 圖層（樹、灌木）
-- ============================================================
-- 這一層不用 map() 畫，而是由這裡一格一格畫，才能讓樹梢跟著風歪：
--   上面 10 列（樹冠）往右移 1 像素，下面 6 列（樹幹）不動。
-- 只畫畫面看得到的格子（大約 21 × 16 格）

function plants_draw()
  local m = world.map
  local cx0, cy0 = world.cam_x // TILE, world.cam_y // TILE
  for cy = cy0, cy0 + SCREEN_H // TILE do
    for cx = cx0, cx0 + SCREEN_W // TILE do
      local v = mget(m, "plants", cx, cy)
      if v ~= 0 then
        local x, y = cx * TILE, cy * TILE
        local lean = wind_at(x)
        if lean == 0 then
          world_spr(v, x, y)
        else
          world_sspr(v, 0, 0, 16, 10, x + lean, y)
          world_sspr(v, 0, 10, 16, 6, x, y + 10)
        end
      end
    end
  end
end

-- 草叢翻動：風經過的地方，有草的地面（town 第 1、2 格）左右翻過來畫一次。
-- 地面是 map() 畫的，這裡直接蓋在上面（地面格子不透明，蓋上去就換掉了）
local GRASS = { [2] = true, [3] = true }   -- 地圖編號（town 第 1、2 格：草叢、小花）

function grass_draw()
  local m = world.map
  local cx0, cy0 = world.cam_x // TILE, world.cam_y // TILE
  for cy = cy0, cy0 + SCREEN_H // TILE do
    for cx = cx0, cx0 + SCREEN_W // TILE do
      local v = mget(m, "ground", cx, cy)
      if GRASS[v] and wind_at(cx * TILE + 8) == 1 then
        world_spr(v, cx * TILE, cy * TILE, true)
      end
    end
  end
end

-- ============================================================
-- 蝴蝶
-- ============================================================
-- 進入地圖時，在草地上（沒有牆、不是泥土路）挑幾個「家」，
-- 蝴蝶繞著家飛：位置 = 家 + 慢慢變化的 sin 曲線，每 6 幀拍一次翅膀

local BUTTERFLY_COLORS = { 10, 7, 14, 12 }   -- 黃、白、粉紅、藍
local butterflies = {}

function butterflies_enter()
  butterflies = {}
  local m = world.map
  local w, h = mapw(m), maph(m)
  local want = w * h // 150      -- 大約每 150 格一隻
  local tries = 0
  while #butterflies < want and tries < 200 do
    tries = tries + 1
    local cx = hash(tries, w, 1) % w
    local cy = hash(tries, h, 2) % h
    if mget(m, "solid", cx, cy) == 0 and GRASS[mget(m, "ground", cx, cy)] then
      local i = #butterflies + 1
      butterflies[i] = {
        hx = cx * TILE + 8, hy = cy * TILE + 8,
        seed = hash(i, cx, cy),
        color = BUTTERFLY_COLORS[i % #BUTTERFLY_COLORS + 1],
      }
    end
  end
end

function butterflies_draw()
  local f = frame()
  for _, b in ipairs(butterflies) do
    -- 兩條不同速度的 sin 疊起來，飛行路線才不會一直重複同一個圈
    local t = f + b.seed
    local x = b.hx + isin(t // 7) * 3 + isin(t // 17) * 2
    local y = b.hy + isin(t // 9 + 8) * 2 + isin(t // 23) - 6
    if (t // 6) % 2 == 0 then
      rect(x - 2, y - 1, 2, 2, b.color)   -- 翅膀張開：左右各一片 2 × 2
      rect(x + 1, y - 1, 2, 2, b.color)
    else
      rect(x - 1, y - 2, 1, 2, b.color)   -- 翅膀合起來：兩片立在身體兩邊
      rect(x + 1, y - 2, 1, 2, b.color)
    end
    pset(x, y, 0)                       -- 身體
  end
end
