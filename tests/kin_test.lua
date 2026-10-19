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

-- 招式：Lv5 會撞擊、吼叫、葉刃（Lv1 兩招 + Lv5 一招）
expect("Lv5 芽角羊 招式數", #sheep.moves, 3)
expect("第 3 招", sheep.moves[3].key, "leaf")
expect("招式次數", sheep.moves[3].pp, 25)

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
