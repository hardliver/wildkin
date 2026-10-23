-- cutscene.lua：劇情腳本（W52）
--
-- 劇情寫成「照順序的一段程式」，用 Lua 的 coroutine 一步一步跑：
--
--   SCENE.elder_stop = function()
--     emote("elder", "!")                 -- 老苔頭上冒「！」
--     walk_to("elder", "player")          -- 走到主角旁邊
--     say("老苔：等一下，年輕人！")         -- 對話框，等玩家看完
--     if ask("要帶回復藥嗎？", { "要", "不用" }) == 1 then give("potion", 2) end
--     set_flag("met_elder")
--   end
--
-- 每個工具做完才回來（說話等玩家按完、走路等走到），所以劇情照寫的順序發生。
-- 劇情跑的時候主角不能動、不會遇敵、不能開選單。戰鬥（fight）、轉場（fade）也可以放在劇情裡。
--
-- 怎麼開始一段劇情：
--   1. 地圖的物件層放 type = "event"（Studio：物件 → 事件），欄位 scene = 劇本編號：
--      主角走進那一格就開始。每段劇情只發生一次（跑完記在 FLAGS["scene_編號"]）；
--      劇本回傳 "again" 就不記，下次走進來還會再發生（例如「還沒拿到東西不能出去」）
--   2. 程式裡呼叫 cutscene_start(函式)：NPC 的對話（talk.lua）、訓練家（trainer.lua）都用這個
--
-- 角色（who）：「"player"」是主角；字串是 NPC 的 name（地圖物件的名字）；也可以直接給 NPC 表格。
-- 劇本放在 scenes.lua 的 SCENE 表格（W53 寫序章、第 1 章）。

SCENE = SCENE or {}

local co = nil        -- 正在跑的劇情
local emotes = {}     -- 頭上的氣泡 { who, kind, t }

local overlay = nil   -- 蓋住地圖的畫面：{ kind = "black" }、{ kind = "text", text }、{ kind = "chapter", n }
local props = {}      -- 劇情裡暫時放在地圖上的野伴（序章的三隻初始野伴）：props[id] = { no, x, y, right }

-- 開始一段劇情（已經有劇情在跑就不理）。有對話框開著的話，等它關掉才開始
function cutscene_start(fn)
  if co then return false end
  co = coroutine.create(function()
    while dialog_active() do coroutine.yield() end
    fn()
  end)
  return true
end

-- 直接蓋上黑畫面（新遊戲的開場：第一幀就要是黑的，不能先看到地圖）
function cutscene_blackout(on)
  overlay = on and { kind = "black" } or nil
end

function cutscene_active() return co ~= nil end

-- 停掉正在跑的劇情（除錯用：跳過序章）
function cutscene_skip()
  co = nil
  overlay = nil
end

-- main.lua 每幀呼叫：劇情開了畫面（取名、選野伴）就先給畫面；再讓對話框動，再讓劇情往下走一步
function cutscene_update()
  if ui_active() then
    ui_update()
    return
  end
  if dialog_active() then dialog_update() end
  local ok, err = coroutine.resume(co)
  if not ok then
    co = nil
    error(err, 0)
  end
  if coroutine.status(co) == "dead" then co = nil end
  world_follow(player.x16 // 16 + TILE // 2, player.y16 // 16 + TILE // 2)   -- 主角被劇情移動時，相機也跟著
end

-- 地圖上的事件格：主角走進來就開始（main.lua 在主角移動之後呼叫）
local last_cell = nil
function cutscene_check()
  local cx, cy = player_cell()
  local cell = world.name .. ":" .. cx .. ":" .. cy
  if cell == last_cell then return false end   -- 站著不動、在同一格裡走不算
  last_cell = cell
  for _, o in ipairs(world.objects) do
    if o.type == "event" and o.x == cx and o.y == cy then
      local name = o.scene
      local fn = SCENE[name]
      if fn and not FLAGS["scene_" .. name] then
        cutscene_start(function()
          if fn() ~= "again" then FLAGS["scene_" .. name] = true end
        end)
        return true
      end
    end
  end
  return false
end

-- 換地圖、讀檔之後：主角站的那一格不算「走進來」。
-- 有些劇情是「進到某張地圖時」開始（scenes.lua 的 scene_on_enter）
function cutscene_enter_map()
  local cx, cy = player_cell()
  last_cell = world.name .. ":" .. cx .. ":" .. cy
  props = {}
  if scene_on_enter then scene_on_enter(world.name) end
end

-- ============================================================
-- 劇本裡用的工具（只能在劇情裡呼叫：它們會等）
-- ============================================================

local DIR = { up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 } }

-- 角色的圖左上角（像素）
local function pos(who)
  if who == "player" then return player.x16 // 16, player.y16 // 16 end
  return who.x, who.y
end

local function actor(who)
  if who == "player" or type(who) == "table" then return who end
  for _, n in ipairs(npcs) do
    if n.name == who then return n end
  end
  error("劇情：這張地圖沒有叫 " .. tostring(who) .. " 的 NPC", 2)
end

-- 等幾幀
function wait(frames)
  for _ = 1, frames do coroutine.yield() end
end

-- 說話：等玩家看完（文字裡 \f 換頁，見 dialog.lua）
function say(text)
  dialog_open(text)
  while dialog_active() do coroutine.yield() end
end

-- 問問題：回傳選了第幾項
function ask(text, choices)
  local r = nil
  dialog_ask(text, choices, function(c) r = c end)
  while r == nil or dialog_active() do coroutine.yield() end
  return r
end

-- 面向：dir = "up"／"down"／"left"／"right"，或另一個角色（轉向他）
function face(who, dir)
  local a = actor(who)
  local d = DIR[dir]
  if not d then   -- 轉向另一個角色
    local ax, ay = pos(a)
    local bx, by = pos(actor(dir))
    if math.abs(bx - ax) >= math.abs(by - ay) then d = { bx > ax and 1 or -1, 0 }
    else d = { 0, by > ay and 1 or -1 } end
  end
  if a == "player" then
    player.dir_x, player.dir_y = d[1], d[2]
    if d[1] ~= 0 then player.facing_left = d[1] < 0 end
  elseif d[1] ~= 0 then
    a.face_left = d[1] < 0
    a.talked = frame()   -- 剛轉過來，不要馬上東張西望
  end
end

-- 往 dir 方向走 pixels 像素（每幀 1 像素，和 GB 一樣慢慢走）
local function step(a, dir, pixels)
  local d = DIR[dir]
  face(a, dir)
  for _ = 1, pixels do
    if a == "player" then
      player.x16, player.y16 = player.x16 + d[1] * 16, player.y16 + d[2] * 16
      player.walking = true
      player.walk_frames = player.walk_frames + 1
    else
      a.x, a.y = a.x + d[1], a.y + d[2]
    end
    coroutine.yield()
  end
  if a == "player" then player.walking, player.walk_frames = false, 0 end
end

-- 走一段：dir 方向走 tiles 格。劇情裡的走路不看碰撞，劇本自己安排路線
function walk(who, dir, tiles)
  step(actor(who), dir, (tiles or 1) * TILE)
end

-- 走到第 (cx, cy) 格（先橫再直）；walk_to(誰, 另一個角色)：停在他旁邊那一格
function walk_to(who, cx, cy)
  local a = actor(who)
  local x, y = pos(a)
  local tx, ty
  if cy == nil then
    local bx, by = pos(actor(cx))
    tx, ty = bx, by
    if math.abs(bx - x) >= math.abs(by - y) then tx = bx + (x < bx and -TILE or TILE)
    else ty = by + (y < by and -TILE or TILE) end
  else
    tx, ty = cx * TILE, cy * TILE
  end
  if tx ~= x then step(a, tx > x and "right" or "left", math.abs(tx - x)) end
  if ty ~= y then step(a, ty > y and "down" or "up", math.abs(ty - y)) end
end

-- 直接把角色放到第 (cx, cy) 格（通常在 fade 裡用，看不到瞬間移動）
function place(who, cx, cy)
  local a = actor(who)
  if a == "player" then player_place(cx, cy) else a.x, a.y = cx * TILE, cy * TILE end
end

-- 頭上冒氣泡：kind = "!"（發現）、"?"（疑問）、"…"（無言）、"♪"（開心）。等氣泡消失
function emote(who, kind, frames)
  local e = { who = actor(who), kind = kind or "!", t = 0 }
  emotes[#emotes + 1] = e
  wait(frames or 40)
  for i, x in ipairs(emotes) do
    if x == e then table.remove(emotes, i) break end
  end
end

-- 得到東西：放進背包，說「大志得到了回復藥 ×2！」
function give(item, n)
  n = n or 1
  bag_add(item, n)
  snd("item")
  say(PLAYER_NAME .. "得到了" .. DATA.items[item].name .. " ×" .. n .. "！")
end

-- 和訓練家對戰（data/trainers.json 的編號）。回傳 "win"／"lose"；輸了劇情停在這裡，照常回營地
function fight(trainer)
  local t = DATA.trainers[trainer]
  local result = nil
  battle_scene_start(trainer_party(t), { wild = false, trainer = t.name, flash = true }, function(r) result = r end)
  while result == nil or transition_active() do coroutine.yield() end
  if result ~= "lose" then FLAGS["trainer_" .. trainer] = true end
  return result
end

-- 畫面暗下來，全黑時做 fn（換地圖、移動 NPC），再亮起來
function fade(fn)
  local done = false
  transition_start(fn or function() end, false, { on_end = function() done = true end })
  while not done do coroutine.yield() end
end

-- 開一個畫面（取名、選野伴），等它給結果。open(完成時呼叫的函式)
function await_screen(open)
  local result = nil
  open(function(r) result = r end)
  while result == nil or ui_active() or dialog_active() do coroutine.yield() end
  return result
end

-- 黑畫面上置中的字（開場的申請表）：按 A 換下一句
function narrate(text)
  overlay = { kind = "text", text = text }
  wait(12)   -- 剛出現時不要被上一句的 A 直接跳過
  while not pressed(A) do coroutine.yield() end
  coroutine.yield()
  overlay = { kind = "black" }
end

-- 片尾（W75）：黑畫面上，一行一行字從下往上捲。lines 裡的 "" 是空一行
-- 每 2 幀往上 1 像素；全部捲出畫面就結束（按住 A 捲快 4 倍，和戰鬥加速一樣）
local CREDIT_LINE = 18
function credits_roll(lines)
  overlay = { kind = "credits", lines = lines, y = SCREEN_H * 2 }   -- y：第一行的位置 × 2（放大 2 倍才能每 2 幀動 1 像素）
  local finish = -(#lines * CREDIT_LINE) * 2
  while overlay.y > finish do
    overlay.y = overlay.y - (btn(0, A) and 4 or 1)
    coroutine.yield()
  end
  overlay = { kind = "black" }
end

-- 黑畫面（先拉百葉窗變黑）／回到地圖
function blackout(on)
  if on then fade(function() overlay = { kind = "black" } end)
  else fade(function() overlay = nil end) end
end

-- 章節標題：畫面暗下來 → 大字「第 1 章　霧林的守護者」約 2.5 秒 → 回到地圖
-- 章節標題卡顯示中：晝夜的顏色要暫停（標題卡是圖片，晚上會被染暗；clock.lua）
function cutscene_overlay_art()
  return overlay ~= nil and overlay.kind == "chapter"
end

function chapter_card(n)
  fade(function() overlay = { kind = "chapter", n = n } end)
  wait(150)
  fade(function() overlay = nil end)
end

-- 劇情裡暫時放在地圖上的野伴（小圖示，站著）。離開這張地圖就沒了
function prop_add(id, no, cx, cy, right)
  props[id] = { no = no, x = cx * TILE, y = cy * TILE, right = right }
end
function prop_remove(id) props[id] = nil end

-- 劇情旗標（存檔時一起存）
function flag(name) return FLAGS[name] == true end
function set_flag(name, v) FLAGS[name] = (v == nil) and true or v end

-- ============================================================
-- 畫氣泡（角色之後畫，世界座標）
-- ============================================================

local function bubble(x, y, kind)
  rect(x, y, 11, 12, 0)
  rect(x + 1, y + 1, 9, 10, 7)
  rect(x + 4, y + 12, 3, 2, 0)   -- 小尾巴
  rect(x + 5, y + 11, 1, 1, 7)
  if kind == "!" then
    rect(x + 4, y + 2, 2, 5, 8); rect(x + 4, y + 8, 2, 2, 8)
  elseif kind == "?" then
    rect(x + 3, y + 2, 4, 1, 12); rect(x + 7, y + 3, 1, 2, 12); rect(x + 5, y + 5, 2, 1, 12)
    rect(x + 5, y + 6, 1, 1, 12); rect(x + 5, y + 8, 1, 2, 12)
  elseif kind == "♪" then
    rect(x + 6, y + 2, 1, 6, 14); rect(x + 7, y + 2, 2, 1, 14); rect(x + 4, y + 7, 2, 2, 14)
  else   -- "…"
    for i = 0, 2 do rect(x + 2 + i * 3, y + 6, 1, 1, 0) end
  end
end

-- 給 main.lua 的 draw_actors：暫時放的野伴也依 y 排序
function cutscene_actors(list)
  for _, p in pairs(props) do
    list[#list + 1] = { y = p.y, draw = function() kin_icon_draw(p.no, p.x, p.y, false, 0, p.right) end }
  end
end

-- 蓋住地圖的畫面（在選單、對話框之前畫：取名畫面、對話框要在黑畫面上面）
local CHAPTER_W, CHAPTER_H = 256, 64   -- chapters.png 每章一格
function cutscene_overlay_draw()
  if not overlay then return end
  camera()
  rect(0, 0, SCREEN_W, SCREEN_H, 0)
  if overlay.kind == "text" then
    local lines = {}
    for l in (overlay.text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
    local y = SCREEN_H // 2 - #lines * 9
    for _, l in ipairs(lines) do
      text(l, (SCREEN_W - textw(l)) // 2, y, 7)
      y = y + 18
    end
  elseif overlay.kind == "credits" then
    local y = overlay.y // 2
    for i, l in ipairs(overlay.lines) do
      local ly = y + (i - 1) * CREDIT_LINE
      if ly > -16 and ly < SCREEN_H then text(l, (SCREEN_W - textw(l)) // 2, ly, (i == 1) and 10 or 7) end   -- 只畫看得到的行
    end
  elseif overlay.kind == "chapter" then
    sspr(IMG.chapters, 0, (overlay.n - 1) * CHAPTER_H, CHAPTER_W, CHAPTER_H,
         (SCREEN_W - CHAPTER_W) // 2, (SCREEN_H - CHAPTER_H) // 2)
  end
end

function cutscene_draw()
  for _, e in ipairs(emotes) do
    local x, y = pos(e.who)
    bubble(x + 3, y - 15, e.kind)
  end
end
