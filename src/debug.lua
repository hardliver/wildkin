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
  { "材料各 20", "dbg_give('material', 20)" },
  { "道具各 10", "dbg_give('item', 10)" },
  { "錢 +10000", "MONEY = MONEY + 10000" },
  { "隊伍回復", "for _, k in ipairs(party) do kin_heal(k) end" },
  { "睡到明天早上", "dbg_next_day()" },
  { "時間 +3 小時", "clock_add_minutes(180)" },
  { "跳到晚上 21:00", "clock_add_minutes(minutes_until(21))" },
  { "跳到下一季", "for _ = 1, 7 do clock_add_minutes(24 * 60) end" },
  { "Lv10 囤囤鼠", "dbg_kin('07', 10)" },
  { "→ 營地", "dbg_warp('camp', 19, 15)" },
  { "→ 草原小徑", "dbg_warp('route1', 9, 3)" },
  { "→ 苔石村", "dbg_warp('village', 19, 3)" },
  { "清除旗標", "FLAGS = {}" },
  { "下一隻野生是異色", "DEBUG_NEXT_SHINY = true" },
}

-- 還在標題畫面：直接開一局新遊戲（存在欄位 1），不用一直按
local function ensure_game()
  if title_active() then dbg_new() end
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
  { name = "第 1、2 章平衡表", fields = {}, run = chapter1_table },
}
