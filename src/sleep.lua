-- sleep.lua：大志的睡眠（W71h，2026-10-22 Neil）
--
-- 不是「每次一定要睡滿幾小時」，而是「醒著多久，就要睡多久來補」：
--   ‧ 醒著每 1 分鐘，睡眠債 SLEEP_DEBT +1；睡覺每 1 分鐘 −2（醒著 16 小時，睡 8 小時剛好補完）
--   ‧ 睡眠債 6 小時以內：精神飽滿；6～16 小時：普通；16 小時以上：好睏
-- 落枕：每次睡 2 小時以上，有機會落枕（睡袋 15%、別人家的被子 10%、旅店的床 5%），
--   落枕之後 24 小時（遊戲時間）才會好；已經落枕的不會再落枕
-- 影響：大志自己做的事——丟球的手感（捕獲率）。精神飽滿 ×1.2、好睏 ×0.85、落枕再 ×0.85
-- 存檔：SLEEP_DEBT、STIFF（落枕還剩幾分鐘）
--
-- 直銷說明會的商品（W75b，mlm.lua）也在這裡起作用（背包裡有就算）：
--   磁石負離子枕 pillow：不會落枕　　量子調頻床墊貼 patch：落枕好得快一倍
--   遠紅外線眼罩 mask：補眠 ×1.25　 深海褪黑素軟糖 gummy：睡前吃一顆，這次補眠 ×2（休息時自動吃）
--   磁力護腰 mlm_belt：捕獲率 +5%　 眼罩踩雷（FLAGS.mlm_mask_hot）：下一次睡醒反而更睏，只有那一次

SLEEP_DEBT = SLEEP_DEBT or 0
STIFF = STIFF or 0
local sleeping = false
local gummy_on = false    -- 這次睡前吃了軟糖
local sleep_minutes = 0   -- 這次睡了幾分鐘（眼罩的 ×1.25：每 4 分鐘多還 2）

local FRESH, TIRED = 6 * 60, 16 * 60
local STIFF_TIME = 24 * 60
local STIFF_ODDS = { tent = 15, home = 10, bed = 5 }

-- clock.lua 的 clock_add_minutes 每過 1 分鐘呼叫
function sleep_minute()
  if sleeping then
    -- 補眠：每分鐘還 2；吃了軟糖還 4；有眼罩的話每 4 分鐘再多還 2（整體 ×1.25，只用整數）
    local pay = gummy_on and 4 or 2
    sleep_minutes = sleep_minutes + 1
    if (BAG.mask or 0) > 0 and sleep_minutes % 4 == 0 then pay = pay + 2 end
    SLEEP_DEBT = math.max(0, SLEEP_DEBT - pay)
  else
    SLEEP_DEBT = SLEEP_DEBT + 1
  end
  if STIFF > 0 then STIFF = math.max(0, STIFF - (((BAG.patch or 0) > 0) and 2 or 1)) end
end

-- 開始睡、睡醒（day.lua 的 sleep_hours 前後呼叫）；回傳醒來要說的話
function sleep_begin() sleeping = true; sleep_minutes = 0 end

-- 上床前（day.lua 的 sleep_hours；沒玩的時候不算）：有褪黑素軟糖就吃一顆
function sleep_bedtime()
  if (BAG.gummy or 0) > 0 then
    bag_add("gummy", -1)
    gummy_on = true
  end
end
-- 只停止睡覺、不擲落枕也不說話（現實時鐘模式：沒玩的那段時間算在睡覺，clock.lua 的 realclock_sync）
function sleep_stop() sleeping = false end
function sleep_end(hours, bed)
  sleeping = false
  local lines = {}
  if gummy_on then lines[#lines + 1] = "（睡前吃了一顆深海褪黑素軟糖。）" end
  gummy_on = false
  if FLAGS.mlm_mask_hot then
    -- 眼罩踩雷：戴著睡了這一次，一直發熱，睡醒反而更睏（只有這一次，之後不戴了）
    FLAGS.mlm_mask_hot = nil
    SLEEP_DEBT = SLEEP_DEBT + 4 * 60
    lines[#lines + 1] = "（遠紅外線眼罩一直發熱……\n熱到睡不著。）\f" .. PLAYER_NAME .. "：……這個，還是不要戴了。"
  end
  local got_stiff = false
  local no_stiff = (BAG.pillow or 0) > 0          -- 磁石負離子枕：不會落枕
  if hours >= 2 and STIFF == 0 and not no_stiff and rnd(100) < (STIFF_ODDS[bed or "tent"] or 15) then
    STIFF = STIFF_TIME
    got_stiff = true
  end
  local s = sleep_state()
  if s == "fresh" then lines[#lines + 1] = "睡得很飽！今天精神很好。\n（丟野伴球的手感應該不錯。）"
  elseif s == "tired" then lines[#lines + 1] = "還是好睏……\n醒著太久，這樣根本補不回來。（丟球會失準）"
  else lines[#lines + 1] = "睡了一下，精神普普通通。" end
  if got_stiff then
    lines[#lines + 1] = "（脖子……轉不過去。落枕了。）\n大概要一天才會好。（丟球會失準）"
  end
  return table.concat(lines, "\f")
end

function sleep_state()
  if SLEEP_DEBT < FRESH then return "fresh" end
  if SLEEP_DEBT >= TIRED then return "tired" end
  return "normal"
end

-- 捕獲率的倍率（百分比）：battle_ui 開戰時傳給 battle_new
function sleep_catch_pct()
  local p = 100
  local s = sleep_state()
  if s == "fresh" then p = 120 elseif s == "tired" then p = 85 end
  if STIFF > 0 then p = p * 85 // 100 end
  if (BAG.mlm_belt or 0) > 0 then p = p * 105 // 100 end   -- 磁力護腰：腰不痠，球丟得比較準
  return p
end

-- 狀態的名字（時鐘框、選單用）
function sleep_status_text()
  local s = ({ fresh = "精神飽滿", normal = "普通", tired = "好睏" })[sleep_state()]
  if STIFF > 0 then s = s .. "・落枕" end
  return s
end

-- 丟球時大志說的（沒事就 nil）
function sleep_throw_text()
  if STIFF > 0 then return "（脖子好痛……瞄不太準。）" end
  if sleep_state() == "tired" then return "（好睏……眼睛有點花。）" end
  return nil
end

-- 好睏的時候走在路上，偶爾打個哈欠提醒一下（每個時段最多一次）
local yawn_key = nil
function sleep_check()
  if sleep_state() ~= "tired" or not FLAGS.starter then return end
  local key = DAY * 4 + (TIME // 360)
  if yawn_key == key then return end
  yawn_key = key
  dialog_open("（呼啊……好睏。\n該找個地方睡一下了。）")
end
