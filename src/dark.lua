-- dark.lua：暗處（W67 舊礦坑）
--
-- 地圖的 dark 圖層標 1 的格子是暗的。主角站在暗的格子上時，畫面只看得到以主角為中心的一個圓，其他都是黑的：
--   沒有會「發電」的野伴：半徑 SMALL（身邊一小圈，還是走得動，不會卡關）
--   隊伍裡有會發電的野伴（燈蛾）：半徑 BIG（野外技能「照亮」，自動，不用按）
-- 圓的邊緣有一圈深藍的過渡，看起來比較柔和。
-- 畫法：圓外面用 rect 塗黑。圓的上面、下面各一個大 rect；圓的高度範圍內每 2 列左右各一個 rect
-- （畫的點數 ≈ 黑的面積，見 docs 的運算預算；W62）

local SMALL, BIG = 28, 76
local has_dark = false
local lit = false      -- 這張地圖有沒有照亮（進地圖、換隊伍時重算）

local checked = nil    -- has_dark 是哪一張地圖算的
local function check()
  if checked ~= world.map then
    checked = world.map
    has_dark = pcall(mget, world.map, "dark", 0, 0)
  end
end

function dark_enter()
  check()
  lit = field_skill_kin("power") ~= nil
end

-- 這張地圖是不是室內（有暗處的地圖：礦坑、洞窟）：不下雪、不跟著晝夜變色
-- 沒有暗處、但也是室內的地圖（W70 火山洞：岩漿照得很亮）
INDOOR_MAPS = { volcano = true, factory = true, office = true }

function indoor_map()
  check()
  return has_dark or INDOOR_MAPS[world.name] == true
end

-- 主角在不在暗處
function in_dark()
  check()
  if not has_dark then return false end
  local cx, cy = player_cell()
  return mget(world.map, "dark", cx, cy) ~= 0
end

function dark_radius()
  return lit and BIG or SMALL
end

local function isqrt(n)
  local r = 0
  while (r + 1) * (r + 1) <= n do r = r + 1 end
  return r
end

-- 每一列的半寬先算好（半徑只有兩種）
local spans = {}
local function span_table(r)
  if spans[r] then return spans[r] end
  local t = {}
  for dy = -r, r do t[dy] = isqrt(r * r - dy * dy) end
  spans[r] = t
  return t
end

-- 畫面座標畫（camera() 之後）。主角的中心 = 圖的中間
function dark_draw()
  if not in_dark() then return end
  lit = field_skill_kin("power") ~= nil      -- 隊伍可能換過
  local r = dark_radius()
  local t = span_table(r)
  local cx = player.x16 // 16 + TILE // 2 - world.cam_x
  local cy = player.y16 // 16 + TILE // 2 - world.cam_y
  local top, bot = cy - r, cy + r
  if top > 0 then rect(0, 0, SCREEN_W, top, 0) end
  if bot < SCREEN_H then rect(0, bot, SCREEN_W, SCREEN_H - bot, 0) end
  for y = math.max(top, 0), math.min(bot, SCREEN_H) - 1, 2 do
    local hw = t[y - cy] or 0
    local l, rr = cx - hw, cx + hw
    if l > 0 then
      rect(0, y, l, 2, 0)
      rect(l, y, 3, 2, 1)                    -- 邊緣：深藍的一圈
    end
    if rr < SCREEN_W then
      rect(rr, y, SCREEN_W - rr, 2, 0)
      rect(rr - 3, y, 3, 2, 1)
    end
  end
end
