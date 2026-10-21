-- battle.lua：回合制戰鬥的「邏輯」（不畫畫面、不讀按鍵）
--
-- 用法：
--   local b = battle_new({ kin_new("01", 5) }, { kin_new("07", 3) }, { wild = true })
--   local events = battle_step(b, { kind = "move", index = 1 }, battle_ai(b, 2))
--   -- events：這回合發生的事，依順序排好，畫面照著一個一個演出（W26）
--   -- b.over：戰鬥結束時是 "win"、"lose"、"run"、"caught"，還沒結束是 nil
--
-- 為什麼和畫面分開（design.md「為連線對戰預留」）：
--   戰鬥只由「目前狀態 + 雙方選了什麼」決定，算出新的狀態和事件。
--   連線對戰時兩台機器只要交換「選了哪一招」，各自算出一模一樣的結果；
--   也可以不開畫面跑 1000 場，做平衡試算（W61）。
--   亂數只用 rnd()，而且每次呼叫的順序固定，所以同一個種子一定得到同一場戰鬥。
--
-- 雙方叫 side 1（玩家）、side 2（對手）。選擇（choice）有：
--   { kind = "move", index = 1～4 }   使用第幾招
--   { kind = "switch", index = 隊伍第幾隻 }
--   { kind = "run" }                  逃跑（只有野生戰）
--   { kind = "item", item = "potion", target = 隊伍第幾隻 }   用道具（W33）。背包的數量由畫面那邊扣
--   { kind = "item", item = "ball" }            丟野伴球（W34，只有野生戰；畫面那邊會擋）

local STAGE_MIN, STAGE_MAX = -3, 3
local STAT_NAMES = { atk = "攻擊", def = "防禦", spd = "速度" }

-- ============================================================
-- 建立
-- ============================================================

local function new_side(party)
  return { party = party, active = 1, stages = { atk = 0, def = 0, spd = 0 } }
end

-- opts.wild：野生戰（可以逃跑、打贏得到經驗）
function battle_new(party, foe_party, opts)
  opts = opts or {}
  return {
    sides = { new_side(party), new_side(foe_party) },
    wild = opts.wild or false,
    trainer = opts.trainer,   -- 訓練家的名字（訊息用：「阿穗的炭毛狸使用了……」）
    turn = 0,
    run_tries = 0,
    over = nil,
  }
end

function battle_active(b, side)
  local s = b.sides[side]
  return s.party[s.active]
end

local function other(side) return 3 - side end

-- 隊伍裡還有沒有能戰鬥的
local function has_alive(party)
  for _, k in ipairs(party) do
    if k.hp > 0 then return true end
  end
  return false
end

-- ============================================================
-- 數值
-- ============================================================

-- 能力階段（-3～+3）：能力 × (2 + max(階, 0)) // (2 + max(-階, 0))
local function staged(value, stage)
  return value * (2 + math.max(stage, 0)) // (2 + math.max(-stage, 0))
end

-- 戰鬥中的能力值：基礎能力 → 能力階段 → 狀態（灼傷攻擊減半、麻痺速度剩 1/4）
function battle_stat(b, side, stat)
  local k = battle_active(b, side)
  local v = staged(kin_stat(k, stat), b.sides[side].stages[stat])
  if stat == "atk" and k.status == "burn" then v = v // 2 end
  if stat == "spd" and k.status == "paralyze" then v = v // 4 end
  return math.max(v, 1)
end

-- 屬性相剋倍率（× 2 的整數：4 = 效果絕佳、2 = 一般、1 = 效果不好、0 = 沒效）
function type_mult(move_type, target_type)
  local row = DATA.types.chart[move_type]
  local v = row and row[target_type]
  if v == nil then return 2 end
  return v
end

-- 傷害公式（design.md）。roll：亂數 85～100，由呼叫的人決定（測試時可以指定）
--   基本 = (等級 × 2 // 5 + 2) × 威力 × 攻擊 // 防禦 // 50 + 2
--   同屬性 × 3 // 2，相剋 × 倍率 // 2，亂數 × roll // 100
-- 回傳傷害、相剋倍率
function battle_damage(level, power, atk, def, move_type, user_type, target_type, roll)
  local d = (level * 2 // 5 + 2) * power * atk // def // 50 + 2
  if move_type == user_type then d = d * 3 // 2 end
  local mult = type_mult(move_type, target_type)
  d = d * mult // 2
  d = d * roll // 100
  if mult > 0 then d = math.max(d, 1) end
  return d, mult
end

-- ============================================================
-- 一回合
-- ============================================================

-- 誰先動：換人、逃跑一定先；都出招時，「必定先動」的招先，再比速度，同速擲硬幣
local function priority(b, side, choice)
  if choice.kind ~= "move" then return 2 end
  local key = battle_active(b, side).moves[choice.index].key
  local e = DATA.moves[key].effect
  if e and e.kind == "first" then return 1 end
  return 0
end

local function order(b, c1, c2)
  local p1, p2 = priority(b, 1, c1), priority(b, 2, c2)
  if p1 ~= p2 then return p1 > p2 and { 1, 2 } or { 2, 1 } end
  local s1, s2 = battle_stat(b, 1, "spd"), battle_stat(b, 2, "spd")
  if s1 ~= s2 then return s1 > s2 and { 1, 2 } or { 2, 1 } end
  return rnd(2) == 0 and { 1, 2 } or { 2, 1 }
end

-- 倒下判定：倒下的這一邊，看還有沒有能上場的
local function check_faint(b, side, ev)
  local k = battle_active(b, side)
  if k.hp > 0 then return false end
  ev[#ev + 1] = { kind = "faint", side = side }
  -- 對手的野伴倒下：玩家這隻得到經驗
  if side == 2 and b.wild then
    local me = battle_active(b, 1)
    if me.hp > 0 then
      local amount = kin_exp_reward(k)
      ev[#ev + 1] = { kind = "exp", side = 1, amount = amount }
      for _, e in ipairs(kin_gain_exp(me, amount)) do
        e.side = 1
        ev[#ev + 1] = e
      end
    end
  end
  if not has_alive(b.sides[side].party) then
    b.over = side == 1 and "lose" or "win"
    ev[#ev + 1] = { kind = "end", result = b.over }
  else
    ev[#ev + 1] = { kind = "need_switch", side = side }   -- 下回合開始前要選下一隻
  end
  return true
end

local function change_stage(b, side, stat, n, ev)
  local st = b.sides[side].stages
  local new = clamp(st[stat] + n, STAGE_MIN, STAGE_MAX)
  if new == st[stat] then
    ev[#ev + 1] = { kind = "stat_limit", side = side, stat = stat, up = n > 0 }
  else
    st[stat] = new
    ev[#ev + 1] = { kind = "stat", side = side, stat = stat, amount = n }
  end
end

local function give_status(b, side, status, ev)
  local k = battle_active(b, side)
  if k.status or k.hp <= 0 then return end
  k.status = status
  if status == "sleep" then k.sleep = 1 + rnd(3) end
  ev[#ev + 1] = { kind = "status", side = side, status = status }
end

-- side 使用第 index 招
local function use_move(b, side, index, ev)
  local k = battle_active(b, side)
  if k.hp <= 0 then return end
  local target = other(side)
  local foe = battle_active(b, target)
  local m = k.moves[index]
  local move = DATA.moves[m.key]

  -- 睡著、麻痺：這回合可能不能動
  if k.status == "sleep" then
    k.sleep = k.sleep - 1
    if k.sleep > 0 then
      ev[#ev + 1] = { kind = "asleep", side = side }
      return
    end
    k.status, k.sleep = nil, nil
    ev[#ev + 1] = { kind = "wake", side = side }
  elseif k.status == "paralyze" and rnd(4) == 0 then
    ev[#ev + 1] = { kind = "paralyzed", side = side }
    return
  end

  if m.pp <= 0 then
    ev[#ev + 1] = { kind = "no_pp", side = side, move = m.key }
    return
  end
  m.pp = m.pp - 1
  ev[#ev + 1] = { kind = "use", side = side, move = m.key }

  -- 命中：accuracy 0 = 必定命中；對自己用的招不會落空
  local e = move.effect
  local self_only = e and e.kind == "stat" and e.target == "self"
  if move.accuracy > 0 and not self_only and rnd(100) >= move.accuracy then
    ev[#ev + 1] = { kind = "miss", side = side }
    return
  end

  local dealt = 0
  if move.power > 0 then
    local roll = 85 + rnd(16)
    local dmg, mult = battle_damage(k.level, move.power, battle_stat(b, side, "atk"), battle_stat(b, target, "def"),
                                    move.type, kin_species(k).type, kin_species(foe).type, roll)
    if mult == 0 then
      ev[#ev + 1] = { kind = "no_effect", side = target }
      return
    end
    dealt = math.min(dmg, foe.hp)
    foe.hp = foe.hp - dealt
    ev[#ev + 1] = { kind = "damage", side = target, amount = dealt, hp = foe.hp, mult = mult }
  end

  if e then
    if e.kind == "stat" then
      change_stage(b, e.target == "self" and side or target, e.stat, e.stages, ev)
    elseif e.kind == "drain" and dealt > 0 then
      local heal = math.min(math.max(dealt // 2, 1), kin_max_hp(k) - k.hp)
      if heal > 0 then
        k.hp = k.hp + heal
        ev[#ev + 1] = { kind = "heal", side = side, amount = heal, hp = k.hp }
      end
    elseif e.kind == "status" then
      -- 一定要先擲骰（不管對方有沒有狀態），rnd 的呼叫次數才固定
      if rnd(100) < e.chance then give_status(b, target, e.status, ev) end
    end
  end

  check_faint(b, target, ev)
end

-- ============================================================
-- 抓捕（W34）
-- ============================================================
-- 抓捕值 a（0～255）= (3 × 最大HP − 2 × 目前HP) × 種類的捕獲率 × 球的倍率 // (3 × 最大HP × 100)
--   HP 越少越好抓：滿血時是 1/3，剩 1 點時接近 1 倍；球的倍率 100 = 一般的野伴球
--   睡著 × 2、麻痺／灼傷 × 3 // 2
-- 球搖 4 次，每次 rnd(256) < SHAKE[a] 才繼續搖；4 次都過就抓到 → 抓到的機率剛好 ≈ a / 255
-- SHAKE[a + 1] = 256 × (a / 255) 的 4 次方根（tools 外面用 Python 算好的整數，遊戲裡不用小數）
local SHAKE = {
  0, 64, 76, 84, 90, 95, 100, 104, 107, 110, 113, 116, 119, 121, 123, 126,
  128, 130, 131, 133, 135, 137, 138, 140, 141, 143, 144, 146, 147, 148, 149, 151,
  152, 153, 154, 155, 156, 157, 159, 160, 161, 162, 163, 164, 164, 165, 166, 167,
  168, 169, 170, 171, 172, 172, 173, 174, 175, 176, 176, 177, 178, 179, 179, 180,
  181, 181, 182, 183, 183, 184, 185, 185, 186, 187, 187, 188, 189, 189, 190, 190,
  191, 192, 192, 193, 193, 194, 195, 195, 196, 196, 197, 197, 198, 198, 199, 200,
  200, 201, 201, 202, 202, 203, 203, 204, 204, 205, 205, 206, 206, 206, 207, 207,
  208, 208, 209, 209, 210, 210, 211, 211, 212, 212, 212, 213, 213, 214, 214, 215,
  215, 215, 216, 216, 217, 217, 217, 218, 218, 219, 219, 219, 220, 220, 221, 221,
  221, 222, 222, 223, 223, 223, 224, 224, 224, 225, 225, 226, 226, 226, 227, 227,
  227, 228, 228, 228, 229, 229, 229, 230, 230, 230, 231, 231, 231, 232, 232, 233,
  233, 233, 233, 234, 234, 234, 235, 235, 235, 236, 236, 236, 237, 237, 237, 238,
  238, 238, 239, 239, 239, 240, 240, 240, 240, 241, 241, 241, 242, 242, 242, 242,
  243, 243, 243, 244, 244, 244, 245, 245, 245, 245, 246, 246, 246, 247, 247, 247,
  247, 248, 248, 248, 248, 249, 249, 249, 250, 250, 250, 250, 251, 251, 251, 251,
  252, 252, 252, 252, 253, 253, 253, 253, 254, 254, 254, 254, 255, 255, 255, 256,
}

function catch_value(k, ball_rate)
  local max = kin_max_hp(k)
  local a = (3 * max - 2 * k.hp) * kin_species(k).catch * ball_rate // (3 * max * 100)
  if k.status == "sleep" then a = a * 2
  elseif k.status == "paralyze" or k.status == "burn" then a = a * 3 // 2 end
  return clamp(a, 1, 255)
end

-- 丟球：事件 ball → shake × 0～3 → caught 或 broke
local function throw_ball(b, side, c, ev)
  local foe = battle_active(b, other(side))
  local a = catch_value(foe, DATA.items[c.item].rate)
  local shakes = 0
  for _ = 1, 4 do
    if rnd(256) >= SHAKE[a + 1] then break end
    shakes = shakes + 1
  end
  for i = 1, math.min(shakes, 3) do ev[#ev + 1] = { kind = "shake", side = side, n = i } end
  if shakes == 4 then
    b.over = "caught"
    ev[#ev + 1] = { kind = "caught", side = side }
    ev[#ev + 1] = { kind = "end", result = "caught" }
  else
    ev[#ev + 1] = { kind = "broke", side = side, shakes = shakes }
  end
end

-- 用道具：目前只有回復 HP 的（W33）。昏倒的、HP 滿的不能用（畫面那邊會先擋掉）
local function use_item(b, side, c, ev)
  local it = DATA.items[c.item]
  local k = b.sides[side].party[c.target]
  ev[#ev + 1] = { kind = "item", side = side, item = c.item }
  if it.kind == "ball" then
    throw_ball(b, side, c, ev)
  elseif it.kind == "heal" then
    local heal = math.min(it.amount, kin_max_hp(k) - k.hp)
    k.hp = k.hp + heal
    ev[#ev + 1] = { kind = "item_heal", side = side, index = c.target, amount = heal, hp = k.hp }
  end
end

local function do_switch(b, side, index, ev)
  local s = b.sides[side]
  s.active = index
  s.stages = { atk = 0, def = 0, spd = 0 }   -- 換下場，能力階段歸零
  ev[#ev + 1] = { kind = "switch", side = side, index = index }
end

-- 逃跑（GB 的公式）：速度不輸對方一定成功；否則 值 = 我方速度 × 32 // 對方速度 + 30 × 嘗試次數，rnd(256) < 值 成功
local function try_run(b, ev)
  if not b.wild then
    ev[#ev + 1] = { kind = "cant_run" }
    return
  end
  b.run_tries = b.run_tries + 1
  local mine, theirs = battle_stat(b, 1, "spd"), battle_stat(b, 2, "spd")
  local ok = mine >= theirs or rnd(256) < mine * 32 // theirs + 30 * b.run_tries
  if ok then
    b.over = "run"
    ev[#ev + 1] = { kind = "run", ok = true }
    ev[#ev + 1] = { kind = "end", result = "run" }
  else
    ev[#ev + 1] = { kind = "run", ok = false }
  end
end

-- 回合結束：灼傷扣血（最大 HP 的 1/16）
local function end_of_turn(b, ev)
  for side = 1, 2 do
    if b.over then return end
    local k = battle_active(b, side)
    if k.hp > 0 and k.status == "burn" then
      local d = math.min(math.max(kin_max_hp(k) // 16, 1), k.hp)
      k.hp = k.hp - d
      ev[#ev + 1] = { kind = "burn_damage", side = side, amount = d, hp = k.hp }
      check_faint(b, side, ev)
    end
  end
end

-- 進行一回合。c1：玩家的選擇，c2：對手的選擇。回傳事件列表
function battle_step(b, c1, c2)
  local ev = {}
  if b.over then return ev end
  b.turn = b.turn + 1
  local choices = { c1, c2 }
  for _, side in ipairs(order(b, c1, c2)) do
    if b.over then break end
    local c = choices[side]
    if c.kind == "move" then
      use_move(b, side, c.index, ev)
    elseif c.kind == "switch" then
      do_switch(b, side, c.index, ev)
    elseif c.kind == "run" then
      try_run(b, ev)
    elseif c.kind == "item" then
      use_item(b, side, c, ev)
    end
  end
  if not b.over then end_of_turn(b, ev) end
  return ev
end

-- 倒下之後換上第 index 隻（不算一回合）
function battle_send_out(b, side, index)
  local ev = {}
  do_switch(b, side, index, ev)
  return ev
end

-- 對手怎麼選（W60）
--   野生的野伴：隨機選一招還有次數的（和 GB 一樣，野生的不會想）
--   訓練家：每一招打分數，大多時候選最高分的，偶爾（1/4）隨便選一招，不會每次都被猜中
--     有傷害的招：預估傷害 × 命中率（效果絕佳自然高分、沒效果是 0）；打得倒對方的加很多分
--     改變能力的招：對方或自己還沒到 −2／+2 才有分（不會一直瞪眼）
--     狀態招：對方已經有狀態就 0 分
local function move_score(b, side, m)
  local d = DATA.moves[m.key]
  local me, foe = battle_active(b, side), battle_active(b, 3 - side)
  local foe_hp = math.max(foe.hp, 1)
  local acc = (d.accuracy == 0) and 100 or d.accuracy
  local e = d.effect
  if d.power > 0 then
    local dmg, mult = battle_damage(me.level, d.power, battle_stat(b, side, "atk"), battle_stat(b, 3 - side, "def"),
                                    d.type, kin_species(me).type, kin_species(foe).type, 92)
    if mult == 0 then return 0 end
    local score = math.min(dmg, foe_hp) * 100 // foe_hp * acc // 100   -- 能打掉對方幾 % 的 HP
    if dmg >= foe.hp then score = score + 60 end                        -- 一招打倒
    if e and e.kind == "drain" and me.hp * 2 < kin_max_hp(me) then score = score + 10 end
    if e and e.kind == "first" and dmg >= foe.hp then score = score + 30 end   -- 先手收尾
    return score
  end
  if not e then return 0 end
  if e.kind == "stat" then
    local who = (e.target == "self") and side or (3 - side)
    local now = b.sides[who].stages[e.stat]
    if e.stages < 0 and now <= -2 then return 0 end
    if e.stages > 0 and now >= 2 then return 0 end
    return 25 * acc // 100
  end
  if e.kind == "status" then
    if foe.status then return 0 end
    return 35 * acc // 100
  end
  return 10
end

function battle_ai(b, side)
  local k = battle_active(b, side)
  local usable = {}
  for i, m in ipairs(k.moves) do
    if m.pp > 0 then usable[#usable + 1] = i end
  end
  if #usable == 0 then return { kind = "move", index = 1 } end
  if b.wild or rnd(4) == 0 then
    return { kind = "move", index = usable[rnd(#usable) + 1] }
  end
  local best, best_score = usable[1], -1
  for _, i in ipairs(usable) do
    local sc = move_score(b, side, k.moves[i])
    if sc > best_score then best, best_score = i, sc end
  end
  return { kind = "move", index = best }
end

-- 隊伍裡下一隻能上場的（倒下後自動換人用；玩家那邊之後由選單決定）
function battle_next_alive(b, side)
  for i, k in ipairs(b.sides[side].party) do
    if k.hp > 0 then return i end
  end
  return nil
end

-- ============================================================
-- 事件 → 文字（W26 播放事件時用；現在先給主控台和測試用）
-- ============================================================

local STATUS_TEXT = { burn = "灼傷了", paralyze = "麻痺了", sleep = "睡著了" }

function battle_event_text(b, e)
  local function who(side)
    local k = battle_active(b, side)
    local name = kin_name(k)
    if side == 2 then name = (b.wild and "野生的" or ((b.trainer or "對手") .. "的")) .. name end
    return name
  end
  local K = e.kind
  if K == "use" then return who(e.side) .. "使用了" .. DATA.moves[e.move].name .. "！" end
  if K == "miss" then return "可是沒有打中！" end
  if K == "damage" then
    if e.mult == 4 then return "效果絕佳！" end
    if e.mult == 1 then return "效果不太好……" end
    return nil   -- 一般效果不另外說，血條減少就看得出來
  end
  if K == "no_effect" then return "好像沒有效果……" end
  if K == "heal" then return who(e.side) .. "回復了體力！" end
  if K == "stat" then return who(e.side) .. "的" .. STAT_NAMES[e.stat] .. (e.amount > 0 and "提升了！" or "下降了！") end
  if K == "stat_limit" then return who(e.side) .. "的" .. STAT_NAMES[e.stat] .. "已經不會再" .. (e.up and "提升" or "下降") .. "了！" end
  if K == "status" then return who(e.side) .. STATUS_TEXT[e.status] .. "！" end
  if K == "asleep" then return who(e.side) .. "正在呼呼大睡。" end
  if K == "wake" then return who(e.side) .. "醒來了！" end
  if K == "paralyzed" then return who(e.side) .. "身體麻痺，不能動！" end
  if K == "burn_damage" then return who(e.side) .. "受到灼傷的傷害！" end
  if K == "no_pp" then return "可是招式的次數用完了！" end
  if K == "faint" then return who(e.side) .. "倒下了！" end
  if K == "exp" then return who(e.side) .. "得到了 " .. e.amount .. " 點經驗！" end
  if K == "level" then return who(e.side) .. "升到了 Lv" .. e.level .. "！" end
  if K == "learn" then return who(e.side) .. "學會了" .. DATA.moves[e.key].name .. "！" end
  if K == "full" then return who(e.side) .. "想學" .. DATA.moves[e.key].name .. "，可是已經記住 4 招了。" end
  if K == "switch" then return (e.side == 1 and "上吧！" or ((b.trainer or "對手") .. "換上了")) .. kin_name(battle_active(b, e.side)) .. "！" end
  if K == "run" then return e.ok and "順利逃走了！" or "逃不掉！就像當年的車貸。" end
  if K == "cant_run" then return "不能從對戰中逃走！" end
  if K == "item" then
    if DATA.items[e.item].kind == "ball" then return PLAYER_NAME .. "丟出了" .. DATA.items[e.item].name .. "！" end
    return (e.side == 1 and PLAYER_NAME or (b.trainer or "對手")) .. "使用了" .. DATA.items[e.item].name .. "！"
  end
  if K == "caught" then return "抓到了" .. kin_name(battle_active(b, 2)) .. "！" end
  if K == "broke" then
    if e.shakes == 0 then return "啊！一下就跑出來了！" end
    if e.shakes == 1 then return "可惡！差一點點……" end
    if e.shakes == 2 then return "唉呀！只差一點了！" end
    return "可惜！就差那麼一點！"
  end
  if K == "item_heal" then return kin_name(b.sides[e.side].party[e.index]) .. "回復了 " .. e.amount .. " 點 HP！" end
  return nil
end
