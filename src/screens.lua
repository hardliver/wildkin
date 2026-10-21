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
-- where = "field"／"battle"：只列出那裡能用的；where = "material"：材料
local function bag_list(where)
  local keys = {}
  for key, n in pairs(BAG) do
    local it = DATA.items[key]
    local show = it and ((where == "material" and it.kind == "material") or (where ~= "material" and it[where]))
    if n > 0 and show then keys[#keys + 1] = key end
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
-- 在地圖上有兩個分頁：道具、材料（左右鍵切換）；戰鬥中只有道具
function bag_open(where, on_use, opts)
  local tabs = { { name = "道具", keys = bag_list(where) } }
  if where == "field" then tabs[2] = { name = "材料", keys = bag_list("material") } end
  local empty = true
  for _, t in ipairs(tabs) do if #t.keys > 0 then empty = false end end
  if empty then
    dialog_open("背包裡什麼都沒有。")
    return
  end
  local screen = { tab = (#tabs[1].keys == 0) and 2 or 1 }
  -- 換分頁時重做選單（項目、寬度都不一樣）
  function screen.build(self)
    local keys = tabs[self.tab].keys
    local items = {}
    for i, key in ipairs(keys) do items[i] = DATA.items[key].name .. " ×" .. BAG[key] end
    if #items == 0 then items[1] = "（沒有東西）" end
    local m = menu_new({ items = items, x = 0, y = 24 })
    m.x = 316 - m.w - (where == "field" and 66 or 0)   -- 在地圖上：放在 START 選單的左邊，兩個並排
    self.menu, self.keys = m, keys
  end
  screen:build()
  function screen.update(self)
    if #tabs > 1 and (pressed(L) or pressed(R)) then   -- L、R 切換分頁（鍵盤 Q、E）
      self.tab = 3 - self.tab
      self:build()
      return
    end
    local r = menu_update(self.menu)
    if r == 0 then ui_pop() return end
    if not r then return end
    local key = self.keys[r]
    if not key then return end
    local it = DATA.items[key]
    if it.kind == "material" then
      dialog_open("做東西用的材料。在營地的工作台使用。")
      return
    end
    if it.kind == "ball" then
      -- 野伴球：不用選野伴，直接丟
      if where ~= "battle" then
        dialog_open("在戰鬥中對野生的野伴丟。")
        return
      end
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
    -- 分頁標籤（在選單上面，靠右對齊選單）：[L] 道具 材料 [R]
    local m = self.menu
    local function keycap(x, label)
      rect(x, 10, 11, 12, 0)
      rect(x + 1, 11, 9, 10, 6)
      text(label, x + 3, 9, 0)
    end
    local widths, total = {}, 0
    for i, t in ipairs(tabs) do widths[i] = textw(t.name) + 12; total = total + widths[i] + 2 end
    local caps = (#tabs > 1) and 13 or 0
    local x = m.x + m.w - total - caps * 2 + 2
    if caps > 0 then keycap(x, "L"); x = x + caps end
    for i, t in ipairs(tabs) do
      rect(x, 8, widths[i], 16, i == self.tab and 0 or 5)
      text(t.name, x + 6, 9, 7)
      x = x + widths[i] + 2
    end
    if caps > 0 then keycap(x, "R") end
    menu_draw(m)
    -- 下方：游標所在道具的說明
    ui_box(4, 184, 312, 52)
    local key = self.keys[m.index]
    if key then
      local lines = {}
      for l in (DATA.items[key].desc .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
      for i, l in ipairs(lines) do text(l, 14, 192 + (i - 1) * 16, 0) end
    end
  end
  ui_push(screen)
end

-- ============================================================
-- 選一隻野伴（用道具、之後換人 W35）
-- ============================================================

local ROW = 30
STATUS_NAME = { burn = "灼傷", paralyze = "麻痺", sleep = "睡眠" }
STATUS_COLOR = { burn = 8, paralyze = 10, sleep = 13 }

local function mini_hp_bar(x, y, w, hp, max)
  rect(x, y, w, 5, 0)
  rect(x + 1, y + 1, w - 2, 3, 7)
  local fill = (w - 2) * hp // max
  if hp > 0 and fill == 0 then fill = 1 end
  local c = (hp * 5 <= max) and 8 or ((hp * 2 <= max) and 10 or 11)
  if fill > 0 then rect(x + 1, y + 1, fill, 3, c) end
end

-- prompt：下方的提示；on_pick(第幾隻, 這個畫面)：選了；按 B 取消。
-- on_pick 是 nil 時只看不選。opts.forced：不能按 B 取消（戰鬥中倒下，一定要選下一隻）
-- 回傳這個畫面（呼叫的人可以改 prompt、mark）
function party_pick(prompt, on_pick, opts)
  local screen = { index = 1, prompt = prompt, mark = nil }
  function screen.update(self)
    if pressed_repeat(UP) then self.index = (self.index - 2) % #party + 1 end
    if pressed_repeat(DOWN) then self.index = self.index % #party + 1 end
    if pressed(B) and not (opts and opts.forced) then ui_pop() return end
    if pressed(A) and on_pick then on_pick(self.index, self) end
  end
  function screen.draw(self)
    local x, y, w = 8, 8, 200
    ui_box(x, y, w, 18 + #party * ROW - 6)
    for i, k in ipairs(party) do
      local ry = y + 9 + (i - 1) * ROW
      if i == self.mark then rect(x + 4, ry - 2, w - 8, ROW - 2, 6) end   -- 換順序：先選的那一隻底色變灰
      if i == self.index then ui_arrow_right(x + 8, ry + 4, 0) end
      text(kin_name(k), x + 20, ry, k.hp > 0 and 0 or 5)
      -- 狀態：倒下／灼傷／麻痺／睡眠（戰鬥結束後狀態還在，要回復才會好，和 GB 一樣）
      local tag, c = nil, nil
      if k.hp <= 0 then tag, c = "倒下", 5
      elseif k.status then tag, c = STATUS_NAME[k.status], STATUS_COLOR[k.status] end
      if tag then
        local tx = x + 24 + textw(kin_name(k))
        rect(tx - 2, ry + 1, textw(tag) + 4, 13, c)
        text(tag, tx, ry, 7)
      end
      local lv = "Lv" .. k.level
      text(lv, x + w - 12 - textw(lv), ry, 0)
      mini_hp_bar(x + 20, ry + 16, 100, k.hp, kin_max_hp(k))
      local nums = k.hp .. "/" .. kin_max_hp(k)
      text(nums, x + w - 12 - textw(nums), ry + 12, 0)
    end
    ui_box(4, 184, 312, 52)
    text(self.prompt, 14, 192, 0)
  end
  ui_push(screen)
  return screen
end

-- 小選單（選了野伴之後跳出來的「能力／換順序／取消」）：選了呼叫 on_choose(第幾項)，按 B 或最後一項是取消
local function small_menu(items, on_choose)
  local m = menu_new({ items = items, x = 0, y = 0 })
  m.x, m.y = 316 - m.w, 180 - m.h
  local screen = { menu = m }
  function screen.update(self)
    local r = menu_update(self.menu)
    if r == 0 or r == #items then ui_pop()
    elseif r then on_choose(r) end
  end
  function screen.draw(self) menu_draw(self.menu) end
  ui_push(screen)
end

-- ============================================================
-- 能力（一隻野伴的詳細資料）
-- ============================================================

-- 依寬度把一段文字切成好幾行（一個字一個字量）
function wrap_text(s, width)
  local lines, cur = {}, ""
  for _, c in utf8.codes(s) do
    local ch = utf8.char(c)
    if ch == "\n" then
      lines[#lines + 1] = cur; cur = ""
    elseif textw(cur .. ch) > width then
      lines[#lines + 1] = cur; cur = ch
    else
      cur = cur .. ch
    end
  end
  if cur ~= "" then lines[#lines + 1] = cur end
  return lines
end

local TYPE_COLOR = { normal = 13, grass = 11, fire = 9, water = 12, electric = 10, rock = 4 }

function summary_open(index)
  local screen = { index = index }
  function screen.update(self)
    if pressed(A) or pressed(B) then ui_pop() return end
    if pressed_repeat(UP) then self.index = (self.index - 2) % #party + 1 end      -- 上下：看前一隻、下一隻
    if pressed_repeat(DOWN) then self.index = self.index % #party + 1 end
  end
  function screen.draw(self)
    local k = party[self.index]
    local sp = kin_species(k)
    ui_box(4, 4, 312, 232)
    -- 左上：正面圖、名字、等級、屬性
    rect(14, 14, 68, 68, 6)
    spr(IMG.kin_front, sp.sprite, 16, 16)
    text(sp.name, 92, 14, 0)
    text("Lv" .. k.level, 92, 32, 0)
    local tname = DATA.types.names[sp.type]
    rect(92, 51, textw(tname) + 8, 15, TYPE_COLOR[sp.type] or 13)
    text(tname, 96, 51, 7)
    if k.status then
      text(STATUS_NAME[k.status], 92 + textw(tname) + 16, 51, STATUS_COLOR[k.status])
    end
    -- 右上：能力
    local x = 200
    local function row(label, v, y) text(label, x, y, 0); text(v, 304 - textw(v), y, 0) end
    row("HP", k.hp .. "/" .. kin_max_hp(k), 14)
    row("攻擊", tostring(kin_stat(k, "atk")), 30)
    row("防禦", tostring(kin_stat(k, "def")), 46)
    row("速度", tostring(kin_stat(k, "spd")), 62)
    local need = (k.level < 50) and tostring(kin_exp_for(k.level + 1) - k.exp) or "—"
    row("下一級還要", need, 82)
    -- 工作特性
    local works = {}
    for w, lv in pairs(sp.work or {}) do works[#works + 1] = DATA.work[w] .. " " .. lv end
    table.sort(works)
    text("工作：" .. table.concat(works, "、"), 14, 100, 0)
    -- 招式
    rect(10, 120, 300, 1, 5)
    for i, m in ipairs(k.moves) do
      local d = DATA.moves[m.key]
      local y = 126 + (i - 1) * 18
      text(d.name, 14, y, 0)
      local tn = DATA.types.names[d.type]
      rect(90, y + 1, textw(tn) + 6, 14, TYPE_COLOR[d.type] or 13)
      text(tn, 93, y, 7)
      local pp = "次數 " .. m.pp .. "/" .. d.pp
      text(pp, 304 - textw(pp), y, m.pp > 0 and 0 or 8)
    end
    -- 最下面：說明（太長自動換行）
    rect(10, 198, 300, 1, 5)
    for i, l in ipairs(wrap_text(sp.desc, 290)) do
      if i <= 2 then text(l, 14, 202 + (i - 1) * 16, 5) end
    end
  end
  ui_push(screen)
end

-- ============================================================
-- 隊伍（地圖上：能力、換順序；戰鬥中：換上場、能力）
-- ============================================================

-- on_switch(第幾隻)：戰鬥中選了「換上場」；active = 現在在場上的是第幾隻
function party_open(where, on_switch, active)
  if #party == 0 then
    dialog_open("還沒有野伴。")
    return
  end
  local base = (where == "battle") and "要換哪一隻上場？" or "要看哪一隻？"
  party_pick(base, function(i, picker)
    -- 換順序的第二步：選要和誰交換
    if picker.mark then
      party[picker.mark], party[i] = party[i], party[picker.mark]
      picker.mark, picker.prompt = nil, base
      return
    end
    if where == "battle" then
      small_menu({ "換上場", "能力", "取消" }, function(r)
        if r == 2 then summary_open(i) return end
        local k = party[i]
        if i == active then dialog_open(kin_name(k) .. "已經在場上了！") return end
        if k.hp <= 0 then dialog_open(kin_name(k) .. "已經倒下了，不能戰鬥！") return end
        ui_clear()
        on_switch(i)
      end)
    else
      small_menu({ "能力", "換順序", "取消" }, function(r)
        if r == 1 then summary_open(i) return end
        ui_pop()   -- 小選單
        picker.mark, picker.prompt = i, "要和哪一隻交換順序？"
      end)
    end
  end)
end

-- ============================================================
-- 野伴手冊（W39）
-- ============================================================
-- DEX.seen[編號] = true：遇過（看過樣子）；DEX.caught[編號] = true：抓過（隊伍裡有過）
-- 遇過的看得到樣子和名字；抓過的才看得到屬性和說明（GB 的做法）

DEX = DEX or { seen = {}, caught = {} }

function dex_seen(no) DEX.seen[no] = true end
function dex_caught(no) DEX.seen[no] = true; DEX.caught[no] = true end

local function dex_numbers()
  local list = {}
  for no in pairs(DATA.species) do list[#list + 1] = no end
  table.sort(list)
  return list
end

local function dex_count()
  local seen, caught = 0, 0
  for no in pairs(DATA.species) do
    if DEX.seen[no] then seen = seen + 1 end
    if DEX.caught[no] then caught = caught + 1 end
  end
  return seen, caught
end

local function dex_detail(nos, index)
  local screen = { index = index }
  function screen.update(self)
    if pressed(A) or pressed(B) then ui_pop() return end
    if pressed_repeat(UP) then self.index = (self.index - 2) % #nos + 1 end
    if pressed_repeat(DOWN) then self.index = self.index % #nos + 1 end
  end
  function screen.draw(self)
    local no = nos[self.index]
    local sp = DATA.species[no]
    ui_box(4, 4, 312, 232)
    rect(14, 14, 68, 68, 6)
    if DEX.seen[no] then spr(IMG.kin_front, sp.sprite, 16, 16) end
    text("No." .. no, 92, 14, 0)
    text(DEX.seen[no] and sp.name or "？？？", 92, 32, 0)
    if DEX.caught[no] then
      local tname = DATA.types.names[sp.type]
      rect(92, 51, textw(tname) + 8, 15, TYPE_COLOR[sp.type] or 13)
      text(tname, 96, 51, 7)
      local works = {}
      for w, lv in pairs(sp.work or {}) do works[#works + 1] = DATA.work[w] .. " " .. lv end
      table.sort(works)
      text("工作：" .. table.concat(works, "、"), 14, 96, 0)
      rect(10, 118, 300, 1, 5)
      for i, l in ipairs(wrap_text(sp.desc, 290)) do text(l, 14, 124 + (i - 1) * 16, 0) end
    elseif DEX.seen[no] then
      text("還沒抓到過。抓到之後才會知道更多。", 14, 96, 5)
    end
  end
  ui_push(screen)
end

function dex_open()
  local nos = dex_numbers()
  local screen = { index = 1, top = 1 }
  local ROWS = 9
  function screen.update(self)
    if pressed(B) then ui_pop() return end
    if pressed_repeat(UP) then self.index = math.max(self.index - 1, 1) end
    if pressed_repeat(DOWN) then self.index = math.min(self.index + 1, #nos) end
    if self.index < self.top then self.top = self.index end
    if self.index >= self.top + ROWS then self.top = self.index - ROWS + 1 end
    if pressed(A) and DEX.seen[nos[self.index]] then dex_detail(nos, self.index) end
  end
  function screen.draw(self)
    local x, y, w = 60, 4, 200
    ui_box(x, y, w, 232)
    local seen, caught = dex_count()
    text("野伴手冊", x + 12, y + 8, 0)
    local c = "遇過 " .. seen .. "　抓過 " .. caught
    text(c, x + w - 12 - textw(c), y + 8, 5)
    rect(x + 8, y + 26, w - 16, 1, 5)
    for r = 0, ROWS - 1 do
      local i = self.top + r
      local no = nos[i]
      if not no then break end
      local ry = y + 32 + r * 21
      if i == self.index then ui_arrow_right(x + 10, ry + 4, 0) end
      if DEX.caught[no] then fx_disc(x + 24, ry + 7, 3, 9) end   -- 抓過：橘色圓點
      text(no, x + 32, ry, 0)
      text(DEX.seen[no] and DATA.species[no].name or "？？？", x + 58, ry, DEX.seen[no] and 0 or 5)
    end
  end
  ui_push(screen)
end

-- ============================================================
-- 錢（W55）
-- ============================================================

MONEY = MONEY or 0   -- 手上的錢（元）；W49 存檔一起存

-- 「1,250 元」
function money_text(n)
  local s = tostring(n)
  while true do
    local t = s:gsub("^(%d+)(%d%d%d)", "%1,%2")
    if t == s then break end
    s = t
  end
  return s .. " 元"
end

-- 右上角的小框：「錢　1,250 元」
function money_box_draw(y)
  local s = money_text(MONEY)
  local w = textw("錢") + textw(s) + 32
  ui_box(4, y or 8, w, 30)
  text("錢", 14, (y or 8) + 7, 5)
  text(s, w - 6 - textw(s), (y or 8) + 7, 0)
end

-- ============================================================
-- 選數量（製作、商店共用）
-- ============================================================
-- title：「要做幾次？」；most：最多幾個；line(n)：選 n 個時下面那一行的說明（「用掉：木材 4」）；
-- label(n)：中間大字（「野伴球 × 3」）；on_done(n)：按 A。按 B 取消
function amount_pick(title, most, label, line, on_done, verb)
  local screen = { n = 1 }
  function screen.update(self)
    if pressed_repeat(RIGHT) then self.n = self.n % most + 1 end
    if pressed_repeat(LEFT) then self.n = (self.n - 2) % most + 1 end
    if pressed_repeat(UP) then self.n = math.min(most, self.n + 10) end
    if pressed_repeat(DOWN) then self.n = math.max(1, self.n - 10) end
    if pressed(B) then ui_pop() return end
    if pressed(A) then
      ui_pop()
      on_done(self.n)
    end
  end
  function screen.draw(self)
    ui_box(4, 128, 312, 108)
    text(title, 14, 138, 0)
    local s = label(self.n)
    local w = textw(s)
    local cx = 160
    text(s, cx - w // 2, 162, 0)
    ui_arrow_right(cx + w // 2 + 8, 165, 0)
    for i = 0, 3 do rect(cx - w // 2 - 12 + i, 168 - i, 1, 1 + i * 2, 0) end   -- 往左的小三角形
    text(line(self.n), 14, 190, 5)
    text("左右 ±1　上下 ±10（最多 " .. most .. "）　A " .. (verb or "確定"), 14, 212, 5)
  end
  ui_push(screen)
end

-- ============================================================
-- START 選單（地圖上）
-- ============================================================

function field_menu_open()
  local m = menu_new({ items = { "野伴", "背包", "手冊", "任務", "存檔", "關閉" }, x = 0, y = 8 })
  m.x = 316 - m.w
  local screen = { menu = m }
  function screen.update(self)
    local r = menu_update(self.menu)
    if r == 0 or r == 6 or pressed(START) then ui_pop()
    elseif r == 3 then dex_open()
    elseif r == 4 then quest_open()
    elseif r == 5 then
      dialog_ask("要存檔嗎？\n（存在欄位 " .. SAVE_SLOT .. "，之前的進度會被蓋掉）", { "存檔", "不要" }, function(c)
        if c ~= 1 then return end
        game_save()
        dialog_open(PLAYER_NAME .. "把今天的事寫進了筆記本。\n存好了！")
      end)
    elseif r == 1 then party_open("field")
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
  function screen.draw(self)
    money_box_draw(8)   -- 左上角：手上的錢（後面打開的畫面會蓋在上面）
    menu_draw(self.menu)
  end
  ui_push(screen)
end
