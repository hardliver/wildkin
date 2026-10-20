-- facility.lua：營地的設施（W44）
--
-- 地圖的物件層放 type = "lot" 的物件 = 一塊 2×2 格的設施空地（物件的位置是左上角那格）。
-- 面對空地按 A → 選要蓋什麼（data/facilities.json）→ 材料夠就扣掉、蓋好。
-- 面對蓋好的設施按 A → 看看／拆掉（拿回一半材料）。
-- 空地和設施都會擋路：載入地圖時把那 4 格的 solid 設成 1（在 Studio 移動空地，碰撞會跟著走）。
--
-- 記錄：FACILITY["地圖:x:y"] = { kind = "lumber", workers = {} }
--   workers：派駐的野伴（W45）；存檔時一起存（W49）
-- 設施的圖：assets/art/facilities.png，每格 32×32；第 0 格是空地，其他是 facilities.json 的 sprite

FACILITY = FACILITY or {}

local lots = {}       -- 這張地圖的空地
local tick = 0        -- 畫面計時（蓋好時的煙塵）

local function key(l) return world.name .. ":" .. l.cx .. ":" .. l.cy end

function facility_load()
  lots = {}
  for _, o in ipairs(world.objects) do
    if o.type == "lot" then
      local l = { cx = o.x, cy = o.y, x = o.x * TILE, y = o.y * TILE }
      l.key = key(l)
      lots[#lots + 1] = l
      for dy = 0, 1 do
        for dx = 0, 1 do mset(world.map, "solid", o.x + dx, o.y + dy, 1) end
      end
    end
  end
end

-- 世界座標 (px, py) 這一點上的空地／設施
function facility_at(px, py)
  local cx, cy = px // TILE, py // TILE
  for _, l in ipairs(lots) do
    if cx >= l.cx and cx <= l.cx + 1 and cy >= l.cy and cy <= l.cy + 1 then return l end
  end
  return nil
end

-- 材料表 { wood = 5, stone = 2 } 依道具的 sort 排好：{ { "wood", 5 }, { "stone", 2 } }
local function sorted_cost(cost)
  local list = {}
  for k, n in pairs(cost) do list[#list + 1] = { k, n } end
  table.sort(list, function(a, b) return DATA.items[a[1]].sort < DATA.items[b[1]].sort end)
  return list
end

-- 「木材 5、石頭 2」
local function cost_text(cost)
  local parts = {}
  for _, c in ipairs(sorted_cost(cost)) do parts[#parts + 1] = DATA.items[c[1]].name .. " " .. c[2] end
  return table.concat(parts, "、")
end

-- 還差什麼（「木材還差 2」）；都夠回傳 nil
local function missing(cost)
  local parts = {}
  for _, c in ipairs(sorted_cost(cost)) do
    local have = BAG[c[1]] or 0
    if have < c[2] then parts[#parts + 1] = DATA.items[c[1]].name .. "還差 " .. (c[2] - have) end
  end
  if #parts == 0 then return nil end
  return table.concat(parts, "、")
end

-- 能蓋的設施，依 sort 排好
local function buildable()
  local keys = {}
  for k, f in pairs(DATA.facilities) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return DATA.facilities[a].sort < DATA.facilities[b].sort end)
  return keys
end

local function build(l, kind)
  local f = DATA.facilities[kind]
  for k, n in pairs(f.cost) do bag_add(k, -n) end
  FACILITY[l.key] = { kind = kind, workers = {} }
  l.dust = tick   -- 從這一刻開始冒煙塵
  ui_clear()
  dialog_open(f.name .. "蓋好了！\n之後可以派野伴來這裡工作。")
end

-- 選要蓋什麼的畫面：右上是清單，左上是設施的圖（放大 2 倍），下面是說明和材料
local function build_menu(l)
  local keys = buildable()
  local items = {}
  for i, k in ipairs(keys) do items[i] = DATA.facilities[k].name end
  items[#items + 1] = "取消"
  local m = menu_new({ items = items, x = 0, y = 8 })
  m.x = 316 - m.w
  local screen = { menu = m }
  function screen.update(self)
    local r = menu_update(self.menu)
    if r == 0 or r == #items then ui_pop() return end
    if not r then return end
    local kind = keys[r]
    local f = DATA.facilities[kind]
    local short = missing(f.cost)
    if short then
      dialog_open("材料不夠：" .. short .. "。")
      return
    end
    dialog_ask("要蓋" .. f.name .. "嗎？\n會用掉" .. cost_text(f.cost) .. "。", { "蓋", "不要" }, function(c)
      if c == 1 then build(l, kind) end
    end)
  end
  function screen.draw(self)
    menu_draw(self.menu)
    local kind = keys[self.menu.index]
    ui_box(4, 128, 312, 108)
    if not kind then
      text("面對空地按 A 可以蓋設施。", 14, 138, 0)
      return
    end
    local f = DATA.facilities[kind]
    -- 圖：放大 2 倍，畫在左上
    ui_box(4, 8, 76, 76)
    for gy = 0, 1 do   -- 底下鋪草地（town 的第 0 格，放大 2 倍）
      for gx = 0, 1 do sspr(IMG.town, 0, 0, 16, 16, 10 + gx * 32, 14 + gy * 32, 32, 32) end
    end
    sspr(IMG.facilities, f.sprite * 32, 0, 32, 32, 10, 14, 64, 64)
    text(f.name, 14, 138, 0)
    text("工作：" .. DATA.work[f.work], 120, 138, 5)
    local y = 158
    for _, line in ipairs(wrap_text(f.desc, 290)) do
      text(line, 14, y, 0)
      y = y + 16
    end
    -- 材料：每一樣「木材 5（有 3）」，不夠的用紅色
    local x = 14
    text("材料：", x, 214, 0)
    x = x + textw("材料：")
    for _, c in ipairs(sorted_cost(f.cost)) do
      local have = BAG[c[1]] or 0
      local s = DATA.items[c[1]].name .. " " .. c[2] .. "（有 " .. have .. "）"
      text(s, x, 214, have >= c[2] and 0 or 8)
      x = x + textw(s) + 8
    end
  end
  ui_push(screen)
end

local function demolish(l)
  local fac = FACILITY[l.key]
  local f = DATA.facilities[fac.kind]
  local back = {}
  for k, n in pairs(f.cost) do
    if n // 2 > 0 then back[k] = n // 2 end
  end
  local msg = "要拆掉" .. f.name .. "嗎？"
  if next(back) then msg = msg .. "\n可以拿回" .. cost_text(back) .. "。" end
  dialog_ask(msg, { "拆掉", "不要" }, function(c)
    if c ~= 1 then return end
    for k, n in pairs(back) do bag_add(k, n) end
    FACILITY[l.key] = nil
    l.dust = tick
    ui_clear()
    dialog_open(f.name .. "拆掉了，這裡又變回空地。")
  end)
end

-- 面對空地／設施按 A
function facility_interact(l)
  local fac = FACILITY[l.key]
  if not fac then
    build_menu(l)
    return
  end
  local f = DATA.facilities[fac.kind]
  local m = menu_new({ items = { "看看", "拆掉", "取消" }, x = 0, y = 8 })
  m.x = 316 - m.w
  local screen = { menu = m }
  function screen.update(self)
    local r = menu_update(self.menu)
    if r == 0 or r == 3 then ui_pop()
    elseif r == 1 then
      dialog_open(f.name .. "：" .. f.desc .. "\n還沒有野伴在這裡工作。")
    elseif r == 2 then
      demolish(l)
    end
  end
  function screen.draw(self) menu_draw(self.menu) end
  ui_push(screen)
end

-- 煙塵：剛蓋好／拆掉的 30 幀，四周冒出幾團灰白色的煙，慢慢往上飄、變小
local DUST = { { -4, 22 }, { 26, 24 }, { 6, 28 }, { 18, 30 }, { 30, 10 }, { -2, 8 } }

local function draw_dust(l)
  local t = tick - l.dust
  if t >= 30 then
    l.dust = nil
    return
  end
  for i, p in ipairs(DUST) do
    local r = 4 - t // 8
    local x = l.x + p[1] + (p[1] < 14 and -1 or 1) * (t // 4)
    local y = l.y + p[2] - t // 3 - i % 2 * 2
    if r > 0 then
      rect(x - r, y - r + 1, r * 2, r * 2 - 2, 6)
      rect(x - r + 1, y - r, r * 2 - 2, r * 2, 6)
      rect(x - r + 2, y - r + 1, r - 1, r - 1, 7)
    end
  end
end

-- 地面之後、裝飾之前畫（世界座標）
function facility_draw()
  tick = tick + 1
  for _, l in ipairs(lots) do
    local fac = FACILITY[l.key]
    local n = fac and DATA.facilities[fac.kind].sprite or 0
    spr(IMG.facilities, n, l.x, l.y)
  end
end

-- 角色之後畫（煙塵蓋在設施和主角上面）
function facility_draw_top()
  for _, l in ipairs(lots) do
    if l.dust then draw_dust(l) end
  end
end
