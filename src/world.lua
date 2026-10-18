-- world.lua：目前所在的地圖，和跟著主角的相機
--
-- 座標分兩種：
--   世界座標：在整張地圖上的位置（主角、NPC 都用這個）
--   畫面座標：在 320 × 240 畫面上的位置（對話框、選單用這個）
-- 相機就是「畫面左上角對到世界的哪一點」：camera(cam_x, cam_y) 之後，
-- 畫在世界座標 (x, y) 的東西會出現在畫面的 (x - cam_x, y - cam_y)。

world = {
  map = nil,      -- 目前的地圖（MAP.camp 等）
  w = 0, h = 0,   -- 地圖的大小（像素）
  cam_x = 0,      -- 相機位置（世界座標）
  cam_y = 0,
}

-- 進入一張地圖
function world_enter(m)
  world.map = m
  world.w = mapw(m) * TILE
  world.h = maph(m) * TILE
end

-- 一個方向的相機位置：讓目標在畫面正中央，但不要拍到地圖外面
local function follow_axis(target, view, size)
  local max = size - view
  if max < 0 then return max // 2 end      -- 地圖比畫面小：地圖放在畫面正中央
  return clamp(target - view // 2, 0, max)
end

-- 相機跟著 (x, y)，通常是主角的中心點
function world_follow(x, y)
  world.cam_x = follow_axis(x, SCREEN_W, world.w)
  world.cam_y = follow_axis(y, SCREEN_H, world.h)
end

-- 開始畫世界：設定相機，畫地面和裝飾。之後畫的角色也會跟著相機
function world_draw()
  camera(world.cam_x, world.cam_y)
  map(world.map, "ground")
  map(world.map, "deco")
end
