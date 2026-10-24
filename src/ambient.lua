-- ambient.lua：讓世界「活」起來的小動作
--
--   風：風力忽強忽弱。風弱時只有少數幾棵樹在晃，風強時大部分的樹都在晃，
--       每棵樹有自己的節奏（樹梢往右歪 1 像素再回來），草叢也零星地翻動
--   蝴蝶：草地上飛來飛去的小蝴蝶
--
-- （試過「呼吸」：上半身抬高 1 像素。16 × 16 的角色只能整塊拉長，看起來像頭在伸縮，
--   不自然，所以拿掉了。要自然的呼吸得畫專門的待機動畫格，等之後有自己畫的角色再做）
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
-- 風
-- ============================================================
-- 不要「一道波從左掃到右」：太整齊，看起來像機器。改成：
--   1. 風力 0～8，由三條速度不同的 sin 疊出來，忽強忽弱、不會規律重複
--   2. 每棵樹（每一格草）用 hash 決定「多強的風才會動」和「自己晃的節奏」
--   → 風弱時只有幾棵在晃；風強時大家都在晃，但各晃各的

local wind = 0   -- 這一幀的風力，wind_update() 算
function wind_now() return wind end

function wind_update()
  local f = frame()
  local w = isin(f // 29) + isin(f // 47 + 9) + isin(f // 83 + 20)   -- -24～24
  wind = clamp((w + 8) // 3, 0, 8)   -- 大部分時間是微風（1～4），偶爾一陣強風
end

-- 第 (cx, cy) 格的東西這一幀要不要歪：回傳 0 或 1。
-- 門檻 1～8：門檻低的比較容易被吹動。節奏 50～89 幀晃一次，其中一半的時間歪著
local function sways_h(h)
  if h % 8 + 1 > wind then return 0 end
  local period = 50 + h % 40
  return (frame() + h) % period < period // 2 and 1 or 0
end

-- ============================================================
-- 植物：地圖的 plants 圖層（樹、灌木）
-- ============================================================
-- 這一層不用 map() 畫，而是由這裡一格一格畫，才能讓樹梢跟著風歪：
--   一般的樹：上面 10 列（樹冠）往右移 1 像素，下面 6 列（樹幹）不動
--   兩格高的樹的上半格（town 第 3、4 格）：整格一起移；用下面那一格的位置判斷，上下才會一起動
-- 只畫畫面看得到的格子（大約 21 × 16 格）
--
-- 運算預算（W62）：每幀對每一格 mget、hash 太花 Lua 指令（霧林一幀 3 萬多個）。
-- 改成進地圖時先整理好：每一列有哪些植物、各自的 hash（ambient_enter），每幀只看可見的那幾列

local TALL_TOP = { [4] = true, [5] = true }   -- 地圖編號（town 第 3、4 格）
local GRASS = { [2] = true, [3] = true }      -- 會翻動的地面（town 第 1、2 格：草叢、小花）

-- 記憶體（2026-10-24，Nova 主機實測）：本來每棵植物存 5 個數字、每格草存 3 個數字，
-- Lua 的表格每個數字佔 16 bytes，一張大地圖光這兩個快取就要 40 多 KB，主機的記憶體會不夠。
-- 改成每棵植物、每格草「一個整數」，用位元運算把幾個小數字裝在一起（打包）：
--   植物：hash（16 位元）| 第幾格 << 16（10 位元）| 圖 << 26（8 位元）| cx << 34（12 位元）| 兩格高 << 46
--   草：  hash（16 位元）| 地面編號 << 16（8 位元）| cx << 24（12 位元）
-- 讀的時候用 >> 和 & 拆回來，結果和以前完全一樣
local plant_rows = {}   -- plant_rows[cy] = { 打包的植物, … }
local flip_rows = {}    -- flip_rows[cy] = { 打包的草, … }

function ambient_enter()
  plant_rows, flip_rows = {}, {}
  local m = world.map
  local w, h = mapw(m), maph(m)
  for cy = 0, h - 1 do
    local pr, fr = {}, {}
    for cx = 0, w - 1 do
      local v = world.has_plants and mget(m, "plants", cx, cy) or 0
      if v ~= 0 then
        local img, n = world_tile_image(v)   -- 先算好是哪張圖的第幾格，畫的時候直接 spr
        local hh = hash(cx, TALL_TOP[v] and cy + 1 or cy, 1)   -- 兩格高的樹用下面那格的 hash
        pr[#pr + 1] = hh | n << 16 | img << 26 | cx << 34 | (TALL_TOP[v] and 1 or 0) << 46
      end
      local g = mget(m, "ground", cx, cy)
      if GRASS[g] then
        fr[#fr + 1] = hash(cx, cy, 2) | g << 16 | cx << 24
      end
    end
    plant_rows[cy], flip_rows[cy] = pr, fr
  end
end

-- 戰鬥中不畫地圖，這兩個快取先放掉（大地圖約 13 KB），戰鬥結束再用 ambient_enter 重建。
-- （2026-10-24 Nova 主機：戰鬥時記憶體不夠。重建只在轉場全黑時做一次）
function ambient_suspend()
  plant_rows, flip_rows = {}, {}
end

function plants_draw()
  local cx0, cy0 = world.cam_x // TILE, world.cam_y // TILE
  local cx1 = cx0 + SCREEN_W // TILE
  for cy = cy0, cy0 + SCREEN_H // TILE do
    local row = plant_rows[cy]
    if row then
      local y = cy * TILE
      for i = 1, #row do
        local p = row[i]
        local cx = p >> 34 & 0xfff
        if cx >= cx0 and cx <= cx1 then
          local img, n, x = p >> 26 & 0xff, p >> 16 & 0x3ff, cx * TILE
          local s = sways_h(p & 0xffff)
          if p >> 46 & 1 == 1 then
            spr(img, n, x + s, y)
          elseif s == 0 then
            spr(img, n, x, y)
          else
            local sx, sy = (n % 12) * 16, (n // 12) * 16   -- town、dungeon 都是一列 12 格
            sspr(img, sx, sy, 16, 10, x + 1, y)
            sspr(img, sx, sy + 10, 16, 6, x, y + 10)
          end
        end
      end
    end
  end
end

-- 草叢翻動：有草的地面左右翻過來畫一下，零星幾格、一次 8 幀。
-- 地面是 map() 畫的，這裡直接蓋在上面（地面格子不透明，蓋上去就換掉了）
function grass_draw()
  if wind < 3 then return end   -- 門檻最低是 3：風太小就整個跳過
  local cx0, cy0 = world.cam_x // TILE, world.cam_y // TILE
  local cx1 = cx0 + SCREEN_W // TILE
  local f = frame()
  for cy = cy0, cy0 + SCREEN_H // TILE do
    local row = flip_rows[cy]
    if row then
      for i = 1, #row do
        local p = row[i]
        local cx, h = p >> 24 & 0xfff, p & 0xffff
        -- 比樹難吹動（門檻 3～10），每 60～109 幀翻一次
        if cx >= cx0 and cx <= cx1 and h % 8 + 3 <= wind and (f + h) % (60 + h % 50) < 8 then
          world_spr(p >> 16 & 0xff, cx * TILE, cy * TILE, true)
        end
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
  if indoor_map() then return end   -- 礦坑裡沒有蝴蝶（dark.lua）
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
