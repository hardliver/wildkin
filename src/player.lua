-- player.lua：主角
--
-- 圖：Kenney Tiny Dungeon 的第 112 格（綠色兜帽的冒險者）
-- 位置用「放大 16 倍的整數」存（x16 = 實際 x × 16），搖桿推一點點也能慢慢走

local HERO_TILE = 112
local MAX_SPEED = 24        -- 每幀最多 24/16 = 1.5 像素

player = {}

function player_init(x, y)
  player.x16 = x * 16
  player.y16 = y * 16
  player.facing_left = false
  player.walking = false
  player.walk_frames = 0    -- 走了幾幀（用來決定走路動畫的哪一步）
end

function player_update()
  local mx, my = move_input()

  player.x16 = player.x16 + mx * MAX_SPEED // 127
  player.y16 = player.y16 + my * MAX_SPEED // 127
  player.x16 = clamp(player.x16, 0, (SCREEN_W - TILE) * 16)
  player.y16 = clamp(player.y16, TILE * 16, (SCREEN_H - TILE) * 16)   -- 最上面一排是樹

  if mx < 0 then player.facing_left = true end
  if mx > 0 then player.facing_left = false end

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
  -- Kenney 的角色原本面向右，往左走時左右翻轉
  spr(IMG.dungeon, HERO_TILE, x, y + bob, player.facing_left)
end
