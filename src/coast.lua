-- coast.lua：海岸（W69；劇本見 docs/story.md「第 3 章　火山的煙」C3-0～C3-3）
--
-- 從港灣鎮西邊的木筏（raft.lua）拖筏過來。海岸的 3 位訓練家是一般訓練家（data/trainers.json 的 coast1～3）。

TALK = TALK or {}

local function P() return PLAYER_NAME end

-- C3-0：第一次到海岸（章節標題）
SCENE.c3_start = function()
  wait(10)
  chapter_card(3)
  say(P() .. "：……我小時候暈船。\n現在也暈。")
  set_flag("ch3")
end

-- C3-2：崖邊看到鐵輪公司的運輸船
SCENE.c3_ship = function()
  face("player", "down")
  say("（海上停著一艘漆著齒輪標誌的大船。\n甲板上一排籠子，裡面都是野伴。）")
  emote("player", "…")
  say(P() .. "：……要運到火山那邊。")
  say(P() .. "：跟礦坑的那些一樣。")
  set_flag("saw_ship")
end

-- C3-1：漁村小屋的阿婆（第一次：傳音石，媽媽第 3 章；之後可以休息、再聽一次）
local MOM_CALL3 = {
  "媽媽：喂？聽說你跑到海的另一邊了？",
  "媽媽：你國小同學阿德，\n開了第三家分店了。",
  "{name}：……嗯。",
  "媽媽：你爸問你過年回不回來。\n他說「隨便他」，但他每天都在問。",
  "{name}：……我會回去。",
}

local function mom3()
  for _, line in ipairs(MOM_CALL3) do say((line:gsub("{name}", PLAYER_NAME))) end
end

TALK.coast_granny = function()
  if not FLAGS.coast_hut then
    cutscene_start(function()
      say("阿婆：喔，是港灣鎮來的？坐、坐。")
      say("阿婆：這邊以前很熱鬧，\n現在年輕人都去鐵輪公司上班了。")
      say("阿婆：傳音石在牆上，有人找你喔。")
      say("（傳音石亮了起來。）")
      mom3()
      say("阿婆：累了就在這裡睡一下。\n不用錢。")
      set_flag("coast_hut")
    end)
    return
  end
  dialog_ask("阿婆：累了嗎？", { "休息", "聽傳音石", "不用了" }, function(c)
    if c == 1 then
      cutscene_start(function()
        fade(function() for _, k in ipairs(party) do kin_heal(k) end end)
        say("阿婆鋪了一床有樟腦丸味道的棉被。")
        say("隊伍的 HP 全部回復了。")
      end)
    elseif c == 2 then
      cutscene_start(function() say("（傳音石亮了起來。）") mom3() end)
    else
      dialog_open("阿婆：火山那邊很熱，記得多喝水。")
    end
  end)
end
