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
TALK.route1_traveler =
  "我在這片草叢蹲了三個小時，\n一隻野伴都沒抓到。" ..
  "\f這速度……跟我還房貸差不多。"

-- ==================== 苔石村 ====================
-- 旅店、商店、招式回想在 village.lua（W55）

TALK.village_uncle = function()
  if FLAGS.ch1_done then
    dialog_open("聽說鐵輪公司在找工人，月薪很高。\f……我這個年紀他們不要。")
  else
    dialog_open("年輕時，我也想走遍全島抓野伴。\f現在我每年唯一的冒險，\n是去做健康檢查。")
  end
end

TALK.village_kid = function()
  if FLAGS.trainer_rival2 then
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
  if k then text = text .. "\f喔，你的" .. kin_name(k) .. "看起來\n很想啃那棵樹。" end
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
