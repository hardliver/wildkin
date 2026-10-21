-- craft.lua：工作台製作道具（W47）
--
-- 配方在 data/recipes.json：做出什麼（item）、一次做幾個（amount）、材料（cost）。
-- 流程：工作台按 A → 配方清單（右上）＋說明、材料「木材 2（有 5）」（下方）→ 選一個 →
--       選數量（左右 ±1、上下 ±10，最多做到材料用完）→ 扣材料、放進背包
-- 要解鎖的配方加 unlock 欄位（劇情旗標的名字），旗標還沒有就不列出來（好球：badge_forest）

-- 依 sort 排好的配方編號
local function recipe_keys()
  local keys = {}
  for k, r in pairs(DATA.recipes) do
    if not r.unlock or FLAGS[r.unlock] then keys[#keys + 1] = k end   -- 還沒解鎖的不列（好球要森之徽記）
  end
  table.sort(keys, function(a, b) return DATA.recipes[a].sort < DATA.recipes[b].sort end)
  return keys
end

-- 材料夠做幾次
local function max_times(r)
  local n = 99
  for item, need in pairs(r.cost) do n = math.min(n, (BAG[item] or 0) // need) end
  return n
end

-- 材料表 × 次數
local function times_cost(cost, t)
  local c = {}
  for k, n in pairs(cost) do c[k] = n * t end
  return c
end

local function recipe_name(r)
  local name = DATA.items[r.item].name
  if r.amount > 1 then name = name .. " ×" .. r.amount end
  return name
end

local function make(r, times)
  for item, need in pairs(r.cost) do bag_add(item, -need * times) end
  local got = r.amount * times
  bag_add(r.item, got)
  dialog_open("叩、叩、叩……\n做好了" .. DATA.items[r.item].name .. " ×" .. got .. "！")
end

-- 選數量（screens.lua 的 amount_pick）：「野伴球 × 3」「用掉：木材 6、石頭 3」
local function amount_screen(r)
  amount_pick("要做幾次？", max_times(r),
    function(n) return DATA.items[r.item].name .. " × " .. (r.amount * n) end,
    function(n) return "用掉：" .. mat_text(times_cost(r.cost, n)) end,
    function(n) make(r, n) end, "製作")
end

function craft_open()
  local keys = recipe_keys()
  local items = {}
  for i, k in ipairs(keys) do items[i] = recipe_name(DATA.recipes[k]) end
  items[#items + 1] = "取消"
  local m = menu_new({ items = items, x = 0, y = 8 })
  m.x = 316 - m.w
  local screen = { menu = m }
  function screen.update(self)
    local r = menu_update(self.menu)
    if r == 0 or r == #items then ui_pop() return end
    if not r then return end
    local rec = DATA.recipes[keys[r]]
    local short = mat_missing(rec.cost)
    if short then
      dialog_open("材料不夠：" .. short .. "。")
      return
    end
    amount_screen(rec)
  end
  function screen.draw(self)
    -- 左上：標題
    ui_box(4, 8, 140, 30)
    text("工作台", 16, 15, 0)
    menu_draw(self.menu)
    local key = keys[self.menu.index]
    ui_box(4, 128, 312, 108)
    if not key then
      text("用材料做道具。材料在野外撿，或派野伴去設施工作。", 14, 138, 0)
      return
    end
    local rec = DATA.recipes[key]
    local it = DATA.items[rec.item]
    text(recipe_name(rec), 14, 138, 0)
    local have = "背包裡有 " .. (BAG[rec.item] or 0)
    text(have, 306 - textw(have), 138, 5)
    local y = 158
    for _, line in ipairs(wrap_text(it.desc, 290)) do
      if y > 190 then break end
      text(line, 14, y, 0)
      y = y + 16
    end
    local x = 14
    text("材料：", x, 214, 0)
    x = x + textw("材料：")
    for _, c in ipairs(mat_sorted(rec.cost)) do
      local n = BAG[c[1]] or 0
      local s = DATA.items[c[1]].name .. " " .. c[2] .. "（有 " .. n .. "）"
      text(s, x, 214, n >= c[2] and 0 or 8)
      x = x + textw(s) + 8
    end
  end
  ui_push(screen)
end
