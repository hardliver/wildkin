-- kin_test.lua：kin.lua 的測試（make check 用）
-- 接在遊戲檔後面一起執行；檢查不通過就 error，Mac 版無頭模擬器會回傳失敗

local failed = 0
local function expect(name, got, want)
  if got ~= want then
    print("✗ " .. name .. "：得到 " .. tostring(got) .. "，應該是 " .. tostring(want))
    failed = failed + 1
  end
end

-- 能力值：照 design.md 的公式手算
local sheep = kin_new("01", 5)          -- 芽角羊 Lv5：基礎 45/49/49/45
expect("Lv5 芽角羊 HP", kin_max_hp(sheep), 45 * 5 // 50 + 5 + 10)   -- 19
expect("Lv5 芽角羊 攻擊", kin_stat(sheep, "atk"), 49 * 5 // 50 + 5)  -- 9
expect("剛產生時 HP 全滿", sheep.hp, 19)
expect("經驗 = 等級³", sheep.exp, 125)

-- 招式：Lv5 會撞擊、吼叫（Lv1 兩招）；葉刃 Lv7 才學（W61 平衡：原本 Lv5，勁敵第 1 戰太難）
expect("Lv5 芽角羊 招式數", #sheep.moves, 2)
local sheep7 = kin_new("01", 7)
expect("Lv7 第 3 招", sheep7.moves[3] and sheep7.moves[3].key, "leaf")
expect("招式次數", sheep7.moves[3] and sheep7.moves[3].pp, 25)

-- Lv20：學過 5 招，只記住最後 4 招（撞擊被擠掉）
local old = kin_new("01", 20)
expect("Lv20 招式數", #old.moves, 4)
expect("Lv20 第 1 招", old.moves[1].key, "growl")
expect("Lv20 第 4 招", old.moves[4].key, "leer")

-- 經驗：囤囤鼠 Lv3 被打倒 → 50 × 3 // 7 = 21
local rat = kin_new("07", 3)
expect("打倒 Lv3 囤囤鼠的經驗", kin_exp_reward(rat), 21)

-- 升級：Lv5（125）+ 100 → 225，升到 Lv6（216），不到 Lv7（343）
sheep.hp = 10
local ev = kin_gain_exp(sheep, 100)
expect("升到 Lv6", sheep.level, 6)
expect("升級事件", ev[1] and ev[1].kind, "level")
expect("升級時 HP 跟著增加", sheep.hp, 10 + kin_max_hp(sheep) - 19)

-- 升到 Lv9 學會吸取（第 4 招，還有空位）
ev = kin_gain_exp(sheep, kin_exp_for(9) - sheep.exp)
expect("升到 Lv9", sheep.level, 9)
local learned = false
for _, e in ipairs(ev) do if e.kind == "learn" and e.key == "absorb" then learned = true end end
expect("Lv9 學會吸取", learned, true)
expect("現在 4 招", #sheep.moves, 4)

-- 升到 Lv13：瞪眼，但招式滿了 → full，等玩家選
ev = kin_gain_exp(sheep, kin_exp_for(13) - sheep.exp)
expect("Lv13 招式滿了", ev[#ev].kind, "full")
kin_replace_move(sheep, 1, "leer")
expect("換掉第 1 招", sheep.moves[1].key, "leer")

-- 回復
sheep.hp = 1; sheep.moves[2].pp = 0
kin_heal(sheep)
expect("回復 HP", sheep.hp, kin_max_hp(sheep))
expect("回復次數", sheep.moves[2].pp, DATA.moves[sheep.moves[2].key].pp)

-- 每一種野伴、1–50 級都能產生，招式 1–4 招
for no in pairs(DATA.species) do
  for lv = 1, 50 do
    local k = kin_new(no, lv)
    if #k.moves < 1 or #k.moves > 4 or k.hp < 1 then
      expect(no .. " Lv" .. lv .. " 的野伴", "不正確", "正確")
    end
  end
end

if failed > 0 then error("kin.lua 有 " .. failed .. " 項測試沒通過") end
print("✓ kin.lua：全部通過")

-- W24：每種野伴都有戰鬥圖（sprite 是 kin_front／kin_back 的第幾格，check_data.mjs 會檢查範圍）
do
  assert(IMG.kin_front and IMG.kin_back, "戰鬥圖沒有載入")
  for no, s in pairs(DATA.species) do
    spr(IMG.kin_front, s.sprite, 0, 0)
    spr(IMG.kin_back, s.sprite, 64, 0)
  end
  print("ok: 戰鬥圖")
end

-- W38：進化
do
  local k = kin_new("01", 15)
  assert(kin_can_evolve(k) == nil, "15 級不能進化")
  k.level = 16
  assert(kin_can_evolve(k) == "02", "16 級芽角羊可以進化成林角羊")
  k.evolve_skip = 16
  assert(kin_can_evolve(k) == nil, "取消之後同一級不再問")
  k.level = 17
  assert(kin_can_evolve(k) == "02", "下一級會再問")
  k.hp = 10
  local before = kin_max_hp(k)
  kin_evolve(k, "02")
  assert(k.no == "02" and kin_name(k) == "林角羊", "進化後換種類")
  assert(k.hp == 10 + kin_max_hp(k) - before, "最大 HP 增加多少，目前 HP 也增加多少")
  assert(kin_can_evolve(k) == nil, "林角羊不會再進化")
  print("ok: 進化")
end

-- 異色（W65）：換色表有換到顏色、每次算出來一樣；能力不變
do
  local m = shiny_map("01")
  local n = 0
  for from, to in pairs(m) do
    n = n + 1
    local ok = false
    for _, img in pairs(IMG) do
      for _, c in ipairs(imgcolors(img)) do if c == to then ok = true end end
    end
    assert(ok, "換成的顏色要是圖片裡已經有的")
  end
  assert(n >= 3, "芽角羊的異色至少換 3 個顏色")
  DEBUG_NEXT_SHINY = true
  local a = shiny_roll(kin_new("01", 5))
  local b = kin_new("01", 5)
  assert(a.shiny and not b.shiny and DEBUG_NEXT_SHINY == nil, "除錯旗標只讓下一隻變異色")
  assert(kin_stat(a, "atk") == kin_stat(b, "atk") and kin_max_hp(a) == kin_max_hp(b), "異色能力一樣")
  print("ok: 異色")
end
