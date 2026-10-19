-- player.lua：主角
--
-- 圖：Kenney Tiny Dungeon 的第 112 格（綠色兜帽的冒險者）
-- 位置用「放大 16 倍的整數」存（x16 = 實際 x × 16），搖桿推一點點也能慢慢走

local HERO_TILE = 112
local MAX_SPEED = 24        -- 每幀最多 24/16 = 1.5 像素
local CORNER_HELP = 4       -- 轉角輔助：差幾像素以內就幫忙對準通道

player = {}

function player_init(x, y)
  player.x16 = x * 16
  player.y16 = y * 16
  player.facing_left = false   -- 圖要不要左右翻轉（只看左右）
  player.dir_x = 0             -- 面向哪個方向（上下左右四個之一）：跟 NPC 說話、看告示牌用
  player.dir_y = 1             -- 一開始面向下
  player.walking = false
  player.walk_frames = 0    -- 走了幾幀（用來決定走路動畫的哪一步）
end

-- 主角的圖左上角（像素）
local function px() return player.x16 // 16 end
local function py() return player.y16 // 16 end

local function blocked(x, y) return world_blocked(x, y, player) end

-- 沿 x 或 y 移動 d16（放大 16 倍的距離）。
-- 被擋住時，一個像素一個像素往前試，停在剛好碰到的位置。回傳有沒有被擋住
local function move_axis(axis, d16)
  if d16 == 0 then return false end
  local key = axis == "x" and "x16" or "y16"
  local from = player[key] // 16
  local to = (player[key] + d16) // 16
  local step = to > from and 1 or -1
  for p = from + step, to, step do               -- 從現在的位置往目標，每次 1 像素
    local x = axis == "x" and p or px()
    local y = axis == "y" and p or py()
    if blocked(x, y) then
      player[key] = (p - step) * 16              -- 停在撞到之前的那個像素
      return true
    end
  end
  player[key] = player[key] + d16                -- 一路暢通（同一個像素內的小移動也會走到這裡）
  return false
end

-- 轉角輔助：往 axis 方向被擋住時，看看另一個方向偏移 1～CORNER_HELP 像素能不能過。
-- 能的話往那邊推 1 像素。這樣走進一格寬的通道時，不用對得很準
local function corner_help(axis, dir)
  for off = 1, CORNER_HELP do
    for _, sign in ipairs({ -1, 1 }) do
      local o = off * sign
      local x = axis == "x" and px() + dir or px() + o
      local y = axis == "y" and py() + dir or py() + o
      if not blocked(x, y) then
        -- 往偏移的方向推 1 像素（推之前確認那 1 像素本身也能站）
        if axis == "x" then
          if not blocked(px(), py() + sign) then player.y16 = player.y16 + sign * 16 end
        else
          if not blocked(px() + sign, py()) then player.x16 = player.x16 + sign * 16 end
        end
        return
      end
    end
  end
end

-- 把主角放到第 (cx, cy) 格（換地圖時用）
function player_place(cx, cy)
  player.x16 = cx * TILE * 16
  player.y16 = cy * TILE * 16
end

-- 主角的腳的中心踩在第幾格（踩門、之後踩草叢都用這個）
function player_cell()
  return (player.x16 // 16 + 8) // TILE, (player.y16 // 16 + 12) // TILE
end

-- 主角面前距離 d 像素的那一點（世界座標）：從腳的中心往面向的方向量。
-- 跟 NPC 說話時，從近到遠試好幾個距離（main.lua 的 interact）：
--   從上面靠近 NPC 時，主角的腳離 NPC 的身體很近（圖會重疊），太遠的點會穿過 NPC；
--   從下面靠近時，腳和 NPC 的身體之間隔著 NPC 的腳，要遠一點才碰得到。
function player_front(d)
  local cx, cy = player.x16 // 16 + 8, player.y16 // 16 + 12
  return cx + player.dir_x * d, cy + player.dir_y * d
end

function player_update()
  local mx, my = move_input()

  -- x、y 分開走：斜著撞牆時，被擋住的方向停下來，另一個方向繼續 → 貼著牆滑過去
  local hit_x = move_axis("x", mx * MAX_SPEED // 127)
  local hit_y = move_axis("y", my * MAX_SPEED // 127)
  -- 只往一個方向走、而且被擋住了：試試轉角輔助
  if hit_x and my == 0 then corner_help("x", mx > 0 and 1 or -1) end
  if hit_y and mx == 0 then corner_help("y", my > 0 and 1 or -1) end

  if mx < 0 then player.facing_left = true end
  if mx > 0 then player.facing_left = false end

  -- 面向：搖桿推得比較多的那個方向（斜推時，誰大就算誰）
  if mx ~= 0 or my ~= 0 then
    if math.abs(mx) > math.abs(my) then
      player.dir_x, player.dir_y = mx > 0 and 1 or -1, 0
    else
      player.dir_x, player.dir_y = 0, my > 0 and 1 or -1
    end
  end

  player.walking = mx ~= 0 or my ~= 0
  if player.walking then
    player.walk_frames = player.walk_frames + 1
  else
    player.walk_frames = 0
  end
end

function player_draw()
  local x, y = player.x16 // 16, player.y16 // 16

  -- 走路動畫：每 8 幀換一步，第二步身體往上 1 像素，看起來在踏步
  local step = (player.walk_frames // 8) % 2
  local bob = 0
  if player.walking and step == 1 then bob = -1 end

  -- 影子
  rect(x + 3, y + 14, 10, 2, 5)
  -- Kenney 的角色原本面向右，往左走時左右翻轉。
  -- 站著不動時會呼吸（ambient.lua）；走路時用上面的踏步動作
  local lift = player.walking and 0 or breath_lift(0)
  draw_body(IMG.dungeon, HERO_TILE, x, y + bob, player.facing_left, lift)
end
