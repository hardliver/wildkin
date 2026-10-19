-- world.lua：目前所在的地圖，和跟著主角的相機
--
-- 座標分兩種：
--   世界座標：在整張地圖上的位置（主角、NPC 都用這個）
--   畫面座標：在 320 × 240 畫面上的位置（對話框、選單用這個）
-- 相機就是「畫面左上角對到世界的哪一點」：camera(cam_x, cam_y) 之後，
-- 畫在世界座標 (x, y) 的東西會出現在畫面的 (x - cam_x, y - cam_y)。

world = {
  name = nil,     -- 目前地圖的名字（"camp" 等，comet.json 的 maps）
  map = nil,      -- 目前的地圖（MAP.camp 等）
  objects = {},   -- 這張地圖的物件（MAPOBJ.camp 等：門、NPC、告示牌……）
  w = 0, h = 0,   -- 地圖的大小（像素）
  cam_x = 0,      -- 相機位置（世界座標）
  cam_y = 0,
  blockers = {},  -- 會擋路的人（NPC）：每個都有 x、y（圖的左上角，世界座標）
}

-- 進入一張地圖（用名字，例如 "camp"）。擋路的人清空，由這張地圖的程式重新加
function world_enter(name)
  local m = MAP[name]
  if not m then error("沒有叫 " .. tostring(name) .. " 的地圖（comet.json 的 maps）") end
  world.name = name
  world.map = m
  world.objects = MAPOBJ[name] or {}
  world.w = mapw(m) * TILE
  world.h = maph(m) * TILE
  world.blockers = {}
end

-- 畫一格地圖格子編號 v 的圖（NPC 的 tile 用的是地圖格子編號）。
-- 地圖的格子編號把這張地圖用的圖接在一起，從 1 開始數：
--   1～132：town（Tiny Town，12 × 11 格）的第 0～131 格
--   133～ ：dungeon（Tiny Dungeon）的第 0 格開始
-- （營地、草原小徑都是 tilesets = ["town", "dungeon"]）
local TOWN_TILES = 132

function world_spr(v, x, y, flip)
  if v <= TOWN_TILES then
    spr(IMG.town, v - 1, x, y, flip)
  else
    spr(IMG.dungeon, v - TOWN_TILES - 1, x, y, flip)
  end
end

-- 畫格子編號 v 的圖的一部分（sx, sy, sw, sh：格子裡的範圍），左上角放在 (x, y)
function world_sspr(v, sx, sy, sw, sh, x, y)
  local img, n = IMG.town, v - 1
  if v > TOWN_TILES then img, n = IMG.dungeon, v - TOWN_TILES - 1 end
  sspr(img, (n % 12) * 16 + sx, (n // 12) * 16 + sy, sw, sh, x, y)
end

-- 世界座標 (px, py) 這一點所在的格子上的告示牌（沒有回傳 nil）
function world_sign_at(px, py)
  local cx, cy = px // TILE, py // TILE
  for _, o in ipairs(world.objects) do
    if o.type == "sign" and o.x == cx and o.y == cy then return o end
  end
  return nil
end

-- 第 (cx, cy) 格上的門（沒有回傳 nil）
function world_door_at(cx, cy)
  for _, o in ipairs(world.objects) do
    if o.type == "door" and o.x == cx and o.y == cy then return o end
  end
  return nil
end

-- ============================================================
-- 碰撞
-- ============================================================
-- 角色的圖是 16 × 16，但碰撞只算「腳」：下半部寬 10、高 6 的方框。
-- 這樣主角可以站在樹的下緣、頭稍微蓋到樹上，看起來比較自然；
-- 整張圖都算的話，主角和牆之間會有一段奇怪的空隙。
local FEET_X, FEET_Y, FEET_W, FEET_H = 3, 9, 10, 6

-- 加一個會擋路的人。who 要有 x、y（圖的左上角）
function world_add_blocker(who)
  world.blockers[#world.blockers + 1] = who
end

-- 地圖上這個像素是不是牆（solid 圖層不是 0；地圖外面也算牆）
local function solid_px(px, py)
  if px < 0 or py < 0 or px >= world.w or py >= world.h then return true end
  return mget(world.map, "solid", px // TILE, py // TILE) ~= 0
end

-- 兩個方框有沒有重疊（左上角 + 寬高）
local function overlap(ax, ay, aw, ah, bx, by, bw, bh)
  return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end

-- 圖的左上角在 (x, y) 的角色，站在這裡會不會撞到東西。
-- self：自己（檢查擋路的人時跳過自己）
function world_blocked(x, y, self)
  local fx, fy = x + FEET_X, y + FEET_Y
  -- 地圖：腳的四個角各看一次。腳比一格小，所以四個角就夠了
  if solid_px(fx, fy) or solid_px(fx + FEET_W - 1, fy)
     or solid_px(fx, fy + FEET_H - 1) or solid_px(fx + FEET_W - 1, fy + FEET_H - 1) then
    return true
  end
  -- 人：腳的方框互相重疊就算撞到
  for _, b in ipairs(world.blockers) do
    if b ~= self and overlap(fx, fy, FEET_W, FEET_H, b.x + FEET_X, b.y + FEET_Y, FEET_W, FEET_H) then
      return true
    end
  end
  return false
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
-- 畫的順序：地面 → 被風吹動的草 → 裝飾（房子、柵欄、告示牌）→ 植物（樹會隨風搖，ambient.lua）
function world_draw()
  camera(world.cam_x, world.cam_y)
  map(world.map, "ground")
  grass_draw()
  map(world.map, "deco")
  plants_draw()
end
