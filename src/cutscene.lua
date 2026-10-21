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

-- 開始一段劇情（已經有劇情在跑就不理）
function cutscene_start(fn)
  if co then return false end
  co = coroutine.create(fn)
  return true
end

function cutscene_active() return co ~= nil end

-- main.lua 每幀呼叫：先讓對話框動，再讓劇情往下走一步
function cutscene_update()
  if dialog_active() then dialog_update() end
  local ok, err = coroutine.resume(co)
  if not ok then
    co = nil
    error(err, 0)
  end
  if coroutine.status(co) == "dead" then co = nil end
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

-- 換地圖、讀檔之後：主角站的那一格不算「走進來」
function cutscene_enter_map()
  local cx, cy = player_cell()
  last_cell = world.name .. ":" .. cx .. ":" .. cy
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

function cutscene_draw()
  for _, e in ipairs(emotes) do
    local x, y = pos(e.who)
    bubble(x + 3, y - 15, e.kind)
  end
end
