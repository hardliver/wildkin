-- factory.lua：鐵輪工廠（W73；劇本見 docs/story.md「終章（上）　鐵輪工廠」E-0～E-7）
--
-- 地圖：maps/factory.json（工廠一樓、二樓）、maps/office.json（社長室），tools/maps/factory_map.py 產生。
-- 和火山洞一樣借 Tiny Dungeon 的圖塊整張換色（season.lua 的 RECOLOR）、室內（dark.lua 的 INDOOR_MAPS）。
--
-- 這裡有兩種新的地圖物件（Studio：物件 → 升降梯／控制台）：
--   lift：升降梯、電梯。to、tx、ty：到哪張地圖的哪一格；face：到了面向哪邊（up／down，預設 down）
--         need：要隊伍裡有會這項工作的野伴才動（電梯沒電：need = "power"）
--         flag：要有這個劇情旗標才開（火山洞的貨梯：第 3 章結束才開）
--         scene：第一次搭之前先跑的劇情（火山洞的貨梯：終章的章節標題）
--   console：生產線的控制台。line：wood／ore／light。顧著的工人打贏了才按得動；按了 FLAGS["line_線"] = true
--
-- 劇情旗標：final（終章開始）、factory（打卡機）、line_wood／line_ore／line_light、exec1_quit（高處長下班）、
--   exec2_sleep（范經理睡著了）、elevator（第一次搭電梯）、boss（打贏社長）、factory_done（野伴加入基地）

TALK = TALK or {}

local function P() return PLAYER_NAME end

local function npc_named(name)
  for _, n in ipairs(npcs) do
    if n.name == name then return n end
  end
  return nil
end

-- 港灣圖塊第 6 列（tools/art/harbor.py）：265 + 第幾格
local BELT, BELT2 = 265 + 60, 265 + 61
local CONSOLE_OFF = 265 + 63

-- 三條生產線：顧著的工人（訓練家）、停下來時說的話、走過來的那一隻代表（E-7 加入基地）
local LINES = {
  wood = { trainer = "factory_wood", stop = "（輸送帶慢慢停下來。）", no = "07",
           rep = "一隻囤囤鼠走了過來。\n牌子上寫著：「鐵輪公司　伐木用　編號 0102」" },
  ore = { trainer = "factory_ore", stop = "（礦車「喀」地一聲停住了。）", no = "12",
          rep = "一隻礫殼犰狳走了過來。\n牌子上寫著：「鐵輪公司　礦石用　編號 0388」" },
  light = { trainer = "factory_light", stop = "（玻璃罩一個一個打開了。）", no = "10",
            rep = "一隻燈蛾飛了過來。\n牌子上寫著：「鐵輪公司　照明用　編號 0218」" },
}
local LINE_ORDER = { "wood", "ore", "light" }

function factory_lines_done()
  for _, l in ipairs(LINE_ORDER) do
    if not FLAGS["line_" .. l] then return false end
  end
  return true
end

-- ============================================================
-- 升降梯、電梯（地圖物件 lift）
-- ============================================================

local lifts = {}
local belts = {}      -- 這張地圖上輸送帶的格子（畫動畫用）
local consoles = {}

-- Studio 的欄位沒填，存起來可能是空字串 ""：Lua 裡 "" 也算「有值」，所以當成沒填（nil）
local function opt(v)
  if v == "" then return nil end
  return v
end

function lift_load()
  lifts = {}
  for _, o in ipairs(world.objects) do
    if o.type == "lift" then
      lifts[#lifts + 1] = { cx = o.x, cy = o.y, to = o.to, tx = o.tx, ty = o.ty, face = opt(o.face),
                            need = opt(o.need), flag = opt(o.flag), scene = opt(o.scene) }
      mset(world.map, "solid", o.x, o.y, 1)
    end
  end
end

function lift_at(px, py)
  local cx, cy = px // TILE, py // TILE
  for _, l in ipairs(lifts) do
    if l.cx == cx and l.cy == cy then return l end
  end
  return nil
end

-- 搭上去：畫面暗下來時換地圖（在劇情裡用 fade，不在劇情裡用 transition_start）
local function lift_warp(l)
  warp(l.to, l.tx, l.ty, 0, l.face == "up" and -1 or 1)
end

local function power_line(k)
  if k.no == "10" then return kin_name(k) .. "拍拍翅膀，電梯的燈亮了。" end   -- 燈蛾（劇本的寫法）
  return kin_name(k) .. "身上閃過一道電光，電梯的燈亮了。"
end

function lift_interact(l)
  if l.flag and not FLAGS[l.flag] then
    dialog_open("貨梯的柵門鎖著。\n告示：「鐵輪公司　施工中　閒人勿進」")
    return
  end
  -- 第一次搭：先跑劇情（終章的章節標題），劇情最後自己搭上去
  if l.scene and not FLAGS["scene_" .. l.scene] then
    cutscene_start(function()
      SCENE[l.scene]()
      set_flag("scene_" .. l.scene)
      fade(function() lift_warp(l) end)
    end)
    return
  end
  -- 要電才動的電梯（E-5）：只看隊伍裡的野伴（和其他野外技能一樣，W71b）
  local k = nil
  if l.need then
    k = field_skill_kin(l.need)
    if not k then
      dialog_open("電梯沒電了。\n按鈕按下去，一點反應也沒有。\f" .. (field_skill_hint(l.need) or ""))
      return
    end
  end
  local where = MAP_NAME[l.to] or l.to
  if k and not FLAGS.elevator then
    cutscene_start(function()
      say("電梯沒電了。")
      say(power_line(k))
      say(P() .. "：……一隻就夠了。\n不用一整條生產線。")
      set_flag("elevator")
      fade(function() lift_warp(l) end)
    end)
    return
  end
  dialog_ask("要搭" .. (l.need and "電梯" or "貨梯") .. "到" .. where .. "嗎？", { "搭", "不要" }, function(c)
    if c ~= 1 then return end
    local function go() transition_start(function() lift_warp(l) end) end
    if k then dialog_open(power_line(k), go) else go() end
  end)
end

-- ============================================================
-- 生產線的控制台（地圖物件 console）
-- ============================================================

function console_load()
  consoles, belts = {}, {}
  for _, o in ipairs(world.objects) do
    if o.type == "console" then
      consoles[#consoles + 1] = { cx = o.x, cy = o.y, line = o.line }
      mset(world.map, "solid", o.x, o.y, 1)
      if FLAGS["line_" .. o.line] then mset(world.map, "deco", o.x, o.y, CONSOLE_OFF) end
    end
  end
  if #consoles == 0 then return end
  -- 輸送帶：進地圖時找一次（之後每幀只畫這幾格，不用每幀掃整張地圖）
  for y = 0, maph(world.map) - 1 do
    for x = 0, mapw(world.map) - 1 do
      if mget(world.map, "ground", x, y) == BELT then belts[#belts + 1] = { x = x, y = y } end
    end
  end
end

function console_at(px, py)
  local cx, cy = px // TILE, py // TILE
  for _, c in ipairs(consoles) do
    if c.cx == cx and c.cy == cy then return c end
  end
  return nil
end

-- 按停止鈕（E-2）
local function stop_line(c)
  local L = LINES[c.line]
  say(P() .. "按下了紅色的停止鈕。")
  set_flag("line_" .. c.line)
  mset(world.map, "deco", c.cx, c.cy, CONSOLE_OFF)
  wait(30)
  say(L.stop)
  say("（野伴們愣在原地，\n好像不知道「停下來」是什麼意思。）")
  say(L.rep)
  if c.line == "light" and flag("moth_rescued") then
    say(P() .. "：……0217，是我在霧林救的那一隻。\n你們是一起的？")
    say("（燈蛾 0218 往霧林的方向，看了很久。）")
  end
  if factory_lines_done() then
    wait(20)
    say("（整座工廠安靜下來了。）")
    say("（大廳那邊，好像有人在等。）")
  end
end

function console_interact(c)
  if FLAGS["line_" .. c.line] then
    dialog_open("停止鈕已經按下去了。\n機器安安靜靜的。")
    return
  end
  local L = LINES[c.line]
  if not FLAGS["trainer_" .. L.trainer] then
    -- 顧著的工人還在：先跟他打
    for _, n in ipairs(npcs) do
      if n.trainer == L.trainer then
        trainer_talk(n)
        return
      end
    end
  end
  cutscene_start(function() stop_line(c) end)
end

-- 地面之後畫（world.lua）：還在跑的輸送帶，兩格圖輪流畫，看起來在動
function factory_draw()
  if #belts == 0 or FLAGS.line_wood then return end
  if (frame() // 8) % 2 == 0 then return end
  for _, b in ipairs(belts) do world_spr(BELT2, b.x * TILE, b.y * TILE) end
end

-- ============================================================
-- 進地圖（scenes.lua 的 scene_on_enter 呼叫）
-- ============================================================

-- 生產線上的野伴（劇情的小圖示）：救出來之前一直在；E-7 之後都離開了
local WORKERS = {
  { "07", 31, 18 }, { "07", 33, 18 }, { "07", 35, 18 },   -- 伐木線：輸送帶前面
  { "12", 5, 18 }, { "12", 8, 18 },                       -- 礦石線：推礦車
}

function factory_enter(map)
  if map == "factory" then
    for i = #npcs, 1, -1 do
      local n = npcs[i]
      if (n.name == "exec1" and FLAGS.exec1_quit) or (n.name == "exec2" and FLAGS.factory_done) then npc_remove(n) end
    end
    if not FLAGS.factory_done then
      for i, w in ipairs(WORKERS) do prop_add("w" .. i, w[1], w[2], w[3], i > 3) end
    end
  elseif map == "office" then
    local n = npc_named("president")
    if n and FLAGS.boss then npc_remove(n) end
  end
end

-- ============================================================
-- 劇情
-- ============================================================

-- E-0：章節標題、貨梯（火山洞的貨梯第一次搭；搭上去由 lift_interact 處理）
SCENE.e0_lift = function()
  set_flag("final")
  chapter_card(4)
  say("（貨梯「喀啦喀啦」往上爬。）")
  say(P() .. "：……我的膝蓋也是這個聲音。")
end

-- E-1：工廠大門的打卡機（事件格）
SCENE.e1_clock = function()
  face("player", "left")
  say("（門口有一台打卡機。旁邊貼著：\n「野伴打卡上工　全年無休」）")
  say(P() .. "：……公司被併購之後，\n我們的打卡機也換成這一款。")
  say(P() .. "：我的卡號是 0039。\n……居然還記得。")
  set_flag("factory")
end

-- E-3：高處長（往二樓的缺口前面；三條線都停了才讓路）
SCENE.e3_exec = function()
  face("exec1", "player")
  say("高處長：……生產線全停了。\n我的 KPI 也完了。")
  say(P() .. "：阿高。")
  say("高處長：大志，鐵輪併購我們公司那時候，\n名單一張一張發下來。")
  say("高處長：你知道你被優化那天，\n我在想什麼嗎？")
  wait(30)
  say("高處長：「還好不是我。」")
  say("高處長：然後我接了你的位子，跟著併進鐵輪，\n當上處長。每天都在等，等哪一天輪到我。")
  say("高處長：……我也不想當設備了。")
  say("高處長：這個給你。\n我抽屜裡放了很久的。")
  give("goodpotion", 3)
  say("高處長：社長在頂樓。\n電梯……你去看就知道了。")
  say("高處長：我先回家了。\n好久沒有準時下班。")
  set_flag("exec1_quit")
  walk("exec1", "down", 4)
  npc_remove(npc_named("exec1"))
end

TALK.exec1_factory = function()
  if factory_lines_done() then
    cutscene_start(SCENE.e3_exec)
  else
    dialog_open("高處長：……大志？\n你怎麼會在這裡。\f高處長：樓上是社長室。\n我不能讓你過去。" ..
      "\f高處長：生產線還在跑。\n……我的 KPI 也還在跑。")
  end
end

-- 高處長下班之後，在港灣鎮的海鮮攤（harbor.json 的 exec1h）
NPC_HOURS = NPC_HOURS or {}
NPC_HOURS.exec1_harbor = function() return FLAGS.exec1_quit == true end
TALK.exec1_harbor = "高處長：燙青菜。不加肉燥。\f高處長：醫生說我膽固醇……\n你也是吧？"

-- E-4：范經理睡著了（二樓辦公室，事件格）
SCENE.e4_sleep = function()
  say("（范經理趴在桌上睡著了。\n平板亮著：「登錄進度 87%」）")
  say(P() .. "：……四個小時，果然不夠。")
  say(P() .. "把外套蓋在范經理身上。")
  say("（我以前也常常這樣睡在公司。）")
  set_flag("exec2_sleep")
end

TALK.exec2_sleep = function()
  dialog_open("（范經理睡得很熟。\n……說夢話：「簡報……第 37 頁……」）")
end

-- E-6：社長戰（社長室，事件格）＋ E-7：野伴加入基地
SCENE.e6_boss = function()
  if flag("boss") or not npc_named("president") then return end
  face("player", "up")
  wait(20)
  say("社長：你就是大志。")
  face("president", "player")
  say("社長：我記得這個名字。\n併購你們公司的時候，優化名單上的第 39 號。")
  say("社長：你們公司以前是我們的協力廠商。\n報價不錯，人太多。")
  say("社長：所以我買下來，把多的人換掉。\n那份名單，是我簽的。")
  emote("player", "…")
  say("社長：別誤會，我沒有惡意。\n公司要活下去，總要有人被換掉。")
  say("社長：野伴也一樣。\n會累的、會餓的、會想休息的，換掉就好。")
  say(P() .. "：我也是被換掉的那一個。")
  say(P() .. "：但我後來才知道——\n被換掉，不代表沒有用。")
  say("社長：那就讓我看看，\n你這個「不良品」有多少用處。")
  if fight("boss") == "lose" then
    wiped_out("老苔：去找鐵輪的老闆吵架了？\n……當年我也想這麼做。")
    return "again"
  end
  local t = DATA.trainers.boss
  say("社長：……")
  MONEY = MONEY + t.money
  say(P() .. "拿到了 " .. money_text(t.money) .. "。")
  say("社長：我以前也有過一隻野伴。\n很久以前。")
  say("社長：牠老了、跑不動了，\n我就……把牠留在這座島上。")
  say("社長：從那之後，我就決定\n不再讓任何東西拖累我。")
  wait(30)
  say("社長：……山頂有一隻野伴，叫「雲根」。\n島上的人說，牠是這座島的根。")
  say("社長：只要登錄了牠，\n這座島就是公司的了。")
  walk("president", "up", 1)          -- 往後門（17, 2）：先上一格，再往右走（不會穿過柱子）
  walk("president", "right", 7)
  npc_remove(npc_named("president"))
  say("（社長從後門的樓梯，往山頂走去了。）")
  set_flag("boss")
  -- E-7：生產線上的野伴放回野外，三隻代表跟著回營地
  blackout(true)
  narrate("被登錄的野伴，一隻一隻走出了工廠的大門。")
  narrate("有的往山上，有的往森林，有的往海邊。")
  warp("camp", 19, 13, 0, -1)
  prop_add("r1", "07", 17, 13, true)
  prop_add("r2", "12", 18, 14, true)
  prop_add("r3", "10", 21, 13, false)
  blackout(false)
  say("老苔：……這些孩子，\n是從工廠來的？")
  say("老苔：牌子拿下來吧。\n在這裡，不用編號。")
  say(P() .. "拿下了野伴身上的牌子。")
  say("（囤囤鼠在營地的草地上滾了一圈。）")
  for _, l in ipairs(LINE_ORDER) do
    local k = kin_new(LINES[l].no, 22)
    RANCH[#RANCH + 1] = k                -- 加入基地：住在牧場，之後可以派去設施工作、帶進隊伍
    dex_caught(LINES[l].no)
  end
  say("囤囤鼠、礫殼犰狳、燈蛾\n住進了營地的牧場！")
  say("老苔：其他的野伴，都放回野外了？\n……好。牠們會記得這裡的。")
  say("老苔：剛剛老柏託人帶話來，\n說霧林晚上的燈，又多了好幾盞。")
  say("老苔：社長往山頂去了？\n那邊是雲根的地方。")
  say("老苔：年輕人，山路很陡。\n膝蓋顧好。")
  set_flag("factory_done")
end

TALK.president = function()
  cutscene_start(SCENE.e6_boss)
end
