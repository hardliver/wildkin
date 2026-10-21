-- battle_test.lua：battle.lua 的測試（make check 用）

local failed = 0
local function expect(name, got, want)
  if got ~= want then
    print("✗ " .. name .. "：得到 " .. tostring(got) .. "，應該是 " .. tostring(want))
    failed = failed + 1
  end
end

-- 1. 傷害公式：Lv5 芽角羊（攻 9）用葉刃（草，威力 45）打 Lv3 囤囤鼠（防 7，普通）
--    基本 = (5×2//5+2) × 45 × 9 // 7 // 50 + 2 = 4 × 45 × 9 // 7 // 50 + 2 = 1620 // 7 // 50 + 2 = 231 // 50 + 2 = 6
--    同屬性 6 × 3 // 2 = 9；草打普通是一般效果（× 2 // 2）= 9
--    亂數 100 → 9；亂數 85 → 9 × 85 // 100 = 7
local sheep, rat = kin_new("01", 5), kin_new("07", 3)
expect("芽角羊攻擊", kin_stat(sheep, "atk"), 9)
expect("囤囤鼠防禦", kin_stat(rat, "def"), 7)
expect("葉刃傷害（亂數 100）", battle_damage(5, 45, 9, 7, "grass", "grass", "normal", 100), 9)
expect("葉刃傷害（亂數 85）", battle_damage(5, 45, 9, 7, "grass", "grass", "normal", 85), 7)
-- 沒有同屬性：撞擊（普通，威力 40）：4 × 40 × 9 // 7 // 50 + 2 = 1440 // 7 = 205 // 50 = 4 + 2 = 6
expect("撞擊傷害（沒有同屬性）", battle_damage(5, 40, 9, 7, "normal", "grass", "normal", 100), 6)
-- 效果絕佳：水打火 → 6 × 4 // 2 = 12（攻擊者是草，沒有同屬性）
expect("效果絕佳", battle_damage(5, 40, 9, 7, "water", "grass", "fire", 100), 12)
-- 效果不好：草打火 → 9 × 1 // 2 = 4
expect("效果不好", battle_damage(5, 45, 9, 7, "grass", "grass", "fire", 100), 4)
expect("沒有效果（電打岩）", battle_damage(5, 40, 9, 7, "electric", "normal", "rock", 100), 0)

-- 2. 屬性相剋表
expect("草打水", type_mult("grass", "water"), 4)
expect("電打岩", type_mult("electric", "rock"), 0)
expect("普通打草（表裡沒寫）", type_mult("normal", "grass"), 2)

-- 3. 能力階段：攻擊 −1 → × 2 // 3；+2 → × 4 // 2
local b = battle_new({ kin_new("01", 5) }, { kin_new("07", 3) }, { wild = true })
b.sides[1].stages.atk = -1
expect("攻擊 −1 階", battle_stat(b, 1, "atk"), 9 * 2 // 3)
b.sides[1].stages.atk = 2
expect("攻擊 +2 階", battle_stat(b, 1, "atk"), 9 * 4 // 2)
b.sides[1].stages.atk = 0
battle_active(b, 1).status = "burn"
expect("灼傷攻擊減半", battle_stat(b, 1, "atk"), 9 // 2)

-- 4. 灼傷：回合結束扣最大 HP 的 1/16（芽角羊 19 → 1）
local hp0 = battle_active(b, 1).hp
local ev = battle_step(b, { kind = "move", index = 2 }, { kind = "move", index = 1 })   -- 吼叫 vs 撞擊
local burned = false
for _, e in ipairs(ev) do if e.kind == "burn_damage" and e.side == 1 and e.amount == 1 then burned = true end end
expect("灼傷扣血", burned, true)
battle_active(b, 1).status = nil

-- 5. 逃跑：芽角羊（速 9）對囤囤鼠（速 55 × 3 // 50 + 5 = 8）→ 速度不輸，一定成功
local r = battle_new({ kin_new("01", 5) }, { kin_new("07", 3) }, { wild = true })
battle_step(r, { kind = "run" }, battle_ai(r, 2))
expect("速度不輸對方，一定逃得掉", r.over, "run")
-- 訓練家戰不能逃
local t = battle_new({ kin_new("01", 5) }, { kin_new("07", 3) }, { wild = false })
ev = battle_step(t, { kind = "run" }, battle_ai(t, 2))
expect("訓練家戰不能逃", ev[1].kind, "cant_run")
expect("不能逃也沒有結束", t.over, nil)

-- 6. 吼叫讓對方攻擊 −1；連用 4 次之後到底了
local g = battle_new({ kin_new("01", 5) }, { kin_new("07", 3) }, { wild = true })
for i = 1, 4 do battle_step(g, { kind = "move", index = 2 }, { kind = "move", index = 1 }) end
expect("對方攻擊最多 −3", g.sides[2].stages.atk, -3)

-- 7. 一整場戰鬥：固定的亂數種子（Mac 版測試是種子 1），印出事件，檢查一定會結束、HP 不會是負的
print("---- 測試戰鬥：Lv5 芽角羊 vs 野生 Lv3 囤囤鼠 ----")
local f = battle_new({ kin_new("01", 5) }, { kin_new("07", 3) }, { wild = true })
f.sides[1].party[1].moves[3] = { key = "leaf", pp = 25 }   -- 葉刃 Lv7 才學（W61 平衡）；測試直接給
local turns = 0
while not f.over and turns < 30 do
  turns = turns + 1
  ev = battle_step(f, { kind = "move", index = 3 }, battle_ai(f, 2))   -- 一直用葉刃
  for _, e in ipairs(ev) do
    local line = battle_event_text(f, e)
    if e.kind == "damage" then
      line = (line and line .. " " or "") .. "（" .. e.amount .. " 傷害，剩 " .. e.hp .. "）"
    end
    if line then print("  第 " .. turns .. " 回合：" .. line) end
    if e.hp and e.hp < 0 then expect("HP 不會是負的", e.hp, 0) end
  end
end
expect("戰鬥在 30 回合內結束", f.over ~= nil, true)
expect("Lv5 打 Lv3 應該贏", f.over, "win")
expect("打贏得到經驗（囤囤鼠 50 × 3 // 7 = 21）", battle_active(f, 1).exp, 125 + 21)

-- W33：用道具。回復藥一定比招式先（priority 2）；回復 20，但不會超過最大 HP
do
  local me, foe = kin_new("01", 10), kin_new("07", 10)
  local b = battle_new({ me }, { foe }, { wild = true })
  me.hp = 5
  local ev = battle_step(b, { kind = "item", item = "potion", target = 1 }, { kind = "move", index = 1 })
  expect("道具先動", ev[1].kind, "item")
  expect("回復 20", ev[2].amount, 20)
  me.hp = kin_max_hp(me) - 3
  ev = battle_step(b, { kind = "item", item = "potion", target = 1 }, { kind = "move", index = 1 })
  expect("回復不超過最大 HP", ev[2].amount, 3)
end

-- W34：抓捕
do
  -- 抓捕值：Lv3 囤囤鼠（捕獲率 200）滿血 → (3m − 2m) × 200 × 100 // (3m × 100) = 200 // 3 = 66
  local rat = kin_new("07", 3)
  expect("抓捕值（滿血）", catch_value(rat, 100), 66)
  rat.hp = 1
  local m = kin_max_hp(rat)
  expect("抓捕值（剩 1 點）", catch_value(rat, 100), (3 * m - 2) * 200 // (3 * m))
  rat.status = "sleep"
  expect("抓捕值（睡著 × 2，最多 255）", catch_value(rat, 100), 255)
  -- 抓捕值 255 一定抓到：事件 item → shake 1、2、3 → caught → end
  local b = battle_new({ kin_new("01", 5) }, { rat }, { wild = true })
  local ev = battle_step(b, { kind = "item", item = "ball" }, { kind = "move", index = 1 })
  expect("丟球事件", ev[1].kind, "item")
  expect("搖了 3 下", ev[4].kind == "shake" and ev[4].n, 3)
  expect("抓到了", ev[5].kind, "caught")
  expect("戰鬥結束", b.over, "caught")
  -- 1000 次統計：Lv3 囤囤鼠滿血（a = 66）抓到的機率應該接近 66/255 ≈ 26%
  local got = 0
  for _ = 1, 1000 do
    local r = kin_new("07", 3)
    local b2 = battle_new({ kin_new("01", 5) }, { r }, { wild = true })
    battle_step(b2, { kind = "item", item = "ball" }, { kind = "move", index = 1 })
    if b2.over == "caught" then got = got + 1 end
  end
  print("  滿血囤囤鼠 1000 球抓到 " .. got .. " 次（理論約 259）")
  expect("抓捕機率在合理範圍", got > 200 and got < 320, true)
end

-- W60：訓練家的 AI
do
  -- 鬚鬚鯰（水）對炭毛狸（火）：撞擊、水花、吼叫 → 大多時候選水花（效果絕佳）
  local picks = { 0, 0, 0 }
  for _ = 1, 200 do
    local fish = kin_new("05", 10)
    fish.moves = { { key = "tackle", pp = 35 }, { key = "splash", pp = 25 }, { key = "growl", pp = 40 } }
    local b3 = battle_new({ kin_new("03", 10) }, { fish }, { wild = false })
    local c = battle_ai(b3, 2)
    picks[c.index] = picks[c.index] + 1
  end
  print("  訓練家 AI 200 次：撞擊 " .. picks[1] .. "、水花 " .. picks[2] .. "、吼叫 " .. picks[3])
  expect("訓練家大多選效果絕佳的招", picks[2] > 140, true)
  -- 對方攻擊已經 −2：不再用吼叫（除了 1/4 的隨便選）
  local fish = kin_new("05", 10)
  fish.moves = { { key = "growl", pp = 40 }, { key = "tackle", pp = 35 } }
  local b4 = battle_new({ kin_new("01", 10) }, { fish }, { wild = false })
  b4.sides[1].stages.atk = -2
  local growls = 0
  for _ = 1, 200 do if battle_ai(b4, 2).index == 1 then growls = growls + 1 end end
  expect("對方攻擊已經 −2 就少用吼叫", growls < 60, true)
end

if failed > 0 then error("battle.lua 有 " .. failed .. " 項測試沒通過") end
print("✓ battle.lua：全部通過")
