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
--   所以畫面用自己的一份 HP、經驗、等級，事件演到哪裡才更新到哪裡（W26 再把它變成慢慢減少）。

-- 戰鬥畫面自己的顏色（圖片的顏色從 16 號往上排，這裡用最後面幾號，不會撞到）
local C_SKY, C_GROUND, C_GROUND_EDGE = 250, 251, 252
pal(C_SKY, 240, 242, 224)
pal(C_GROUND, 202, 222, 160)
pal(C_GROUND_EDGE, 150, 182, 112)

local STATUS_TAG = { burn = { "灼傷", 8 }, paralyze = { "麻痺", 10 }, sleep = { "睡眠", 13 } }

local S = nil   -- 目前的戰鬥畫面；nil = 不在戰鬥中
-- S = {
--   b       = battle.lua 的戰鬥狀態
--   view    = { [1] = { kin, hp, exp, level }, [2] = ... }  畫面上顯示的數值
--   mode    = "msg"（訊息播放中，交給 dialog）／"command"（選指令）／"move"（選招式）
--   cmd     = 指令選單（戰鬥、野伴、背包、逃跑）
--   moves   = 招式選單
--   on_end  = 戰鬥結束後呼叫，參數是 b.over
-- }

-- ============================================================
-- 畫面上的數值
-- ============================================================

local function view_of(k)
  return { kin = k, hp = k.hp, exp = k.exp, level = k.level }
end

-- 畫面上的最大 HP 用「畫面上的等級」算（升級訊息出來之前，血條上限還是舊的）
local function view_max_hp(v)
  return kin_stat({ no = v.kin.no, level = v.level }, "hp")
end

local function refresh_view(side)
  S.view[side] = view_of(battle_active(S.b, side))
end

-- 事件演到這一個時，畫面跟著更新
local function apply(e)
  local v = e.side and S.view[e.side]
  local K = e.kind
  if K == "damage" or K == "heal" or K == "burn_damage" then v.hp = e.hp
  elseif K == "exp" then v.exp = v.exp + e.amount
  elseif K == "level" then
    local old = view_max_hp(v)
    v.level = e.level
    v.hp = v.hp + view_max_hp(v) - old       -- 和 kin_gain_exp 一樣：上限加多少，目前 HP 也加多少
  elseif K == "switch" then refresh_view(e.side)
  end
end

-- ============================================================
-- 訊息：一串文字依序用對話框播放
-- ============================================================

-- 依序演出事件，演完呼叫 done
local function play(events, done)
  local i = 0
  local function next_event()
    i = i + 1
    local e = events[i]
    if not e then return done() end
    apply(e)
    local t = battle_event_text(S.b, e)
    if t then dialog_open(t, next_event) else next_event() end
  end
  S.mode = "msg"
  next_event()
end

local function say(text, done)
  S.mode = "msg"
  dialog_open(text, done)
end

-- ============================================================
-- 流程
-- ============================================================

local to_command   -- 下面才定義（after_turn 會用到）

-- 結束：轉場到全黑時才關掉戰鬥畫面（在那之前還是畫戰鬥），然後通知呼叫的人
local function finish()
  S.mode = "done"
  transition_start(function()
    local over, on_end = S.b.over, S.on_end
    S = nil
    if on_end then on_end(over) end
  end)
end

-- 一回合演完：結束了就離開；有一邊倒下就換下一隻；不然回到選指令
local function after_turn(events)
  if S.b.over then return finish() end
  for _, e in ipairs(events) do
    if e.kind == "need_switch" then
      -- 倒下之後換下一隻（玩家這邊之後改成自己選，W35）
      local i = battle_next_alive(S.b, e.side)
      return play(battle_send_out(S.b, e.side, i), function() after_turn({}) end)
    end
  end
  to_command()
end

local function do_turn(choice)
  local events = battle_step(S.b, choice, battle_ai(S.b, 2))
  play(events, function() after_turn(events) end)
end

to_command = function()
  S.mode = "command"
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
    cmd = menu_new({ items = { "戰鬥", "野伴", "背包", "逃跑" }, cols = 2, x = 0, y = 0, cancel = false }),
  }
  S.cmd.x, S.cmd.y, S.cmd.h = 316 - S.cmd.w, 184, 52   -- 疊在訊息框右邊
  refresh_view(1)
  refresh_view(2)
  local foe = battle_active(b, 2)
  local intro = (b.wild and "野生的" or "對手派出了") .. kin_name(foe) .. (b.wild and "出現了！" or "！")
  say(intro, function()
    say("上吧！" .. kin_name(battle_active(b, 1)) .. "！", to_command)
  end)
end

-- 進場：轉場到全黑時換成戰鬥畫面
function battle_scene_start(foe_party, opts, on_end)
  transition_start(function() begin(foe_party, opts, on_end) end)
end

function battle_scene_active()
  return S ~= nil
end

-- ============================================================
-- 每幀
-- ============================================================

function battle_scene_update()
  if dialog_active() then
    dialog_update()
    return
  end
  if S.mode == "command" then
    local r = menu_update(S.cmd)
    if r == 1 then
      open_moves()
    elseif r == 2 then
      say(#party > 1 and "換人的選單在 W35 才會做好。" or "沒有其他可以換上的野伴。", to_command)
    elseif r == 3 then
      say("背包裡什麼都沒有。", to_command)
    elseif r == 4 then
      do_turn({ kind = "run" })
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

local function draw_foe()
  local v = S.view[2]
  if v.hp <= 0 then return end   -- 倒下就不畫（W26 加上往下沉的動畫）
  spr(IMG.kin_front, kin_species(v.kin).sprite, 224, 18)
end

local function draw_mine()
  local v = S.view[1]
  if v.hp <= 0 then return end
  local n = kin_species(v.kin).sprite
  sspr(IMG.kin_back, n * 32, 0, 32, 32, 40, 120, 64, 64)   -- 背面圖放大 2 倍
end

function battle_scene_draw()
  camera()
  cls(C_SKY)

  -- 對手：右上
  platform(256, 78, 50, 11)
  draw_foe()
  local f = S.view[2]
  name_line(f, 18, 150, 12)
  hp_bar(26, 34, 124, f.hp, view_max_hp(f))
  bracket(14, 156, 30, 44, 14)

  -- 自己：左下
  platform(72, 178, 60, 12)
  draw_mine()
  local m = S.view[1]
  name_line(m, 170, 304, 104)
  hp_bar(178, 126, 126, m.hp, view_max_hp(m))
  local nums = m.hp .. "/" .. view_max_hp(m)
  text(nums, 304 - textw(nums), 134, 0)
  text("EXP", 170, 150, 0)
  exp_bar(198, 155, 106, m)
  bracket(166, 310, 122, 166, 308)

  -- 下方：訊息框和選單（訊息播放中由 dialog_draw 畫）
  if S.mode == "command" then
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
end
