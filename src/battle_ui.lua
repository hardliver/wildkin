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

-- 戰鬥畫面自己的顏色（圖片的顏色從 16 號往上排，這裡用最後面幾號，不會撞到）
local C_SKY, C_GROUND, C_GROUND_EDGE = 250, 251, 252
pal(C_SKY, 240, 242, 224)
pal(C_GROUND, 202, 222, 160)
pal(C_GROUND_EDGE, 150, 182, 112)

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

-- 演出一個事件
local function show(e)
  local K = e.kind
  local v = e.side and S.view[e.side]
  local text = battle_event_text(S.b, e)
  if K == "use" then
    msg(text)                                -- 先說「○○使用了○○！」，再演招式
    fx_move(ctx, e.move, e.side, 3 - e.side)
    return
  elseif K == "damage" then
    fx_hit(ctx, e.side, e.mult)
    slide_hp(e.side, e.hp)
  elseif K == "burn_damage" then
    fx_status(ctx, e.side, "burn")
    fx_hit(ctx, e.side, 2)
    slide_hp(e.side, e.hp)
  elseif K == "stat" then
    fx_stat(ctx, e.side, e.amount > 0)
  elseif K == "status" or K == "asleep" or K == "paralyzed" then
    fx_status(ctx, e.side, K == "asleep" and "sleep" or K == "paralyzed" and "paralyze" or e.status)
  elseif K == "item" and DATA.items[e.item].kind == "ball" then
    msg(text)
    fx_ball_throw(ctx, set_ball)
    return
  elseif K == "shake" then
    fx_ball_shake(ctx, set_ball)
  elseif K == "broke" then
    fx_ball_break(ctx, set_ball)
  elseif K == "caught" then
    fx_ball_caught(ctx)
    msg(text)
    -- 加入隊伍（滿 6 隻送到營地的牧場，W44 之後在基地看得到）
    local k = battle_active(S.b, 2)
    if #party < 6 then
      party[#party + 1] = k
      msg(kin_name(k) .. "加入了隊伍！")
    else
      RANCH = RANCH or {}
      RANCH[#RANCH + 1] = k
      msg("隊伍滿了，" .. kin_name(k) .. "被送到營地的牧場。")
    end
    return
  elseif K == "item_heal" then
    if e.index == S.b.sides[e.side].active then slide_hp(e.side, e.hp) end
  elseif K == "heal" then
    slide_hp(e.side, e.hp)
  elseif K == "faint" then
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
    -- 招式滿了：問要不要忘掉一招
    local k = v.kin
    local new = DATA.moves[e.key].name
    msg(text)
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
          kin_replace_move(k, i, e.key)
          msg("1、2 的……砰！")
          msg(kin_name(k) .. "忘掉了" .. old_name .. "，\n學會了" .. new .. "！")
          return
        end
      elseif ask("不學" .. new .. "了嗎？", { "對", "再想想" }) == 1 then
        msg(kin_name(k) .. "沒有學" .. new .. "。")
        return
      end
    end
  elseif K == "switch" then
    refresh_view(e.side)
    S.fx[e.side] = new_fx()
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
    if S.b.over then return finish() end
    for _, e in ipairs(events) do
      if e.kind == "need_switch" then
        -- 倒下之後換下一隻（玩家這邊之後改成自己選，W35）
        local i = battle_next_alive(S.b, e.side)
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
  local b = battle_new(party, foe_party, opts)
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
  run(function()
    -- 進場：對手從左邊、自己從右邊滑進來（GB 的開場）
    tween(240, 0, 40, function(x) S.fx[2].dx = -x; S.fx[1].dx = x end)
    if b.wild then
      msg("野生的" .. kin_name(foe) .. "出現了！")
    else
      msg((b.trainer or "對手") .. "要和你對戰！")
      msg((b.trainer or "對手") .. "派出了" .. kin_name(foe) .. "！")
    end
    msg("上吧！" .. kin_name(battle_active(b, 1)) .. "！")
    to_command()
  end)
end

-- 進場：轉場到全黑時換成戰鬥畫面
function battle_scene_start(foe_party, opts, on_end)
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
      say(#party > 1 and "換人的選單在 W35 才會做好。" or "沒有其他可以換上的野伴。", to_command)
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

local function ellipse(cx, cy, rx, ry, c)
  for dy = -ry, ry do
    local hw = isqrt(rx * rx * (ry * ry - dy * dy) // (ry * ry))
    rect(cx - hw, cy + dy, hw * 2 + 1, 1, c)
  end
end

local function platform(cx, cy, rx, ry)
  ellipse(cx, cy, rx, ry, C_GROUND_EDGE)
  ellipse(cx, cy - 1, rx - 2, ry - 2, C_GROUND)
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

-- GB 的資訊框：只有兩條線（一條直的、一條橫的）圍著
local function bracket(x1, x2, y_top, y_bottom, side_x)
  rect(side_x, y_top, 2, y_bottom - y_top + 1, 0)
  rect(x1, y_bottom, x2 - x1 + 1, 2, 0)
end

-- 野伴的圖：閃爍時不畫；倒下時往下沉（只畫上面的部分、往下移，看起來像沉進草地）
local function draw_foe()
  local v, fx = S.view[2], S.fx[2]
  if fx.hidden or fx.sink >= 64 then return end
  local n = kin_species(v.kin).sprite
  sspr(IMG.kin_front, n * 64, 0, 64, 64 - fx.sink, 224 + fx.dx + fx.ox, 18 + fx.sink + fx.oy)
end

local function draw_mine()
  local v, fx = S.view[1], S.fx[1]
  if fx.hidden or fx.sink >= 64 then return end
  local n = kin_species(v.kin).sprite
  local h = (64 - fx.sink) // 2                                          -- 原圖要畫幾列（放大 2 倍前）
  sspr(IMG.kin_back, n * 32, 0, 32, h, 40 + fx.dx + fx.ox, 120 + 64 - h * 2 + fx.oy, 64, h * 2)   -- 背面圖放大 2 倍
end

function battle_scene_draw()
  camera()
  cls(C_SKY)

  -- 場地和野伴（會跟著畫面晃動）
  camera(S.sx, S.sy)
  platform(256, 78, 50, 11)
  platform(72, 178, 60, 12)
  draw_foe()
  draw_mine()
  camera()

  -- 對手：左上的資訊
  local f = S.view[2]
  name_line(f, 18, 150, 12)
  hp_bar(26, 34, 124, f.hp, view_max_hp(f))
  bracket(14, 156, 30, 44, 14)

  -- 自己：右下的資訊
  local m = S.view[1]
  name_line(m, 170, 304, 104)
  hp_bar(178, 126, 126, m.hp, view_max_hp(m))
  local nums = m.hp .. "/" .. view_max_hp(m)
  text(nums, 304 - textw(nums), 134, 0)
  text("EXP", 170, 150, 0)
  exp_bar(198, 155, 106, m)
  bracket(166, 310, 122, 166, 308)

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
