-- scenes.lua：劇本（W52 起）
--
-- 每段劇情是 SCENE 表格裡的一個函式，用 cutscene.lua 的工具寫：
--   say(文字)、ask(文字, 選項) → 第幾項、wait(幀數)
--   walk(誰, 方向, 格數)、walk_to(誰, 格x, 格y)、walk_to(誰, 另一個角色)、face(誰, 方向或角色)、place(誰, 格x, 格y)
--   emote(誰, "!"／"?"／"…"／"♪")、give(道具, 數量)、fight(訓練家) → "win"／"lose"
--   fade(函式)：畫面暗下來時做事；flag(名字)、set_flag(名字)
-- 「誰」：「"player"」或 NPC 的 name。
-- 地圖上的事件格（type = "event"，scene = 這裡的名字）走進去就開始，每段只發生一次。
--
-- 序章、第 1 章的完整劇本在 W53 寫；這裡先放一段示範（W54 序章時會重寫）。

-- 營地南邊出口：第一次要出營地時，老苔追上來給回復藥
SCENE.camp_exit = function()
  say("「年輕人——！等一下！」")
  emote("player", "!")
  face("player", "up")
  place("elder", 19, 21)               -- 老苔從遠處跑過來（直接放到路上再走過來，比較快）
  walk_to("elder", "player")
  emote("elder", "…", 30)
  say("老苔：呼……呼……\f跑這幾步就喘成這樣，\n我也不年輕了。")
  say("老苔：出門前，帶著這個。")
  give("potion", 2)
  say("老苔：草原小徑的草叢裡有野伴，\n要是受傷了就用它。\f……還有，腰要顧好。")
  emote("player", "♪")
  fade(function() place("elder", 19, 11) end)   -- 老苔回小屋前面
end
