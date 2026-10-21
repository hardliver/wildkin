-- sim.lua：戰鬥試算（W61，Studio 25）
--
-- 用遊戲本身的戰鬥程式（battle.lua）算，不開畫面，所以試算和實際玩一定一致：
--   sim_damage_text：兩隻野伴互打，每一招的傷害範圍、佔對方 HP 幾 %、幾下打倒
--   sim_battles：自動打 n 場（雙方都用訓練家的 AI 選招），看勝率、平均幾回合
-- Studio 的「狀態」分頁 →「工具」會列出 debug.lua 的 DEBUG_TOOLS，按「執行」就呼叫這裡。
-- 注意：自動對戰會用到 rnd()，在 Studio 裡跑會改變遊戲接下來的亂數（只影響開發，玩家不會跑這個）

local function pad(s, w)
  local n = 0
  for _ in utf8.codes(s) do n = n + 1 end
  return s .. string.rep(" ", math.max(0, w - n))
end

-- 一隻打另一隻：每一招的傷害（亂數 85～100 的最小、最大）
local function moves_vs(att, def)
  local b = battle_new({ att }, { def }, { wild = false })
  local lines = {}
  local hp = kin_max_hp(def)
  for _, m in ipairs(att.moves) do
    local d = DATA.moves[m.key]
    if d.power > 0 then
      local lo = battle_damage(att.level, d.power, battle_stat(b, 1, "atk"), battle_stat(b, 2, "def"), d.type, kin_species(att).type, kin_species(def).type, 85)
      local hi, mult = battle_damage(att.level, d.power, battle_stat(b, 1, "atk"), battle_stat(b, 2, "def"), d.type, kin_species(att).type, kin_species(def).type, 100)
      local tag = (mult == 4 and "（效果絕佳）") or (mult == 1 and "（效果不好）") or (mult == 0 and "（沒有效果）") or ""
      local hits = (hi > 0) and ((hp + hi - 1) // hi .. "～" .. ((lo > 0) and (hp + lo - 1) // lo or "∞")) or "—"
      lines[#lines + 1] = "  " .. pad(d.name, 6) .. lo .. "～" .. hi .. "（" .. lo * 100 // hp .. "～" .. hi * 100 // hp .. "%）" .. hits .. " 下" .. tag
    else
      lines[#lines + 1] = "  " .. pad(d.name, 6) .. "（不造成傷害）"
    end
  end
  return table.concat(lines, "\n")
end

local function stat_line(k)
  return kin_name(k) .. " Lv" .. k.level .. "　HP " .. kin_max_hp(k) .. "　攻 " .. kin_stat(k, "atk") ..
         "　防 " .. kin_stat(k, "def") .. "　速 " .. kin_stat(k, "spd")
end

function sim_damage_text(me_no, me_lv, foe_no, foe_lv)
  local me, foe = kin_new(me_no, me_lv), kin_new(foe_no, foe_lv)
  local out = { stat_line(me), stat_line(foe), "", kin_name(me) .. " 打 " .. kin_name(foe) .. "：", moves_vs(me, foe),
                "", kin_name(foe) .. " 打 " .. kin_name(me) .. "：", moves_vs(foe, me) }
  -- 抓捕機率（對方滿血、剩 1/5、剩 1/5 又睡著）
  local full = battle_catch_permille(foe, 100)
  foe.hp = math.max(1, kin_max_hp(foe) // 5)
  local low = battle_catch_permille(foe, 100)
  local low_good = battle_catch_permille(foe, 150)
  foe.status = "sleep"
  local sleep = battle_catch_permille(foe, 100)
  out[#out + 1] = ""
  out[#out + 1] = "抓 " .. kin_name(foe) .. "（野伴球）：滿血 " .. full // 10 .. "%　剩 1/5 HP " .. low // 10 ..
                  "%（好球 " .. low_good // 10 .. "%）　剩 1/5 又睡著 " .. sleep // 10 .. "%"
  return table.concat(out, "\n")
end

-- 我方用訓練家的 AI 出招（當作玩家會選好的招）；對手照遊戲裡真正的規則（野生隨機、訓練家 AI）
local function smart(b, side)
  local w = b.wild
  b.wild = false
  local c = battle_ai(b, side)
  b.wild = w
  return c
end

-- spec：{ { "01", 10 }, { "07", 8 } }。回傳 勝場、平均回合、贏的時候平均剩幾 % HP（整隊加總）
function sim_battles(my_spec, foe_spec, wild, n)
  local wins, turns, left = 0, 0, 0
  for _ = 1, n do
    local mine, foes = {}, {}
    for i, s in ipairs(my_spec) do mine[i] = kin_new(s[1], s[2]) end
    for i, s in ipairs(foe_spec) do foes[i] = kin_new(s[1], s[2]) end
    local b = battle_new(mine, foes, { wild = wild })
    for _ = 1, 200 do
      battle_step(b, smart(b, 1), battle_ai(b, 2))
      if b.over then break end
      for side = 1, 2 do
        if battle_active(b, side).hp <= 0 then battle_send_out(b, side, battle_next_alive(b, side)) end
      end
    end
    turns = turns + b.turn
    if b.over == "win" then
      wins = wins + 1
      local hp, max = 0, 0
      for _, k in ipairs(mine) do hp, max = hp + math.max(k.hp, 0), max + kin_max_hp(k) end
      left = left + hp * 100 // max
    end
  end
  return wins, turns * 10 // n, (wins > 0) and (left // wins) or 0
end

-- 「勝率 87%　平均 4.2 回合　贏的時候剩 63% HP」
function sim_battles_text(my_spec, foe_spec, wild, n)
  local w, t10, left = sim_battles(my_spec, foe_spec, wild, n)
  return "勝率 " .. w * 100 // n .. "%　平均 " .. t10 // 10 .. "." .. t10 % 10 .. " 回合　贏的時候剩 " .. left .. "% HP"
end
