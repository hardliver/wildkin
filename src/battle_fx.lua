-- battle_fx.lua：戰鬥動畫（招式、受擊、能力變化、狀態）
--
-- battle_ui.lua 在演出事件時呼叫這裡，傳進一個 ctx（演出用的工具）：
--   ctx.wait(n)              等 n 幀（coroutine 裡用）
--   ctx.pos(side)            這一邊野伴的中心點（畫面座標）
--   ctx.offset(side, x, y)   把這一邊的野伴圖片移動 (x, y)（撞過去、往後退）
--   ctx.hide(side, bool)     藏起來／出現（閃爍）
--   ctx.shake(x, y)          畫面（不含下方訊息框）晃動的位移
--   ctx.overlay(fn)          每幀在野伴上面多畫 fn()；nil = 不畫
--
-- 每招的動畫寫在 MOVE_ANIM[招式代號]；沒寫的招用屬性的預設動畫。
-- 新增招式時：在 moves.json 加資料，這裡加一個函式（或直接用屬性預設）。
--
-- 所有「隨機」都用 hash()，不用 rnd()：rnd 是戰鬥計算用的，
-- 動畫如果也用，戰鬥結果就會被動畫影響（試算器和實際玩起來會不一樣）。

-- ============================================================
-- 小工具：形狀
-- ============================================================

local function isqrt(n)
  local r = 0
  while (r + 1) * (r + 1) <= n do r = r + 1 end
  return r
end

-- 實心圓
function fx_disc(cx, cy, r, c)
  if r <= 0 then return end
  for dy = -r, r do
    local hw = isqrt(r * r - dy * dy)
    rect(cx - hw, cy + dy, hw * 2 + 1, 1, c)
  end
end

-- 空心圓（每列畫左右兩點）
function fx_ring(cx, cy, r, c)
  if r <= 0 then return end
  for dy = -r, r do
    local hw = isqrt(r * r - dy * dy)
    pset(cx - hw, cy + dy, c)
    pset(cx + hw, cy + dy, c)
  end
  for dx = -r, r do
    local hh = isqrt(r * r - dx * dx)
    pset(cx + dx, cy - hh, c)
    pset(cx + dx, cy + hh, c)
  end
end

-- 粗線（兩點之間每一步畫一個方塊）
local function thick_line(x1, y1, x2, y2, w, c)
  local n = math.max(math.abs(x2 - x1), math.abs(y2 - y1), 1)
  for i = 0, n do
    rect(x1 + (x2 - x1) * i // n - w // 2, y1 + (y2 - y1) * i // n - w // 2, w, w, c)
  end
end

-- 衝擊的星形：8 道光芒，r 是長度
local function burst(cx, cy, r, c1, c2)
  local D = { { 1, 0 }, { 1, 1 }, { 0, 1 }, { -1, 1 }, { -1, 0 }, { -1, -1 }, { 0, -1 }, { 1, -1 } }
  for i, d in ipairs(D) do
    local len = (i % 2 == 1) and r or r * 2 // 3
    thick_line(cx + d[1] * len // 3, cy + d[2] * len // 3, cx + d[1] * len, cy + d[2] * len, 3, c1)
  end
  fx_disc(cx, cy, r // 3, c2)
end

-- 葉子（兩種角度輪流畫，看起來在轉；每點畫成 2×2，葉子 10×10）
local LEAF = {
  { "..##.", ".#gg#", "#ggg#", "#gg#.", ".##.." },
  { ".###.", "#ggg#", "#ggg#", ".#g#.", "..#.." },
}
local function leaf(x, y, frame_n)
  local shape = LEAF[frame_n % 2 + 1]
  for r = 1, 5 do
    for c = 1, 5 do
      local ch = shape[r]:sub(c, c)
      if ch == "#" then rect(x + (c - 3) * 2, y + (r - 3) * 2, 2, 2, 3)
      elseif ch == "g" then rect(x + (c - 3) * 2, y + (r - 3) * 2, 2, 2, 11) end
    end
  end
end

-- 火球：外橘內黃，大小隨時間跳動
local function flame(x, y, size, t)
  local r = size + (hash(t, x) % 2)
  fx_disc(x, y, r + 1, 8)
  fx_disc(x, y - 1, r, 9)
  fx_disc(x, y - 1, r // 2, 10)
end

-- 水滴：藍色圓 + 白色反光
local function drop(x, y, r)
  fx_disc(x, y, r, 12)
  pset(x - r // 2, y - r // 2, 7)
end

-- 從 (x1,y1) 到 (x2,y2) 的拋物線上第 t / n 的位置（h：最高點比直線高多少）
local function arc(x1, y1, x2, y2, t, n, h)
  local x = x1 + (x2 - x1) * t // n
  local y = y1 + (y2 - y1) * t // n - h * 4 * t * (n - t) // (n * n)
  return x, y
end

-- ============================================================
-- 共用動作
-- ============================================================

-- 衝向對方再退回：往對方的方向移動 dist 像素（frames 幀衝過去）
local function lunge(ctx, u, t, dist, frames)
  local ux, uy = ctx.pos(u)
  local tx, ty = ctx.pos(t)
  local dx, dy = tx - ux, ty - uy
  local len = math.max(isqrt(dx * dx + dy * dy), 1)
  for i = 1, frames do
    ctx.offset(u, dx * dist * i // frames // len, dy * dist * i // frames // len)
    ctx.wait(1)
  end
  return function(back_frames)   -- 回傳「退回去」的函式，讓呼叫的人決定什麼時候退
    for i = back_frames - 1, 0, -1 do
      ctx.offset(u, dx * dist * i // back_frames // len, dy * dist * i // back_frames // len)
      ctx.wait(1)
    end
  end
end

-- 原地抖動（蓄力、吼叫）
local function wiggle(ctx, side, frames, amp)
  for i = 1, frames do
    ctx.offset(side, (i // 2 % 2 == 0) and amp or -amp, 0)
    ctx.wait(1)
  end
  ctx.offset(side, 0, 0)
end

-- overlay 播放 frames 幀：draw(第幾幀) 負責畫
local function play(ctx, frames, draw)
  for i = 1, frames do
    ctx.overlay(function() draw(i) end)
    ctx.wait(1)
  end
  ctx.overlay(nil)
end

-- ============================================================
-- 招式動畫
-- ============================================================

local MOVE_ANIM = {}

-- 撞擊：整隻撞過去，撞到的瞬間出現星形
MOVE_ANIM.tackle = function(ctx, u, t)
  local back = lunge(ctx, u, t, 28, 6)
  local tx, ty = ctx.pos(t)
  ctx.overlay(function() burst(tx, ty, 22, 0, 10); burst(tx, ty, 18, 7, 10) end)
  ctx.wait(4)
  ctx.overlay(nil)
  back(10)
end

-- 快爪：一下子衝過去（拖著速度線），抓一下
MOVE_ANIM.quick = function(ctx, u, t)
  local ux, uy = ctx.pos(u)
  local tx, ty = ctx.pos(t)
  ctx.overlay(function()
    for k = 0, 2 do thick_line(ux, uy + k * 8 - 8, (ux + tx) // 2, (uy + ty) // 2 + k * 8 - 8, 1, 6) end
  end)
  local back = lunge(ctx, u, t, 36, 3)
  ctx.overlay(nil)
  play(ctx, 8, function(i) thick_line(tx - 10, ty - 10, tx - 10 + i * 20 // 8, ty - 10 + i * 20 // 8, 3, 7) end)
  back(8)
end

-- 抓抓：三道爪痕從右上往左下劃過
MOVE_ANIM.scratch = function(ctx, u, t)
  local back = lunge(ctx, u, t, 14, 5)
  local tx, ty = ctx.pos(t)
  play(ctx, 14, function(i)
    local n = math.min(i, 8)
    for k = -1, 1 do
      local x1, y1 = tx + 12 + k * 9, ty - 16
      local x2, y2 = x1 - 18 * n // 8, y1 + 30 * n // 8
      thick_line(x1, y1, x2, y2, 3, 0)
      thick_line(x1, y1, x2, y2, 1, 7)
    end
  end)
  back(8)
end

-- 吼叫：抖一抖，聲波一圈一圈往對方擴散
MOVE_ANIM.growl = function(ctx, u, t)
  local ux, uy = ctx.pos(u)
  local tx, ty = ctx.pos(t)
  for i = 1, 30 do
    ctx.offset(u, (i // 2 % 2 == 0) and 2 or -2, 0)
    ctx.overlay(function()
      for k = 0, 2 do
        local p = (i * 2 + k * 20) % 60                       -- 這一圈走到哪（0～60）
        local x, y = ux + (tx - ux) * p // 60, uy + (ty - uy) * p // 60
        fx_ring(x, y, 4 + p // 4, (p < 40) and 0 or 5)
      end
    end)
    ctx.wait(1)
  end
  ctx.offset(u, 0, 0)
  ctx.overlay(nil)
end

-- 瞪眼：眼睛閃光，對方嚇一跳
MOVE_ANIM.leer = function(ctx, u, t)
  local ux, uy = ctx.pos(u)
  play(ctx, 16, function(i)
    local r = (i < 8) and i or 16 - i
    for _, ex in ipairs({ -8, 8 }) do
      thick_line(ux + ex - r, uy - 14, ux + ex + r, uy - 14, 1, 10)
      thick_line(ux + ex, uy - 14 - r, ux + ex, uy - 14 + r, 1, 10)
    end
  end)
  wiggle(ctx, t, 12, 3)
end

-- 葉刃：葉子轉著飛過去，最後一刀劃過
MOVE_ANIM.leaf = function(ctx, u, t)
  local ux, uy = ctx.pos(u)
  local tx, ty = ctx.pos(t)
  wiggle(ctx, u, 6, 1)
  local N, FLY, GAP = 4, 18, 4                                -- 4 片葉子，每片飛 18 幀，間隔 4 幀
  play(ctx, FLY + GAP * (N - 1), function(i)
    for k = 0, N - 1 do
      local s = i - k * GAP
      if s >= 1 and s <= FLY then
        local x, y = arc(ux, uy - 6 + k * 4, tx + (k - 1) * 6, ty + (k - 2) * 5, s, FLY, 14 + k * 4)
        leaf(x, y, s // 2 + k)
      end
    end
  end)
  play(ctx, 6, function(i)
    thick_line(tx + 22, ty - 18, tx + 22 - i * 44 // 6, ty - 18 + i * 36 // 6, 2, 11)
  end)
end

-- 吸取：綠色光點從對方身上飄回自己
MOVE_ANIM.absorb = function(ctx, u, t)
  local ux, uy = ctx.pos(u)
  local tx, ty = ctx.pos(t)
  play(ctx, 36, function(i)
    for k = 0, 5 do
      local s = i - k * 3
      if s >= 1 and s <= 18 then
        local x, y = arc(tx + (hash(k, 1) % 21) - 10, ty + (hash(k, 2) % 21) - 10, ux, uy, s, 18, 10)
        x = x + isin(s * 3 + k * 5) // 2
        fx_disc(x, y, 5, 3)
        fx_disc(x, y, 3, 11)
        pset(x - 1, y - 1, 7)
      end
    end
  end)
  play(ctx, 10, function(i) fx_ring(ux, uy, 6 + i * 2, 11) end)
end

-- 火星：一串火球噴過去，打到的地方冒火
MOVE_ANIM.ember = function(ctx, u, t)
  local ux, uy = ctx.pos(u)
  local tx, ty = ctx.pos(t)
  wiggle(ctx, u, 6, 1)
  play(ctx, 30, function(i)
    for k = 0, 4 do
      local s = i - k * 3
      if s >= 1 and s <= 16 then
        local x, y = arc(ux, uy, tx + (k - 2) * 7, ty + (k % 2) * 6, s, 16, 8)
        flame(x, y, 3 + s // 4, i + k)
      end
    end
  end)
  play(ctx, 14, function(i)
    for k = 0, 2 do flame(tx + (k - 1) * 14, ty + 10 - i // 2 - k * 3, 6 - i // 3, i + k) end
  end)
end

-- 焰牙：撲過去，上下兩排牙咬合，牙上帶火
MOVE_ANIM.firefang = function(ctx, u, t)
  local back = lunge(ctx, u, t, 20, 6)
  local tx, ty = ctx.pos(t)
  play(ctx, 16, function(i)
    local gap = math.max(18 - i * 3, 2)
    for k = -2, 2 do
      local x = tx + k * 7
      for r = 0, 5 do
        rect(x - 3 + r // 2, ty - gap - 6 + r, 6 - r // 2 * 2, 1, 7)       -- 上排牙（尖往下）
        rect(x - 3 + r // 2, ty + gap + 6 - r, 6 - r // 2 * 2, 1, 7)       -- 下排牙（尖往上）
      end
    end
    if i > 6 then for k = 0, 3 do flame(tx - 18 + k * 12, ty - 4 + (k % 2) * 8, 5, i + k) end end
  end)
  back(8)
end

-- 水花：水滴拋過去，打到之後往下濺
MOVE_ANIM.splash = function(ctx, u, t)
  local ux, uy = ctx.pos(u)
  local tx, ty = ctx.pos(t)
  wiggle(ctx, u, 6, 1)
  play(ctx, 26, function(i)
    for k = 0, 3 do
      local s = i - k * 3
      if s >= 1 and s <= 16 then
        local x, y = arc(ux, uy - 8, tx + (k - 1) * 8, ty - 4, s, 16, 24)
        drop(x, y, 5)
      end
    end
  end)
  play(ctx, 16, function(i)
    for k = 0, 5 do
      local vx = (k - 2) * 2 - 1
      drop(tx + vx * i, ty - 6 - 3 * i + i * i // 4 + (k % 2) * 4, 3)
    end
  end)
end

-- 泡泡網：一堆泡泡搖搖晃晃飄過去，黏在對方身上，最後破掉
MOVE_ANIM.bubblenet = function(ctx, u, t)
  local ux, uy = ctx.pos(u)
  local tx, ty = ctx.pos(t)
  local N = 7
  play(ctx, 44, function(i)
    for k = 0, N - 1 do
      local s = math.min(i - k * 3, 24)
      if s >= 1 then
        local ex, ey = tx + (hash(k, 7) % 41) - 20, ty + (hash(k, 8) % 41) - 20
        local x, y = ux + (ex - ux) * s // 24, uy + (ey - uy) * s // 24
        x = x + isin(i * 2 + k * 7) // 3
        local r = 5 + hash(k, 9) % 4
        fx_ring(x, y, r, 12)
        pset(x - 1, y - r + 2, 7)
      end
    end
  end)
  play(ctx, 8, function(i)
    for k = 0, N - 1 do
      local ex, ey = tx + (hash(k, 7) % 41) - 20, ty + (hash(k, 8) % 41) - 20
      if i < 4 then fx_ring(ex, ey, 6 + i, 7) end
    end
  end)
end

-- 霧幕：霧從腳下冒出來把自己包住，慢慢散開
MOVE_ANIM.mist = function(ctx, u, t)
  local ux, uy = ctx.pos(u)
  play(ctx, 48, function(i)
    for k = 0, 9 do
      local a = hash(k, 3) % 32
      local d = 10 + hash(k, 4) % 18
      local x = ux + isin(a + i // 4) * d // 8
      local y = uy + 12 + isin(a + 8) * d // 16 - i // 3
      local r = 5 + hash(k, 5) % 4 + ((i < 24) and i // 6 or (48 - i) // 6)
      fx_disc(x, y, r, (k % 3 == 0) and 6 or 7)
    end
  end)
end

-- 屬性預設（moves.json 加了新招、還沒寫動畫時用）
local TYPE_ANIM = {
  normal = MOVE_ANIM.tackle, grass = MOVE_ANIM.leaf, fire = MOVE_ANIM.ember,
  water = MOVE_ANIM.splash, electric = MOVE_ANIM.tackle, rock = MOVE_ANIM.tackle,
}

function fx_move(ctx, key, u, t)
  local f = MOVE_ANIM[key] or TYPE_ANIM[DATA.moves[key].type] or MOVE_ANIM.tackle
  f(ctx, u, t)
  ctx.offset(u, 0, 0)
  ctx.overlay(nil)
end

-- ============================================================
-- 受擊、能力變化、狀態
-- ============================================================

-- 被打到：往後退一下 + 畫面晃動 + 閃爍。效果絕佳晃得更大
function fx_hit(ctx, side, mult)
  local amp = (mult == 4) and 5 or (mult == 1) and 1 or 3
  local away = (side == 2) and 1 or -1           -- 對手往右後退，自己往左後退
  for i = 1, 24 do
    local shake = (i <= 10) and ((i % 2 == 0) and amp or -amp) or 0
    ctx.shake(shake, (i <= 10) and (i % 3 - 1) * amp // 2 or 0)
    ctx.offset(side, (i <= 8) and away * (8 - i) or 0, 0)
    ctx.hide(side, i > 4 and (i // 4) % 2 == 1)
    ctx.wait(1)
  end
  ctx.shake(0, 0)
  ctx.offset(side, 0, 0)
  ctx.hide(side, false)
end

-- 能力上升：紅色箭頭往上飄；下降：藍色箭頭往下掉
function fx_stat(ctx, side, up)
  local x0, y0 = ctx.pos(side)
  local c1, c2 = up and 8 or 1, up and 9 or 12
  play(ctx, 30, function(i)
    for k = 0, 4 do
      local x = x0 - 24 + k * 12
      local p = (i * 2 + k * 9) % 40
      local y = up and (y0 + 20 - p) or (y0 - 20 + p)
      local dir = up and -1 or 1
      for r = 0, 3 do rect(x - r, y + dir * (r - 3) * 1, r * 2 + 1, 1, c1) end   -- 箭頭的三角形
      rect(x - 1, up and y + 1 or y - 6, 3, 6, c2)                              -- 箭頭的桿
    end
  end)
end

-- 狀態：灼傷冒火、麻痺閃電、睡著冒 Z
function fx_status(ctx, side, status)
  local x0, y0 = ctx.pos(side)
  if status == "burn" then
    play(ctx, 24, function(i)
      for k = 0, 3 do flame(x0 - 18 + k * 12, y0 + 16 - (i + k * 5) % 24, 3, i + k) end
    end)
  elseif status == "paralyze" then
    play(ctx, 24, function(i)
      if (i // 3) % 2 == 0 then
        for k = 0, 1 do
          local x = x0 - 16 + k * 30
          thick_line(x, y0 - 18, x - 6, y0 - 4, 2, 10)
          thick_line(x - 6, y0 - 4, x + 4, y0 - 2, 2, 10)
          thick_line(x + 4, y0 - 2, x - 2, y0 + 14, 2, 10)
        end
      end
      ctx.offset(side, (i % 2 == 0) and 1 or -1, 0)
    end)
    ctx.offset(side, 0, 0)
  elseif status == "sleep" then
    play(ctx, 40, function(i)
      for k = 0, 2 do
        local p = (i + k * 13) % 40
        text("Z", x0 + 10 + p // 3, y0 - 10 - p, (p < 30) and 1 or 13)
      end
    end)
  end
end

-- 升級：金色的光點從腳下往上飄，繞著野伴轉
function fx_levelup(ctx, side)
  local x0, y0 = ctx.pos(side)
  play(ctx, 40, function(i)
    for k = 0, 7 do
      local p = (i * 2 + k * 10) % 50                 -- 這顆光點升到哪（0～50）
      local x = x0 + isin(k * 4 + i // 2) * 3
      local y = y0 + 28 - p
      local r = (p < 40) and 2 or 1
      fx_disc(x, y, r, (k % 2 == 0) and 10 or 7)
      if p % 10 < 5 then pset(x, y - 3, 7) end
    end
  end)
end
