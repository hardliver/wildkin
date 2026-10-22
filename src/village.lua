-- village.lua：苔石村的旅店、商店、招式回想（W55）
--
-- 旅店：住一晚免費，隊伍全部回復；第一次來會接到媽媽的傳音（docs/story.md 的 C1-1）
-- 商店：買（SHOP_STOCK 裡的東西，照 items.json 的 price）、賣（背包裡有價錢的東西，半價收）
-- 招式回想：選一隻野伴，列出牠「這個等級以前學得會、但現在不會」的招，免費想起來（滿 4 招要忘一招）

-- ============================================================
-- 旅店
-- ============================================================

-- 媽媽每章換一句（content.md 的笑話表）。第 1 章：
local MOM_CALL = {
  "媽媽：喂？{name}喔？到了沒？",
  "{name}：到了到了。",
  "媽媽：有沒有吃飯？",
  "{name}：有。",
  "媽媽：島上有沒有不錯的女生？",
  "{name}：……媽，我在拓荒。",
  "媽媽：阿穗的兒子都會叫阿嬤了。",
  "媽媽：好啦，不吵你，記得穿外套。",
}

-- 第 2 章（港灣旅店，W68）
local MOM_CALL2 = {
  "媽媽：喂？你到港灣鎮了喔？",
  "媽媽：那邊的魚很便宜，記得寄一點回來。",
  "媽媽：……還有，你表弟下個月要結婚了。",
  "{name}：……好。",
  "媽媽：他比你小 12 歲喔。",
  "{name}：媽，我知道。",
}

local function name_fmt(s) return (s:gsub("{name}", PLAYER_NAME)) end

-- 聽傳音石：港灣旅店是第 2 章的台詞，苔石旅店是第 1 章
local function mom_call(lines)
  cutscene_start(function()
    say("（傳音石亮了起來。）")
    for _, line in ipairs(lines or MOM_CALL) do say(name_fmt(line)) end
  end)
end

-- 住旅店：和帳篷一樣選睡幾個小時（day.lua 的 rest_open），時間會往前走
local function inn_stay(host)
  rest_open({ before = (host or "老闆娘") .. "：好好休息喔。", bed = "bed" })
end

TALK.village_innkeeper = function()
  if not FLAGS.inn_first then
    FLAGS.inn_first = true
    cutscene_start(function()
      say("老闆娘：歡迎來到苔石旅店。\n住一晚，野伴就能恢復精神。")
      say("老闆娘：……咦，你是" .. PLAYER_NAME .. "先生？\n剛好有你的傳音。")
      say("老闆娘：傳音石在那邊，\n拿起來就能說話了。")
      say("（傳音石是一顆會發光的石頭，\n島上的電話。）")
      for _, line in ipairs(MOM_CALL) do say(name_fmt(line)) end
    end)
    return
  end
  dialog_ask("老闆娘：歡迎來到苔石旅店。\n要休息嗎？不用錢喔。", { "休息", "聽傳音石", "不用了" }, function(c)
    if c == 1 then inn_stay()
    elseif c == 2 then mom_call()
    else dialog_open("老闆娘：路上小心。") end
  end)
end

-- 港灣旅店（W68）：和苔石旅店一樣，傳音石是媽媽第 2 章的台詞（story.md C2-9）
TALK.harbor_innkeeper = function()
  if not FLAGS.harbor_inn then
    FLAGS.harbor_inn = true
    cutscene_start(function()
      say("老闆：歡迎！苔石旅店的老闆娘說你會來，\n傳音石有你的訊息。")
      say("（傳音石亮了起來。）")
      for _, line in ipairs(MOM_CALL2) do say(name_fmt(line)) end
    end)
    return
  end
  dialog_ask("老闆：港灣旅店，休息不用錢。\n要休息嗎？", { "休息", "聽傳音石", "不用了" }, function(c)
    if c == 1 then inn_stay("老闆")
    elseif c == 2 then mom_call(MOM_CALL2)
    else dialog_open("老闆：出海小心。") end
  end)
end

-- ============================================================
-- 商店
-- ============================================================

SHOP_STOCK = { "ball", "potion", "superpotion", "feed" }   -- 苔石商店賣的東西
HARBOR_STOCK = { "ball", "goodball", "potion", "superpotion", "goodpotion", "feed" }   -- 港灣商店（W68）

local function sell_price(key) return (DATA.items[key].price or 0) // 2 end

local function shop_buy(stock)
  local items = {}
  for i, key in ipairs(stock) do
    local it = DATA.items[key]
    items[i] = it.name
  end
  items[#items + 1] = "取消"
  local m = menu_new({ items = items, x = 0, y = 44 })
  m.w = m.w + 80              -- 右邊留位置寫價錢
  m.x = 316 - m.w
  local screen = { menu = m }
  function screen.update(self)
    local r = menu_update(self.menu)
    if r == 0 or r == #items then ui_pop() return end
    if not r then return end
    local key = stock[r]
    local it = DATA.items[key]
    local most = math.min(99, MONEY // it.price)
    if most < 1 then
      dialog_open("錢不夠。")
      return
    end
    amount_pick("要買幾個？", most,
      function(n) return it.name .. " × " .. n end,
      function(n) return "共 " .. money_text(it.price * n) .. "（有 " .. money_text(MONEY) .. "）" end,
      function(n)
        MONEY = MONEY - it.price * n
        bag_add(key, n)
        dialog_open("謝謝光臨！\n" .. PLAYER_NAME .. "買了" .. it.name .. " ×" .. n .. "。")
      end, "買")
  end
  function screen.draw(self)
    money_box_draw(8)
    menu_draw(self.menu)
    -- 價錢：清單右邊
    for i, key in ipairs(stock) do
      local p = money_text(DATA.items[key].price)
      text(p, self.menu.x + self.menu.w - 12 - textw(p), self.menu.y + 9 + (i - 1) * 16, 0)
    end
    local key = stock[self.menu.index]
    ui_box(4, 184, 312, 52)
    if key then
      local lines = wrap_text(DATA.items[key].desc, 220)
      for i = 1, math.min(2, #lines) do text(lines[i], 14, 192 + (i - 1) * 16, 0) end
      local have = "背包裡有 " .. (BAG[key] or 0)
      text(have, 306 - textw(have), 192, 5)
    end
  end
  ui_push(screen)
end

local function shop_sell()
  local keys = {}
  for key, n in pairs(BAG) do
    if n > 0 and DATA.items[key] and sell_price(key) > 0 then keys[#keys + 1] = key end
  end
  if #keys == 0 then
    dialog_open("沒有可以賣的東西。")
    return
  end
  table.sort(keys, function(a, b) return DATA.items[a].sort < DATA.items[b].sort end)
  local screen = { index = 1 }
  local function rebuild(self)
    local items = {}
    for i, key in ipairs(keys) do items[i] = DATA.items[key].name .. " ×" .. BAG[key] end
    items[#items + 1] = "取消"
    self.menu = menu_new({ items = items, x = 0, y = 44, index = math.min(self.index, #items) })
    self.menu.w = self.menu.w + 80
    self.menu.x = 316 - self.menu.w
  end
  rebuild(screen)
  function screen.update(self)
    local r = menu_update(self.menu)
    self.index = self.menu.index
    if r == 0 or r == #keys + 1 then ui_pop() return end
    if not r then return end
    local key = keys[r]
    local it = DATA.items[key]
    amount_pick("要賣幾個？", BAG[key],
      function(n) return it.name .. " × " .. n end,
      function(n) return "可以拿到 " .. money_text(sell_price(key) * n) end,
      function(n)
        bag_add(key, -n)
        MONEY = MONEY + sell_price(key) * n
        dialog_open("好，" .. money_text(sell_price(key) * n) .. "給你。")
        if not BAG[key] then table.remove(keys, r) end
        if #keys == 0 then ui_pop() else rebuild(self) end
      end, "賣")
  end
  function screen.draw(self)
    money_box_draw(8)
    menu_draw(self.menu)
    for i, key in ipairs(keys) do
      local p = money_text(sell_price(key))
      text(p, self.menu.x + self.menu.w - 12 - textw(p), self.menu.y + 9 + (i - 1) * 16, 0)
    end
  end
  ui_push(screen)
end

-- 商店（苔石村、港灣鎮共用）：greeting = 老闆的第一句話，stock = 賣的東西
function shop_open(greeting, stock)
  dialog_ask(greeting .. "\n要買什麼？", { "買", "賣", "離開" }, function(c)
    if c == 1 then shop_buy(stock)
    elseif c == 2 then shop_sell()
    else dialog_open("老闆：歡迎再來！") end
  end)
end

TALK.village_shopkeeper = function()
  shop_open("老闆：這裡是苔石商店。", SHOP_STOCK)
end

-- ============================================================
-- 招式回想
-- ============================================================

-- 這隻野伴想得起來的招：種類的學招表裡、等級到了、現在不會的
local function recallable(k)
  local list, seen = {}, {}
  for _, m in ipairs(k.moves) do seen[m.key] = true end
  for _, entry in ipairs(kin_species(k).learn) do
    if entry[1] <= k.level and not seen[entry[2]] then
      seen[entry[2]] = true
      list[#list + 1] = entry[2]
    end
  end
  return list
end

-- 選要想起哪一招，滿 4 招再選要忘掉哪一招
local function recall_moves(k)
  local list = recallable(k)
  if #list == 0 then
    dialog_open("回想師：" .. kin_name(k) .. "現在沒有想不起來的招式。")
    return
  end
  local items = {}
  for i, key in ipairs(list) do items[i] = DATA.moves[key].name end
  items[#items + 1] = "取消"
  local m = menu_new({ items = items, x = 0, y = 8 })
  m.x = 316 - m.w
  local screen = { menu = m }
  function screen.update(self)
    local r = menu_update(self.menu)
    if r == 0 or r == #items then ui_pop() return end
    if not r then return end
    local key = list[r]
    local mv = DATA.moves[key]
    if #k.moves < 4 then
      ui_clear()
      k.moves[#k.moves + 1] = { key = key, pp = mv.pp }
      dialog_open(kin_name(k) .. "想起了" .. mv.name .. "！")
      return
    end
    -- 滿 4 招：選要忘掉的
    local forget = {}
    for i, old in ipairs(k.moves) do forget[i] = DATA.moves[old.key].name end
    forget[#forget + 1] = "不要了"
    local fm = menu_new({ items = forget, x = 0, y = 8 })
    fm.x = 316 - fm.w - self.menu.w - 4
    local fs = { menu = fm }
    function fs.update(me)
      local f = menu_update(me.menu)
      if f == 0 or f == #forget then ui_pop() return end
      if not f then return end
      local old = DATA.moves[k.moves[f].key].name
      ui_clear()
      kin_replace_move(k, f, key)
      dialog_open("1、2 的……砰！\n" .. kin_name(k) .. "忘掉了" .. old .. "，想起了" .. mv.name .. "！")
    end
    function fs.draw(me)
      menu_draw(me.menu)
      ui_box(4, 184, 312, 52)
      text("要忘掉哪一招？", 14, 192, 0)
    end
    ui_push(fs)
  end
  function screen.draw(self)
    menu_draw(self.menu)
    local key = list[self.menu.index]
    ui_box(4, 184, 312, 52)
    if key then
      local mv = DATA.moves[key]
      text(mv.name .. "　" .. DATA.types.names[mv.type] .. "　威力 " .. (mv.power > 0 and mv.power or "—") .. "　次數 " .. mv.pp, 14, 192, 0)
      text("要讓" .. kin_name(k) .. "想起哪一招？", 14, 210, 5)
    end
  end
  ui_push(screen)
end

TALK.village_recall = function()
  dialog_ask("回想師：我是招式回想師。\n野伴忘掉的招式，我都能幫牠想起來。\f不用錢。要試試看嗎？", { "好", "不用" }, function(c)
    if c ~= 1 then
      dialog_open("回想師：人老了也會忘東忘西，\n野伴也一樣。")
      return
    end
    party_pick("要幫哪一隻想起招式？", function(i) recall_moves(party[i]) end)
  end)
end
