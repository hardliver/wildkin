-- summit.lua：山脊與山頂聖所（W74；劇本見 docs/story.md「終章（下）　山脊與山頂聖所」E-8～E-13）
--
-- 地圖：maps/ridge.json（山脊，20 × 45）、maps/summit.json（聖所，20 × 15），tools/maps/ridge_map.py 產生。
-- 山脊從社長室的後門上來（打贏社長才開，factory.lua）；遇敵草叢有稀有的 15 號雷角羚（雷雨 ×3）。
--
-- 劇情旗標：ridge（第一次上山脊）、saw_antelope（斷角的影子）、trainer_rival4（阿穗終戰）、
--   summit（聖所：社長與阿電）、cloudroot_caught／cloudroot_beaten（雲根：抓到／打倒）、ch4_done（社長放下登錄器）、
--   elder_cloudroot（回營地，老苔說雲根是自己選的）

TALK = TALK or {}

CLOUDROOT_LEVEL = 38   -- 雲根的等級（W74 試算：Lv40 時選火的隊伍 Lv35 只有約 60%；Lv38 約 78–97%）

local function P() return PLAYER_NAME end

local function npc_named(name)
  for _, n in ipairs(npcs) do
    if n.name == name then return n end
  end
  return nil
end

-- 進地圖（scenes.lua 的 scene_on_enter 呼叫）
function summit_enter(map)
  if map == "ridge" then
    if ending_check(map) then return end   -- 社長下山之後第一次走出聖所：結局（ending.lua）
    if not FLAGS.ridge then cutscene_start(SCENE.e8_ridge) end
  elseif map == "summit" then
    if FLAGS.ch4_done then
      -- 劇情結束：社長帶著阿電下山了；雲根沒被抓到的話回到樹根裡（W75 再挑戰）
      local n = npc_named("president")
      if n then npc_remove(n) end
      if cloudroot_again_visible() then prop_add("root", "16", 9, 4, false) end   -- 破關後再挑戰（ending.lua）
    elseif FLAGS.summit then
      -- 輸了、逃走了再回來：雲根和阿電還在
      prop_add("root", "16", 9, 4, false)
      prop_add("aden", "15", 11, 5, false)
    end
  end
end

-- E-8：山路入口（第一次上山脊）
SCENE.e8_ridge = function()
  wait(10)
  say("（社長室的後門外，是一條往上的石階。\n風很大。）")
  say(P() .. "：……這個坡度。")
  say(P() .. "：我上一次爬這麼高，是公司的員工旅遊。\n最後是坐纜車下山的。")
  set_flag("ridge")
end

-- E-9：雷角羚的影子（山脊下段，事件格）：岩壁上一閃而過，角斷了一半（阿電的伏筆）
SCENE.e9_antelope = function()
  prop_add("ant", "15", 8, 31, false)
  wait(10)
  emote("player", "!")
  say("（岩壁上，一隻野伴的角之間\n「啪」地跳過一道電光。）")
  say("（……牠的一根角，好像斷了一半。）")
  prop_remove("ant")
  wait(10)
  say("（一眨眼，牠已經跳到看不見的地方了。）")
  say(P() .. "：……好快。\n我年輕的時候也沒那麼快。")
  set_flag("saw_antelope")
end

-- E-10：阿穗終戰（觀景台下面那一段路，事件格）
SCENE.e10_rival = function()
  if flag("trainer_rival4") then return end
  local asui = npc_named("asui")
  if not asui then return end
  emote("kid1", "!")
  say("小孩（大）：爸！就是他！那個大叔！")
  face("asui", "player")
  walk_to("asui", 12, 21)
  face("player", "asui")
  say("阿穗：" .. P() .. "！你也爬上來了？")
  say("阿穗：我答應兒子，\n要帶他們來看山頂的「雲根」。")
  say("阿穗：……結果爬到一半，\n我的膝蓋先不行了。")
  say(P() .. "：我也是。")
  wait(20)
  say("阿穗：25 年前，我們同一天出發。")
  say("阿穗：後來你一直走，我停下來了。\n結婚、生小孩、當主管。")
  say("阿穗：我不後悔。只是……偶爾會想，\n要是我也一直走，會走到哪裡。")
  say(P() .. "：我也偶爾會想。\n你那邊，是什麼樣子。")
  say("小孩（小）：爸爸加油！大叔也加油！")
  say("阿穗：來吧。最後一場，用全力。")
  if fight("rival4") == "lose" then
    wiped_out("老苔：輸給阿穗了？\n……那小子，二十五年前也是這樣，越輸越不服氣。")
    return "again"
  end
  local t = DATA.trainers.rival4
  say("阿穗：……輸了。輸得很乾脆。")
  say("小孩（大）：爸，你好遜！")
  say("小孩（小）：可是爸爸剛剛很帥！")
  say("阿穗：……聽到沒？我兒子說我很帥。\n這樣就夠了。")
  MONEY = MONEY + t.money
  say(P() .. "拿到了 " .. money_text(t.money) .. "獎金。")
  say("阿穗：這個給你。\n我老婆說，這次多做了一點。")
  give("bento", 3)
  say("阿穗：還有這個。剛剛幫你拍的。")
  bag_add("photo", 1)
  say(P() .. "得到了「家族合照」！")
  say("（照片裡，阿穗一家人，\n旁邊站著一個表情僵硬的大叔。）")
  say("（遠處的停車場，阿穗的老婆朝這邊揮了揮手。）")
  say("阿穗：……下次換你帶家人來，好嗎？")
  say(P() .. "：……先讓我找到人再說。")
  say(P() .. "：（照片裡最僵硬的那個人，就是我。\n……拍照果然也要練習。）")
  walk_to("asui", 14, 19)
  face("asui", "player")
end

TALK.rival4_after = function()
  if not FLAGS.trainer_rival4 then
    cutscene_start(SCENE.e10_rival)
  else
    dialog_open("阿穗：" .. DATA.trainers.rival4.after)
  end
end
TALK.asui_kid1 = function()
  if FLAGS.trainer_rival4 then dialog_open("小孩（大）：大叔，你什麼時候要帶家人來？\f（……這題比對戰還難。）")
  else dialog_open("小孩（大）：我爸說，他以前跟一個大叔\n同一天出發去旅行。") end
end
TALK.asui_kid2 = function()
  if FLAGS.trainer_rival4 then dialog_open("小孩（小）：大叔好帥！\n……跟我爸一樣帥！")
  else dialog_open("小孩（小）：雲根是什麼？\n可以吃嗎？") end
end

-- E-11～E-13：聖所（事件格）。輸了、逃走了回傳 "again"：下次走進來從雲根那裡接著
SCENE.e11_summit = function()
  if flag("ch4_done") then return end
  if not flag("summit") then
    -- E-11：社長與老雷角羚
    face("player", "up")
    wait(20)
    say("（老榕樹下，社長拿著一台\n像大型野伴球的機器。）")
    prop_add("root", "16", 9, 4, false)
    say("（樹根動了一下。\n雲根的頭，從根裡抬了起來。）")
    say("社長：……找到了。這座島的「根」。")
    say("社長：只要登錄了你，這座島就——")
    prop_add("aden", "15", 11, 5, false)
    emote("player", "!")
    say("（一隻老雷角羚從岩石後面跳出來，\n擋在雲根前面。牠的一根角斷了一半。）")
    wait(30)
    say("社長：…………")
    say("社長：那根角……")
    say("社長：……阿電？")
    say("（老雷角羚的角之間，\n「啪」地跳出一道很小的電光。）")
    say("社長：三十年了。我以為你早就……")
    say("社長：我把你留在這裡，\n因為你跑不動了。")
    say("社長：你卻一直在這裡……\n守著這座島。")
    say("（社長手上的登錄器，掉在地上。）")
    say(P() .. "：……社長。")
    set_flag("summit")
    say("（雲根站了起來，看著" .. P() .. "。）")
    say(P() .. "：……我知道。你要看看，\n我帶來的這些野伴，是夥伴，還是工具。")
  else
    face("player", "up")
    say("（雲根靜靜地看著" .. P() .. "。）")
  end
  -- E-12：雲根（野生的對戰，可以丟球）
  local result = nil
  battle_scene_start({ kin_new("16", CLOUDROOT_LEVEL) }, { wild = true, flash = true }, function(r) result = r end)
  while result == nil or transition_active() do coroutine.yield() end
  if result == "lose" then
    wiped_out("老苔：去山頂了？……那邊的空氣，\n對我們這個年紀太稀薄了。")
    return "again"
  end
  if result == "run" then
    say("（雲根沒有追過來。\n只是一直看著" .. P() .. "。）")
    return "again"
  end
  prop_remove("root")
  if result == "caught" then
    set_flag("cloudroot_caught")
    say("（野伴球在" .. P() .. "手上，輕輕地動了一下。）")
    say("社長：……那種球，關不住牠的。")
    say("社長：是牠自己進去的。牠選了你。")
    say("（老雷角羚的角之間，\n跳出一道很小、很溫和的電光。）")
  else
    set_flag("cloudroot_beaten")
    say("（雲根倒下之後，慢慢站了起來，\n走回了樹根裡。）")
  end
  -- E-13：社長放下登錄器
  wait(20)
  face("president", "player")
  say("社長：……我輸了。\n不是輸給你，是輸給牠。")
  say("（社長摸著老雷角羚斷掉的角。）")
  say("社長：我當年在大賽第一輪就輸了。\n從那之後，就只看數字。")
  say("社長：……工廠，我會關掉。\n登錄的資料，也會刪掉。")
  say("社長：阿電，跟我回去吧。\n……這次換我照顧你。")
  walk("president", "down", 4)
  npc_remove(npc_named("president"))
  prop_remove("aden")
  set_flag("ch4_done")
end

TALK.president_summit = function()
  cutscene_start(SCENE.e11_summit)
end

-- 抓到雲根之後第一次回營地：老苔（雲根是自己選擇跟大志走的）
SCENE.cloudroot_home = function()
  wait(10)
  say("老苔：雲根……跟你回來了？")
  say("老苔：牠不是被抓的。這座島的根，\n自己想去看看島上的人過得好不好。")
  say("老苔：……好好照顧牠。\n牠比我還老。")
  set_flag("elder_cloudroot")
end
