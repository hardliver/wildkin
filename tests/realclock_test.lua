-- realclock_test.lua：現實時鐘模式（W64e）的測試。引擎的 clock() 換成假的，想要幾點就幾點

do
  local engine_clock = clock
  local fake = nil
  clock = function() return fake end

  -- 用年月日時分做一個假的 clock() 結果（time：1970 年起的秒數）
  local function is_leap(y) return y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0) end
  local MDAYS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  local function at(y, mo, d, h, mi)
    local days = 0
    for yy = 1970, y - 1 do days = days + (is_leap(yy) and 366 or 365) end
    for m = 1, mo - 1 do days = days + MDAYS[m] + ((m == 2 and is_leap(y)) and 1 or 0) end
    days = days + d - 1
    return { year = y, month = mo, day = d, hour = h, min = mi, sec = 0, wday = (days + 4) % 7,
             time = days * 86400 + h * 3600 + mi * 60 }
  end

  local saved = { BAG, FACILITY, GATHERED, DAY, TIME, TIME_SUB, CLOCK_MODE, REAL_LAST, REAL_MONTH, SLEEP_DEBT, STIFF, LAST_FEED, party }
  party = {}   -- 設施工作的經驗要看隊伍（W71g）
  BAG, FACILITY, GATHERED, DAY, TIME, TIME_SUB = { feed = 10 }, {}, {}, 3, 8 * 60, 0
  CLOCK_MODE, REAL_LAST, REAL_MONTH, SLEEP_DEBT, STIFF = "game", nil, nil, 0, 0
  -- 囤囤鼠（伐木 1）在伐木場：吃飽一天木材 2（每小時累積，滿了才給）
  FACILITY["camp:1:1"] = { kind = "lumber", workers = { kin_new("07", 5) } }

  -- 1. 沒有時間來源：換不了現實時鐘
  assert(clock_mode_set("real") == false and CLOCK_MODE == "game", "讀不到時間就不能換成現實時鐘")

  -- 2. 換成現實時鐘：時間跳到現實的 14:05，季節看月份（10 月 = 秋）；換過來的這一刻不補產出
  fake = at(2026, 10, 22, 14, 5)
  assert(clock_mode_set("real") and CLOCK_MODE == "real", "換成現實時鐘")
  assert(TIME == 14 * 60 + 5 and DAY == 3, "時間對齊現實，天數不變：" .. clock_text())
  assert(season() == "autumn", "10 月是秋天")
  assert(BAG.wood == nil, "換模式不補產出")
  SEASON_NEWS = nil

  -- 3. 離開 12 小時（到隔天 02:05）：半夜換日、吃飼料，12 小時的產出（一天 2 個的一半 = 1 個）；沒玩的時候算在睡覺
  SLEEP_DEBT = 10 * 60
  fake = at(2026, 10, 23, 2, 5)
  local report = away_settle()
  assert(DAY == 4 and TIME == 2 * 60 + 5, "換了一天，時間 02:05：第 " .. DAY .. " 天 " .. clock_text())
  assert(BAG.wood == 1, "12 小時的產出 = 木材 1，得到 " .. tostring(BAG.wood))
  assert(BAG.feed == 9, "半夜吃掉 1 份飼料")
  assert(SLEEP_DEBT == 0, "沒玩的 12 小時算在睡覺，睡眠債還清")
  assert(report and report:find("離開了 12 小時", 1, true), "報告離開多久：" .. tostring(report))

  -- 4. 離開 5 天：只補算 24 小時（木材 +2），但天數照走 5 天
  fake = at(2026, 10, 28, 2, 5)
  report = away_settle()
  assert(DAY == 9 and TIME == 2 * 60 + 5, "天數走 5 天：第 " .. DAY .. " 天 " .. clock_text())
  assert(BAG.wood == 3, "最多補算 24 小時（木材 +2），得到 " .. tostring(BAG.wood))
  assert(BAG.feed == 8, "只結算 24 小時：只吃 1 份飼料，剩 " .. tostring(BAG.feed))
  assert(report:find("離開了 5 天", 1, true) and report:find("最多只算 24 小時", 1, true), "報告超過上限：" .. report)

  -- 5. 時鐘往回調一天：不產出，時間跟著現實；再調回來也不會重複算（REAL_LAST 不倒退）
  local last = REAL_LAST
  fake = at(2026, 10, 27, 5, 0)
  realclock_sync(false)
  assert(TIME == 5 * 60 and REAL_LAST == last and BAG.wood == 3, "往回調：時間對齊，不產出")
  fake = at(2026, 10, 28, 3, 5)
  local gap = realclock_sync(false)
  assert(gap == 60, "調回來只算比原本多出來的 1 小時，算了 " .. tostring(gap) .. " 分鐘")

  -- 6. 地圖上每秒對一次時；離開不到 1 小時、也沒發生什麼，讀檔時不報告
  fake = at(2026, 10, 28, 3, 20)
  for _ = 1, FRAMES_PER_MINUTE do clock_update() end
  assert(TIME == 3 * 60 + 20, "clock_update 每秒對時：" .. clock_text())
  fake = at(2026, 10, 28, 3, 30)
  assert(away_settle() == nil, "離開 10 分鐘不報告")

  -- 7. 季節照月份；換月換季會提示
  SEASON_NEWS = nil
  fake = at(2026, 12, 1, 0, 0)
  realclock_sync(false)
  assert(season() == "winter" and SEASON_NEWS == "winter", "12 月是冬天，而且會提示換季")
  SEASON_NEWS = nil

  -- 8. 對時途中讀不到時間（例如主機的 RTC 沒電）：照遊戲時鐘走，60 幀 = 1 分鐘
  fake = nil
  local t0 = TIME
  for _ = 1, FRAMES_PER_MINUTE do clock_update() end
  assert(TIME == (t0 + 1) % (24 * 60), "讀不到時間時照遊戲時鐘走")

  -- 9. 換回遊戲時鐘：時間接著走，季節回到看天數
  assert(clock_mode_set("game") and CLOCK_MODE == "game", "換回遊戲時鐘")
  assert(season() == season(DAY), "遊戲時鐘的季節看天數")
  assert(duration_text(90) == "1 小時 30 分鐘" and duration_text(24 * 60 + 120) == "1 天 2 小時" and duration_text(5) == "5 分鐘", "時間長度的寫法")

  BAG, FACILITY, GATHERED, DAY, TIME, TIME_SUB, CLOCK_MODE, REAL_LAST, REAL_MONTH, SLEEP_DEBT, STIFF, LAST_FEED, party = table.unpack(saved, 1, 13)
  SEASON_NEWS = nil
  clock = engine_clock
  print("ok: 現實時鐘")
end
