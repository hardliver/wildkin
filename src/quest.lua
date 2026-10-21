-- quest.lua：任務日誌（W59）
--
-- 按 Select（鍵盤 Tab）打開，或 START 選單的「任務」。
-- 任務照順序列在 QUESTS：done(旗標) 為真就算完成；第一個還沒完成的就是「現在該做的事」，下面附提示。
-- 全部由劇情旗標算出來，不另外存東西（存檔裡已經有 FLAGS）。

local function cut(map, x, y) return FLAGS["cut:" .. map .. ":" .. x .. ":" .. y] end
local function any_worker()
  for _, fac in pairs(FACILITY) do
    if #fac.workers > 0 then return true end
  end
  return false
end

QUESTS = {
  { chapter = "序章", title = "選一隻初始野伴", done = function() return FLAGS.starter end,
    hint = "到老苔的小屋前面。" },
  { chapter = "序章", title = "出發去草原小徑", done = function() return FLAGS.got_balls end,
    hint = "營地南邊的出口。" },
  { chapter = "序章", title = "抓一隻野伴", done = function() return FLAGS.first_catch end,
    hint = "在草叢裡遇到野伴，先把牠打弱一點，\n再從背包丟野伴球。" },
  { chapter = "序章", title = "在營地蓋一個設施", done = function() return next(FACILITY) ~= nil end,
    hint = "營地東邊柵欄裡的空地，面對它按 A。\n木材不夠的話，野外的木頭可以撿。" },
  { chapter = "序章", title = "派野伴工作，睡一覺", done = function() return (FLAGS.slept or DAY > 1) and any_worker() end,
    hint = "面對設施選「派駐」，\n再到老苔小屋左邊的帳篷睡覺（晚上睡到天亮，白天小睡）。" },
  { chapter = "序章", title = "前往苔石村", done = function() return FLAGS.ch1 end,
    hint = "穿過草原小徑一直往南。\n路口好像有人在等你。" },
  { chapter = "第 1 章", title = "打通往霧林的路", done = function() return cut("village", 38, 14) end,
    hint = "苔石村東口的倒木，要找會伐木的野伴。\n派在營地工作的也算。" },
  { chapter = "第 1 章", title = "找到森之守", done = function() return FLAGS.badge_forest end,
    hint = "穿過霧林，到最東邊的森之祠。推薦等級 Lv12～14。\n柏伯的野伴大多是草屬性，帶一隻火屬性的會輕鬆很多。\n（霧林傍晚、晚上常有搧火蝠出沒。）" },
  { chapter = "第 1 章", title = "回苔石村", done = function() return FLAGS.ch1_done end,
    hint = "把霧林的事告訴村民。" },
  { chapter = "第 2 章", title = "去舊礦坑", done = function() return FLAGS.mine_entered end,
    hint = "苔石村的西口，鐵輪公司的柵欄打開了。" },
  { chapter = "第 2 章", title = "穿過礦坑深處", done = function() return FLAGS.mine_rock1 end,
    hint = "暗的地方：有會發電的野伴（燈蛾）就會亮。\n落石：要找會採礦的野伴，礦坑口右下的碎石洞裡有。" },
  { chapter = "第 2 章", title = "找到鐵輪公司的負責人", done = function() return FLAGS.trainer_exec1 end,
    hint = "礦坑最深處，西邊的大廳。推薦等級 Lv15～17。\n礫殼犰狳怕水和草。" },
  { chapter = "第 2 章", title = "到港灣鎮", done = function() return FLAGS.harbor end,
    hint = "舊礦坑西邊的鐵門，高處長走的時候沒關。" },
  { chapter = "第 2 章", title = "找到岩之守", done = function() return FLAGS.badge_rock end,
    hint = "港灣鎮西邊，防波堤盡頭的燈塔。推薦等級 Lv19～21。\n礁嬤的野伴大多是岩屬性：水和草最有效，火很吃力。\n（碼頭的淺灘有霧傘水母，霧林有菇菇蟹。）" },
  { chapter = "第 2 章", title = "在營地蓋爐", done = function() for _, f in pairs(FACILITY) do if f.kind == "furnace" then return true end end return false end,
    hint = "營地的空地，選「爐」。石頭 15、木材 5。\n派會生火的野伴（搧火蝠、炭毛狸）把礦石燒成金屬。" },
  { chapter = "第 3 章", title = "渡海到海岸", done = function() return FLAGS.ch3 end,
    hint = "港灣鎮西邊的海邊有木筏。\n要有會灌溉的野伴拖（霧傘水母、鬚鬚鯰）。" },
  { chapter = "第 3 章", title = "往火山洞", done = function() return FLAGS.volcano end,
    hint = "沿著海岸一直往西。推薦等級 Lv20～23。\n漁村的阿婆可以讓你休息。" },

}

local function current()
  for i, q in ipairs(QUESTS) do
    if not q.done() then return i end
  end
  return nil
end

function quest_open()
  local screen = {}
  function screen.update(self)
    if pressed(A) or pressed(B) or pressed(SELECT) or pressed(START) then ui_pop() end
  end
  function screen.draw(self)
    ui_box(4, 4, 312, 232)
    local cur = current()
    local chap = cur and QUESTS[cur].chapter or "第 2 章"
    text("任務日誌", 16, 14, 0)
    text(chap, 304 - textw(chap), 14, 5)
    rect(12, 32, 296, 1, 6)
    -- 現在該做的事
    if cur then
      local q = QUESTS[cur]
      rect(12, 40, 296, 70, 6)
      ui_arrow_right(18, 49, 8)
      text(q.title, 28, 45, 0)
      local y = 67
      for line in (q.hint .. "\n"):gmatch("(.-)\n") do
        text(line, 28, y, 5)
        y = y + 16
      end
    else
      rect(12, 40, 296, 70, 6)
      text("第 1 章完成了！", 28, 45, 0)
      text("第 2 章，敬請期待。", 28, 67, 5)
    end
    -- 做完的：最近 6 個，打勾
    text("做完的事", 16, 118, 5)
    local last = (cur or #QUESTS + 1) - 1
    local first = math.max(1, last - 5)
    local y = 138
    for i = last, first, -1 do
      local q = QUESTS[i]
      rect(18, y + 4, 8, 8, 11)      -- 綠色方塊打勾
      rect(20, y + 7, 2, 2, 7); rect(22, y + 9, 1, 1, 7); rect(23, y + 5, 2, 4, 7)
      text(q.title, 32, y, 0)
      y = y + 16
    end
    if last == 0 then text("（還沒有）", 32, 138, 5) end
  end
  ui_push(screen)
end
