-- debug.lua：開發用的除錯工具（W51）
--
-- Comet Studio 的「狀態」分頁會讀這兩個表格（說明見 comet 的 AI_GUIDE「除錯」）：
--   DEBUG_VIEW：要顯示的值（算式字串），每半秒更新，可以點開、點值直接改
--   DEBUG_COMMANDS：快捷按鈕 { 按鈕上的字, 要執行的 Lua }
-- 玩家玩的時候用不到；放在遊戲裡也不會有任何影響（遊戲本身不會呼叫這些函式）。
-- 指令列也可以直接打：dbg_warp("route1", 9, 20)、dbg_kin("09", 12)、BAG.ball = 30

DEBUG_VIEW = {
  "SAVE_SLOT", "DAY", "world.name", "{ player_cell() }",
  "BAG", "party", "RANCH", "FACILITY", "FLAGS", "DEX.caught", "GATHERED",
}

DEBUG_COMMANDS = {
  { "新遊戲（跳過標題）", "dbg_new()" },
  { "材料各 20", "dbg_give('material', 20)" },
  { "道具各 10", "dbg_give('item', 10)" },
  { "隊伍回復", "for _, k in ipairs(party) do kin_heal(k) end" },
  { "過一天", "dbg_next_day()" },
  { "Lv10 囤囤鼠", "dbg_kin('07', 10)" },
  { "→ 營地", "dbg_warp('camp', 19, 15)" },
  { "→ 草原小徑", "dbg_warp('route1', 9, 3)" },
  { "→ 苔石村", "dbg_warp('village', 19, 3)" },
  { "清除旗標", "FLAGS = {}" },
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
