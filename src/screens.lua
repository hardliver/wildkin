-- screens.lua：疊在地圖或戰鬥上面的畫面（START 選單、背包、選野伴……）（W33）
--
-- 畫面是一個表格，有 update(self) 和 draw(self)。用「堆疊」管理：
--   ui_push(畫面)：打開一個新畫面，蓋在最上面
--   ui_pop()：關掉最上面的畫面，回到底下那個
-- 只有最上面的畫面會讀按鍵，但每一層都會畫（看得到底下的選單，知道自己在哪裡）。
-- 對話框（dialog）在所有畫面之上：有對話時先處理對話。

local stack = {}

function ui_push(s) stack[#stack + 1] = s end
function ui_pop() stack[#stack] = nil end
function ui_clear() stack = {} end
function ui_active() return #stack > 0 end

function ui_update()
  if dialog_active() then
    dialog_update()
    return
  end
  local top = stack[#stack]
  if top then top:update() end
end

function ui_draw()
  camera()
  for _, s in ipairs(stack) do s:draw() end
end

-- ============================================================
-- 背包
-- ============================================================

BAG = BAG or {}   -- BAG.potion = 3（W49 存檔時一起存）

function bag_add(key, n)
  BAG[key] = (BAG[key] or 0) + n
  if BAG[key] <= 0 then BAG[key] = nil end
end

-- 背包裡有的道具，依 sort 排好；where = "field"／"battle"：只列出那裡能用的
local function bag_list(where)
  local keys = {}
  for key, n in pairs(BAG) do
    local it = DATA.items[key]
    if n > 0 and it and it[where] then keys[#keys + 1] = key end
  end
  table.sort(keys, function(a, b) return DATA.items[a].sort < DATA.items[b].sort end)
  return keys
end

-- 這個道具能不能給這隻野伴用（不能的話回傳原因）
local function item_target_ok(key, k)
  local it = DATA.items[key]
  if it.kind == "heal" then
    if k.hp <= 0 then return false, kin_name(k) .. "倒下了，用了也沒有效果。" end
    if k.hp >= kin_max_hp(k) then return false, kin_name(k) .. "的 HP 是滿的。" end
  end
  return true
end

-- 打開背包。where：在哪裡用；on_use(道具, 隊伍第幾隻)：決定要用了（數量由這裡扣）
-- opts.wild：戰鬥是不是野生戰（野伴球只能對野生的用）
function bag_open(where, on_use, opts)
  local keys = bag_list(where)
  if #keys == 0 then
    dialog_open("背包裡什麼都沒有。")
    return
  end
  local items = {}
  for i, key in ipairs(keys) do items[i] = DATA.items[key].name .. " ×" .. BAG[key] end
  local m = menu_new({ items = items, x = 0, y = 8 })
  m.x = 316 - m.w - (where == "field" and 66 or 0)   -- 在地圖上：放在 START 選單的左邊，兩個並排
  local screen = { menu = m }
  function screen.update(self)
    local r = menu_update(self.menu)
    if r == 0 then ui_pop() return end
    if not r then return end
    local key = keys[r]
    if DATA.items[key].kind == "ball" then
      -- 野伴球：不用選野伴，直接丟
      if not (opts and opts.wild) then
        dialog_open("不能搶別人的野伴！")
        return
      end
      bag_add(key, -1)
      ui_pop()
      on_use(key, nil)
      return
    end
    party_pick("要給哪一隻用？", function(i)
      local ok, why = item_target_ok(key, party[i])
      if not ok then
        dialog_open(why)
        return
      end
      bag_add(key, -1)
      ui_pop()   -- 選野伴
      ui_pop()   -- 背包
      on_use(key, i)
    end)
  end
  function screen.draw(self)
    menu_draw(self.menu)
    -- 下方：游標所在道具的說明
    ui_box(4, 184, 312, 52)
    local lines = {}
    for l in (DATA.items[keys[self.menu.index]].desc .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
    for i, l in ipairs(lines) do text(l, 14, 192 + (i - 1) * 16, 0) end
  end
  ui_push(screen)
end

-- ============================================================
-- 選一隻野伴（用道具、之後換人 W35）
-- ============================================================

local ROW = 30

local function mini_hp_bar(x, y, w, hp, max)
  rect(x, y, w, 5, 0)
  rect(x + 1, y + 1, w - 2, 3, 7)
  local fill = (w - 2) * hp // max
  if hp > 0 and fill == 0 then fill = 1 end
  local c = (hp * 5 <= max) and 8 or ((hp * 2 <= max) and 10 or 11)
  if fill > 0 then rect(x + 1, y + 1, fill, 3, c) end
end

-- prompt：下方的提示；on_pick(第幾隻)：選了；按 B 取消。on_pick 是 nil 時只看不選（START → 野伴）
function party_pick(prompt, on_pick)
  local screen = { index = 1 }
  function screen.update(self)
    if pressed_repeat(UP) then self.index = (self.index - 2) % #party + 1 end
    if pressed_repeat(DOWN) then self.index = self.index % #party + 1 end
    if pressed(B) then ui_pop() return end
    if pressed(A) and on_pick then on_pick(self.index) end
  end
  function screen.draw(self)
    local x, y, w = 8, 8, 200
    ui_box(x, y, w, 18 + #party * ROW - 6)
    for i, k in ipairs(party) do
      local ry = y + 9 + (i - 1) * ROW
      if i == self.index then ui_arrow_right(x + 8, ry + 4, 0) end
      text(kin_name(k), x + 20, ry, k.hp > 0 and 0 or 5)
      local lv = "Lv" .. k.level
      text(lv, x + w - 12 - textw(lv), ry, 0)
      mini_hp_bar(x + 20, ry + 16, 100, k.hp, kin_max_hp(k))
      local nums = k.hp .. "/" .. kin_max_hp(k)
      text(nums, x + w - 12 - textw(nums), ry + 12, 0)
    end
    ui_box(4, 184, 312, 52)
    text(prompt, 14, 192, 0)
  end
  ui_push(screen)
end

-- ============================================================
-- START 選單（地圖上）
-- ============================================================

function field_menu_open()
  local m = menu_new({ items = { "野伴", "背包", "關閉" }, x = 0, y = 8 })
  m.x = 316 - m.w
  local screen = { menu = m }
  function screen.update(self)
    local r = menu_update(self.menu)
    if r == 0 or r == 3 or pressed(START) then ui_pop()
    elseif r == 1 then party_pick("隊伍裡的野伴（按 B 回去）", nil)
    elseif r == 2 then
      bag_open("field", function(key, i)
        local k = party[i]
        local it = DATA.items[key]
        local heal = math.min(it.amount, kin_max_hp(k) - k.hp)
        k.hp = k.hp + heal
        dialog_open(kin_name(k) .. "回復了 " .. heal .. " 點 HP！")
      end)
    end
  end
  function screen.draw(self) menu_draw(self.menu) end
  ui_push(screen)
end
