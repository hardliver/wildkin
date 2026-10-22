-- harbor.lua：港灣鎮（W68；劇本見 docs/story.md「港灣鎮」C2-7～C2-12）
--
-- 旅店、商店的共用程式在 village.lua（TALK.harbor_innkeeper、shop_open）。
-- 阿穗第 3 戰是一般的訓練家（data/trainers.json 的 rival3，地圖 NPC 的 trainer 欄位）。
-- 岩之守礁嬤的對戰在劇情 c2_keeper 裡（和柏伯一樣：fight → 徽記 → 爐的蓋法）。

TALK = TALK or {}

local function P() return PLAYER_NAME end

-- C2-7：第一次進港灣鎮（東口的事件格）
SCENE.c2_harbor = function()
  wait(10)
  say("第一次聞到這麼重的海味。")
  say(P() .. "：……港灣鎮。\n小時候畢業旅行來過一次。")
  say(P() .. "：那時候在這裡買的鑰匙圈，\n現在還掛在家裡。")
  set_flag("harbor")
end

-- C2-8：鐵輪公司辦事處的櫃台
TALK.harbor_reception = function()
  if FLAGS.saw_office then
    dialog_open("櫃台小姐：參觀工廠請預約喔。\n社長最近很忙。")
    return
  end
  cutscene_start(function()
    say("櫃台小姐：歡迎光臨鐵輪公司。")
    say("櫃台小姐：應徵請上網投履歷。……")
    say("櫃台小姐：先生，\n您的年齡欄好像填錯了？")
    say(P() .. "：我不是來應徵的。")
    say("櫃台小姐：喔。那參觀工廠請預約，\n社長最近很忙。")
    say("櫃台小姐：聽說火山那邊的新工廠，\n下個月就要開工了。")
    set_flag("saw_office")
  end)
end

TALK.harbor_worker = function()
  if FLAGS.trainer_exec1 then
    dialog_open("工人：高處長回來的時候臉很臭。\f……是你喔？")
  else
    dialog_open("工人：礦坑那邊在趕工，\n處長說月底前要挖完。")
  end
end

TALK.harbor_seafood = function()
  if time_period() == "night" then
    cutscene_start(function()
      say("老闆：這麼晚還來？\n宵夜要吃什麼？")
      say("（" .. P() .. "想到上次半夜吃炸花枝，\n胃酸逆流到天亮。）")
      say(P() .. "：……一碗清湯就好。")
      say("老闆：年輕人都點炸的。")
      say("（我知道。我以前也是。）")
    end)
    return
  end
  cutscene_start(function()
    say("老闆：今天的魚很新鮮喔！\n烤魚、蛤蜊湯、炸花枝！")
    say("（" .. P() .. "看了看菜單，想到尿酸，\n點了燙青菜。）")
    say("老闆：……燙青菜也很新鮮。")
  end)
end

TALK.harbor_insurance = "業務員：野伴意外險，月繳 100 元，\n戰鬥倒下也理賠！" ..
  "\f業務員：先生，你這個年紀，\n該為自己規劃了。" ..
  "\f（" .. "只是聽聽而已，沒有買。）"

TALK.harbor_fisher = function()
  local w = weather_now()
  if w == "rain" then
    dialog_open("漁夫：下雨天魚比較會咬餌。\f人比較不想出門就是了。")
  elseif time_period() == "morning" then
    dialog_open("漁夫：四點出海，現在收工了。\f年輕人都說我們起得早。\n其實是老了睡不著。")
  elseif FLAGS.ch2_done then
    dialog_open("漁夫：燈塔的燈比較亮了。\f不過最近海上常看到鐵輪公司的船，\n往火山那邊開。")
  else
    dialog_open("漁夫：霧傘水母會飄到淺灘。\f牠會噴水，田裡有牠很好用。")
  end
end

TALK.harbor_kid = function()
  local p, w = time_period(), weather_now()
  if p == "night" then
    cutscene_start(function()
      say(P() .. "：小朋友，這麼晚了，\n爸媽知道你在這裡嗎？")
      say("小孩：我爸還在船上。\n我在等他回來。")
      say(P() .. "：……那你在路燈下面等，\n不要靠近水邊。")
      say("小孩：大叔，你也是誰的爸爸嗎？")
      say("（……這題有點難回答。）")
    end)
  elseif w == "rain" or w == "storm" then
    dialog_open("小孩：下雨天船都不出海，\n我爸在家睡一整天。")
  elseif p == "evening" then
    dialog_open("小孩：太陽下山的時候，\n海是橘色的。\f我爸說那是太陽在泡澡。")
  else
    dialog_open("小孩：我爸說鐵輪公司的船很臭。")
  end
end

TALK.harbor_shopkeeper = function()
  shop_open("老闆：港灣商店，什麼都有！", HARBOR_STOCK)
end

-- C2-11：岩之守 礁嬤（燈塔前，跟她說話）
SCENE.c2_keeper = function()
  face("reef", "player")
  say("礁嬤：……小苔那個孩子，叫你來的？")
  emote("player", "?")
  say(P() .. "：小苔……？")
  say("礁嬤：老苔啦。\n他五十年前說要請我吃飯，到現在還沒請。")
  say("礁嬤：這座防波堤，\n是我一塊一塊石頭砌起來的。")
  say("礁嬤：鐵輪公司說要把它拆了，\n蓋他們的碼頭。")
  say("礁嬤：石頭要一塊一塊疊，急不來。\n野伴也是。")
  say("礁嬤：讓我看看，你是不是急性子！")
  if fight("rock_keeper") == "lose" then
    say("礁嬤：太急了。回去喝杯茶再來。")
    wiped_out()
    return
  end
  local t = DATA.trainers.rock_keeper
  MONEY = MONEY + t.money
  say("礁嬤：……穩。你跟你的野伴，都很穩。")
  say("礁嬤：這是「岩之徽記」。")
  say(P() .. "得到了岩之徽記！")
  set_flag("badge_rock")
  say("礁嬤：有了它，營地就能蓋「爐」了。\n礦石放進去燒，會變成金屬。")
  say(P() .. "學會了爐的蓋法！\n（石頭 15、木材 5；派會生火的野伴）")
  say(P() .. "拿到了 " .. money_text(t.money) .. "謝禮。")
  say("礁嬤：鐵輪公司的工廠在火山那邊。\n要去，得先過海岸。")
  say("礁嬤：還有……回去跟小苔說，\n飯還是要請。")
  -- C2-12：第 2 章結束
  wait(20)
  say("（遠遠聽到碼頭的漁夫在喊：\n「燈塔的燈好像比較亮了！」）")
  say("（……「不過最近海上常看到鐵輪公司的船，\n往火山那邊開。」）")
  blackout(true)
  narrate("第 2 章　完")
  set_flag("ch2_done")
  blackout(false)
end

TALK.rock_keeper = function()
  if FLAGS.badge_rock then
    dialog_open("礁嬤：" .. DATA.trainers.rock_keeper.after)
  else
    cutscene_start(SCENE.c2_keeper)
  end
end
