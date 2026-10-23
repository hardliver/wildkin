-- debug.lua：開發用的除錯工具（W51）
--
-- Comet Studio 的「狀態」分頁會讀這兩個表格（說明見 comet 的 AI_GUIDE「除錯」）：
--   DEBUG_VIEW：要顯示的值（算式字串），每半秒更新，可以點開、點值直接改
--   DEBUG_COMMANDS：快捷按鈕 { 按鈕上的字, 要執行的 Lua }
-- 玩家玩的時候用不到；放在遊戲裡也不會有任何影響（遊戲本身不會呼叫這些函式）。
-- 指令列也可以直接打：dbg_warp("route1", 9, 20)、dbg_kin("09", 12)、BAG.ball = 30

DEBUG_VIEW = {
  "SAVE_SLOT", "clock_long_text()", "MONEY", "world.name", "{ player_cell() }",
  "BAG", "party", "RANCH", "FACILITY", "FLAGS", "DEX.caught", "GATHERED",
}

DEBUG_COMMANDS = {
  { "新遊戲（跳過標題）", "dbg_new()" },
  { "跳到第 1 章開頭（苔石村）", "dbg_chapter(1)" },
  { "跳到第 2 章開頭（舊礦坑前）", "dbg_chapter(2)" },
  { "跳到第 3 章開頭（港灣鎮的木筏）", "dbg_chapter(3)" },
  { "跳到終章開頭（火山洞的貨梯）", "dbg_chapter(4)" },
  { "跳到終章（下）（社長室的後門）", "dbg_chapter(5)" },
  { "材料各 20", "dbg_give('material', 20)" },
  { "道具各 10", "dbg_give('item', 10)" },
  { "錢 +10000", "MONEY = MONEY + 10000" },
  { "隊伍回復", "for _, k in ipairs(party) do kin_heal(k) end" },
  { "睡到明天早上", "dbg_next_day()" },
  { "時間 +3 小時", "clock_add_minutes(180)" },
  { "跳到晚上 21:00", "clock_add_minutes(minutes_until(21))" },
  { "跳到下一季", "for _ = 1, 7 do clock_add_minutes(24 * 60) end" },
  { "現實時鐘：假裝離開 3 小時", "dbg_away(180)" },
  { "現實時鐘：假裝離開 3 天", "dbg_away(3 * 24 * 60)" },
  { "Lv10 囤囤鼠", "dbg_kin('07', 10)" },
  { "→ 營地", "dbg_warp('camp', 19, 15)" },
  { "→ 草原小徑", "dbg_warp('route1', 9, 3)" },
  { "→ 苔石村", "dbg_warp('village', 19, 3)" },
  { "清除旗標", "FLAGS = {}" },
  { "下一隻野生是異色", "DEBUG_NEXT_SHINY = true" },
  { "天氣：下雨", "DEBUG_WEATHER = 'rain'" },
  { "天氣：雷雨", "DEBUG_WEATHER = 'storm'" },
  { "天氣：晴天", "DEBUG_WEATHER = 'sunny'" },
  { "天氣：起霧", "DEBUG_WEATHER = 'fog'" },
  { "天氣：下雪", "DEBUG_WEATHER = 'snow'" },
  { "天氣：照常", "DEBUG_WEATHER = nil" },
}

-- 還在標題畫面：直接開一局新遊戲（存在欄位 1），不用一直按
local function ensure_game()
  if title_active() then dbg_new() end
end

-- 現實時鐘模式：假裝上次對時是 minutes 分鐘前，像讀檔一樣補算（W64e）。遊戲時鐘模式先換成現實時鐘
function dbg_away(minutes)
  ensure_game()
  if CLOCK_MODE ~= "real" and not clock_mode_set("real") then
    dialog_open("讀不到現實的時間（Mac 版要加 --clock now）。")
    return
  end
  REAL_LAST = REAL_LAST - minutes
  dialog_open(away_settle() or "（沒什麼變化）")
end

-- 新遊戲，跳過序章開頭（取名、選初始、老苔給東西）：直接拿芽角羊 Lv5、野伴球 5、回復藥 2
function dbg_new()
  title_close()
  ui_clear()
  new_game(1)
  cutscene_skip()
  cutscene_blackout(false)
  party[1] = kin_new("01", 5)
  dex_caught("01")
  BAG.ball, BAG.potion = 5, 2
  FLAGS.arrived, FLAGS.starter, FLAGS.got_balls = true, true, true
  FLAGS.scene_camp_exit = true
end

-- 跳到第 n 章的開頭（測試用，不用每次從序章玩起）：前面章節的旗標、徽記、營火都設好，
-- 隊伍是那一章的推薦等級，然後傳送到那一章的起點。選哪一隻初始野伴：starter（"01"／"03"／"05"，預設芽角羊）
local CH_FLAGS = {
  [1] = { "arrived", "starter", "got_balls", "scene_camp_exit", "first_wild", "first_catch", "tutorial_base", "tutorial_sleep", "bike",
          "slept", "tip_heal", "trainer_rival1", "ch1" },
  [2] = { "inn_first", "heard_forest", "cut:village:38:14", "cut:village:38:15", "saw_ironwheel", "scene_c1_ironwheel",
          "moth_rescued", "scene_c1_moth", "trainer_rival2", "badge_forest", "ch1_done", "fire:village", "fire:forest" },
  [3] = { "ch2", "mine_entered", "scene_c2_foreman", "mine_dark", "scene_c2_dark", "mine_rock1", "cut:mine:16:14", "cut:mine:16:15",
          "mine_kin_seen", "scene_c2_carts", "trainer_exec1", "scene_c2_exec", "mine_done", "harbor", "scene_c2_harbor",
          "saw_office", "harbor_inn", "trainer_rival3", "badge_rock", "ch2_done", "fire:mine", "fire:harbor" },
  [5] = { "final", "scene_e0_lift", "factory", "scene_e1_clock", "line_wood", "line_ore", "line_light",
          "trainer_factory_wood", "trainer_factory_ore", "trainer_factory_light", "exec1_quit", "exec2_sleep", "scene_e4_sleep",
          "elevator", "boss", "trainer_boss", "scene_e6_boss", "factory_done", "fire:factory" },
  [4] = { "ch3", "coast_hut", "saw_ship", "scene_c3_ship", "trainer_coast1", "trainer_coast2", "trainer_coast3", "volcano",
          "trainer_exec2", "scene_c3_exec", "badge_fire", "ch3_done", "fire:coast", "fire:volcano" },
}
local CH_PARTY = {      -- 第一隻是初始野伴（等級到了會用進化後的樣子）
  [1] = { 9, { "07", 7 } },
  [2] = { 15, { "11", 13 }, { "07", 13 } },
  [3] = { 21, { "11", 19 }, { "12", 19 }, { "13", 19 } },
  [4] = { 29, { "13", 27 }, { "12", 27 }, { "10", 27 }, { "14", 27 } },   -- 燈蛾：社長室的電梯要發電
  [5] = { 34, { "13", 32 }, { "12", 32 }, { "10", 32 }, { "14", 32 } },
}
local CH_START = { [1] = { "village", 19, 3 }, [2] = { "village", 2, 14 }, [3] = { "harbor", 9, 19 }, [4] = { "volcano", 16, 13 }, [5] = { "office", 16, 2 } }

function dbg_chapter(n, starter)
  dbg_new()
  starter = starter or "01"
  FLAGS.starter_no = starter
  for c = 1, n do
    for _, f in ipairs(CH_FLAGS[c]) do FLAGS[f] = true end
  end
  local p = CH_PARTY[n]
  local no = starter
  local ev = DATA.species[no].evolve
  if ev and p[1] >= ev.level then no = ev.to end
  party = { kin_new(no, p[1]) }
  dex_caught(starter)
  for i = 2, #p do
    party[i] = kin_new(p[i][1], p[i][2])
    dex_caught(p[i][1])
  end
  BAG.ball, BAG.goodball, BAG.potion, BAG.superpotion, BAG.feed = 10, (n >= 2) and 5 or nil, 5, (n >= 2) and 3 or nil, 10
  if n >= 4 then BAG.fineball = 10 end   -- 精製球（第 3 章焰之徽記之後才做得出來）
  MONEY = 3000 + n * 3000
  DAY = 1 + (n - 1) * 3
  local s = CH_START[n]
  warp(s[1], s[2], s[3])
end

-- 背包加東西。kind = "material"（材料）／"item"（材料以外的道具）
function dbg_give(kind, n)
  ensure_game()
  for key, it in pairs(DATA.items) do
    if (kind == "material") == (it.kind == "material") then bag_add(key, n) end
  end
end

-- 加一隻野伴：隊伍有空位放隊伍，滿了放牧場
function dbg_kin(no, level)
  ensure_game()
  local k = kin_new(no, level or 5)
  dex_caught(no)
  return send_home(k)
end

-- 傳送到某張地圖的第 (cx, cy) 格（面向下）
function dbg_warp(name, cx, cy)
  ensure_game()
  ui_clear()
  warp(name, cx, cy)
end

-- ============================================================
-- 工具（Studio 狀態分頁的「工具」：欄位填一填按「執行」，結果顯示在下面）
-- ============================================================
-- 每個工具：name、fields（{ 欄位名, 標題, "choice"／"int", 預設值, 選項 }）、run(填好的值) → 文字

local function species_options()
  local nos = {}
  for no in pairs(DATA.species) do nos[#nos + 1] = no end
  table.sort(nos)
  local opts = {}
  for i, no in ipairs(nos) do opts[i] = { no, no .. " " .. DATA.species[no].name } end
  return opts
end

-- 第 1 章的平衡表：每一行是一個情況，跑 300 場
local function chapter1_table()
  local N = 300
  local rows = {
    { "草原小徑野生：芽角羊 Lv5 vs 囤囤鼠 Lv3", { { "01", 5 } }, { { "07", 3 } }, true },
    { "草原小徑野生：炭毛狸 Lv5 vs 哨哨雀 Lv4", { { "03", 5 } }, { { "08", 4 } }, true },
    { "霧林野生：芽角羊 Lv10 vs 燈蛾 Lv10", { { "01", 10 } }, { { "10", 10 } }, true },
    { "霧林野生：鬚鬚鯰 Lv10 vs 菇菇蟹 Lv10", { { "05", 10 } }, { { "09", 10 } }, true },
    { "霧林野生：鬚鬚鯰 Lv10 vs 搧火蝠 Lv10", { { "05", 10 } }, { { "11", 10 } }, true },
  }
  local rival = { ["01"] = "03", ["03"] = "05", ["05"] = "01" }      -- 阿穗用剋制主角的那隻
  -- 主角在霧林多抓的那一隻（W65d：御三家野外抓不到）：草、水的玩家帶搧火蝠（火，剋柏伯的草），火的玩家帶燈蛾
  local mate = { ["01"] = "11", ["03"] = "10", ["05"] = "11" }
  for _, st in ipairs({ "01", "03", "05" }) do
    local n = DATA.species[st].name
    rows[#rows + 1] = { "阿穗第 1 戰：" .. n .. " Lv7 vs Lv6", { { st, 7 } }, { { rival[st], 6 } }, false }
    rows[#rows + 1] = { "阿穗第 1 戰：" .. n .. " Lv6＋囤囤鼠 Lv3 vs Lv6", { { st, 6 }, { "07", 3 } }, { { rival[st], 6 } }, false }
  end
  local keeper = {}
  for i, p in ipairs(DATA.trainers.forest_keeper.party) do keeper[i] = { p.species, p.level } end
  for _, st in ipairs({ "01", "03", "05" }) do
    for _, lv in ipairs({ 12, 13, 14 }) do
      rows[#rows + 1] = { "柏伯：" .. DATA.species[st].name .. " Lv" .. lv .. "＋" .. DATA.species[mate[st]].name .. "、囤囤鼠 Lv" .. (lv - 2),
                          { { st, lv }, { mate[st], lv - 2 }, { "07", lv - 2 } }, keeper, false }
    end
  end
  -- 第 2 章：高處長（W67）。隊伍：初始＋搧火蝠、礫殼犰狳（低 2 級）
  local exec = {}
  for i, p in ipairs(DATA.trainers.exec1.party) do exec[i] = { p.species, p.level } end
  for _, st in ipairs({ "01", "03", "05" }) do
    for _, lv in ipairs({ 15, 17 }) do
      rows[#rows + 1] = { "高處長：" .. DATA.species[st].name .. " Lv" .. lv .. "＋搧火蝠、礫殼犰狳 Lv" .. (lv - 2),
                          { { st, lv }, { "11", lv - 2 }, { "12", lv - 2 } }, exec, false }
    end
  end
  -- 第 2 章：阿穗第 3 戰、礁嬤（W68）。主角是進化後的樣子；草、水帶搧火蝠，火帶霧傘水母
  local EVO = { ["01"] = "02", ["03"] = "04", ["05"] = "06" }
  local mate2 = { ["01"] = "11", ["03"] = "13", ["05"] = "11" }
  for _, st in ipairs({ "01", "03", "05" }) do
    local foe = {}
    for i, p in ipairs(DATA.trainers.rival3.party) do foe[i] = { p.species == "rival" and rival[st] or p.species, p.level } end
    rows[#rows + 1] = { "阿穗第 3 戰：" .. DATA.species[EVO[st]].name .. " Lv17＋" .. DATA.species[mate2[st]].name .. "、礫殼犰狳 Lv15",
                        { { EVO[st], 17 }, { mate2[st], 15 }, { "12", 15 } }, foe, false }
    local keeper2 = {}
    for i, p in ipairs(DATA.trainers.rock_keeper.party) do keeper2[i] = { p.species, p.level } end
    local third = (st == "03") and "09" or "13"
    rows[#rows + 1] = { "礁嬤：" .. DATA.species[EVO[st]].name .. " Lv20＋" .. DATA.species[mate2[st]].name .. "、" .. DATA.species[third].name .. " Lv18",
                        { { EVO[st], 20 }, { mate2[st], 18 }, { third, 18 } }, keeper2, false }
  end
  -- 第 3 章：范經理、炭爺（W70）。隊伍：進化後的初始＋霧傘水母、礫殼犰狳、搧火蝠（低 2 級）
  for _, t in ipairs({ { "exec2", "范經理", 24 }, { "fire_keeper", "炭爺", 27 } }) do
    local foe3 = {}
    for i, p in ipairs(DATA.trainers[t[1]].party) do foe3[i] = { p.species, p.level } end
    for _, st in ipairs({ "01", "03", "05" }) do
      local lv = t[3]
      rows[#rows + 1] = { t[2] .. "：" .. DATA.species[EVO[st]].name .. " Lv" .. lv .. "＋霧傘水母、礫殼犰狳、搧火蝠 Lv" .. (lv - 2),
                          { { EVO[st], lv }, { "13", lv - 2 }, { "12", lv - 2 }, { "11", lv - 2 } }, foe3, false }
    end
  end
  -- 終章：工廠的工人、社長（W73）。隊伍：進化後的初始＋霧傘水母、礫殼犰狳、燈蛾（低 2 級；燈蛾是電梯要的）
  for _, t in ipairs({ { "factory_wood", "阿德", 28 }, { "factory_ore", "品管小姐", 28 }, { "factory_light", "保全大哥", 28 },
                       { "boss", "社長", 30 }, { "boss", "社長", 32 } }) do
    local foe4 = {}
    for i, p in ipairs(DATA.trainers[t[1]].party) do foe4[i] = { p.species, p.level } end
    for _, st in ipairs({ "01", "03", "05" }) do
      local lv = t[3]
      rows[#rows + 1] = { t[2] .. "：" .. DATA.species[EVO[st]].name .. " Lv" .. lv .. "＋霧傘水母、礫殼犰狳、燈蛾 Lv" .. (lv - 2),
                          { { EVO[st], lv }, { "13", lv - 2 }, { "12", lv - 2 }, { "10", lv - 2 } }, foe4, false }
    end
  end
  -- 終章（下）：阿穗第 4 戰、雲根（W74）。隊伍：草、水帶搧火蝠，火帶霧傘水母；加礫殼犰狳、燈蛾（低 2 級）
  for _, st in ipairs({ "01", "03", "05" }) do
    local mate = (st == "03") and "13" or "11"
    local foe5 = {}
    for i, p in ipairs(DATA.trainers.rival4.party) do
      local no = p.species
      if no == "rival" then no = rival[st] end     -- 阿穗用剋制主角初始的那一隻
      local ev = DATA.species[no].evolve
      if ev and p.level >= ev.level then no = ev.to end
      foe5[i] = { no, p.level }
    end
    for _, lv in ipairs({ 34, 36 }) do
      local me = { { EVO[st], lv }, { mate, lv - 2 }, { "12", lv - 2 }, { "10", lv - 2 } }
      rows[#rows + 1] = { "阿穗第 4 戰：" .. DATA.species[EVO[st]].name .. " Lv" .. lv .. "＋" .. DATA.species[mate].name .. "、礫殼犰狳、燈蛾 Lv" .. (lv - 2), me, foe5, false }
      rows[#rows + 1] = { "雲根 Lv" .. CLOUDROOT_LEVEL .. "（野生）：同上", me, { { "16", CLOUDROOT_LEVEL } }, true }
    end
  end
  -- 破關後：守護者再戰（W75）。帶對屬性的隊伍：柏伯→火（爐背牛、搧火蝠）、礁嬤→水草（霧傘水母、菇菇蟹）、炭爺→水岩
  local prep = { forest_keeper2 = { "14", "11", "12" }, rock_keeper2 = { "13", "09", "15" }, fire_keeper2 = { "13", "12", "15" } }
  for _, key in ipairs({ "forest_keeper2", "rock_keeper2", "fire_keeper2" }) do
    local foe6 = {}
    for i, p in ipairs(DATA.trainers[key].party) do foe6[i] = { p.species, p.level } end
    local m = prep[key]
    for _, st in ipairs({ "01", "03", "05" }) do
      local me = { { EVO[st], 44 }, { m[1], 42 }, { m[2], 42 }, { m[3], 42 } }
      rows[#rows + 1] = { DATA.trainers[key].name .. "再戰：" .. DATA.species[EVO[st]].name .. " Lv44＋" .. DATA.species[m[1]].name .. "、" ..
                          DATA.species[m[2]].name .. "、" .. DATA.species[m[3]].name .. " Lv42", me, foe6, false }
    end
  end
  local out = {}
  for _, r in ipairs(rows) do
    out[#out + 1] = r[1]
    out[#out + 1] = "  " .. sim_battles_text(r[2], r[3], r[4], N)
  end
  return table.concat(out, "\n")
end

DEBUG_TOOLS = {
  { name = "戰鬥試算", fields = {
      { "me", "我方", "choice", "01", species_options },
      { "me_lv", "等級", "int", 10 },
      { "foe", "對手", "choice", "07", species_options },
      { "foe_lv", "等級", "int", 8 },
      { "n", "自動對戰幾場", "int", 1000 },
    },
    run = function(a)
      return sim_damage_text(a.me, a.me_lv, a.foe, a.foe_lv) .. "\n\n自動對戰 " .. a.n .. " 場（我方選最好的招，對手是訓練家）：\n" ..
             sim_battles_text({ { a.me, a.me_lv } }, { { a.foe, a.foe_lv } }, false, a.n)
    end },
  { name = "第 1 章～終章平衡表", fields = {}, run = chapter1_table },
}
