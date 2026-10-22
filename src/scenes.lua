-- scenes.lua：劇本（W52 起；台詞見 docs/story.md）
--
-- 每段劇情是 SCENE 表格裡的一個函式，用 cutscene.lua 的工具寫：
--   say(文字)、ask(文字, 選項) → 第幾項、wait(幀數)、narrate(黑畫面上的字)
--   walk(誰, 方向, 格數)、walk_to(誰, 格x, 格y)、walk_to(誰, 另一個角色)、face(誰, 方向或角色)、place(誰, 格x, 格y)
--   emote(誰, "!"／"?"／"…"／"♪")、give(道具, 數量)、fight(訓練家) → "win"／"lose"
--   fade(函式)：畫面暗下來時做事；blackout(true/false)；chapter_card(第幾章)
--   prop_add(編號, 野伴, 格x, 格y)：暫時放一隻野伴在地圖上；await_screen(開畫面的函式)
--   flag(名字)、set_flag(名字)
-- 「誰」：「"player"」或 NPC 的 name。
-- 怎麼開始：地圖的事件格（type = "event"，scene = 名字）、scene_on_enter（進到某張地圖時）、
--           程式裡 cutscene_start(SCENE.名字)

local function P() return PLAYER_NAME end

-- ============================================================
-- 序章 P0～P2：開場、取名、抵達營地、選初始野伴（新遊戲時 main.lua 開始）
-- ============================================================

SCENE.prologue = function()
  -- P0：黑畫面
  wait(30)
  narrate("雲根島拓荒計畫　申請表")
  narrate("年齡欄：39")
  narrate("承辦人員看了很久。")
  narrate("「……你確定？限 40 歲以下喔。」")
  narrate("「確定。今年是最後一年了。」")
  say("承辦人員：那麼，請寫上你的名字。")
  PLAYER_NAME = await_screen(function(done) name_entry_open("大志", done) end)
  say("承辦人員：" .. P() .. "先生，歡迎參加拓荒計畫。")
  say("承辦人員：船明天一早出發。\n祝你……呃，身體健康。")
  wait(30)

  -- P1：抵達營地（主角在南口，老苔在前面兩格）
  place("elder", 19, 25)
  face("player", "up")
  blackout(false)
  wait(20)
  emote("elder", "!")
  say("老苔：喔！你就是新來的拓荒者吧？")
  say("老苔：我是新芽營地的管理員，\n大家都叫我老苔。")
  say("老苔：我看看申請表……\n" .. P() .. "，39 歲。")
  say("老苔：年輕人，歡迎！")
  emote("player", "…", 30)
  say(P() .. "：（……被叫年輕人了。）")
  say("老苔：這座雲根島以前很熱鬧，\n大家跟野伴一起種田、蓋房子。")
  say("老苔：後來人都搬走了，\n營地只剩我一個老頭子。")
  say("老苔：來，先到我的小屋前面，\n有東西給你看。")
  set_flag("arrived")

  -- P2：選初始野伴（小屋前的空地，三隻站成一排）
  fade(function()
    place("elder", 19, 11)
    place("player", 19, 15)
    face("player", "up")
    prop_add("s1", "01", 18, 13, true)
    prop_add("s2", "03", 19, 13, true)
    prop_add("s3", "05", 20, 13, false)
  end)
  say("老苔：這三隻是營地的野伴。\n牠們會幫忙工作，也會陪你冒險。")
  say("老苔：三隻選一隻吧，年輕人。")
  say(P() .. "：25 年前，我也是這樣選的。")
  local no = await_screen(starter_pick_open)
  local k = kin_new(no, 5)
  party[1] = k
  FLAGS.starter_no = no         -- 選了哪一隻（阿穗用來挑剋制的野伴；進化之後編號會變，所以另外記）
  dex_caught(no)
  say(P() .. "得到了" .. kin_name(k) .. "！")
  say("老苔：好眼光。牠看起來也很喜歡你。")
  say("老苔：剩下的兩隻就留在營地陪我吧。\n牠們的同伴，野外可是很少見的。")
  fade(function()
    prop_remove("s1"); prop_remove("s2"); prop_remove("s3")
  end)
  say("老苔：對了，按 START 可以看隊伍和背包。")
  say("老苔：野伴累了，就在營地的帳篷睡一覺。\n帳篷在我小屋的左邊。")
  say("老苔：什麼時候去睡都行，\n睡一下，野伴就全好了。")
  say("老苔：先到南邊的草原小徑看看吧。")
  set_flag("starter")
end

-- ============================================================
-- 序章 P3：出營地前（營地南口的事件格）
-- ============================================================

SCENE.camp_exit = function()
  if not flag("starter") then
    say("老苔：年輕人，空著手去草叢太危險了！")
    walk("player", "up", 1)
    return "again"
  end
  say("「年輕人——！等一下！」")
  emote("player", "!")
  face("player", "up")
  place("elder", 19, 21)               -- 老苔從遠處跑過來（直接放到路上再走過來，比較快）
  walk_to("elder", "player")
  emote("elder", "…", 30)
  say("老苔：呼……呼……\n跑這幾步就喘成這樣，我也不年輕了。")
  say("老苔：這個給你。野伴球，\n丟向野生的野伴就有機會抓到。")
  give("ball", 5)
  say("老苔：還有回復藥。\n草叢裡的野伴不會手下留情。")
  give("potion", 2)
  say("老苔：去吧。……腰要顧好。")
  fade(function() place("elder", 19, 11) end)   -- 老苔回小屋前面
  set_flag("got_balls")
end

-- ============================================================
-- 序章 P6、P7：基地教學
-- ============================================================

-- P6：第一次抓到野伴之後回到營地（還沒蓋過設施）
SCENE.p6_base = function()
  place("elder", 19, 23)
  walk_to("elder", "player")
  face("player", "elder")
  say("老苔：喔，抓到新夥伴啦！")
  say("老苔：野伴不只能戰鬥，\n也能在營地工作。")
  say("老苔：東邊柵欄裡面是設施空地。\n用材料蓋設施，再派野伴去工作。")
  say("老苔：先蓋個伐木場吧。這些木材給你。")
  give("wood", 5)
  say("老苔：面對空地按 A，就能蓋設施了。")
  local caught = FLAGS.first_catch
  local work = caught and DATA.species[caught] and DATA.species[caught].work or {}
  if caught == "07" then
    say("老苔：囤囤鼠愛啃木頭，派去伐木場剛好。")
  elseif not work.lumber then
    say("老苔：伐木要找會伐木的野伴。\n草原小徑的囤囤鼠就會。")
  end
  fade(function() place("elder", 19, 11) end)
  set_flag("tutorial_base")
end

-- P7：第一次蓋好設施（facility.lua 蓋好時開始）
SCENE.p7_feed = function()
  local px, py = player_cell()
  place("elder", px - 3, py)
  walk_to("elder", "player")
  face("player", "elder")
  say("老苔：蓋得不錯嘛！")
  say("老苔：野伴工作要吃飯。這些飼料給你，\n一隻一天吃一份。")
  give("feed", 3)
  say("老苔：飼料可以在工作台用莓果和麥做。")
  say("老苔：派了野伴，牠們就會一直工作，\n做好的東西會自己送進你的背包。")
  say("老苔：天黑了就到帳篷睡一覺，\n一覺醒來，收成也多了。")
  say("老苔：我年輕的時候，\n一天工作十六個小時……")
  wait(20)
  say("老苔：……那樣不行。\n野伴也是，要吃飽、要睡覺。")
  bike_gift()
  fade(function() place("elder", 19, 11) end)
  set_flag("tutorial_sleep")
end

-- 老苔借菜籃車（W71e）：序章 P7 的最後；舊存檔已經過了 P7 的，回營地時老苔會走過來補給
function bike_gift()
  say("老苔：對了，小屋後面有台舊菜籃車，\n我年輕時騎的。借你吧。")
  say("老苔：後座以前載過我老伴……\n咳，載過很多東西。")
  set_flag("bike")
  say(P() .. "借到了菜籃車！")
  say("老苔：按 B 上車、下車。\n屋子裡、洞穴裡就牽著走吧。")
end

SCENE.bike_late = function()
  local px, py = player_cell()
  place("elder", px - 3, py)
  walk_to("elder", "player")
  face("player", "elder")
  say("老苔：年輕人，等一下！")
  bike_gift()
  fade(function() place("elder", 19, 11) end)
end

-- 營地蓋了發電機：老苔幫菜籃車裝馬達（W71e）
local function camp_has_generator()
  for key, fac in pairs(FACILITY) do
    if fac.kind == "generator" and key:sub(1, 5) == "camp:" then return true end
  end
  return false
end

SCENE.ebike = function()
  local px, py = player_cell()
  place("elder", px - 3, py)
  walk_to("elder", "player")
  face("player", "elder")
  say("老苔：發電機蓋好啦？\n把菜籃車牽過來。")
  blackout(true)
  wait(30)
  blackout(false)
  say("老苔：裝了顆馬達、一顆電池。\n上坡也不用站起來踩了。")
  set_flag("ebike")
  say(P() .. "的菜籃車變成電動輔助了！")
  say("老苔：電池是發電機充的，\n用電要感謝野伴喔。")
  fade(function() place("elder", 19, 11) end)
end

-- ============================================================
-- 序章 P9：到苔石村（第 1 章開始）
-- ============================================================

SCENE.p9_village = function()
  wait(10)
  chapter_card(1)
  say("村民：喔？生面孔。是拓荒計畫來的？")
  say("村民：歡迎來到苔石村。\n旅店在西邊，商店在東邊。")
  say("村民：東邊的霧林……最近不太對勁，\n晚上常有奇怪的聲音。")
  set_flag("ch1")
end

-- ============================================================
-- 第 1 章：霧林（C1-4、C1-5）
-- ============================================================

-- C1-4：霧林入口，鐵輪公司的木樁
SCENE.c1_ironwheel = function()
  say("（路邊插著幾根漆成紅色的木樁，\n還有一塊新的告示牌。）")
  say("告示牌：「鐵輪公司　土地測量中\n閒人勿近」")
  emote("player", "?")
  say(P() .. "：鐵輪公司……？")
  say(P() .. "：這個 logo 好像在哪裡看過。")
  set_flag("saw_ironwheel")
end

-- C1-5：過勞的燈蛾（霧林中段，路邊）
SCENE.c1_moth = function()
  face("player", "right")
  emote("player", "!")
  say("（路邊有一隻燈蛾躺在地上，\n翅膀的光一閃一閃，很微弱。）")
  say("燈蛾的牌子上寫著：\n「鐵輪公司　照明用　編號 0217」")
  say("燈蛾看起來很累，翅膀幾乎不亮了。")
  local yes = ask("要給牠回復藥嗎？", { "給", "不給" }) == 1
  if yes and (BAG.potion or 0) == 0 then
    say("……背包裡沒有回復藥。")
    yes = false
  end
  if yes then
    bag_add("potion", -1)
    say("燈蛾的翅膀慢慢亮起來了。")
    say("燈蛾繞著" .. P() .. "飛了一圈，\n往森林深處飛走了。")
    fade(function() prop_remove("moth") end)
    say(P() .. "：……編號 0217。")
    say(P() .. "：我在公司的員工編號也是四碼。")
    set_flag("moth_rescued")
  else
    say("燈蛾自己慢慢飛走了。")
    fade(function() prop_remove("moth") end)
  end
end

-- C1-7：森之守柏伯（跟他說話）
SCENE.c1_keeper = function()
  face("keeper", "player")
  say("柏伯：……有人來了。")
  say("柏伯：你就是小苔說的那個新來的？")
  emote("player", "?")
  say(P() .. "：小苔……？")
  say("柏伯：老苔啦。\n我認識他的時候他才二十歲。")
  say("柏伯：我是這片霧林的守護者。\n島上的人叫我「森之守」。")
  say("柏伯：這片森林的野伴，\n是跟人一起長大的。")
  say("柏伯：最近有人在森林裡打木樁，\n把野伴抓去工廠……")
  say("柏伯：我得確定，你跟他們不一樣。")
  if flag("moth_rescued") then
    say("柏伯：……那隻燈蛾回來了，\n說有個人救了牠。")
    say("柏伯：是你吧。")
  end
  say("柏伯：讓我看看你和野伴的默契！")
  if fight("forest_keeper") == "lose" then
    say("柏伯：還不夠。多跟野伴相處吧。")
    wiped_out()
    return
  end
  MONEY = MONEY + DATA.trainers.forest_keeper.money
  say("柏伯：……好。你的野伴很信任你。")
  say("柏伯：這是「森之徽記」。")
  say(P() .. "得到了森之徽記！")
  set_flag("badge_forest")
  say("柏伯：有了徽記，\n工作台就能做「好球」了。我也教你做法。")
  say(P() .. "學會了好球的做法！\n（木材 2、礦石 1）")
  say(P() .. "拿到了 " .. money_text(DATA.trainers.forest_keeper.money) .. "謝禮。")
  say("柏伯：鐵輪公司的事……小心點。\n他們不是只來砍樹的。")
  say("柏伯：回去跟小苔說，\n下次換他來找我下棋。")
end

TALK = TALK or {}
TALK.forest_keeper = function()
  if FLAGS.badge_forest then
    dialog_open("柏伯：" .. DATA.trainers.forest_keeper.after)
  else
    cutscene_start(SCENE.c1_keeper)
  end
end

-- C1-8：拿到徽記後回到苔石村（第 1 章結束）
SCENE.c1_end = function()
  wait(10)
  say("村民：霧林的聲音變小了！\n是你去找森之守嗎？")
  say("村民：……不過，港灣鎮那邊\n來了好多鐵輪公司的人。")
  say("村民：說是要在舊礦坑蓋新工廠。")
  blackout(true)
  narrate("第 1 章　完")
  set_flag("ch1_done")
  village_fence_open()          -- 西口的鐵輪柵欄打開（往舊礦坑，第 2 章）
  blackout(false)
  say("（村子西邊傳來敲敲打打的聲音。\n鐵輪公司的柵欄好像打開了。）")
end

-- 苔石村西口的鐵輪柵欄（3, 14）（3, 15）：第 1 章結束才打開（W67）
function village_fence_open()
  if not FLAGS.ch1_done then return end
  for _, y in ipairs({ 14, 15 }) do
    mset(world.map, "deco", 3, y, 0)
    mset(world.map, "solid", 3, y, 0)
  end
end

-- 舊礦坑西邊的鐵門（往港灣鎮）：打贏高處長之後打開
function mine_gate_open()
  for _, y in ipairs({ 14, 15 }) do
    mset(world.map, "deco", 0, y, 0)
    mset(world.map, "solid", 0, y, 0)
  end
end

-- 舊礦坑：工頭走了就不在；礦車旁的野伴（劇情的小圖示，一直都在推車）
local function mine_enter()
  for i = #npcs, 1, -1 do
    local n = npcs[i]
    if (n.name == "foreman" and FLAGS.mine_entered) or (n.name == "exec" and FLAGS.trainer_exec1) then
      npc_remove(n)
    end
  end
  if FLAGS.mine_done then mine_gate_open() end
  prop_add("w1", "12", 7, 11, true)
  prop_add("w2", "12", 10, 11, true)
  prop_add("w3", "12", 13, 11, true)
end

-- 進到某張地圖時（cutscene.lua 的 cutscene_enter_map 呼叫）
function scene_on_enter(map)
  if map == "village" then village_fence_open() end
  if map == "mine" then
    mine_enter()
    if not FLAGS.ch2 then cutscene_start(SCENE.c2_start) return end
  end
  if map == "coast" and not FLAGS.ch3 then cutscene_start(SCENE.c3_start) return end   -- 第 3 章（coast.lua）
  if map == "volcano" then volcano_enter() return end                                   -- 火山洞（volcano.lua）
  if map == "camp" and FLAGS.first_catch and not FLAGS.tutorial_base and next(FACILITY) == nil then
    cutscene_start(SCENE.p6_base)
  elseif map == "camp" and FLAGS.tutorial_sleep and not FLAGS.bike then
    cutscene_start(SCENE.bike_late)
  elseif map == "camp" and FLAGS.bike and not FLAGS.ebike and camp_has_generator() then
    cutscene_start(SCENE.ebike)
  elseif map == "village" and not FLAGS.ch1 then
    cutscene_start(SCENE.p9_village)
  elseif map == "village" and FLAGS.badge_forest and not FLAGS.ch1_done then
    cutscene_start(SCENE.c1_end)
  elseif map == "forest" and not FLAGS.scene_c1_moth then
    prop_add("moth", "10", 20, 5, false)   -- 躺在路邊的燈蛾（C1-5 之後就不在了）
  end
end

-- ============================================================
-- 第 2 章：舊礦坑（W67；劇本見 docs/story.md「第 2 章　舊礦坑的燈」）
-- ============================================================

local function npc_named(name)
  for _, n in ipairs(npcs) do
    if n.name == name then return n end
  end
  return nil
end

-- C2-0：第一次走進舊礦坑（從苔石村西口）
SCENE.c2_start = function()
  wait(10)
  chapter_card(2)
  set_flag("ch2")
end

-- C2-1：礦坑口的工頭（事件格，或直接跟他說話）
SCENE.c2_foreman = function()
  if not npc_named("foreman") then return end
  face("foreman", "player")
  emote("foreman", "!")
  say("工頭：喂，那邊那個大叔！\n礦坑在施工，閒人勿進！")
  say("工頭：……還是你是來應徵的？")
  say("工頭：我們只收 35 歲以下喔。")
  say(P() .. "：……我只是路過。")
  wait(20)
  say("（噹——噹——午休的鐘聲響了。）")
  say("工頭：午休了午休了。\n你自己小心，裡面很暗。")
  walk("foreman", "up", 5)
  npc_remove(npc_named("foreman"))
  set_flag("mine_entered")
end

TALK.mine_foreman = function()
  cutscene_start(SCENE.c2_foreman)
end

-- C2-2：第一次走進暗處
SCENE.c2_dark = function()
  say("好暗……" .. P() .. "的夜間視力\n也不如從前了。")
  local k = field_skill_kin("power")
  if k then
    say(kin_name(k) .. "的翅膀亮了起來！\n四周看得清楚了。")
  else
    say(field_skill_hint("power"))
  end
  set_flag("mine_dark")
end

-- C2-4：礦車旁的野伴
SCENE.c2_carts = function()
  wait(10)
  say("（一排礦車，每台旁邊一隻礫殼犰狳在推。\n身上掛著牌子：「鐵輪公司　編號 0388」）")
  emote("player", "…")
  say(P() .. "：……這些野伴，看起來好累。")
  say(P() .. "：跟我以前加班的樣子\n一模一樣。")
  set_flag("mine_kin_seen")
end

-- C2-5：鐵輪幹部 高處長（礦坑最深處，事件格）
SCENE.c2_exec = function()
  if flag("trainer_exec1") or not npc_named("exec") then return end
  face("exec", "left")
  say("高處長：這條礦脈挖完，\n港灣鎮的新工廠就能……")
  wait(20)
  face("exec", "player")
  emote("exec", "!")
  say("高處長：……咦？")
  say("高處長：大志？\n你不是被優化了嗎？")
  say(P() .. "：……好久不見，阿高。")
  say("高處長：叫我高處長。\n我現在是處長了。")
  say("高處長：你知道嗎？你走了之後，\n你的位子是我接的。績效很好喔。")
  say(P() .. "：那這些野伴呢？")
  say("高處長：野伴？牠們是「設備」。\n設備不用睡覺。")
  wait(30)
  say("高處長：……跟我們以前一樣。")
  say("高處長：既然你擋路，\n就照公司的規矩來吧。")
  if fight("exec1") == "lose" then
    wiped_out("老苔：你跟以前的同事打架？\n……年輕真好。")
    return "again"              -- 下次走進來還會再遇到
  end
  local t = DATA.trainers.exec1
  say("高處長：……你還是一樣，\n做事不看 KPI。")
  MONEY = MONEY + t.money
  say(P() .. "拿到了 " .. money_text(t.money) .. "獎金。")
  say("高處長：港灣鎮的工廠，社長很重視。\n你最好別再管了。")
  say("高處長：我先走了。\n……腰，記得顧。")
  walk("exec", "left", 5)
  npc_remove(npc_named("exec"))
  wait(20)
  mine_gate_open()
  say("（高處長從西邊的鐵門走了。門沒有關。\n遠遠可以聞到海的味道。）")
  set_flag("mine_done")
end

TALK.exec1 = function()
  cutscene_start(SCENE.c2_exec)
end
