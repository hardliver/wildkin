-- ending.lua：結局與破關後（W75；劇本見 docs/story.md「結局與破關後」F-1～F-5）
--
-- 結局：社長下山（ch4_done）之後，第一次離開聖所（走到山脊）就開始：
--   一週後的字幕 → 營地的聚餐（老苔請三位守護者吃飯）→ 大志 40 歲生日 → 媽媽的傳音 → 片尾 → 第二天早上，存檔
-- 破關後（credits 之後）：
--   守護者再戰（每個遊戲日一次）、雲根再挑戰（W74 打倒沒抓到的話）、收容所的社長、手冊 16/16 的拓荒者證書
--
-- 聚餐的客人是營地地圖上的 NPC（guest_…），只在「結局進行中」出現（NPC_HOURS：ending1 之後、credits 之前）

TALK = TALK or {}
NPC_HOURS = NPC_HOURS or {}

local function P() return PLAYER_NAME end

-- ============================================================
-- 結局
-- ============================================================

local function party_day() return FLAGS.ending1 == true and not FLAGS.credits end
for _, name in ipairs({ "guest_bo", "guest_reef", "guest_coal", "guest_asui", "guest_kid1", "guest_kid2" }) do
  NPC_HOURS[name] = party_day
end

-- 聚餐的長桌：營地中間暫時擺一排桌子（Tiny Dungeon 的木桌），片尾之後收掉
local TABLE_CELLS = { 18, 19, 20, 21 }   -- 第 13 列的這幾欄
local TABLE_TILE = 133 + 72              -- dungeon 的第 72 格（木桌）；地圖格子編號見 world.lua
local function table_set(on)
  for _, x in ipairs(TABLE_CELLS) do
    mset(world.map, "deco", x, 13, on and TABLE_TILE or 0)
    mset(world.map, "solid", x, 13, on and 1 or 0)
  end
end

local CREDITS = {
  "Wildkin 野伴",
  "",
  "企劃、程式",
  "Neil",
  "",
  "引擎",
  "Comet",
  "",
  "美術",
  "Kenney（Tiny Town、Tiny Dungeon，CC0）",
  "原創野伴",
  "",
  "",
  "謝謝你玩到最後。",
  "",
  "……膝蓋還好嗎？",
}

SCENE.ending = function()
  set_flag("ending1")
  -- F-1：一週後
  blackout(true)
  narrate("一週後。")
  narrate("鐵輪公司的工廠關了。")
  narrate("社長把工廠改成「野伴收容所」。\n所長是一隻斷了角的雷角羚。")
  narrate("高處長辭職了，在港灣鎮的海鮮攤幫忙。\n燙青菜不加肉燥。")
  narrate("范經理每天睡八個小時。\n聽說臉色好很多。")
  -- F-2：營地的聚餐
  warp("camp", 19, 14, 0, -1)          -- 換地圖時客人就出現了（NPC_HOURS 看 ending1）
  table_set(true)
  if flag("cloudroot_caught") then prop_add("root", "16", 25, 12, false) end
  blackout(false)
  say("（營地中間擺了一張長桌。\n柏伯、礁嬤、炭爺都來了。）")
  say("老苔：……人到齊了。坐。")
  say("礁嬤：小苔，五十年。\n你終於請我吃飯了。")
  say("老苔：……我煮的。\n不好吃不要怪我。")
  say("（炭爺從口袋拿出一顆棋子，放在桌上。）")
  say("炭爺：這個，還你。")
  say("老苔：……我就知道少一顆。")
  say("炭爺：重下一盤吧。這次不偷了。")
  say("柏伯：輸的人洗碗。")
  say("（阿穗一家也來了，帶了一大袋便當。）")
  say("阿穗：我老婆說，人多要多帶一點。")
  if flag("cloudroot_caught") then
    say("小孩（大）：大叔！雲根在哪裡？\n……啊，在那邊的樹下打盹！")
  else
    say("小孩（大）：大叔！雲根在哪裡？")
    say(P() .. "：在山頂。牠是這座島的根，\n要守著這裡。")
  end
  set_flag("ending2")
  -- F-3：40 歲生日
  say("阿穗：對了，" .. P() .. "，\n今天是你生日吧？")
  say(P() .. "：……你怎麼記得？")
  say("阿穗：25 年前我們同一天出發，\n那天也是你生日啊。")
  say("（小孩們端出一個插滿莓果的蛋糕。\n蠟燭插成「40」。）")
  say(P() .. "：……40 歲了。\n拓荒計畫的資格，今天就沒了。")
  say("老苔：資格？你已經在這裡了啊。")
  wait(30)
  say("老苔：……年輕人。")
  say("老苔：嗯，現在不能這樣叫你了。")
  say(P() .. "：……還是叫年輕人吧。")
  say("老苔：好，年輕人。")
  set_flag("ending3")
  -- F-4：媽媽的傳音
  say("老苔：對了，你媽打來的。\n打了好幾次。")
  say("（老苔從小屋拿出一顆傳音石。）")
  say("媽媽：喂？" .. P() .. "？生日快樂。")
  say("媽媽：有沒有吃飯？")
  say(P() .. "：有。很多人一起吃。")
  say("媽媽：……島上有沒有不錯的女生？")
  say(P() .. "：……有很多不錯的野伴。")
  wait(40)
  say("媽媽：…………")
  say("媽媽：你爸說，過年把牠們\n帶回來給他看。")
  say("媽媽：他說「隨便他」。\n但他已經去買狗屋了。")
  set_flag("ending4")
  -- F-5：片尾
  blackout(true)
  play_music("ending")
  credits_roll(CREDITS)
  table_set(false)
  set_flag("credits")
  -- 第二天早上：遊戲時鐘走到 06:00（現實時鐘照現實的時間，不快轉）；隊伍回滿；存檔
  if CLOCK_MODE ~= "real" then clock_add_minutes(minutes_until(6)) end
  for _, k in ipairs(party) do kin_heal(k) end
  warp("camp", 19, 13, 0, -1)          -- 客人回去了（NPC_HOURS 看 credits）
  blackout(false)
  say("老苔：早啊，年輕人。\n……昨天的碗，是老柏洗的。")
  if SAVE_SLOT then
    game_save()
    say("（" .. P() .. "把昨天的事寫進了筆記本。\n存好了！）")
  end
  say("（雲根島的拓荒，還會繼續。\n守護者們隨時歡迎再來比一場。）")
end

-- 社長下山之後第一次走出聖所（scenes.lua 的 scene_on_enter：山脊）
function ending_check(map)
  if map == "ridge" and FLAGS.ch4_done and not FLAGS.ending1 then
    cutscene_start(SCENE.ending)
    return true
  end
  return false
end

-- 聚餐時跟客人說話
TALK.guest_bo = "柏伯：小苔煮的菜，五十年前就這個味道。\f……不難吃。只是很鹹。"
TALK.guest_reef = "礁嬤：（小聲）其實很好吃。\n不要跟他說。"
TALK.guest_coal = "炭爺：這盤棋，我會好好下。\n……大概。"
TALK.guest_asui = "阿穗：40 歲生日快樂。\n……我比你早三個月，已經習慣了。"
TALK.guest_kid1 = "小孩（大）：大叔，你的蛋糕上面，\n為什麼要插那麼多根蠟燭？"
TALK.guest_kid2 = "小孩（小）：大叔，生日快樂！\n……你幾歲？四歲？"

-- ============================================================
-- 破關後：守護者再戰（每個遊戲日一次）
-- ============================================================

local function rematch(key, base_talk)
  return function(n)
    if not FLAGS.credits then return base_talk(n) end
    local t = DATA.trainers[key]
    if FLAGS["rematch:" .. key] == DAY then
      dialog_open(t.name .. "：" .. t.after)
      return
    end
    cutscene_start(function()
      if ask(t.name .. "：" .. t.intro, { "比", "下次" }) ~= 1 then return end
      if fight(key) == "lose" then
        wiped_out()
        return
      end
      FLAGS["rematch:" .. key] = DAY   -- 今天打過了（存檔一起存；換日就能再打）
      MONEY = MONEY + t.money
      say(P() .. "拿到了 " .. money_text(t.money) .. "。")
      say(t.name .. "：" .. t.win)
    end)
  end
end
TALK.forest_keeper = rematch("forest_keeper2", TALK.forest_keeper)
TALK.rock_keeper = rematch("rock_keeper2", TALK.rock_keeper)
TALK.fire_keeper = rematch("fire_keeper2", TALK.fire_keeper)

-- ============================================================
-- 破關後：雲根再挑戰（聖所的樹根下，事件格）
-- ============================================================
CLOUDROOT_AGAIN_LEVEL = 45

-- 回傳 "again"：條件還沒到、或這次沒抓到 → 下次走進來還會發生
SCENE.cloudroot_again = function()
  if not (FLAGS.credits and FLAGS.cloudroot_beaten and not FLAGS.cloudroot_caught) then return "again" end
  face("player", "up")
  say("（雲根從樹根裡抬起頭，\n看著" .. P() .. "。）")
  if ask("要和雲根再比一次嗎？", { "比", "不要" }) ~= 1 then return "again" end
  local result = nil
  battle_scene_start({ kin_new("16", CLOUDROOT_AGAIN_LEVEL) }, { wild = true, flash = true }, function(r) result = r end)
  while result == nil or transition_active() do coroutine.yield() end
  if result == "lose" then
    wiped_out()
    return "again"
  end
  if result ~= "caught" then
    say("（雲根又慢慢走回了樹根裡。）")
    return "again"
  end
  prop_remove("root")
  set_flag("cloudroot_caught")
  say("（野伴球在" .. P() .. "手上，輕輕地動了一下。）")
  say("（……是牠自己進去的。）")
end

function cloudroot_again_visible()
  return FLAGS.credits and FLAGS.cloudroot_beaten and not FLAGS.cloudroot_caught
end

-- ============================================================
-- 破關後：收容所的社長（工廠大廳）、老苔、手冊 16/16
-- ============================================================
NPC_HOURS.president_shelter = function() return FLAGS.credits == true end
TALK.president_shelter = "社長：這裡的野伴，想走就走，想留就留。\f社長：……跟你的營地學的。\f（阿電的角之間，\n「啪」地跳出一道小小的電光。）"

function dex_count()
  local n = 0
  for _ in pairs(DEX.caught) do n = n + 1 end
  return n
end

local base_elder = TALK.elder
TALK.elder = function(n)
  if not FLAGS.credits then return base_elder(n) end
  local total = 0
  for _ in pairs(DATA.species) do total = total + 1 end
  if dex_count() >= total and not FLAGS.got_cert then
    cutscene_start(function()
      say("老苔：手冊……全部都填滿了？")
      say("老苔：" .. total .. " 種。這座島上所有的野伴，\n你都見過、都抓過了。")
      say("老苔：這個給你。\n拓荒計畫的人，前幾天寄來的。")
      bag_add("cert", 1)
      say(P() .. "得到了「拓荒者證書」！")
      say("老苔：年齡欄寫 40。\n……承辦人員看了很久吧。")
      set_flag("got_cert")
    end)
    return
  end
  local idle = {
    "老苔：重下的那盤，我贏了。\n大哥說他不是故意輸的。",
    "老苔：阿礁說下個月換她請。\n……五十年，換來一頓。划算。",
    "老苔：早啊，年輕人。",
  }
  if dex_count() < total then
    idle[#idle + 1] = "老苔：手冊還差 " .. (total - dex_count()) .. " 種。\n慢慢來，這座島又不會跑掉。"
  end
  dialog_open(idle[hash(DAY, frame() // 600) % #idle + 1])
end
