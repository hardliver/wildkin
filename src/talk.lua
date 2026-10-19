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
TALK.elder = function()
  dialog_ask(
    "你就是新來的拓荒者吧？我是新芽營地的管理員，大家都叫我老苔。" ..
    "\f這座雲根島上住著許多野生的生物，\n我們叫牠們「野伴」。" ..
    "\f牠們會幫忙種田、砍樹，\n也會陪你一起冒險。" ..
    "\f那麼，你準備好出發了嗎？",
    { "是", "否" },
    function(choice)
      if choice == 1 then
        dialog_open("很好！先到營地外的草原小徑看看吧。\n小心草叢裡的野伴。")
      else
        dialog_open("沒關係，準備好了再來找我。")
      end
    end)
end

-- 草原小徑上的旅人
TALK.route1_traveler =
  "我在這片草叢蹲了三個小時，\n一隻野伴都沒抓到。" ..
  "\f這速度……跟我還房貸差不多。"

-- 跟 NPC 說話：找它的對話編號來執行。沒寫的編號顯示「……」並在主控台提醒
function talk_to(npc)
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
