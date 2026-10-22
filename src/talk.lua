-- talk.lua：NPC 說的話
--
-- 地圖上每個 NPC 有一個「對話編號」（talk），在這裡寫它要說什麼：
--   TALK.編號 = "一段話"                    最簡單：說完就結束
--   TALK.編號 = function(npc) ... end      要問問題、看劇情旗標、給道具時用函式
-- 文字裡 \n 換行、\f 換頁（見 dialog.lua）。
--
-- 為什麼對話不直接寫在地圖檔裡：對話之後會依劇情改變（W52 的劇情旗標），
-- 需要程式判斷；地圖只記「這個人是誰」，說什麼由這裡決定。
-- 告示牌只會說固定的話，所以直接寫在地圖物件的 text 裡。

TALK = TALK or {}   -- scenes.lua、village.lua 也會往裡面加

-- 老苔：新芽營地的管理員
-- 全滅後被送回營地時，老苔說的話
TALK.elder_rescue =
  "醒啦？你倒在草叢裡，是路過的旅人把你扛回來的。" ..
  "\f野伴我已經幫你照顧好了。\n倒是你，腰還好吧？" ..
  "\f到了這個年紀，出門前記得先暖身……\n還有，保險要保。" ..
  "\f下次野伴累了，就先回帳篷睡一下，\n別硬撐。我們都不年輕了。"

-- 老苔：看序章進度說下一步該做什麼；教學都做完之後隨機說一句（台詞見 docs/story.md）
local ELDER_IDLE = {
  "睡飽了嗎？我每天四點就醒了。",
  "野伴今天也很努力。",
  "營地熱鬧起來了，像以前一樣。",
}
TALK.elder = function()
  if not FLAGS.got_balls then
    dialog_open("老苔：草原小徑在營地的南邊。\n準備好就出發吧。")
  elseif not FLAGS.first_catch then
    dialog_open("老苔：在草叢裡遇到野伴，\n先打弱一點再丟野伴球。")
  elseif not FLAGS.tutorial_sleep then
    dialog_open("老苔：東邊柵欄裡面是設施空地。\n面對空地按 A，就能蓋設施。")
  elseif not FLAGS.bike then
    cutscene_start(bike_gift)   -- 舊存檔：還沒借到菜籃車（scenes.lua）
  elseif FLAGS.badge_fire then
    dialog_open("老苔：……大哥他，還在燒炭？\f老苔：那顆棋子……\n算了。下次我去找他下完。")
  elseif FLAGS.badge_rock then
    dialog_open("老苔：……阿礁還記得我？\f老苔：她說飯還是要請？\n……嗯。我會請的。")
  elseif FLAGS.badge_forest then
    dialog_open("老苔：老柏還活著？那老頭子，\n五十年前就說要退休了。")
  else
    dialog_open("老苔：" .. ELDER_IDLE[hash(DAY, frame() // 600) % #ELDER_IDLE + 1])
  end
end

-- 草原小徑上的旅人
local function P() return PLAYER_NAME end

-- ==================== 依時段、天氣出沒的 NPC（W71i）====================
-- NPC_HOURS（npc.lua）：回傳 true = 在。p：morning／day／evening／night；w：天氣（weather.lua，室內 nil）
local function wet(w) return w == "rain" or w == "storm" end
local function late_night() return hash(DAY, 515) % 3 == 0 end   -- 三天有一天，小孩玩到很晚還沒回家

NPC_HOURS.route1_traveler = function(p, w) return p ~= "night" and w ~= "storm" end
NPC_HOURS.village_uncle = function(p, w) return p ~= "night" and w ~= "storm" end
NPC_HOURS.village_kid = function(p, w) return p ~= "night" or late_night() end
NPC_HOURS.harbor_kid = function(p, w) return p ~= "night" or late_night() end
NPC_HOURS.harbor_fisher = function(p, w) return (p == "morning" or p == "day") and w ~= "storm" end
NPC_HOURS.harbor_worker = function(p, w) return p ~= "night" end
NPC_HOURS.harbor_insurance = function(p, w) return p == "morning" or p == "day" end   -- 上班時間
NPC_HOURS.salaryman = function(p, w) return p == "evening" or p == "night" end          -- 鐵輪新人阿翔：下班（加班）後才來

TALK.route1_traveler = function()
  local p, w = time_period(), weather_now()
  if wet(w) then
    dialog_open("下雨天野伴比較少……\n但我已經蹲了，就蹲完。\f……我老婆說我這叫固執。\n我說這叫毅力。")
  elseif p == "morning" then
    dialog_open("早上露水多，野伴也多……\n應該吧。\f我五點就來了。\n不是勤勞，是老了睡不著。")
  elseif p == "evening" then
    dialog_open("天快黑了，再蹲一下就回家。\f我老婆說，我比野伴還難抓回家。")
  else
    dialog_open("我在這片草叢蹲了三個小時，\n一隻野伴都沒抓到。\f這速度……跟我還房貸差不多。")
  end
end

-- ==================== 苔石村 ====================
-- 旅店、商店、招式回想在 village.lua（W55）

TALK.village_uncle = function()
  if wet(weather_now()) then
    dialog_open("下雨天膝蓋會痛。\f你也會？……歡迎加入。")
  elseif time_period() == "evening" then
    dialog_open("傍晚的風很舒服。\f……我是說，膝蓋比較不痛。")
  elseif FLAGS.ch1_done then
    dialog_open("聽說鐵輪公司在找工人，月薪很高。\f……我這個年紀他們不要。")
  else
    dialog_open("年輕時，我也想走遍全島抓野伴。\f現在我每年唯一的冒險，\n是去做健康檢查。")
  end
end

TALK.village_kid = function()
  local p, w = time_period(), weather_now()
  if p == "night" then           -- 玩到很晚還沒回家（三天有一天）
    if hash(DAY, 9) % 2 == 0 then
      cutscene_start(function()
        say(P() .. "：好孩子這個時間，\n早就在睡覺了喔。")
        say("小孩：那大叔你怎麼也還沒睡？")
        say("（……大人有大人的事。）")
      end)
    else
      cutscene_start(function()
        say(P() .. "：這麼晚了還不回家？\n明天不用上學嗎？")
        say("小孩：明天放假！")
        say("（我們那個時候哪有在放假的……）")
        say(P() .. "：……玩一下就回去，\n你媽會擔心。")
        say("小孩：大叔你講話跟我阿嬤一模一樣。")
      end)
    end
  elseif p == "evening" then
    cutscene_start(function()
      say("小孩：我再玩一下下就回家！")
      say(P() .. "：天都快黑了。\n晚上草叢裡有搧火蝠喔。")
      say("小孩：……真的嗎？")
      say(P() .. "：真的。我小時候被咬過。")
      say("（其實沒有。但小孩就是要這樣嚇。）")
    end)
  elseif wet(w) then
    dialog_open("下雨了！我在屋簷下等雨停。\f……大叔你也沒帶傘喔？")
  elseif FLAGS.trainer_rival2 then
    dialog_open("剛剛有個大叔被打敗，\n他兒子在旁邊笑。")
  else
    dialog_open("大叔，你也是來抓野伴的嗎？\f……什麼？你說你是大哥哥？")
  end
end

-- 苔石村東口的守衛（docs/story.md 的 C1-2）
TALK.village_guard = function()
  if FLAGS["cut:village:38:14"] then
    dialog_open("守衛：霧林裡有森之守，很兇，\n但人很好。")
    return
  end
  FLAGS.heard_forest = true
  local text = "守衛：前面是霧林。上個月颳大風，\n一棵大樹倒下來把路堵住了。" ..
    "\f要過去，得找會「伐木」的野伴\n把它砍開。" ..
    "\f草原小徑的囤囤鼠就會。\n牠們什麼都啃。"
  local k = field_skill_kin("lumber")
  if k then text = text .. "\f喔，你的" .. kin_name(k) .. "看起來\n很想啃那棵樹。"
  else
    local home = field_skill_home("lumber")
    if home then text = text .. "\f" .. home end
  end
  dialog_open(text)
end

-- 跟 NPC 說話：找它的對話編號來執行。沒寫的編號顯示「……」並在主控台提醒
function talk_to(npc)
  if npc.trainer then return trainer_talk(npc) end
  local t = TALK[npc.talk]
  if type(t) == "function" then
    t(npc)
  elseif type(t) == "string" then
    dialog_open(t)
  else
    print("talk.lua 裡沒有對話編號「" .. tostring(npc.talk) .. "」（NPC：" .. tostring(npc.name) .. "）")
    dialog_open("……")
  end
end
