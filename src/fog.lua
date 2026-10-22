-- fog.lua：霧林的霧（W57）
--
-- 霧是 assets/art/fog.png（64×32 的點陣霧團，tools/art/fog.py 產生）。
-- 霧林地圖上撒十幾團，每團用自己的速度慢慢往右飄，飄出地圖右邊就從左邊再出來。
-- 畫在角色上面（主角走在霧裡），選單和對話框下面。
-- 位置只看 frame()，不用 rnd()：霧是裝飾，不能影響遊戲的亂數

local FOG_MAPS = { forest = 14 }   -- 哪些地圖有霧、幾團
local FOG_W, FOG_H = 64, 32

function fog_draw()
  local n = FOG_MAPS[world.name] or weather_fog_count()   -- 起霧的時段，室外地圖都有霧（weather.lua）
  if n == 0 then return end
  local f = frame()
  local span = world.w + FOG_W * 2
  for i = 1, n do
    local speed = 3 + hash(i, 1) % 4                       -- 每 3～6 幀走 1 像素
    local x = (hash(i, 2) % span + f // speed) % span - FOG_W
    local y = hash(i, 3) % (world.h - FOG_H)
    y = y + isin((f // 8 + i * 5) % 32) // 4               -- 上下輕輕飄
    -- 只畫看得到的（相機範圍內）
    if x + FOG_W > world.cam_x and x < world.cam_x + SCREEN_W and y + FOG_H > world.cam_y and y < world.cam_y + SCREEN_H then
      sspr(IMG.fog, 0, 0, FOG_W, FOG_H, x, y)
    end
  end
end
