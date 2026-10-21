-- shiny.lua：異色野伴（W65）
--
-- 野生的野伴有 1/256 的機率是「異色」：同一張圖，換一組顏色（色相轉一個角度）。不用另外畫圖：
--   1. imgcolors 找出這種野伴的戰鬥圖（正面、背面）和小圖示用了哪些顏色
--   2. 每個顏色的色相轉 SHIFT 度，在遊戲已經有的顏色裡找最接近的（引擎所有圖片加起來最多 240 色，不能新增）
--   3. 畫的時候用 dpal（W64）換色。對照表第一次用到時算好、存起來
-- 灰色、黑色、白色（彩度很低的）不換，眼睛、輪廓才不會變怪。
-- 異色只是外觀，能力、招式完全一樣（content.md：改變「長什麼樣子」，不改變「多強」）。

SHINY_RATE = 256

-- 每種轉幾度（色相 0～359）：挑過，讓異色和原本差很多、又不會太醜
local SHIFT = { ["01"] = 150, ["02"] = 150, ["03"] = 200, ["04"] = 200, ["05"] = 120,
                ["06"] = 120, ["07"] = 180, ["08"] = 240, ["09"] = 90, ["10"] = 270 }

-- 整數版的 RGB ↔ HSV：h 0～359、s 0～255、v 0～255（不用小數：每個平台算出來一樣）
local function rgb_to_hsv(r, g, b)
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

local function hsv_to_rgb(h, s, v)
  local c = v * s // 255
  local hp = h % 360
  local x = c * (60 - math.abs(hp % 120 - 60)) // 60
  local m = v - c
  local r, g, b
  if hp < 60 then r, g, b = c, x, 0
  elseif hp < 120 then r, g, b = x, c, 0
  elseif hp < 180 then r, g, b = 0, c, x
  elseif hp < 240 then r, g, b = 0, x, c
  elseif hp < 300 then r, g, b = x, 0, c
  else r, g, b = c, 0, x end
  return r + m, g + m, b + m
end

-- 可以用的顏色：所有圖片用過的（換完的顏色一定是調色盤裡已經有的）
local candidates = nil
local function all_colors()
  if candidates then return candidates end
  local seen = {}
  candidates = {}
  for _, img in pairs(IMG) do
    for _, c in ipairs(imgcolors(img)) do
      if not seen[c] then
        seen[c] = true
        local r, g, b = palget(c)
        candidates[#candidates + 1] = { c, r, g, b }
      end
    end
  end
  return candidates
end

local function nearest(r, g, b)
  local best, bd = nil, nil
  for _, c in ipairs(all_colors()) do
    -- 人眼對綠最敏感、藍最不敏感：距離加權（2:4:3）
    local dr, dg, db = c[2] - r, c[3] - g, c[4] - b
    local d = 2 * dr * dr + 4 * dg * dg + 3 * db * db
    if not bd or d < bd then best, bd = c[1], d end
  end
  return best
end

local maps = {}

-- 這種野伴的異色換色表 { [原色] = 新色 }
function shiny_map(no)
  if maps[no] then return maps[no] end
  local sp = DATA.species[no]
  local used = {}
  for _, list in ipairs({ imgcolors(IMG.kin_front, sp.sprite * 64, 0, 64, 64),
                          imgcolors(IMG.kin_back, sp.sprite * 32, 0, 32, 32),
                          imgcolors(IMG.kin_icons, sp.sprite * 48, 0, 48, 16) }) do
    for _, c in ipairs(list) do used[c] = true end
  end
  local shift = SHIFT[no] or 180
  local map = {}
  for c in pairs(used) do
    local r, g, b = palget(c)
    local h, s, v = rgb_to_hsv(r, g, b)
    if s >= 48 then                      -- 灰、黑、白不換
      local nr, ng, nb = hsv_to_rgb(h + shift, s, v)
      map[c] = nearest(nr, ng, nb)
    end
  end
  maps[no] = map
  return map
end

-- 畫一隻野伴之前呼叫：異色的話設好換色；畫完記得 dpal() 還原
function kin_dpal(k)
  if k and k.shiny then dpal(shiny_map(k.no)) end
end

-- 野生野伴出現時：1/256 是異色（Studio 的除錯按鈕可以讓下一隻一定是）
function shiny_roll(k)
  if DEBUG_NEXT_SHINY or rnd(SHINY_RATE) == 0 then
    DEBUG_NEXT_SHINY = nil
    k.shiny = true
  end
  return k
end

-- 異色的小記號：7×7 的四角星（字型沒有星號，用方塊畫）
function shiny_mark(x, y)
  rect(x + 2, y - 1, 3, 9, 9)      -- 橘色外框
  rect(x - 1, y + 2, 9, 3, 9)
  rect(x + 3, y, 1, 7, 10)         -- 黃色星
  rect(x, y + 3, 7, 1, 10)
  rect(x + 2, y + 2, 3, 3, 10)
end
