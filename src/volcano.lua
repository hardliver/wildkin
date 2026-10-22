-- volcano.lua：火山洞（W70；劇本見 docs/story.md「第 3 章　火山的煙」C3-4～C3-7）
--
-- 地圖用 Tiny Dungeon 的圖塊整張換色（season.lua 的 RECOLOR）；室內（dark.lua 的 INDOOR_MAPS）。
-- 范經理的對戰在劇情 c3_exec 裡（和高處長一樣：事件格觸發，打輸事件格保留）。
-- 焰之守炭爺：和柏伯、礁嬤一樣，跟他說話 → 對戰 → 徽記 → 精製球、發電機 → 第 3 章結束。

TALK = TALK or {}

local function P() return PLAYER_NAME end

local function npc_named(name)
  for _, n in ipairs(npcs) do
    if n.name == name then return n end
  end
  return nil
end

-- C3-4：第一次進火山洞
SCENE.c3_volcano = function()
  wait(10)
  say("（一走進洞裡，熱氣撲面而來。）")
  say(P() .. "：……好熱。\n比健身房的三溫暖還熱。")
  set_flag("volcano")
end

-- 進火山洞時（scenes.lua 的 scene_on_enter 呼叫）：范經理打完就不在
function volcano_enter()
  for i = #npcs, 1, -1 do
    if npcs[i].name == "exec2" and FLAGS.trainer_exec2 then npc_remove(npcs[i]) end
  end
  if not FLAGS.volcano then cutscene_start(SCENE.c3_volcano) end
end

-- C3-5：鐵輪幹部 2 范經理（施工區，事件格）
SCENE.c3_exec = function()
  if flag("trainer_exec2") or not npc_named("exec2") then return end
  face("exec2", "player")
  say("范經理：這裡是施工區，\n大叔你走錯了。")
  emote("player", "…")
  say(P() .. "：……大叔。")
  say("范經理：高處長說有個大叔一直來亂。\n就是你吧？")
  say("范經理：你們那一代就是這樣，\n什麼都講感情。")
  say("范經理：野伴放著也是放著。\n給牠們工作，牠們才有價值。")
  say(P() .. "：……那你呢？\n你一天睡幾個小時？")
  wait(20)
  say("范經理：……四個。夠了。")
  say("范經理：別浪費我時間。")
  if fight("exec2") == "lose" then
    wiped_out("老苔：被年輕人打敗了？\n……我也是。每天都是。")
    return "again"
  end
  local t = DATA.trainers.exec2
  say("范經理：……這不在我的計畫裡。")
  MONEY = MONEY + t.money
  say(P() .. "拿到了 " .. money_text(t.money) .. "獎金。")
  say("范經理：工廠下個月就要開了。\n社長說，這座島的野伴全部都要「登錄」。")
  say("范經理：……你要阻止，\n就去山頂找社長吧。我還有會要開。")
  walk("exec2", "left", 5)
  npc_remove(npc_named("exec2"))
end

TALK.exec2 = function()
  cutscene_start(SCENE.c3_exec)
end

-- C3-6：焰之守 炭爺（溫泉，跟他說話）
SCENE.c3_keeper = function()
  face("charcoal", "player")
  say("炭爺：……誰？泡湯要先沖身體。")
  say("炭爺：你從新芽營地來的？\n……那邊還有人住？")
  say(P() .. "：老苔在。")
  wait(30)
  say("炭爺：…………他還活著啊。")
  say("炭爺：那傢伙，五十年前下棋輸給我，\n翻桌就走了。")
  say("炭爺：……其實那盤棋，\n是我偷走了一顆子。")
  say("炭爺：火要慢慢燒，炭才會好。\n人跟野伴也是。")
  say("炭爺：讓我看看，你燒得夠不夠久！")
  if fight("fire_keeper") == "lose" then
    say("炭爺：火候還不夠。\n去泡個湯再來。")
    wiped_out()
    return
  end
  local t = DATA.trainers.fire_keeper
  MONEY = MONEY + t.money
  say("炭爺：……燒得好。")
  say("炭爺：這是「焰之徽記」。")
  say(P() .. "得到了焰之徽記！")
  set_flag("badge_fire")
  say("炭爺：有了它，就能做「精製球」，\n營地也能蓋「發電機」。")
  say(P() .. "學會了精製球的做法！\n（金屬 2、木材 2）")
  say(P() .. "學會了發電機的蓋法！\n（金屬 10、石頭 10；派會發電的野伴）")
  say(P() .. "拿到了 " .. money_text(t.money) .. "謝禮。")
  say("炭爺：……回去跟那傢伙說，\n那顆棋子，我還留著。")
  -- C3-7：第 3 章結束
  blackout(true)
  narrate("走出洞口，火山的山腰上，\n一座巨大的工廠正冒著黑煙。")
  narrate("齒輪的標誌。鐵輪公司。")
  narrate(P() .. "：……就是那裡。")
  narrate("第 3 章　完")
  set_flag("ch3_done")
  blackout(false)
end

TALK.fire_keeper = function()
  if FLAGS.badge_fire then
    dialog_open("炭爺：" .. DATA.trainers.fire_keeper.after)
  else
    cutscene_start(SCENE.c3_keeper)
  end
end
