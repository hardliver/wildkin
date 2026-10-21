-- clock_test.lua：遊戲時鐘（W64c）的測試：時段、季節、每小時產出加起來等於一天的產量、半夜吃飼料

do
  assert(time_period(4 * 60 + 59) == "night" and time_period(5 * 60) == "morning", "05:00 開始是早上")
  assert(time_period(12 * 60) == "day" and time_period(19 * 60) == "evening" and time_period(21 * 60) == "night", "時段的交界")
  assert(season(1) == "spring" and season(7) == "spring" and season(8) == "summer" and season(29) == "spring", "7 天一季、28 天一年")
  assert(clock_text(6 * 60 + 5) == "06:05", "時間的寫法")

  -- 囤囤鼠（伐木 1）在伐木場：吃飽一天 = 木材 2 × (1 × 2) // 2 = 2
  local saved = { BAG, FACILITY, GATHERED, DAY, TIME, TIME_SUB }
  BAG, FACILITY, GATHERED, DAY, TIME, TIME_SUB = { feed = 1 }, {}, {}, 1, 0, 0
  FACILITY["camp:1:1"] = { kind = "lumber", workers = { kin_new("07", 5) } }
  clock_add_minutes(24 * 60)          -- 00:00 走到隔天 00:00
  assert(DAY == 2 and TIME == 0, "走 24 小時換一天")
  assert(BAG.wood == 2, "一整天的產出 = 舊的一天公式（木材 2），得到 " .. tostring(BAG.wood))
  assert((BAG.feed or 0) == 0, "半夜吃掉 1 份飼料（這是第 2 天的飯）")
  clock_add_minutes(24 * 60)          -- 第 2 天吃飽 → 木材 +2；第 3 天開始時飼料沒了
  assert(DAY == 3 and BAG.wood == 4, "第 2 天吃飽，得到 " .. tostring(BAG.wood))
  assert(FACILITY["camp:1:1"].workers[1].hungry, "沒吃到飼料會記下來")
  clock_add_minutes(24 * 60)          -- 第 3 天餓著 → 只有一半
  assert(BAG.wood == 5, "餓著的那一天只有一半（木材 +1），得到 " .. tostring(BAG.wood))
  TIME = 22 * 60
  assert(minutes_until(6) == 8 * 60, "22:00 睡到 06:00 是 8 小時")
  local r, g, b = tint_at(23 * 60)
  assert(r < 200 and b > r, "晚上變暗偏藍")
  r = tint_at(15 * 60)
  assert(r == 256, "白天原色")
  BAG, FACILITY, GATHERED, DAY, TIME, TIME_SUB = saved[1], saved[2], saved[3], saved[4], saved[5], saved[6]
  -- 季節的換色（W64d）：春天不換；秋、冬有換到草和樹的綠色；換成的都是已經有的顏色
  assert(season_map("spring") == nil, "春天是原色")
  for _, sname in ipairs({ "summer", "autumn", "winter" }) do
    local n = 0
    for _ in pairs(season_map(sname)) do n = n + 1 end
    assert(n >= 3, sname .. " 至少換 3 個綠色")
  end
  print("ok: 遊戲時鐘")
end
