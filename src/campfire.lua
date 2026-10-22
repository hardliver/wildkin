-- campfire.lua：營火傳送（W71）
--
-- 地圖物件 type = "fire"（Studio：物件 → 營火），一格、擋路。
--   第一次面對它按 A：點燃（FLAGS["fire:地圖名"] = true，存檔一起存）
--   之後按 A：列出所有點燃過的營火，選一個 → 畫面暗下來 → 站到那堆營火的前面（下面一格），面向營火
-- 新芽營地的營火一開始就是點著的（基地）。
-- 為什麼是營火、不是騎野伴飛：騎乘飛行是任天堂告 Pocketpair 的專利範圍（content.md「版權與專利的紅線」）。
-- 其他地圖的營火在哪一格：從 MAPOBJ（每張地圖的物件，cart 產生的）找，不用先進那張地圖。

local fires = {}

-- 選單上的順序（照故事前進的順序）；沒列到的地圖排在最後
local ORDER = { camp = 1, route1 = 2, village = 3, forest = 4, mine = 5, harbor = 6, coast = 7, volcano = 8, factory = 9 }

function fire_lit(map)
  return map == "camp" or FLAGS["fire:" .. map] == true
end

function fire_load()
  fires = {}
  for _, o in ipairs(world.objects) do
    if o.type == "fire" then
      fires[#fires + 1] = { cx = o.x, cy = o.y, x = o.x * TILE, y = o.y * TILE }
      mset(world.map, "solid", o.x, o.y, 1)
    end
  end
end

function fire_at(px, py)
  local cx, cy = px // TILE, py // TILE
  for _, f in ipairs(fires) do
    if f.cx == cx and f.cy == cy then return f end
  end
  return nil
end

-- 地面之後畫（和帳篷一起）：點著的火焰兩格輪流（看起來在閃）
function fire_draw()
  if #fires == 0 then return end
  local lit = fire_lit(world.name)
  for _, f in ipairs(fires) do
    local n = 0
    if lit then n = 1 + (frame() // 10 + f.cx) % 2 end
    spr(IMG.campfire, n, f.x, f.y)
  end
end

-- 每張地圖的第一堆營火：{ map, cx, cy }
local function all_fires()
  local list = {}
  for name, objs in pairs(MAPOBJ) do
    for _, o in ipairs(objs) do
      if o.type == "fire" then
        list[#list + 1] = { map = name, cx = o.x, cy = o.y }
        break
      end
    end
  end
  table.sort(list, function(a, b)
    local oa, ob = ORDER[a.map] or 99, ORDER[b.map] or 99
    if oa ~= ob then return oa < ob end
    return a.map < b.map
  end)
  return list
end

local function travel(dest)
  ui_clear()
  transition_start(function()
    warp(dest.map, dest.cx, dest.cy + 1, 0, -1)    -- 站在營火的下面一格，面向營火
  end, false, { hold = 30, caption = "……" })
end

-- 傳送的選單：右上角列出點燃過的營火（這裡不算）
local function travel_menu()
  local dests, items = {}, {}
  for _, d in ipairs(all_fires()) do
    if d.map ~= world.name and fire_lit(d.map) then
      dests[#dests + 1] = d
      items[#items + 1] = MAP_NAME[d.map] or d.map
    end
  end
  if #dests == 0 then
    dialog_open("營火燒得很旺。\n（還沒有點燃別的地方的營火，\n找到其他營火就能在兩邊傳送。）")
    return
  end
  items[#items + 1] = "取消"
  local m = menu_new({ items = items, x = 0, y = 8 })
  m.x = 316 - m.w
  local screen = { menu = m }
  function screen.update(self)
    local r = menu_update(self.menu)
    if r == 0 or r == #items then ui_pop() return end
    if r then travel(dests[r]) end
  end
  function screen.draw(self)
    ui_box(4, 8, 180, 30)
    text("要傳送到哪一堆營火？", 14, 15, 0)
    menu_draw(self.menu)
  end
  ui_push(screen)
end

function fire_interact(f)
  if not fire_lit(world.name) then
    FLAGS["fire:" .. world.name] = true
    dialog_open(PLAYER_NAME .. "點燃了營火！\f（蹲下去三次才把火點著。\n膝蓋響了兩次。）" ..
      "\f以後從別的營火，就能傳送到這裡。")
    return
  end
  travel_menu()
end
