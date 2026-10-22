-- sleep.lua：大志的睡眠（W71h，2026-10-22 Neil）
--
-- 不是「每次一定要睡滿幾小時」，而是「醒著多久，就要睡多久來補」：
--   ‧ 醒著每 1 分鐘，睡眠債 SLEEP_DEBT +1；睡覺每 1 分鐘 −2（醒著 16 小時，睡 8 小時剛好補完）
--   ‧ 睡眠債 6 小時以內：精神飽滿；6～16 小時：普通；16 小時以上：好睏
-- 落枕：每次睡 2 小時以上，有機會落枕（睡袋 15%、別人家的被子 10%、旅店的床 5%），
--   落枕之後 24 小時（遊戲時間）才會好；已經落枕的不會再落枕
-- 影響：大志自己做的事——丟球的手感（捕獲率）。精神飽滿 ×1.2、好睏 ×0.85、落枕再 ×0.85
-- 存檔：SLEEP_DEBT、STIFF（落枕還剩幾分鐘）

SLEEP_DEBT = SLEEP_DEBT or 0
STIFF = STIFF or 0
local sleeping = false

local FRESH, TIRED = 6 * 60, 16 * 60
local STIFF_TIME = 24 * 60
local STIFF_ODDS = { tent = 15, home = 10, bed = 5 }

-- clock.lua 的 clock_add_minutes 每過 1 分鐘呼叫
function sleep_minute()
  if sleeping then SLEEP_DEBT = math.max(0, SLEEP_DEBT - 2) else SLEEP_DEBT = SLEEP_DEBT + 1 end
  if STIFF > 0 then STIFF = STIFF - 1 end
end

-- 開始睡、睡醒（day.lua 的 sleep_hours 前後呼叫）；回傳醒來要說的話
function sleep_begin() sleeping = true end
function sleep_end(hours, bed)
  sleeping = false
  local lines = {}
  local got_stiff = false
  if hours >= 2 and STIFF == 0 and rnd(100) < (STIFF_ODDS[bed or "tent"] or 15) then
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
