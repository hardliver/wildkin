-- mlm_test.lua：直銷說明會（W75b）的測試：結果固定（不能重讀刷）、期望值大約打平、商品輪流、睡眠商品的效果

do
  local saved = { FLAGS, BAG, SLEEP_DEBT, STIFF, party }
  FLAGS, BAG, party = { mlm_seed = 1234 }, {}, {}

  -- 1. 同一個種子、同一週：問幾次都一樣（讀檔重來也一樣）
  local first = {}
  for w = 0, 199 do first[w] = mlm_lucky(w) end
  for w = 0, 199 do assert(mlm_lucky(w) == first[w], "第 " .. w .. " 週的結果應該固定") end

  -- 2. 中獎率大約一半（200 週，40%～60%）
  local wins = 0
  for w = 0, 199 do if first[w] then wins = wins + 1 end end
  assert(wins >= 80 and wins <= 120, "中獎率應該大約 50%，得到 " .. wins .. "/200")

  -- 3. 舊存檔沒有種子：用名字和初始野伴算，算兩次一樣
  FLAGS = {}
  local a = mlm_lucky(3)
  local s1 = FLAGS.mlm_seed
  FLAGS = {}
  assert(mlm_lucky(3) == a and FLAGS.mlm_seed == s1, "舊存檔的種子要固定")

  -- 4. 商品照週數輪流；已經抽中、一直有效的跳過
  local n0 = mlm_product(2).name
  BAG.mlm_belt = 1                  -- 第 3 種（護腰）已經有了
  assert(mlm_product(2).name ~= "磁力護腰" and mlm_product(2).name == "多功能鍋具", "有護腰就跳到下一種，得到 " .. mlm_product(2).name)
  assert(n0 == "磁力護腰", "第 2 週（從 0 算）是第 3 種商品")

  -- 5. 睡眠商品：軟糖補眠 ×2、眼罩 ×1.25、枕頭不落枕、床墊貼落枕好得快
  local function slept(minutes)
    sleep_bedtime(); sleep_begin()
    for _ = 1, minutes do sleep_minute() end
    sleep_end(minutes // 60, "tent")
  end
  BAG = {}
  SLEEP_DEBT, STIFF = 1000, 0
  slept(60)
  assert(SLEEP_DEBT == 1000 - 120, "沒有商品：一小時還 120，剩 " .. SLEEP_DEBT)
  BAG.gummy = 1
  SLEEP_DEBT = 1000
  slept(60)
  assert(SLEEP_DEBT == 1000 - 240 and (BAG.gummy or 0) == 0, "吃了軟糖：一小時還 240、軟糖少一顆，剩 " .. SLEEP_DEBT)
  BAG = { mask = 1 }
  SLEEP_DEBT = 1000
  slept(60)
  assert(SLEEP_DEBT == 1000 - 150, "眼罩：一小時還 150（×1.25），剩 " .. SLEEP_DEBT)
  BAG = { patch = 1 }
  SLEEP_DEBT, STIFF = 0, 100
  sleep_begin(); for _ = 1, 30 do sleep_minute() end; sleep_stop()
  assert(STIFF == 40, "床墊貼：落枕每分鐘好 2，剩 " .. STIFF)
  BAG = { pillow = 1 }
  STIFF = 0
  for _ = 1, 50 do slept(180) end
  assert(STIFF == 0, "枕頭：怎麼睡都不會落枕")
  BAG = { mlm_belt = 1 }
  SLEEP_DEBT, STIFF = 8 * 60, 0
  assert(sleep_catch_pct() == 105, "護腰：捕獲率 +5%，得到 " .. sleep_catch_pct())

  FLAGS, BAG, SLEEP_DEBT, STIFF, party = saved[1], saved[2], saved[3], saved[4], saved[5]
  print("ok: 直銷說明會")
end
