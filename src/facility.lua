-- facility.lua：營地的設施（W44）
--
-- 地圖的物件層放 type = "lot" 的物件 = 一塊 2×2 格的設施空地（物件的位置是左上角那格）。
-- 面對空地按 A → 選要蓋什麼（data/facilities.json）→ 材料夠就扣掉、蓋好。
-- 面對蓋好的設施按 A → 看看／拆掉（拿回一半材料）。
-- 空地和設施都會擋路：載入地圖時把那 4 格的 solid 設成 1（在 Studio 移動空地，碰撞會跟著走）。
--
-- 記錄：FACILITY["地圖:x:y"] = { kind = "lumber", workers = { 野伴, … } }
--   workers：派駐的野伴（W45）。派過去的野伴離開隊伍／牧場，叫回來才會回去；存檔時一起存（W49）
-- 派駐的野伴在設施旁邊走來走去：在 4 個定點（前面左右、兩側）之間走，停下來時一跳一跳地工作
-- 設施的圖：assets/art/facilities.png，每格 32×32；第 0 格是空地，其他是 facilities.json 的 sprite，第 5 格是工作台
--
-- 工作台：地圖物件 type = "workbench"，也是 2×2 格、擋路；面對它按 A 開製作（craft.lua）

FACILITY = FACILITY or {}

local lots = {}       -- 這張地圖的空地
local benches = {}    -- 這張地圖的工作台
local WORKBENCH_SPRITE = 5
local tick = 0        -- 畫面計時（蓋好時的煙塵、野伴走路）
local MAX_WORKERS = 3 -- 一個設施最多派幾隻

local function key(l) return world.name .. ":" .. l.cx .. ":" .. l.cy end

local function block_2x2(o)
  for dy = 0, 1 do
    for dx = 0, 1 do mset(world.map, "solid", o.x + dx, o.y + dy, 1) end
  end
end

function facility_load()
  lots, benches = {}, {}
  for _, o in ipairs(world.objects) do
    if o.type == "lot" then
      local l = { cx = o.x, cy = o.y, x = o.x * TILE, y = o.y * TILE }
      l.key = key(l)
      lots[#lots + 1] = l
      block_2x2(o)
    elseif o.type == "workbench" then
      benches[#benches + 1] = { cx = o.x, cy = o.y, x = o.x * TILE, y = o.y * TILE }
      block_2x2(o)
    end
  end
end

-- 世界座標 (px, py) 這一點上的工作台
function workbench_at(px, py)
  local cx, cy = px // TILE, py // TILE
  for _, b in ipairs(benches) do
    if cx >= b.cx and cx <= b.cx + 1 and cy >= b.cy and cy <= b.cy + 1 then return b end
  end
  return nil
end

function workbench_interact(b)
  craft_open()   -- craft.lua
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

-- 給製作（craft.lua）共用
mat_sorted, mat_text, mat_missing = sorted_cost, cost_text, missing   -- 材料清單排序、「木材 5、石頭 2」、還差什麼

-- 能蓋的設施，依 sort 排好
local function buildable()
  local keys = {}
  for k, f in pairs(DATA.facilities) do
    if not f.unlock or FLAGS[f.unlock] then keys[#keys + 1] = k end   -- unlock：要拿到徽記才能蓋（爐，W68）
  end
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
  if not FLAGS.tutorial_sleep then cutscene_start(SCENE.p7_feed) end   -- 序章 P7：老苔來教派野伴、睡覺
end

-- 選要蓋什麼的畫面：右上是清單，左上是設施的圖（放大 2 倍），下面是說明和材料
local function build_menu(l)
  local keys = buildable()
  local items = {}
  for i, k in ipairs(keys) do items[i] = DATA.facilities[k].name end
  items[#items + 1] = "取消"
  local m = menu_new({ items = items, x = 0, y = 8 })
  m.x = 316 - m.w
  local screen = { menu = m, art = true }
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

-- ============================================================
-- 派駐野伴（W45）
-- ============================================================

-- 這隻野伴的某項工作等級（不會就是 0）
local function work_level(k, work)
  local w = kin_species(k).work
  return (w and w[work]) or 0
end

-- 叫回來：隊伍有空位回隊伍，滿了去牧場。回傳去了哪裡
function send_home(k)
  if #party < 6 then
    party[#party + 1] = k
    return "隊伍"
  end
  RANCH[#RANCH + 1] = k
  return "牧場"
end

-- 每天的產出：{ { "wood", 2 } }（基本量 × 派駐野伴的工作等級總和；吃飽的情況）
function facility_output(fac)
  local f = DATA.facilities[fac.kind]
  local total = 0
  for _, k in ipairs(fac.workers) do total = total + work_level(k, f.work) end
  local list = {}
  for _, c in ipairs(sorted_cost(f.output)) do
    if c[2] * total > 0 then list[#list + 1] = { c[1], c[2] * total } end
  end
  return list, total
end

-- 營地有沒有在發電（發電機有派野伴）：晚上就沒那麼暗（clock.lua 的 clock_tint）
function camp_lit()
  for key, fac in pairs(FACILITY) do
    if DATA.facilities[fac.kind].lights and #fac.workers > 0 and key:sub(1, 5) == "camp:" then return true end
  end
  return false
end

-- 換日時（day.lua 的 day_change）：每隻派駐的野伴吃 1 份飼料（BAG.feed）；吃不到的那隻記 k.hungry = true，
-- 接下來這一天產量減半。照固定順序分飼料（pairs 的順序每次可能不同）。回傳：派駐的野伴總數、餓著的隻數
local function sorted_keys()
  local keys = {}
  for k in pairs(FACILITY) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

function facility_feed()
  local workers, hungry = 0, 0
  for _, key in ipairs(sorted_keys()) do
    for _, k in ipairs(FACILITY[key].workers) do
      workers = workers + 1
      if (BAG.feed or 0) > 0 then
        bag_add("feed", -1)
        k.hungry = nil
      else
        k.hungry = true
        hungry = hungry + 1
      end
    end
  end
  return workers, hungry
end

-- 每到整點（clock.lua）：每個設施做一小時份的產出，直接放進背包。
-- 一天的產量（和 W46 一樣）= 基本量 × Σ(工作等級 × 2，餓著的 × 1) // 2
-- 平均分到 24 小時：每小時把「基本量 × Σ」加進 fac.acc，滿 48（= 2 × 24）就給 1 個，餘數留著。
-- 這樣一整天下來剛好是一天的產量，不會因為切成小時而少給（只用整數）。
function facility_hour()
  for _, key in ipairs(sorted_keys()) do
    local fac = FACILITY[key]
    local f = DATA.facilities[fac.kind]
    local units = 0
    for _, k in ipairs(fac.workers) do
      local lv = work_level(k, f.work)
      units = units + (k.hungry and lv or lv * 2)
    end
    if units > 0 then
      fac.acc = fac.acc or {}
      for _, c in ipairs(sorted_cost(f.output)) do
        local acc = (fac.acc[c[1]] or 0) + c[2] * units
        local n = acc // 48
        -- input：做一個要用掉的材料（爐：礦石 1 → 金屬 1，W68）。材料不夠就只做得出夠的那幾個，
        -- 沒做的那些先留在 acc 裡（等有材料再做，不會白白浪費工作量）
        if n > 0 and f.input then
          for item, per in pairs(f.input) do n = math.min(n, (BAG[item] or 0) // per) end
          for item, per in pairs(f.input) do if n > 0 then bag_add(item, -per * n) end end
        end
        if n > 0 then bag_add(c[1], n) end
        fac.acc[c[1]] = math.min(acc - n * 48, 48 * 4)    -- 最多存 4 個的量（材料一直沒有時不要無限累積）
      end
    end
  end
end

-- 一行野伴：小圖示、名字、Lv、工作等級。y 是這一行的上緣
local function worker_row(k, work, x, y, w, selected)
  if selected then ui_arrow_right(x + 4, y + 5, 0) end
  kin_icon_draw(k.no, x + 14, y + 1, false, 0, true, k.shiny)
  text(kin_name(k), x + 36, y + 1, 0)
  local lv = "Lv" .. k.level
  text(lv, x + 120, y + 1, 5)
  local wl = DATA.work[work] .. " " .. work_level(k, work)
  text(wl, x + w - 12 - textw(wl), y + 1, 0)
end

-- 可以派的野伴：隊伍和牧場裡，會這項工作的
local function candidates(work)
  local list = {}
  for i, k in ipairs(party) do
    if work_level(k, work) > 0 then list[#list + 1] = { k = k, from = "隊伍" } end
  end
  for i, k in ipairs(RANCH) do
    if work_level(k, work) > 0 then list[#list + 1] = { k = k, from = "牧場" } end
  end
  return list
end

local function remove_from(t, k)
  for i, v in ipairs(t) do
    if v == k then table.remove(t, i) return end
  end
end

-- 沒有能派的：告訴玩家哪些「見過的」野伴會這項工作（沒見過的不爆雷）
local function nobody_text(f)
  local names = {}
  local nos = {}
  for no in pairs(DATA.species) do nos[#nos + 1] = no end
  table.sort(nos)
  for _, no in ipairs(nos) do
    local w = DATA.species[no].work
    if DEX.seen[no] and w and w[f.work] then names[#names + 1] = DATA.species[no].name end
  end
  local s = "隊伍和牧場裡沒有會" .. DATA.work[f.work] .. "的野伴。"
  if #names > 0 then s = s .. "\n" .. table.concat(names, "、") .. "會" .. DATA.work[f.work] .. "。" end
  return s
end

-- 選要派哪一隻
local function pick_worker(l, fac)
  local f = DATA.facilities[fac.kind]
  local list = candidates(f.work)
  if #list == 0 then
    dialog_open(nobody_text(f))
    return
  end
  local screen = { index = 1, art = true }
  function screen.update(self)
    if pressed_repeat(UP) then self.index = (self.index - 2) % #list + 1 end
    if pressed_repeat(DOWN) then self.index = self.index % #list + 1 end
    if pressed(B) then ui_pop() return end
    if not pressed(A) then return end
    local c = list[self.index]
    if c.from == "隊伍" and #party <= 1 then
      dialog_open("隊伍裡至少要留一隻野伴。")
      return
    end
    remove_from(c.from == "隊伍" and party or RANCH, c.k)
    fac.workers[#fac.workers + 1] = c.k
    ui_pop()
    dialog_open(kin_name(c.k) .. "開始在" .. f.name .. "工作了！")
  end
  function screen.draw(self)
    local x, y, w = 24, 40, 264      -- 往右下錯開，看得到底下派駐畫面的標題
    ui_box(x, y, w, 18 + #list * 20)
    for i, c in ipairs(list) do
      local ry = y + 9 + (i - 1) * 20
      worker_row(c.k, f.work, x + 4, ry, w - 48, i == self.index)
      text(c.from, x + w - 12 - textw(c.from), ry + 1, 5)
    end
    ui_box(4, 184, 312, 52)
    text("要派哪一隻去" .. f.name .. "？", 14, 192, 0)
    text("派去工作的野伴會離開" .. (#RANCH > 0 and "隊伍或牧場" or "隊伍") .. "。", 14, 210, 5)
  end
  ui_push(screen)
end

-- 派駐畫面：3 個位置，空的選了派一隻，有野伴的選了叫回來
local function workers_screen(l, fac)
  local f = DATA.facilities[fac.kind]
  local screen = { index = 1, art = true }
  function screen.update(self)
    if pressed_repeat(UP) then self.index = (self.index - 2) % MAX_WORKERS + 1 end
    if pressed_repeat(DOWN) then self.index = self.index % MAX_WORKERS + 1 end
    if pressed(B) then ui_pop() return end
    if not pressed(A) then return end
    local k = fac.workers[self.index]
    if not k then
      pick_worker(l, fac)
      return
    end
    dialog_ask("要叫" .. kin_name(k) .. "回來嗎？", { "叫回來", "不要" }, function(c)
      if c ~= 1 then return end
      remove_from(fac.workers, k)
      local where = send_home(k)
      dialog_open(kin_name(k) .. "回到" .. where .. "了。")
    end)
  end
  function screen.draw(self)
    local x, y, w = 8, 8, 304
    ui_box(x, y, w, 26 + MAX_WORKERS * 20)
    text(f.name .. "：派駐的野伴", x + 12, y + 7, 0)
    for i = 1, MAX_WORKERS do
      local ry = y + 27 + (i - 1) * 20
      local k = fac.workers[i]
      if k then
        worker_row(k, f.work, x + 4, ry, w - 4, i == self.index)
      else
        if i == self.index then ui_arrow_right(x + 8, ry + 6, 0) end
        text("（空位）", x + 40, ry + 1, 5)
      end
    end
    ui_box(4, 184, 312, 52)
    local out = facility_output(fac)
    if f.lights then
      -- 發電機（W70）：沒有產出，有野伴在工作時營地晚上會亮燈
      text(#fac.workers > 0 and "營地晚上會亮燈。" or "沒有會" .. DATA.work[f.work] .. "的野伴工作，晚上就不會亮。", 14, 192, 0)
    elseif #out == 0 then
      text("沒有會" .. DATA.work[f.work] .. "的野伴工作，就不會有產出。", 14, 192, 0)
    else
      local parts = {}
      for _, c in ipairs(out) do parts[#parts + 1] = DATA.items[c[1]].name .. " " .. c[2] end
      text("每天產出（每小時慢慢進背包）：" .. table.concat(parts, "、"), 14, 192, 0)
    end
    if f.input then
      -- 要用材料的設施（爐）：寫出每做一個要用掉什麼、背包裡還有多少
      local parts = {}
      for _, c in ipairs(sorted_cost(f.input)) do
        parts[#parts + 1] = DATA.items[c[1]].name .. " " .. c[2] .. "（有 " .. (BAG[c[1]] or 0) .. "）"
      end
      text("每做一個要用掉：" .. table.concat(parts, "、"), 14, 210, 5)
    else
      text("每隻每天半夜吃 1 份飼料，沒吃到的那天產量減半。", 14, 210, 5)
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
  if #fac.workers > 0 then msg = msg .. "\n在這裡工作的野伴會回去。" end
  dialog_ask(msg, { "拆掉", "不要" }, function(c)
    if c ~= 1 then return end
    for k, n in pairs(back) do bag_add(k, n) end
    for _, k in ipairs(fac.workers) do send_home(k) end
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
  local m = menu_new({ items = { "派駐", "看看", "拆掉", "取消" }, x = 0, y = 8 })
  m.x = 316 - m.w
  local screen = { menu = m }
  function screen.update(self)
    local r = menu_update(self.menu)
    if r == 0 or r == 4 then ui_pop()
    elseif r == 1 then
      workers_screen(l, fac)
    elseif r == 2 then
      local names = {}
      for _, k in ipairs(fac.workers) do names[#names + 1] = kin_name(k) end
      local who = (#names > 0) and ("在這裡工作：" .. table.concat(names, "、") .. "。") or "還沒有野伴在這裡工作。"
      dialog_open(f.name .. "：" .. f.desc .. "\n" .. who)
    elseif r == 3 then
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

-- ============================================================
-- 在設施旁邊走來走去的野伴
-- ============================================================

-- 4 個定點（圖示左上角，相對設施左上角）：前面左、前面右、左側、右側。
-- 設施之間、設施前面都留了一格走道，圖示站在走道上
local SPOTS = { { 2, 24 }, { 15, 24 }, { -10, 10 }, { 26, 10 } }
local FRONT_Y = 24
local walkers = {}   -- walkers[野伴] = { x, y, spot, wait, right, step }（只是畫面，不存檔）

local function walker(l, k, i)
  local w = walkers[k]
  if not w or w.lot ~= l then
    local s = (i - 1) % #SPOTS + 1
    w = { lot = l, x = SPOTS[s][1], y = SPOTS[s][2], spot = s, wait = 30 + hash(i, l.cx, l.cy) % 90, right = s ~= 4, step = 0 }
    walkers[k] = w
  end
  return w
end

-- 一幀：停著就倒數（工作中）；倒數完選下一個定點，先走到前面那一排、再左右走、再上下走（不會穿過設施）
local function walker_step(l, w, i)
  local s = SPOTS[w.spot]
  local tx, ty = s[1], s[2]
  if w.x == tx and w.y == ty then
    if w.wait > 0 then
      w.wait = w.wait - 1
      return false
    end
    local n = hash(tick, i, l.cx * 64 + l.cy) % (#SPOTS - 1) + 1
    w.spot = (w.spot + n - 1) % #SPOTS + 1             -- 一定換一個定點
    w.wait = 90 + hash(tick, i, 7) % 150
    return true
  end
  if tick % 2 == 1 then return true end                 -- 走慢一點：兩幀走一像素
  w.step = w.step + 1
  if w.x ~= tx and w.y ~= FRONT_Y then
    w.y = w.y + (FRONT_Y > w.y and 1 or -1)
  elseif w.x ~= tx then
    w.right = tx > w.x
    w.x = w.x + (w.right and 1 or -1)
  else
    w.y = w.y + (ty > w.y and 1 or -1)
  end
  return true
end

-- 給 main.lua 的 draw_actors：把野伴加進「依 y 排序」的清單，和主角、NPC 互相遮擋
function facility_actors(list)
  for _, l in ipairs(lots) do
    local fac = FACILITY[l.key]
    if fac then
      for i, k in ipairs(fac.workers) do
        local w = walker(l, k, i)
        local moving = walker_step(l, w, i)
        local x, y = l.x + w.x, l.y + w.y
        if moving then
          list[#list + 1] = { y = y, draw = function() kin_icon_draw(k.no, x, y, true, w.step, w.right, k.shiny) end }
        else
          -- 工作中：面向設施，每 24 幀跳一下
          local right = (w.spot == 3) or (w.spot ~= 4 and w.right)
          local hop = (tick + i * 8) % 24 < 4 and 1 or 0
          list[#list + 1] = { y = y, draw = function() kin_icon_draw(k.no, x, y - hop, false, 0, right, k.shiny) end }
        end
      end
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
  for _, b in ipairs(benches) do spr(IMG.facilities, WORKBENCH_SPRITE, b.x, b.y) end
end

-- 角色之後畫（煙塵蓋在設施和主角上面）
function facility_draw_top()
  for _, l in ipairs(lots) do
    if l.dust then draw_dust(l) end
  end
end
