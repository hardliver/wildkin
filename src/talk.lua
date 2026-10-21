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

TALK = {}

-- 老苔：新芽營地的管理員
-- 全滅後被送回營地時，老苔說的話
TALK.elder_rescue =
  "醒啦？你倒在草叢裡，是路過的旅人把你扛回來的。" ..
  "\f野伴我已經幫你照顧好了。\n倒是你，腰還好吧？" ..
  "\f到了這個年紀，出門前記得先暖身……\n還有，保險要保。"

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
-- 旅店、商店、招式回想的功能在 W55 才做，先讓他們說明一下

TALK.village_innkeeper =
  "歡迎來到苔石旅店。\n住一晚，野伴就能恢復精神喔。" ..
  "\f……不過我們正在整修，\n過幾天再來吧。"

TALK.village_shopkeeper =
  "這裡是苔石商店。\n野伴球、回復藥，應有盡有……" ..
  "\f咦？今天的貨還沒送到。\n下次再來吧！"

TALK.village_recall =
  "我是招式回想師。\n野伴忘掉的招式，我都能幫牠想起來。" ..
  "\f等你的野伴學會更多招式，再來找我吧。"

TALK.village_uncle =
  "年輕時，我也想走遍全島抓野伴。" ..
  "\f現在我每年唯一的冒險，\n是去做健康檢查。"

TALK.village_kid =
  "大叔，你也是來抓野伴的嗎？" ..
  "\f……什麼？你說你是大哥哥？"

TALK.village_guard =
  "往東是霧林。\n最近霧太濃了，誰都不准進去。" ..
  "\f等老苔說可以了，再來找我吧。"

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
