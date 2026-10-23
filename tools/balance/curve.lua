-- curve.lua：全遊戲等級曲線試算（W78）
--
-- 用法（在 wildkin 資料夾）：make curve
--   接在 build/wildkin.lua 後面，用引擎的 Mac 版無頭跑（和 tests/ 一樣），不放進遊戲本體（主機記憶體小）。
--
-- 模擬一個「不刻意練等」的玩家，照劇情順序從序章走到雲根：
--   ‧ 第一次到一個地區遇敵幾次：用 tools/balance/paths.mjs 算（主線路的草叢來回走、旁邊的草叢逛一半）
--   ‧ 每個地區第一次遇到的野伴都抓一隻（手冊第一次抓到 3 倍經驗）；隊伍照 Studio 平衡表的組法
--   ‧ 路上的訓練家全部打（劇情的、一般的都打）
--   ‧ 到了頭目前：用「現在的隊伍」自動對戰 100 場看勝率；不到 TARGET_WIN 就在這一區的草叢練等，
--     每 5 場重算一次，數要多打幾場 → 這就是「需要刻意練等」的量
-- 戰鬥全部用遊戲本身的 battle.lua（和 sim.lua 一樣），經驗、升級、進化、上場過的拿全額沒上場的拿一半，都和實際玩一樣。
--
-- 時間（估計，秒）：戰鬥照回合數算、劇情照對話頁數算，再加每章固定的「雜事」（走路、基地、商店、回復、看手冊、和路人說話）。
-- 這是模型，不是實測；W80 實際玩一次之後，把實測的時間記在 docs/balance.md，回來調這裡的常數。

local RUNS = 5             -- 每個初始野伴跑幾次全程（取平均；每次遇到的野伴、亂數都不一樣）
local N_SIM = 100          -- 頭目勝率：自動對戰幾場
local TARGET_WIN = 70      -- 頭目前勝率到多少 % 才算「準備好了」（一般玩家會用道具、換人，比自動對戰強一點）

-- 時間的常數（秒）
local SEC_WILD = 12        -- 野生戰固定的部分：進場、「野生的○○出現了」、放出野伴、經驗
local SEC_TRAINER = 20     -- 訓練家戰固定的部分：對話、派出、獎金
local SEC_TURN = 5         -- 每回合：選招、兩邊出招的訊息和動畫
local SEC_CATCH = 35       -- 抓一隻：削血、丟球、搖晃、加入隊伍
local SEC_STEP = 3         -- 練等時兩次遇敵之間在草叢裡走的時間（約 12 格）
local SEC_PAGE = 3         -- 一頁對話

-- ============================================================
-- 劇情順序（每一步：地區、做什麼）
-- ============================================================
-- wild = 一般玩家第一次到這一區遇敵幾次（paths.mjs 的結果）
-- catch = 這一區第一次抓的（keep = 加進隊伍；其他的抓了送營地）
-- boss = 頭目（到了先檢查勝率，不夠就練等）
-- chapter = 這一章開始；target = 企劃的分鐘（content.md「章節」）；pages = 這一章劇情的對話大約幾頁（src 裡那一章的 say、narrate 數）；
--   chores = 雜事幾分鐘（猜的，等實測）
local PLAYTHROUGH = {
  { chapter = "序章", target = 20, pages = 110, chores = 6 },
  { area = "route1", wild = 6.6, catch = { "07", "08" }, keep = { "07" } },
  { area = "route1", trainer = "youth_kai" },
  { area = "route1", trainer = "route1_guard" },
  { area = "route1", trainer = "rival1" },
  { chapter = "第 1 章", target = 50, pages = 120, chores = 10 },
  { area = "forest", wild = 7.2, catch = { "09", "10", "11" }, keep = { "mate" } },
  { area = "forest", trainer = "youth_zhe" },
  { area = "forest", trainer = "rival2" },
  { area = "forest", boss = "forest_keeper" },
  { chapter = "第 2 章", target = 60, pages = 200, chores = 10 },
  { area = "mine", wild = 2.9, catch = { "12" }, keep = { "12" } },
  { area = "mine", boss = "exec1" },
  { area = "harbor", wild = 3.5, catch = { "13" }, keep = { "13" } },
  { area = "harbor", trainer = "youth_rou" },
  { area = "harbor", trainer = "youth_xiang" },
  { area = "harbor", trainer = "rival3" },
  { area = "harbor", boss = "rock_keeper" },
  { chapter = "第 3 章", target = 60, pages = 120, chores = 10 },
  { area = "coast", wild = 11.0 },
  { area = "coast", trainer = "coast1" },
  { area = "coast", trainer = "coast2" },
  { area = "coast", trainer = "coast3" },
  { area = "coast", trainer = "youth_jie" },
  { area = "volcano", wild = 3.8, catch = { "14" } },
  { area = "volcano", boss = "exec2" },
  { area = "volcano", boss = "fire_keeper" },
  { chapter = "終章", target = 40, pages = 190, chores = 5 },
  { area = "volcano", trainer = "factory_wood" },     -- 工廠沒有草叢：不夠的話回火山洞練
  { area = "volcano", trainer = "factory_ore" },
  { area = "volcano", trainer = "factory_light" },
  { area = "volcano", boss = "boss" },
  { area = "ridge", wild = 5.2, catch = { "15" } },
  { area = "ridge", boss = "rival4" },
  { area = "ridge", boss = "cloudroot" },
  { chapter = "end" },
}

local RIVAL = { ["01"] = "03", ["03"] = "05", ["05"] = "01" }   -- 阿穗用剋制主角的那隻
local MATE = { ["01"] = "11", ["03"] = "10", ["05"] = "11" }    -- 霧林多抓的那一隻（和平衡表一樣）

-- ============================================================
-- 小工具
-- ============================================================

-- 複製一隻野伴（頭目勝率要用「現在的隊伍」打很多場，不能改到本來的）
local function clone(k)
  local c = {}
  for key, v in pairs(k) do c[key] = v end
  c.moves = {}
  for i, m in ipairs(k.moves) do c.moves[i] = { key = m.key, pp = m.pp } end
  return c
end

local function heal_all(team)
  for _, k in ipairs(team) do kin_heal(k) end
end

-- 一招值多少（玩家「招式滿了」時忘掉哪一招）：有傷害的看威力，和自己同屬性的加一半；不造成傷害的算 20
local function move_value(k, key)
  local d = DATA.moves[key]
  if d.power == 0 then return 20 end
  if d.type == kin_species(k).type then return d.power * 3 // 2 end
  return d.power
end

-- 學招：學招表裡等級到了、還不會的招。滿 4 招時，比最差的那招好就換掉
-- （遊戲裡是玩家選要忘掉哪一招；kin_gain_exp 回傳的 full 事件。不處理的話，模擬的野伴一輩子只會最早的 4 招）
local function learn_all(team)
  for _, k in ipairs(team) do
    for _, entry in ipairs(kin_species(k).learn) do
      if entry[1] <= k.level then
        local e = kin_learn(k, entry[2])
        if e.kind == "full" then
          local worst, worst_v = nil, nil
          for i, m in ipairs(k.moves) do
            local v = move_value(k, m.key)
            if not worst or v < worst_v then worst, worst_v = i, v end
          end
          if move_value(k, entry[2]) > worst_v then kin_replace_move(k, worst, entry[2]) end
        end
      end
    end
  end
end

-- 戰鬥結束：進化（和遊戲一樣檢查，不取消）、學招
local function evolve_all(team)
  for _, k in ipairs(team) do
    local to = kin_can_evolve(k)
    if to then kin_evolve(k, to) end
  end
  learn_all(team)
end

-- 我方選招：和 sim.lua 一樣用訓練家的 AI（當作玩家會選好的招）
local function smart(b, side)
  local w = b.wild
  b.wild = false
  local c = battle_ai(b, side)
  b.wild = w
  return c
end

-- 我方這一隻對上對手那一隻有多有利：自己最好的招打對方的倍率，減掉對方屬性打自己的倍率
-- （type_mult：0 沒效、1 不好、2 普通、4 絕佳；battle.lua）。玩家會派有利的上場，不會派囤囤鼠去送
local function matchup(k, foe)
  local my_type, foe_type = kin_species(k).type, kin_species(foe).type
  local best = 0
  for _, m in ipairs(k.moves) do
    local d = DATA.moves[m.key]
    if d.power > 0 then best = math.max(best, type_mult(d.type, foe_type)) end
  end
  return best * 2 - type_mult(foe_type, my_type)
end

-- 挑下一隻上場：還能戰鬥的裡面，對上對手最有利的；一樣有利就挑等級高的
local function pick(team, foe)
  local best, best_score = nil, nil
  for i, k in ipairs(team) do
    if k.hp > 0 then
      local score = matchup(k, foe) * 100 + k.level
      if not best or score > best_score then best, best_score = i, score end
    end
  end
  return best
end

-- 打一場（隊伍會真的得到經驗、升級）。回傳 結果、回合數
-- 訓練家戰：一開始就派最有利的那隻（玩家看得到對手是什麼）；野生戰：照隊伍順序（帶頭的初始野伴）
local function fight(team, foes, wild)
  local b = battle_new(team, foes, { wild = wild })
  if not wild then
    local i = pick(team, foes[1])
    if i ~= 1 then battle_send_out(b, 1, i) end
  end
  for _ = 1, 200 do
    battle_step(b, smart(b, 1), battle_ai(b, 2))
    if b.over then break end
    if battle_active(b, 1).hp <= 0 then battle_send_out(b, 1, pick(team, battle_active(b, 2))) end
    if battle_active(b, 2).hp <= 0 then battle_send_out(b, 2, battle_next_alive(b, 2)) end
  end
  return b.over, b.turn
end

-- 訓練家的隊伍（阿穗的 "rival" 換成剋制主角的那隻，夠等級就是進化後的樣子）
local function trainer_party(key, starter)
  local foes = {}
  for i, p in ipairs(DATA.trainers[key].party) do
    local no = p.species
    if no == "rival" then no = RIVAL[starter] end
    local ev = DATA.species[no].evolve
    if ev and p.level >= ev.level then no = ev.to end
    foes[i] = kin_new(no, p.level)
  end
  return foes
end

local function boss_party(key, starter)
  if key == "cloudroot" then return { kin_new("16", CLOUDROOT_LEVEL) }, true end
  return trainer_party(key, starter), false
end

-- 頭目勝率：用現在隊伍的複製打 N_SIM 場
local function win_rate(team, key, starter)
  local wins = 0
  for _ = 1, N_SIM do
    local mine = {}
    for i, k in ipairs(team) do mine[i] = clone(k) end
    heal_all(mine)
    local foes, wild = boss_party(key, starter)
    if fight(mine, foes, wild) == "win" then wins = wins + 1 end
  end
  return wins * 100 // N_SIM
end

-- 遭遇表的權重：四個時段平均（玩家各時段都會玩到；不算季節、天氣）
local PERIODS = { "morning", "day", "evening", "night" }
local function weight(e)
  local w = 0
  for _, p in ipairs(PERIODS) do w = w + ((e.times and e.times[p]) or e.weight) end
  return w
end

local function wild_foe(area)
  local list = DATA.encounters[area].list
  local total = 0
  for _, e in ipairs(list) do total = total + weight(e) end
  local r = rnd(total)
  for _, e in ipairs(list) do
    if r < weight(e) then return kin_new(e.species, e.min + rnd(e.max - e.min + 1)) end
    r = r - weight(e)
  end
end

-- 這一區這一種野伴的平均等級（抓到的那隻用）
local function area_level(area, no)
  for _, e in ipairs(DATA.encounters[area].list) do
    if e.species == no then return (e.min + e.max) // 2 end
  end
  return 5
end

-- ============================================================
-- 跑一個初始野伴的全程一次
-- ============================================================
-- 回傳 rec：rec.boss[第幾個頭目] = { arrive, w0, extra, after }；rec.chapter[第幾章] = { sec }；rec.lost[輸給的訓練家] = true
local function run(starter)
  local team = { kin_new(starter, 5) }
  local hero = team[1]                 -- 初始野伴（報告看它的等級）
  local rec = { boss = {}, chapter = {}, lost = {} }
  local sec, chapter_sec, chapter = 0, 0, nil

  local function add(seconds) sec, chapter_sec = sec + seconds, chapter_sec + seconds end

  local function wild_battle(area)
    local _, turns = fight(team, { wild_foe(area) }, true)
    heal_all(team)          -- 當作有用傷藥、回旅店（一般玩家不會帶著半血一直打）
    evolve_all(team)
    add(SEC_WILD + turns * SEC_TURN)
  end

  for _, step in ipairs(PLAYTHROUGH) do
    if step.chapter then
      if chapter then
        add(chapter.pages * SEC_PAGE + chapter.chores * 60)
        rec.chapter[#rec.chapter + 1] = { sec = chapter_sec }
      end
      chapter, chapter_sec = step, 0
    else
      local area = step.area
      -- 第一次到這一區的遇敵（四捨五入）
      if step.wild then
        for _ = 1, (step.wild * 10 + 5) // 10 do wild_battle(area) end
      end
      -- 抓：每一種第一次抓到 3 倍經驗（battle.lua 的規則；經驗照 give_exp 分給隊伍）
      for _, no in ipairs(step.catch or {}) do
        local lv = area_level(area, no)
        local foe = kin_new(no, lv)
        local b = battle_new(team, { foe }, { wild = true })
        give_exp(b, kin_exp_reward(foe) * 3, {})
        evolve_all(team)
        add(SEC_CATCH)
        for _, kept in ipairs(step.keep or {}) do
          if kept == no or (kept == "mate" and MATE[starter] == no) then
            if #team < 6 then team[#team + 1] = kin_new(no, lv) end
          end
        end
      end
      if step.trainer then
        local result, turns = fight(team, trainer_party(step.trainer, starter), false)
        heal_all(team)
        evolve_all(team)
        add(SEC_TRAINER + turns * SEC_TURN)
        if result ~= "win" then rec.lost[step.trainer] = true end
      end
      if step.boss then
        local r = { arrive = hero.level }
        r.w0 = win_rate(team, step.boss, starter)
        local extra, w = 0, r.w0
        while w < TARGET_WIN and extra < 300 do
          for _ = 1, 5 do wild_battle(area); add(SEC_STEP) end
          extra = extra + 5
          w = win_rate(team, step.boss, starter)
        end
        r.extra, r.after = extra, hero.level
        rec.boss[#rec.boss + 1] = r
        local foes, wild = boss_party(step.boss, starter)
        local _, turns = fight(team, foes, wild)
        heal_all(team)
        evolve_all(team)
        add(SEC_TRAINER + turns * SEC_TURN)
      end
    end
  end
  rec.sec = sec
  local t = {}
  for i, k in ipairs(team) do t[i] = kin_name(k) .. " " .. k.level end
  rec.team = table.concat(t, "、")
  return rec
end

-- ============================================================
-- 跑 RUNS 次，取平均
-- ============================================================
local function avg10(sum) return string.format("%d.%d", sum * 10 // RUNS // 10, sum * 10 // RUNS % 10) end

local function report(starter)
  local recs = {}
  for i = 1, RUNS do recs[i] = run(starter) end
  local out = { "", "=== 初始：" .. DATA.species[starter].name .. "（跑 " .. RUNS .. " 次的平均）===" }
  -- 頭目
  local bi = 0
  for _, step in ipairs(PLAYTHROUGH) do
    if step.boss then
      bi = bi + 1
      local a, w0, ex, af, mx = 0, 0, 0, 0, 0
      for _, r in ipairs(recs) do
        local b = r.boss[bi]
        a, w0, ex, af = a + b.arrive, w0 + b.w0, ex + b.extra, af + b.after
        mx = math.max(mx, b.extra)
      end
      local name = step.boss == "cloudroot" and "雲根" or DATA.trainers[step.boss].name
      out[#out + 1] = string.format("  %s：到的時候 Lv%s、勝率 %d%%　→ 要練等 %d 場（最多 %d）→ Lv%s",
        name, avg10(a), w0 // RUNS, ex // RUNS, mx, avg10(af))
    end
  end
  -- 每章時間
  local chapters = {}
  for _, step in ipairs(PLAYTHROUGH) do
    if step.chapter and step.target then chapters[#chapters + 1] = step end
  end
  local line, total = {}, 0
  for i, c in ipairs(chapters) do
    local s = 0
    for _, r in ipairs(recs) do s = s + r.chapter[i].sec end
    line[#line + 1] = string.format("%s %d 分（企劃 %d）", c.chapter, s // RUNS // 60, c.target)
    total = total + s
  end
  out[#out + 1] = "  時間：" .. table.concat(line, "、")
  local sec = total // RUNS
  out[#out + 1] = string.format("  全程約 %d 小時 %d 分（企劃 4 小時）", sec // 3600, sec % 3600 // 60)
  local lost = {}
  for _, r in ipairs(recs) do for key in pairs(r.lost) do lost[key] = (lost[key] or 0) + 1 end end
  for key, n in pairs(lost) do out[#out + 1] = "  （" .. RUNS .. " 次裡輸給「" .. DATA.trainers[key].name .. "」" .. n .. " 次）" end
  out[#out + 1] = "  最後的隊伍（第 1 次）：" .. recs[1].team
  return table.concat(out, "\n")
end

print("全遊戲等級曲線（W78；模型的假設見 tools/balance/curve.lua 開頭）")
print("頭目：到的時候初始野伴的等級、勝率；勝率不到 " .. TARGET_WIN .. "% 就在那一區練等，每 5 場重算")
for _, st in ipairs({ "01", "03", "05" }) do print(report(st)) end
