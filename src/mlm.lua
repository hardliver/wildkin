-- mlm.lua：支線「直銷說明會」（W75b；劇本見 docs/story.md「支線：直銷說明會」，2026-10-23 Neil 確認）
--
-- 美玲姊（阿穗老婆的朋友，人很好、真的相信自己賣的東西）在城鎮邀你去「健康分享說明會」：
--   ‧ 第 1 章結束 → 苔石村、到了港灣鎮 → 港灣鎮、第 3 章 → 海岸漁村、破關後 → 營地（四張地圖都放了她，NPC_HOURS 決定在哪一張）
--   ‧ 每 7 個遊戲日可以去一次；不去沒有任何損失
--   ‧ 當期商品 1000 元，當場拆開：一半中獎（價值約 2000）、一半踩雷 → 期望值大約打平
--
-- 不能重讀存檔刷結果：每一期中不中，用「說明會種子」和「第幾週」算 hash 決定（不是買的當下擲 rnd）。
--   種子在新遊戲時擲一次（main.lua 的 new_game），存在 FLAGS.mlm_seed，所以同一個存檔、同一週，讀幾次都一樣。
--   舊存檔沒有種子：用主角名字和初始野伴算一個（也是同一個存檔一定一樣）
--
-- 商品的效果在 sleep.lua（枕頭、眼罩、軟糖、床墊貼、護腰）、craft（鍋具的配方 unlock = mlm_pot）

TALK = TALK or {}
NPC_HOURS = NPC_HOURS or {}

local function P() return PLAYER_NAME end

MLM_PRICE = 1000

-- 美玲姊現在在哪張地圖（照劇情進度，只會在一張）
local function meiling_map()
  if FLAGS.credits then return "camp" end
  if FLAGS.ch3 then return "coast" end
  if FLAGS.harbor then return "harbor" end
  if FLAGS.ch1_done then return "village" end
  return nil
end
NPC_HOURS.meiling = function() return meiling_map() == world.name end

local function week() return (DAY - 1) // 7 end

-- 說明會種子：舊存檔沒有的話，用名字和初始野伴算（同一個存檔一定算出一樣的數字）
local function seed()
  if not FLAGS.mlm_seed then
    local h = 7
    for i = 1, #PLAYER_NAME do h = hash(h, PLAYER_NAME:byte(i)) end
    FLAGS.mlm_seed = hash(h, tonumber(FLAGS.starter_no or "1") or 1) % 65536
  end
  return FLAGS.mlm_seed
end

-- 這一期中不中（50%）。給測試用的名字：mlm_lucky
local function lucky(w) return hash(seed(), w, 75) % 100 < 50 end
mlm_lucky = lucky

-- ============================================================
-- 商品：介紹、中獎、踩雷。owned()：已經抽中、會一直有效的，不再出現
-- ============================================================
local PRODUCTS = {
  { name = "野伴營養粉（一大桶）", pitch = "野伴吃了毛色發亮，\n工作一整天都不累！",
    win = function() bag_add("feed", 200); say("……打開是真的飼料！\n得到了飼料 ×200！") end,
    lose = function()
      say("……是麵粉。")
      say(P() .. "拿來做了一個大饅頭。\n大家分著吃了。")
      for _, k in ipairs(party) do kin_heal(k) end
      say("隊伍的 HP 全部回復了。")
    end },
  { name = "量子能量水", pitch = "這是經過量子共振的水，\n喝了會變年輕！",
    win = function() say("……其實是火山的溫泉水。\n真的有用。"); give("goodpotion", 2) end,
    lose = function() say("……什麼都沒有。\n說明寫著：「喝了感覺有變年輕。」") end },
  { name = "磁力護腰", pitch = "腰挺直了，\n人生就挺直了！",
    owned = function() return BAG.mlm_belt end,
    win = function() bag_add("mlm_belt", 1); say("得到了磁力護腰！\n（腰不痠，丟野伴球比較準。）") end,
    lose = function() bag_add("plain_belt", 1); say("……是普通的腰帶。\n（但是有比較暖。）") end },
  { name = "多功能鍋具", pitch = "煎煮炒炸燉，\n一鍋搞定！",
    owned = function() return FLAGS.mlm_pot end,
    win = function()
      set_flag("mlm_pot")
      say("附了一張食譜！\n學會在工作台做「野伴燉菜」了！")
      say("（莓果 2、麥 1、菇 1 → 好傷藥）")
    end,
    lose = function() bag_add("broken_pot", 1); say("……把手掉了。") end },
  { name = "磁石負離子枕", pitch = "磁石加負離子，\n一覺到天亮！",
    owned = function() return BAG.pillow end,
    win = function() bag_add("pillow", 1); say("得到了磁石負離子枕！\n（帶著睡覺，就不會落枕。）") end,
    lose = function() say("……普通的枕頭。\n還是會落枕。（但是很軟。）") end },
  { name = "深海褪黑素軟糖（5 顆）", pitch = "深海萃取，\n睡前一顆，一覺好眠！",
    win = function() bag_add("gummy", 5); say("得到了深海褪黑素軟糖 ×5！\n（休息的時候會自動吃一顆。）") end,
    lose = function() bag_add("candy", 5); say("……就是軟糖。很好吃。\n得到了軟糖 ×5！") end },
  { name = "遠紅外線眼罩", pitch = "遠紅外線，\n深層放鬆！",
    owned = function() return BAG.mask end,
    win = function() bag_add("mask", 1); say("得到了遠紅外線眼罩！\n（戴著睡，補眠比較快。）") end,
    lose = function() set_flag("mlm_mask_hot"); say("……摸起來有點燙。\n（今天晚上戴戴看吧。）") end },
  { name = "量子調頻床墊貼", pitch = "量子會幫你調頻！",
    owned = function() return BAG.patch end,
    win = function() bag_add("patch", 1); say("得到了量子調頻床墊貼！\n（……落枕好像真的好得比較快。）") end,
    lose = function() say("說明寫著：「量子會幫你調頻。」\n……什麼都沒發生。") end },
}

-- 這一期的商品：照週數輪流，跳過已經抽中、一直有效的。全部都有了就 nil
local function product_of(w)
  for i = 0, #PRODUCTS - 1 do
    local p = PRODUCTS[(w + i) % #PRODUCTS + 1]
    if not (p.owned and p.owned()) then return p end
  end
  return nil
end

mlm_product = product_of   -- 給測試用

local WHISPERS = {   -- 每一期輪流（每句都包含「阿穗：（小聲）」，斷行照對話框的寬度）
  "阿穗：（小聲）我老婆上次買了一台按摩椅……\n現在拿來掛衣服。",
  "阿穗：（小聲）我岳母買了一整箱，\n說喝了會變年輕。\f阿穗：（小聲）……她今年生日，\n蠟燭還是插 70。",
  "阿穗：（小聲）不過美玲姊人真的很好。\n上次我小孩發燒，是她開車送去醫院的。",
  "阿穗：（小聲）你知道嗎，我也買過一個。\n……我不想說是什麼。",
}

-- ============================================================
-- 說明會
-- ============================================================
local function seminar(w, p)
  blackout(true)
  narrate("～　健康分享說明會　～")
  say("美玲姊：各位朋友！今天要介紹的，\n是我們這一期的明星商品——")
  say("美玲姊：「" .. p.name .. "」！\n" .. p.pitch)
  say("美玲姊：原價 3000，今天說明會特價，\n只要 1000！")
  say("（阿穗從後面的椅子探出頭來。）")
  say("阿穗：（小聲）……我老婆硬拉我來的。")
  say(WHISPERS[w % #WHISPERS + 1])
  set_flag("mlm_week", w)
  local c = ask("要買嗎？（有 " .. money_text(MONEY) .. "）", { "買一份（1000 元）", "我再想想" })
  if c == 1 and MONEY < MLM_PRICE then
    say("美玲姊：沒關係！下次再來！")
  elseif c == 1 then
    MONEY = MONEY - MLM_PRICE
    say(P() .. "打開了盒子……")
    if lucky(w) then
      p.win()
      say(P() .. "：……咦？好像真的不錯。")
      say("美玲姊：你看！我就說吧！\n" .. P() .. "你也覺得好用對不對？")
    else
      p.lose()
      say(P() .. "：…………嗯。\n（美玲姊人很好。真的。）")
      say("美玲姊：哎呀……可能是體質不一樣。\n下一期的一定適合你！")
    end
  else
    say("美玲姊：好喔！\n下次也歡迎來聽聽！")
  end
  blackout(false)
end

TALK.meiling = function()
  local w = week()
  cutscene_start(function()
    if not flag("mlm_met") then
      say("美玲姊：哎呀，你就是" .. P() .. "吧？\n阿穗他太太常常提到你！")
      say("美玲姊：我叫美玲，大家都叫我美玲姊。")
      say("美玲姊：一個人在島上拓荒，很辛苦吧？\n身體一定要顧。")
      say("美玲姊：我們這週有一場健康分享說明會，\n免費參加喔！")
      say("美玲姊：不買也沒關係！\n就是來聽聽，交個朋友。")
      say(P() .. "：（……「不買也沒關係」。\n這句話我聽過很多次。）")
      set_flag("mlm_met")
    end
    if FLAGS.credits and not FLAGS.mlm_catalog then
      say("美玲姊：聽說你 40 歲了？生日快樂！\n……這是我們的新產品型錄，送你。")
      bag_add("catalog", 1)
      say(P() .. "得到了「產品型錄」！")
      set_flag("mlm_catalog")
    end
    if FLAGS.mlm_week == w then
      say("美玲姊：下一期的說明會，下週見喔！\n我會幫你留位子！")
      return
    end
    local p = product_of(w)
    if not p then
      say("美玲姊：你什麼都有了耶！\n下一期的新產品，我再通知你！")
      return
    end
    if ask("美玲姊：這週的說明會，要來聽聽嗎？", { "去聽聽", "我再想想" }) ~= 1 then
      say("美玲姊：好喔！下週也有，隨時歡迎！")
      return
    end
    seminar(w, p)
  end)
end
