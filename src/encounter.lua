-- encounter.lua：草叢和遇敵（W28）
--
-- 地圖的 grass 圖層：有畫東西的格子就是遇敵草叢（在 Studio 的地圖編輯器畫這一層）。
-- 遭遇表用地圖的名字找：DATA.encounters.route1（data/encounters.json）。
--
-- 規則（design.md）：主角每「走進」一格草叢，就擲一次 rnd(256)，小於遭遇表的 rate 就遇敵；
-- 遇到哪一隻依 weight 權重抽，等級在 min～max 之間。
-- 站著不動不會遇敵；在同一格裡走來走去也不會（要換到另一格才算）。

local last_cx, last_cy = nil, nil
local has_grass = false   -- 這張地圖有沒有 grass 圖層

-- 進入地圖時呼叫：主角站的那一格先記起來，不然一進地圖就站在草叢裡會馬上遇敵
function encounter_enter()
  has_grass = pcall(mget, world.map, "grass", 0, 0)
  last_cx, last_cy = player_cell()
end

function in_grass(cx, cy)
  return has_grass and mget(world.map, "grass", cx, cy) ~= 0
end

-- 依權重抽一筆：weight 50、40、5、5 → 抽到第一筆的機率 50%
local function pick(list)
  local total = 0
  for _, e in ipairs(list) do total = total + e.weight end
  local r = rnd(total)
  for _, e in ipairs(list) do
    if r < e.weight then return e end
    r = r - e.weight
  end
  return list[#list]
end

local function party_alive()
  for _, k in ipairs(party) do
    if k.hp > 0 then return true end
  end
  return false
end

-- 每幀呼叫（主角移動之後）
function encounter_check()
  local cx, cy = player_cell()
  if cx == last_cx and cy == last_cy then return end
  last_cx, last_cy = cx, cy
  if not in_grass(cx, cy) then return end
  local t = DATA.encounters[world.name]
  if not t or not party_alive() then return end
  if rnd(256) >= t.rate then return end
  local e = pick(t.list)
  local level = e.min + rnd(e.max - e.min + 1)
  battle_scene_start({ kin_new(e.species, level) }, { wild = true, flash = true }, function(result)
    if result == "lose" then wiped_out() end
  end)
end

-- ============================================================
-- 畫草叢
-- ============================================================
-- tallgrass.png 有 3 格：0 正常、1 往左晃、2 往右晃。
-- 和樹一樣：每格用 hash 決定多強的風才會晃；主角站的那一格一直晃（被踩到）。

local function grass_frame(cx, cy)
  local pcx, pcy = player_cell()
  if cx == pcx and cy == pcy and player.walking then
    return 1 + (frame() // 6) % 2
  end
  local h = hash(cx, cy, 5)
  if h % 7 + 2 <= wind_now() and (frame() + h) % (50 + h % 40) < 12 then
    return 1 + (frame() // 6 + h) % 2
  end
  return 0
end

-- 地面之後、角色之前畫
function tallgrass_draw()
  if not has_grass then return end
  local cx0, cy0 = world.cam_x // TILE, world.cam_y // TILE
  for cy = cy0, cy0 + SCREEN_H // TILE do
    for cx = cx0, cx0 + SCREEN_W // TILE do
      if in_grass(cx, cy) then
        spr(IMG.tallgrass, grass_frame(cx, cy), cx * TILE, cy * TILE)
      end
    end
  end
end

-- 角色之後畫：主角腳邊的草叢下半部再畫一次，蓋住主角的腳（看起來站在草裡面）
function tallgrass_front()
  if not has_grass then return end
  local x, y = player.x16 // 16, player.y16 // 16
  for cx = x // TILE, (x + 15) // TILE do
    local cy = (y + 15) // TILE
    if in_grass(cx, cy) then
      local f = grass_frame(cx, cy)
      sspr(IMG.tallgrass, f * 16, 9, 16, 7, cx * TILE, cy * TILE + 9)
    end
  end
end

-- ============================================================
-- 全滅（W29）
-- ============================================================
-- 戰鬥畫面全黑的那一刻呼叫：回到營地老苔的小屋前，隊伍全部補滿，老苔說一句話。
-- GB 會扣一半的錢；這個遊戲還沒有錢（W55 商店），先不扣。
function wiped_out()
  for _, k in ipairs(party) do kin_heal(k) end
  warp("camp", 19, 13, 0, -1)          -- 老苔（19, 11）的前面，面向他
  dialog_open(TALK.elder_rescue)
end
