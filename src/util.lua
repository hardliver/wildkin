-- util.lua：到處都會用到的小工具

-- 按鍵編號（Comet 的 btn）
LEFT, RIGHT, UP, DOWN = 0, 1, 2, 3
A, B, START, SELECT = 4, 5, 6, 7
X, Y, L, R = 8, 9, 10, 11

TILE = 16   -- 地圖一格 16 × 16 像素

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
