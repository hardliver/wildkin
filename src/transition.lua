-- transition.lua：換地圖時的轉場（百葉窗）
--
-- 畫面每 16 像素一條黑色橫條，HALF 幀內從 0 長到 16 像素（全黑），
-- 全黑的那一幀呼叫 on_middle（在這裡換地圖，玩家看不到切換的瞬間），
-- 再用 HALF 幀縮回去。引擎沒有半透明，這樣每幀只要畫 15 個 rect，主機上也很便宜。

local HALF = 16
local trans = nil   -- { t = 經過幾幀, on_middle = 全黑時要做的事 }

function transition_start(on_middle)
  trans = { t = 0, on_middle = on_middle }
end

function transition_active()
  return trans ~= nil
end

function transition_update()
  if not trans then return end
  trans.t = trans.t + 1
  if trans.t == HALF then trans.on_middle() end
  if trans.t >= HALF * 2 then trans = nil end
end

function transition_draw()
  if not trans then return end
  -- 前半段越來越黑，後半段越來越亮：0 → HALF → 0
  local k = trans.t <= HALF and trans.t or HALF * 2 - trans.t
  local h = k * 16 // HALF
  if h <= 0 then return end
  camera()
  for y = 0, SCREEN_H - 1, 16 do rect(0, y, SCREEN_W, h, 0) end
end
