-- util.lua：到處都會用到的小工具

-- 按鍵編號（Comet 的 btn）
LEFT, RIGHT, UP, DOWN = 0, 1, 2, 3
A, B, START, SELECT = 4, 5, 6, 7
X, Y, L, R = 8, 9, 10, 11

TILE = 16   -- 地圖一格 16 × 16 像素

-- ============================================================
-- 按鍵：剛按下、按住連發
-- ============================================================
-- btn() 只知道「現在有沒有按著」。選單需要「剛按下的那一幀」，
-- 不然按一下 A，手指壓著的那幾幀會被當成按了好幾次。
-- 做法：每幀記下每個鍵「已經連續按了幾幀」，
--   1    = 這一幀剛按下
--   0    = 沒按
--   2 以上 = 按住不放
-- 每幀一開始要呼叫一次 input_update()（main.lua 的 _update 第一行）

local held = {}                 -- held[鍵] = 連續按了幾幀
for k = 0, 11 do held[k] = 0 end

local REPEAT_DELAY = 15         -- 按住多久之後開始連發（15 幀 = 0.25 秒）
local REPEAT_RATE = 4           -- 連發時每幾幀算一次（每秒 15 次）

function input_update()
  for k = 0, 11 do
    if btn(0, k) then
      held[k] = held[k] + 1
    else
      held[k] = 0
    end
  end
end

-- 這一幀剛按下
function pressed(k)
  return held[k] == 1
end

-- 剛按下時算一次；按住超過 REPEAT_DELAY 幀之後，每 REPEAT_RATE 幀再算一次。
-- 選單的游標移動用這個：按一下移一格，按住會連續移動
function pressed_repeat(k)
  local h = held[k]
  if h == 1 then return true end
  return h > REPEAT_DELAY and (h - REPEAT_DELAY - 1) % REPEAT_RATE == 0
end

function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

-- 讀取 1 號玩家的移動方向：先看左搖桿，沒推的話看十字鍵／方向鍵。
-- 回傳 -127～127 的 x, y（和 stick() 相同的範圍）
function move_input()
  local x, y = stick(0, 0)
  if x == 0 and y == 0 then
    if btn(0, LEFT)  then x = -127 end
    if btn(0, RIGHT) then x =  127 end
    if btn(0, UP)    then y = -127 end
    if btn(0, DOWN)  then y =  127 end
    -- 斜走時縮短，不會比直走快（127 × 0.7 ≈ 90）
    if x ~= 0 and y ~= 0 then
      x = x * 90 // 127
      y = y * 90 // 127
    end
  end
  return x, y
end
