-- battle_ui.lua：戰鬥畫面（W25）
--
-- battle.lua 只管「算」，這裡只管「畫」和「讀按鍵」：
--   battle_scene_start(對手隊伍, { wild = true }, function(結果) 回到地圖後要做的事 end)
--     進場、離場的轉場都在這裡做，呼叫的人不用管；結果是 "win"／"lose"／"run"
--   _update 裡：if battle_scene_active() then battle_scene_update() return end
--   _draw 裡：  if battle_scene_active() then battle_scene_draw() else 畫地圖 end
--
-- 版面（320 × 240，design.md「戰鬥系統 → 畫面」）：
--   右上：對手正面圖 64×64，左上是牠的名字、等級、血條
--   左下：自己的背面圖 32×32 放大 2 倍，右邊是名字、等級、血條、HP 數字、經驗條
--   下方：訊息框（和對話框同一個位置，直接用 dialog.lua）＋指令選單
--
-- 畫面上的數值（view）和戰鬥的真正狀態分開：
--   battle_step 一下子就把整回合算完了，但玩家要「先看到訊息，再看到血條變少」，
--   所以畫面用自己的一份 HP、經驗、等級，事件演到哪裡才更新到哪裡（W26：血條、經驗條慢慢變化）。

-- 戰鬥背景的顏色在 battle_bg.lua（調色盤 242～252 號，開戰時照地點、時間、天氣設定）

local STATS = { "hp", "atk", "def", "spd" }
local STAT_LABEL = { hp = "最大HP", atk = "攻擊", def = "防禦", spd = "速度" }

local STATUS_TAG = { burn = { "灼傷", 8 }, paralyze = { "麻痺", 10 }, sleep = { "睡眠", 13 } }

local S = nil   -- 目前的戰鬥畫面；nil = 不在戰鬥中
-- S = {
--   b       = battle.lua 的戰鬥狀態
--   view    = { [1] = { kin, hp, exp, level }, [2] = ... }  畫面上顯示的數值
--   mode    = "msg"（演出中）／"command"（選指令）／"move"（選招式）／"done"（結束轉場中）
--   co      = 正在跑的演出（coroutine），nil = 沒有
--   fx      = 每一邊的演出狀態：hidden（閃爍中藏起來）、sink（倒下沉了幾像素）、dx（進場滑入的位移）
--   cmd     = 指令選單（戰鬥、野伴、背包、逃跑）
--   moves   = 招式選單
--   on_end  = 戰鬥結束後呼叫，參數是 b.over
-- }

-- ============================================================
-- 畫面上的數值
-- ============================================================

local function view_of(k)
  return { kin = k, hp = k.hp, exp = k.exp, exp_target = k.exp, level = k.level }
end

-- 畫面上的最大 HP 用「畫面上的等級」算（升級訊息出來之前，血條上限還是舊的）
local function view_max_hp(v)
  return kin_stat({ no = v.kin.no, level = v.level }, "hp")
end

local function refresh_view(side)
  S.view[side] = view_of(battle_active(S.b, side))
end

-- ============================================================
-- 演出：用 coroutine 照順序寫
-- ============================================================
-- 一回合的演出是「訊息 → 閃爍 → 血條慢慢減少 → 下一句訊息……」，
-- 每一步都要等好幾幀。如果用一般函式，得把它拆成一堆「做完這個再呼叫那個」的回呼；
-- 用 coroutine 就能照順序寫，每次 wait() 或 msg() 都會「暫停到下一幀再回來」。
-- battle_scene_update 每幀呼叫一次 coroutine.resume，讓它往下跑一點。

-- 等 n 幀
local function wait(n)
  for _ = 1, n do coroutine.yield() end
end

-- 顯示一句訊息，等玩家按 A 關掉
local function msg(text)
  S.last = text
  dialog_open(text)
  while dialog_active() do coroutine.yield() end
end

-- 開始一段演出（取代目前的）
local function run(fn)
  S.mode = "msg"
  S.co = coroutine.create(fn)
end

-- 等玩家按 A 或 B（加速時一幀跑好幾次，只有每幀的第一次看按鍵）
local function wait_press()
  repeat coroutine.yield() until S.input_ok and (pressed(A) or pressed(B))
end

-- 問「是／否」之類的問題，回傳選了第幾項
local function ask(text, choices)
  S.last = text
  local answer = nil
  dialog_ask(text, choices, function(i) answer = i end)
  while answer == nil do coroutine.yield() end
  return answer
end

-- 在戰鬥畫面上開一個選單（畫在 S.panel_menu），回傳選了第幾項，按 B 回傳 0
local function choose(m)
  S.panel_menu = m
  local r = nil
  repeat
    coroutine.yield()
    if S.input_ok then r = menu_update(m) end
  until r ~= nil
  S.panel_menu = nil
  return r
end

local function say(text, after)
  run(function() msg(text); after() end)
end

-- 給 battle_fx.lua 用的工具（動畫只能透過這些改畫面，不直接碰 S）
local CENTER = { { 72, 152 }, { 256, 50 } }   -- 自己、對手的圖片中心
local ctx = {
  wait = wait,
  pos = function(side) return CENTER[side][1], CENTER[side][2] end,
  offset = function(side, x, y) S.fx[side].ox, S.fx[side].oy = x, y end,
  hide = function(side, h) S.fx[side].hidden = h end,
  white = function(side, w) S.fx[side].white = w end,
  glow = function(side, g) S.fx[side].glow = g end,          -- 粉紅色的輪廓（收回、放出時）
  scale = function(side, s) S.fx[side].scale = s end,        -- 大小：0～16（16 = 原來大小），腳底對齊
  away = function(side, a) S.fx[side].away = a end,          -- 還沒上場：連資訊框都不畫
  shake = function(x, y) S.sx, S.sy = x, y end,
  overlay = function(fn) S.overlay = fn end,
}

-- 野伴球的位置（丟球、搖晃時畫；nil = 不畫）
local function set_ball(x, y, tilt)
  if x == nil then S.ball = nil else S.ball = { x = x, y = y, tilt = tilt } end
end

local function new_fx()
  return { sink = 0, dx = 0, ox = 0, oy = 0, hidden = false }
end

-- 丟球放出一隻（W65b）：訊息留在框裡（不用按 A），球飛過去、打開、野伴從白光裡長出來
-- 呼叫時這一邊的 S.view 已經是新的那一隻
local function send_out(side, text)
  S.fx[side].hidden, S.fx[side].away = true, true
  if text then S.last = text end
  fx_send_out(ctx, side, set_ball)
  wait(20)
end

-- 從 a 慢慢變到 b，總共 frames 幀，每幀呼叫 set(目前的值)
local function tween(a, b, frames, set)
  for t = 1, frames do
    set(a + (b - a) * t // frames)
    wait(1)
  end
end

-- 血條慢慢變到 to：變化越多越久（整條約 1 秒），最少 8 幀
local function slide_hp(side, to)
  local v = S.view[side]
  local frames = clamp(math.abs(to - v.hp) * 60 // view_max_hp(v), 8, 60)
  tween(v.hp, to, frames, function(x) v.hp = x end)
end

-- 經驗條慢慢增加，但最多到「下一級」為止（升級之後再繼續）
local function fill_exp(v)
  local to = v.exp_target
  if v.level < 50 then to = math.min(to, kin_exp_for(v.level + 1)) end
  if to > v.exp then tween(v.exp, to, 40, function(x) v.exp = x end) end
end

-- 倒下：往下沉進草地（24 幀）
local function sink(side)
  tween(0, 64, 24, function(x) S.fx[side].sink = x end)
end

-- 招式滿了：問要不要忘掉一招來學 key（升級、進化都會用到）
local function forget_and_learn(k, key)
  local new = DATA.moves[key].name
  while true do
    if ask("要忘掉一招，學會" .. new .. "嗎？", { "要", "不要" }) == 1 then
      local items = {}
      for i, m in ipairs(k.moves) do items[i] = DATA.moves[m.key].name end
      local m = menu_new({ items = items, x = 0, y = 0 })
      m.x, m.y = 316 - m.w, 184 - m.h
      S.last = "要忘掉哪一招呢？"
      local i = choose(m)
      if i > 0 then
        local old_name = items[i]
        kin_replace_move(k, i, key)
        msg("1、2 的……砰！")
        msg(kin_name(k) .. "忘掉了" .. old_name .. "，\n學會了" .. new .. "！")
        return
      end
    elseif ask("不學" .. new .. "了嗎？", { "對", "再想想" }) == 1 then
      msg(kin_name(k) .. "沒有學" .. new .. "。")
      return
    end
  end
end

-- ============================================================
-- 進化（W38）
-- ============================================================
-- 戰鬥結束後、離開之前：新舊兩個樣子交替閃，越閃越快；按 B 可以取消

local function evolve_scene(k, to)
  local from_name = kin_name(k)
  S.evo = { from = kin_species(k).sprite, to = DATA.species[to].sprite, show_new = false, glow = 0,
            shiny = k.shiny, from_no = k.no, to_no = to }
  S.mode = "evolve"
  msg("咦？" .. from_name .. "的樣子……！")
  -- 交替：一開始每 24 幀換一次，越來越快，最後每 2 幀換一次
  local interval, t, cancelled = 24, 0, false
  while interval > 2 do
    for _ = 1, interval do
      coroutine.yield()
      t = t + 1
      S.evo.glow = t
      if S.input_ok and pressed(B) then cancelled = true break end
    end
    if cancelled then break end
    S.evo.show_new = not S.evo.show_new
    interval = interval * 4 // 5
  end
  if cancelled then
    S.evo.show_new, S.evo.glow = false, 0
    k.evolve_skip = k.level
    msg("咦？" .. from_name .. "停止了變化。")
    S.evo = nil
    return
  end
  -- 白光一閃，變成新的樣子
  S.evo.flash = true
  snd("evolve")
  wait(12)
  S.evo.flash, S.evo.show_new, S.evo.glow = false, true, 0
  local events = kin_evolve(k, to)
  dex_caught(to)
  msg("恭喜！" .. from_name .. "進化成" .. kin_name(k) .. "了！")
  for _, e in ipairs(events) do
    if e.kind == "learn" then msg(kin_name(k) .. "學會了" .. DATA.moves[e.key].name .. "！")
    elseif e.kind == "full" then
      msg(kin_name(k) .. "想學" .. DATA.moves[e.key].name .. "，可是已經記住 4 招了。")
      forget_and_learn(k, e.key)
    end
  end
  S.evo = nil
end

-- 演出一個事件
local function show(e)
  local K = e.kind
  local v = e.side and S.view[e.side]
  local text = battle_event_text(S.b, e)
  if K == "use" then
    msg(text)                                -- 先說「○○使用了○○！」，再演招式
    snd("move_" .. DATA.moves[e.move].type)  -- 招式的聲音照屬性（sound.lua）
    fx_move(ctx, e.move, e.side, 3 - e.side)
    return
  elseif K == "damage" then
    snd(e.mult >= 4 and "hit_super" or e.mult <= 1 and "hit_weak" or "hit")
    fx_hit(ctx, e.side, e.mult)
    slide_hp(e.side, e.hp)
  elseif K == "burn_damage" then
    fx_status(ctx, e.side, "burn")
    snd("hit")
    fx_hit(ctx, e.side, 2)
    slide_hp(e.side, e.hp)
  elseif K == "stat" then
    snd(e.amount > 0 and "stat_up" or "stat_down")
    fx_stat(ctx, e.side, e.amount > 0)
  elseif K == "status" or K == "asleep" or K == "paralyzed" then
    fx_status(ctx, e.side, K == "asleep" and "sleep" or K == "paralyzed" and "paralyze" or e.status)
  elseif K == "item" and DATA.items[e.item].kind == "ball" then
    msg(text)
    local t2 = sleep_throw_text()   -- 落枕、好睏：丟球前抱怨一下（sleep.lua）
    if t2 then msg(t2) end
    snd("throw")
    fx_ball_throw(ctx, set_ball)
    return
  elseif K == "shake" then
    snd("shake")
    fx_ball_shake(ctx, set_ball)
  elseif K == "broke" then
    snd("break")
    fx_ball_break(ctx, set_ball)
  elseif K == "caught" then
    snd("caught")
    fx_ball_caught(ctx)
    msg(text)
    -- 加入隊伍（滿 6 隻送到營地的牧場，W44 之後在基地看得到）
    local k = battle_active(S.b, 2)
    dex_caught(k.no)
    if k.shiny then DEX.shiny = DEX.shiny or {}; DEX.shiny[k.no] = true end   -- 手冊標記抓過異色
    if #party < 6 then
      party[#party + 1] = k
      msg(kin_name(k) .. "加入了隊伍！")
    else
      RANCH = RANCH or {}
      RANCH[#RANCH + 1] = k
      msg("隊伍滿了，" .. kin_name(k) .. "被送到營地的牧場。")
    end
    -- 序章 P5：第一次抓到
    if not FLAGS.first_catch then
      FLAGS.first_catch = k.no
      msg(PLAYER_NAME .. "：……抓到了。")
      msg(PLAYER_NAME .. "：25 年了，手感還在。")
    end
    return
  elseif K == "item_heal" then
    snd("heal")
    if e.index == S.b.sides[e.side].active then slide_hp(e.side, e.hp) end
  elseif K == "heal" then
    snd("heal")
    slide_hp(e.side, e.hp)
  elseif K == "run" then
    if e.ok then snd("run") end
  elseif K == "faint" then
    snd("faint")
    sink(e.side)
  elseif K == "exp" then
    msg(text)
    v.exp_target = v.exp + e.amount
    fill_exp(v)
    return
  elseif K == "level" then
    local before = {}
    for _, st in ipairs(STATS) do before[st] = kin_stat({ no = v.kin.no, level = v.level }, st) end
    local old = view_max_hp(v)
    v.level = e.level
    v.hp = v.hp + view_max_hp(v) - old       -- 和 kin_gain_exp 一樣：上限加多少，目前 HP 也加多少
    snd("levelup")
    fx_levelup(ctx, e.side)
    msg(text)
    -- 能力提升的表：先顯示「+多少」，按 A 再顯示提升後的數值（和 GB 一樣）
    local lines = {}
    for _, st in ipairs(STATS) do
      local now = kin_stat({ no = v.kin.no, level = v.level }, st)
      lines[#lines + 1] = { STAT_LABEL[st], now - before[st], now }
    end
    S.panel = { lines = lines, total = false }
    wait_press()
    S.panel.total = true
    wait_press()
    S.panel = nil
    fill_exp(v)                              -- 剩下的經驗繼續加到新的一級
    return
  elseif K == "full" then
    msg(text)
    forget_and_learn(v.kin, e.key)
    return
  elseif K == "full_kin" then
    msg(text)
    forget_and_learn(S.b.sides[1].party[e.index], e.key)
    return
  elseif K == "switch" then
    -- 換野伴（W65b）：場上那隻還站著 → 先收回（白光縮進球裡）；再丟球放出新的一隻
    -- 倒下之後換人：倒下的已經沉下去了，直接丟球
    local fx = S.fx[e.side]
    if not fx.hidden and fx.sink < 64 then
      local old = kin_name(S.view[e.side].kin)
      S.last = e.side == 1 and ("回來吧，" .. old .. "！") or ((S.b.trainer or "對手") .. "收回了" .. old .. "。")
      wait(20)                              -- 訊息留在框裡，不用按 A（和丟球放出一樣）
      fx_withdraw(ctx, e.side)
    end
    if e.side == 2 then dex_seen(battle_active(S.b, 2).no) end
    refresh_view(e.side)
    S.fx[e.side] = new_fx()
    send_out(e.side, text)
    return
  end
  if text then msg(text) end
end

-- ============================================================
-- 流程
-- ============================================================

local function to_command()
  S.mode = "command"
end

-- 結束：轉場到全黑時才關掉戰鬥畫面（在那之前還是畫戰鬥），然後通知呼叫的人
local function finish()
  S.mode = "done"
  transition_start(function()
    local over, on_end = S.b.over, S.on_end
    S = nil
    map_music()        -- 回到地圖的音樂（sound.lua）
    if on_end then on_end(over) end
  end)
end

local function do_turn(choice)
  local events = battle_step(S.b, choice, battle_ai(S.b, 2))
  run(function()
    for _, e in ipairs(events) do show(e) end
    if S.b.over == "lose" then
      msg(PLAYER_NAME .. "沒有能戰鬥的野伴了！")
      msg(PLAYER_NAME .. "眼前一片漆黑……")
    end
    if S.b.over then
      if S.b.over == "win" or S.b.over == "caught" then play_music("victory") end
      if S.b.over == "lose" then play_music(nil) end
      if S.b.over ~= "lose" then
        for _, k in ipairs(party) do
          local to = kin_can_evolve(k)
          if to then evolve_scene(k, to) end
        end
      end
      return finish()
    end
    for _, e in ipairs(events) do
      if e.kind == "need_switch" then
        local i
        if e.side == 1 then
          -- 自己的野伴倒下：玩家選下一隻（不能取消、不能選倒下的）
          party_pick("要換哪一隻上場？", function(j)
            if party[j].hp <= 0 then dialog_open(kin_name(party[j]) .. "已經倒下了，不能戰鬥！") return end
            ui_clear()
            i = j
          end, { forced = true })
          while i == nil do coroutine.yield() end
        else
          i = battle_next_alive(S.b, e.side)
        end
        for _, e2 in ipairs(battle_send_out(S.b, e.side, i)) do show(e2) end
      end
    end
    to_command()
  end)
end

local function open_moves()
  local k = battle_active(S.b, 1)
  local items = {}
  for i, m in ipairs(k.moves) do items[i] = DATA.moves[m.key].name end
  S.moves = menu_new({ items = items, cols = 2, x = 4, y = 184, index = S.move_index or 1 })
  S.moves.h = 52                                   -- 和訊息框一樣高
  S.mode = "move"
end

-- ============================================================
-- 開始
-- ============================================================

local function begin(foe_party, opts, on_end)
  local o = {}
  for k, v in pairs(opts or {}) do o[k] = v end
  if o.weather == nil then o.weather = weather_now() end   -- 室外才有天氣（weather.lua）
  if o.catch_pct == nil then o.catch_pct = sleep_catch_pct() end   -- 大志的手感（sleep.lua）
  opts = o
  local b = battle_new(party, foe_party, opts)
  battle_bg_begin()   -- 背景：地點、時間、天氣（battle_bg.lua）
  S = {
    b = b, view = {}, on_end = on_end,
    fx = { new_fx(), new_fx() },   -- 演出用：hidden（閃爍）、sink（倒下）、dx（進場滑入）、ox/oy（招式動畫的位移）
    sx = 0, sy = 0,                -- 畫面晃動
    cmd = menu_new({ items = { "戰鬥", "野伴", "背包", "逃跑" }, cols = 2, x = 0, y = 0, cancel = false }),
  }
  S.cmd.x, S.cmd.y, S.cmd.h = 316 - S.cmd.w, 184, 52   -- 疊在訊息框右邊
  refresh_view(1)
  refresh_view(2)
  local foe = battle_active(b, 2)
  dex_seen(foe.no)
  -- 自己的野伴還在球裡（W65b：丟球才出來）；訓練家的野伴也是
  S.fx[1].hidden, S.fx[1].away = true, true
  if not b.wild then S.fx[2].hidden, S.fx[2].away = true, true end
  run(function()
    -- 進場：野生的對手從左邊滑進來（GB 的開場）
    tween(240, 0, 40, function(x) S.fx[2].dx = -x end)
    if b.wild then
      if foe.shiny then fx_shiny_sparkle(ctx) end    -- 異色：閃一下星星
      msg("野生的" .. kin_name(foe) .. "出現了！")
      if foe.shiny then msg("……咦？這隻的顏色好像不太一樣！") end
    else
      msg((b.trainer or "對手") .. "要和你對戰！")
      send_out(2, (b.trainer or "對手") .. "派出了" .. kin_name(foe) .. "！")
    end
    send_out(1, "上吧！" .. kin_name(battle_active(b, 1)) .. "！")
    local wt = weather_battle_text(b.weather)
    if wt then msg(wt) end
    -- 序章 P4：第一場野生戰教怎麼抓（只說一次）
    if b.wild and not FLAGS.first_wild then
      FLAGS.first_wild = true
      msg("先把牠的 HP 打少一點，再丟野伴球，\n比較容易抓到。")
      msg("睡著、麻痺的野伴也比較好抓。")
    end
    to_command()
  end)
end

-- 進場：轉場到全黑時換成戰鬥畫面
function battle_scene_start(foe_party, opts, on_end)
  -- 戰鬥的音樂：野生和訓練家不一樣；野生的先「唰」一聲（sound.lua）
  local wild = opts and opts.wild
  if wild then snd("encounter") end
  play_music(wild and "battle" or "trainer")
  transition_start(function() begin(foe_party, opts, on_end) end, opts and opts.flash)
end

function battle_scene_active()
  return S ~= nil
end

-- ============================================================
-- 每幀
-- ============================================================

-- 演出往前跑一幀；first = 這一幀的第一次（只有第一次看按鍵）
local function step_show(first)
  S.input_ok = first
  if dialog_active() then dialog_update(not first) end
  local co = S.co
  local ok, err = coroutine.resume(co)
  if not ok then error(err) end
  if S and S.co == co and coroutine.status(co) == "dead" then S.co = nil end
end

local FAST = 4   -- 按住 A 時演出幾倍速（W27）

function battle_scene_update()
  if ui_active() then
    ui_update()
    return
  end
  if S.co then
    -- 按住 A：一幀跑 4 次（動畫、血條、字一起變快）；訊息還是要「按一下」才會換下一句
    local n = btn(0, A) and FAST or 1
    for i = 1, n do
      if not (S and S.co) then break end
      step_show(i == 1)
    end
    return
  end
  if S.mode == "command" then
    local r = menu_update(S.cmd)
    if r == 1 then
      open_moves()
    elseif r == 2 then
      party_open("battle", function(i)
        do_turn({ kind = "switch", index = i })
      end, S.b.sides[1].active)
    elseif r == 3 then
      bag_open("battle", function(key, i)
        do_turn({ kind = "item", item = key, target = i })
      end, { wild = S.b.wild })
    elseif r == 4 then
      if S.b.wild then
        do_turn({ kind = "run" })
      else
        say("不能從對戰中逃走！", to_command)   -- 訓練家戰：不花掉這回合
      end
    end
  elseif S.mode == "move" then
    local r = menu_update(S.moves)
    if r == 0 then
      to_command()
    elseif r then
      S.move_index = r
      if battle_active(S.b, 1).moves[r].pp <= 0 then
        say("這招已經沒有次數了！", open_moves)
      else
        do_turn({ kind = "move", index = r })
      end
    end
  end
end

-- ============================================================
-- 畫面
-- ============================================================

-- 實心橢圓（腳下的草地平台）：每一列算出半寬，用整數平方根，不用小數
local function isqrt(n)
  local r = 0
  while (r + 1) * (r + 1) <= n do r = r + 1 end
  return r
end

-- 每一列的半寬只跟 rx、ry 有關：算一次存起來（每幀重算平方根很花 Lua 指令，運算預算 W62）
local ellipse_rows = {}
local function ellipse(cx, cy, rx, ry, c)
  local k = rx * 1000 + ry
  local rows = ellipse_rows[k]
  if not rows then
    rows = {}
    for dy = -ry, ry do rows[dy + ry + 1] = isqrt(rx * rx * (ry * ry - dy * dy) // (ry * ry)) end
    ellipse_rows[k] = rows
  end
  for dy = -ry, ry do
    local hw = rows[dy + ry + 1]
    rect(cx - hw, cy + dy, hw * 2 + 1, 1, c)
  end
end

local function platform(cx, cy, rx, ry)
  battle_bg_platform(cx, cy, rx, ry, ellipse)   -- battle_bg.lua
end

-- 血條：外框黑、底白；剩一半以上綠、五分之一以上黃、更少紅（GB 的規則）
local function hp_bar(x, y, w, hp, max)
  text("HP", x, y - 5, 0)
  local bx = x + 20
  local bw = w - 20
  rect(bx, y, bw, 6, 0)
  rect(bx + 1, y + 1, bw - 2, 4, 7)
  local inner = bw - 2
  local fill = inner * hp // max
  if hp > 0 and fill == 0 then fill = 1 end   -- 還活著就至少留 1 像素
  local c = 11
  if hp * 2 <= max then c = 10 end
  if hp * 5 <= max then c = 8 end
  if fill > 0 then rect(bx + 1, y + 1, fill, 4, c) end
end

local function exp_bar(x, y, w, v)
  local lo, hi = kin_exp_for(v.level), kin_exp_for(v.level + 1)
  local fill = 0
  if v.level < 50 then fill = (w - 2) * (v.exp - lo) // (hi - lo) end
  fill = clamp(fill, 0, w - 2)
  rect(x, y, w, 4, 0)
  rect(x + 1, y + 1, w - 2, 2, 7)
  if fill > 0 then rect(x + 1, y + 1, fill, 2, 12) end
end

-- 名字＋等級＋狀態；回傳下一行的 y
local function name_line(v, x, right, y)
  text(kin_name(v.kin), x, y, 0)
  local lv = "Lv" .. v.level
  text(lv, right - textw(lv), y, 0)
  local tag = v.kin.status and STATUS_TAG[v.kin.status]
  if tag then
    local tx = x + textw(kin_name(v.kin)) + 6
    rect(tx - 2, y + 1, textw(tag[1]) + 4, 13, tag[2])
    text(tag[1], tx, y, 7)
  end
end

-- 資訊框：圓角的面板（2026-10-22 戰鬥畫面改版：背景有圖了，字要有底才看得清楚）
local function info_panel(x, y, w, h)
  -- 每個像素只塗一次（運算預算：一開始疊了好幾層長方形，一個面板就塗了 4 倍的像素）
  rect(x + 2, y + 2, w - 4, h - 4, 7)                                  -- 底
  rect(x + 2, y, w - 4, 2, 0); rect(x + 2, y + h - 2, w - 4, 2, 0)     -- 上下框（2 像素）
  rect(x, y + 2, 2, h - 4, 0); rect(x + w - 2, y + 2, 2, h - 4, 0)     -- 左右框
  rect(x + 1, y + 1, 1, 1, 0); rect(x + w - 2, y + 1, 1, 1, 0)         -- 圓角
  rect(x + 1, y + h - 2, 1, 1, 0); rect(x + w - 2, y + h - 2, 1, 1, 0)
end

-- 野伴的圖：閃爍時不畫；倒下時往下沉（只畫上面的部分、往下移，看起來像沉進草地）
-- 剪影（W64 的 dpal：把每個顏色都換成同一色）
--   被打到的那一下：整隻變成深色（戰鬥背景是淺米色，白色剪影看不出來）
--   進化中：背景變暗，野伴變成白色的輪廓
--   收回、放出：粉紅色的光（米色背景上白色看不清楚；W65b）
WHITE_MAP, HIT_MAP, GLOW_MAP = {}, {}, {}
for i = 1, 255 do WHITE_MAP[i] = 7; HIT_MAP[i] = 1; GLOW_MAP[i] = 14 end
-- 填好就不會再改：放進唯讀區（主機省 RAM，每張約 4 KB）
WHITE_MAP, HIT_MAP, GLOW_MAP = freeze(WHITE_MAP), freeze(HIT_MAP), freeze(GLOW_MAP)

local function draw_foe()
  local v, fx = S.view[2], S.fx[2]
  if fx.hidden or fx.sink >= 64 then return end
  local n = kin_species(v.kin).sprite
  if fx.white then dpal(HIT_MAP) elseif fx.glow then dpal(GLOW_MAP) else kin_dpal(v.kin) end
  if fx.scale and fx.scale < 16 then
    -- 收回／放出：從腳底中心縮小、放大
    local w = 64 * fx.scale // 16
    if w > 0 then sspr(IMG.kin_front, n * 64, 0, 64, 64, 256 - w // 2 + fx.dx, 82 - w, w, w) end
  else
    sspr(IMG.kin_front, n * 64, 0, 64, 64 - fx.sink, 224 + fx.dx + fx.ox, 18 + fx.sink + fx.oy)
  end
  dpal()
end

local function draw_mine()
  local v, fx = S.view[1], S.fx[1]
  if fx.hidden or fx.sink >= 64 then return end
  local n = kin_species(v.kin).sprite
  local h = (64 - fx.sink) // 2                                          -- 原圖要畫幾列（放大 2 倍前）
  if fx.white then dpal(HIT_MAP) elseif fx.glow then dpal(GLOW_MAP) else kin_dpal(v.kin) end
  if fx.scale and fx.scale < 16 then
    local w = 64 * fx.scale // 16
    if w > 0 then sspr(IMG.kin_back, n * 32, 0, 32, 32, 72 - w // 2 + fx.dx, 184 - w, w, w) end
  else
    sspr(IMG.kin_back, n * 32, 0, 32, h, 40 + fx.dx + fx.ox, 120 + 64 - h * 2 + fx.oy, 64, h * 2)   -- 背面圖放大 2 倍
  end
  dpal()
end

local function draw_evolution()
  local E = S.evo
  cls(E.glow > 0 and 1 or 7)   -- 變化中背景變暗（深藍），白色的輪廓才看得清楚
  -- 背後的光：一圈一圈往外擴散
  for k = 0, 3 do
    local r = (E.glow * 2 + k * 18) % 72
    if E.glow > 0 then fx_ring(160, 88, r + 10, (k % 2 == 0) and 7 or 10) end
  end
  local n = E.show_new and E.to or E.from
  if E.glow > 0 then dpal(WHITE_MAP) elseif E.shiny then dpal(shiny_map(E.show_new and E.to_no or E.from_no)) end   -- 變化中：只看得到白色的輪廓
  sspr(IMG.kin_front, n * 64, 0, 64, 64, 112, 40, 96, 96)   -- 放大 1.5 倍
  dpal()
  if E.flash then rect(0, 0, SCREEN_W, 184, 7) end
  if not dialog_active() then
    ui_box(4, 184, 312, 52)
    if S.last then text(S.last, 14, 192, 0) end
  end
end

function battle_scene_draw()
  camera()
  if S.evo then return draw_evolution() end
  battle_bg_draw()   -- 地點的背景（battle_bg.lua），包含清畫面

  -- 場地和野伴（會跟著畫面晃動）
  camera(S.sx, S.sy)
  platform(256, 78, 50, 11)
  platform(72, 178, 60, 12)
  draw_foe()
  draw_mine()
  camera()
  -- 雨、雪、花瓣：和地圖上同一套（室內沒有）
  if not S.evo then
    season_weather_draw()
    weather_draw()
  end

  -- 對手：左上的資訊（還沒上場不畫）
  local f = S.view[2]
  if not S.fx[2].away then
    info_panel(10, 6, 152, 42)
    name_line(f, 18, 150, 12)
    hp_bar(26, 34, 124, f.hp, view_max_hp(f))
  end

  -- 自己：右下的資訊
  local m = S.view[1]
  if not S.fx[1].away then
    info_panel(162, 98, 152, 72)
    name_line(m, 170, 304, 104)
    hp_bar(178, 126, 126, m.hp, view_max_hp(m))
    local nums = m.hp .. "/" .. view_max_hp(m)
    text(nums, 304 - textw(nums), 134, 0)
    text("EXP", 170, 150, 0)
    exp_bar(198, 155, 106, m)
  end

  if S.ball then fx_draw_ball(S.ball.x, S.ball.y, S.ball.tilt) end

  -- 招式動畫（蓋在資訊上面，也跟著晃）
  if S.overlay then
    camera(S.sx, S.sy)
    S.overlay()
    camera()
  end

  -- 下方：訊息框和選單（訊息播放中由 dialog_draw 畫）
  if (S.mode == "msg" or S.mode == "done") and not dialog_active() then
    -- 動畫中沒有對話框：留著上一句話（和 GB 一樣），版面才不會跳
    ui_box(4, 184, 312, 52)
    if S.last and textw(S.last) <= 292 then text(S.last, 14, 192, 0) end
  elseif S.mode == "command" then
    ui_box(4, 184, 312, 52)
    text("要讓" .. kin_name(m.kin), 14, 192, 0)
    text("做什麼呢？", 14, 208, 0)
    menu_draw(S.cmd)
  elseif S.mode == "move" then
    menu_draw(S.moves)
    -- 右邊：游標所在招式的屬性和剩餘次數
    local mv = battle_active(S.b, 1).moves[S.moves.index]
    local d = DATA.moves[mv.key]
    local ix = S.moves.x + S.moves.w + 4
    ui_box(ix, 184, 316 - ix, 52)
    text("屬性 " .. DATA.types.names[d.type], ix + 10, 192, 0)
    text("次數 " .. mv.pp .. "/" .. d.pp, ix + 10, 208, mv.pp > 0 and 0 or 8)
  end

  -- 升級時的能力表（右上，蓋在資訊上面）
  if S.panel then
    local x, y, w, h = 180, 40, 132, 4 * 16 + 18
    ui_box(x, y, w, h)
    for i, l in ipairs(S.panel.lines) do
      local ly = y + 9 + (i - 1) * 16
      text(l[1], x + 10, ly, 0)
      local v = S.panel.total and tostring(l[3]) or ("+" .. l[2])
      text(v, x + w - 10 - textw(v), ly, 0)
    end
  end
  if S.panel_menu then
    menu_draw(S.panel_menu)
    if S.last and not dialog_active() then
      ui_box(4, 184, 312, 52)
      text(S.last, 14, 192, 0)
    end
  end

  ui_draw()   -- 背包、選野伴（screens.lua）
end
