-- kin.lua：一隻野伴（個體）
--
-- 「種類」和「個體」要分清楚：
--   種類：DATA.species["07"]，所有囤囤鼠共用的資料（名稱、基礎值、學招表）
--   個體：這一隻囤囤鼠，有自己的等級、目前 HP、經驗、記住的招式
-- 個體只存「會變的東西」和種類編號；能力值每次從種類 + 等級算出來，不另外存，
-- 這樣改了 species.json 的基礎值，存檔裡的野伴也會跟著變，不會兩邊對不上。
--
-- 個體是一般的 Lua 表格（之後直接放進存檔）：
--   { no = "07", level = 3, exp = 27, hp = 14, moves = { { key = "tackle", pp = 35 }, ... } }
--
-- 公式（docs/design.md）：
--   HP     = 基礎值 × 等級 // 50 + 等級 + 10
--   其他   = 基礎值 × 等級 // 50 + 5
--   升到 n 級需要的總經驗 = n³
--   打倒一隻得到的經驗 = 基礎經驗 × 對方等級 // 7

local MAX_LEVEL = 50
local MAX_MOVES = 4

function kin_species(k)
  return DATA.species[k.no]
end

function kin_name(k)
  return kin_species(k).name
end

-- 能力值：stat 是 "hp"、"atk"、"def"、"spd"
function kin_stat(k, stat)
  local base = kin_species(k).base[stat]
  if stat == "hp" then
    return base * k.level // 50 + k.level + 10
  end
  return base * k.level // 50 + 5
end

function kin_max_hp(k)
  return kin_stat(k, "hp")
end

-- 升到 level 級需要的總經驗
function kin_exp_for(level)
  return level * level * level
end

-- 野生或剛拿到時記住的招式：學招表裡「等級以下」最後學會的 4 招（同一招不重複）
local function default_moves(species, level)
  local keys = {}
  for _, entry in ipairs(species.learn) do
    local lv, key = entry[1], entry[2]
    if lv > level then break end
    local dup = false
    for _, k in ipairs(keys) do if k == key then dup = true end end
    if not dup then keys[#keys + 1] = key end
  end
  local moves = {}
  for i = math.max(1, #keys - MAX_MOVES + 1), #keys do
    moves[#moves + 1] = { key = keys[i], pp = DATA.moves[keys[i]].pp }
  end
  return moves
end

-- 產生一隻野伴：種類編號（"07"）、等級。HP 全滿、經驗剛好是這個等級的起點
function kin_new(no, level)
  local species = DATA.species[no]
  if not species then error("沒有編號 " .. tostring(no) .. " 的野伴（data/species.json）") end
  level = clamp(level, 1, MAX_LEVEL)
  local k = { no = no, level = level, exp = kin_exp_for(level) }
  k.moves = default_moves(species, level)
  k.hp = kin_max_hp(k)
  return k
end

-- 打倒 foe 得到的經驗
function kin_exp_reward(foe)
  return kin_species(foe).exp * foe.level // 7
end

-- 得到經驗。回傳這次發生的事（給畫面演出用，W30），例如：
--   { { kind = "level", level = 6 }, { kind = "learn", key = "quick" },
--     { kind = "full", key = "leer" } }   ← 招式滿了，要玩家選一招忘掉
-- 升級時最大 HP 增加多少，目前 HP 也增加多少（和 GB 一樣，升級不會把血補滿）
function kin_gain_exp(k, amount)
  local events = {}
  k.exp = k.exp + amount
  while k.level < MAX_LEVEL and k.exp >= kin_exp_for(k.level + 1) do
    local old_max = kin_max_hp(k)
    k.level = k.level + 1
    k.hp = k.hp + kin_max_hp(k) - old_max
    events[#events + 1] = { kind = "level", level = k.level }
    for _, entry in ipairs(kin_species(k).learn) do
      if entry[1] == k.level then
        events[#events + 1] = kin_learn(k, entry[2])
      end
    end
  end
  if k.level == MAX_LEVEL then k.exp = math.min(k.exp, kin_exp_for(MAX_LEVEL)) end
  return events
end

-- 學一招：已經會了就不動；還有空位就學會；滿 4 招就回傳 "full"，交給畫面讓玩家決定
function kin_learn(k, key)
  for _, m in ipairs(k.moves) do
    if m.key == key then return { kind = "known", key = key } end
  end
  if #k.moves < MAX_MOVES then
    k.moves[#k.moves + 1] = { key = key, pp = DATA.moves[key].pp }
    return { kind = "learn", key = key }
  end
  return { kind = "full", key = key }
end

-- 忘掉第 i 招、換成新招（玩家在「招式滿了」時選的）
function kin_replace_move(k, i, key)
  k.moves[i] = { key = key, pp = DATA.moves[key].pp }
end

-- 回復全部 HP 和招式次數（旅店、睡覺、全滅後回營地）
function kin_heal(k)
  k.hp = kin_max_hp(k)
  for _, m in ipairs(k.moves) do m.pp = DATA.moves[m.key].pp end
  k.status = nil
end

-- ============================================================
-- 進化（W38）
-- ============================================================
-- species.json 的 evolve = { to = "02", level = 16 }：到了那個等級就會進化。
-- 玩家取消的話記住 k.evolve_skip = 目前等級，等下一次升級才會再問（和 GB 一樣）

-- 這隻現在能不能進化：能的話回傳進化後的編號
function kin_can_evolve(k)
  local e = kin_species(k).evolve
  if not e or k.hp <= 0 or k.level < e.level then return nil end
  if k.evolve_skip and k.evolve_skip >= k.level then return nil end
  return e.to
end

-- 進化：換種類；最大 HP 增加多少、目前 HP 也增加多少；學會新種類在這個等級的招。回傳學招的事件
function kin_evolve(k, to)
  local old_max = kin_max_hp(k)
  k.no = to
  k.hp = k.hp + kin_max_hp(k) - old_max
  k.evolve_skip = nil
  local events = {}
  for _, entry in ipairs(kin_species(k).learn) do
    if entry[1] == k.level then events[#events + 1] = kin_learn(k, entry[2]) end
  end
  return events
end

-- ============================================================
-- 16×16 小圖示（W42）：基地裡派駐的野伴走來走去用
-- ============================================================
-- kin_icons.png：每種 3 格，從第 sprite × 3 格開始：0 站著、1 左腳在前、2 右腳在前
-- 走路循環：1 →（0，身體往上 1 像素）→ 2 →（0，往上 1 像素），每 STEP 幀換一拍
local ICON_STEP = 6
local WALK = { { 1, 0 }, { 0, -1 }, { 2, 0 }, { 0, -1 } }   -- { 第幾格, 往上幾像素 }

-- no：種類編號；walking：在走嗎；t：計時（幀）；face_right：面向右（圖是面向左畫的，往右就翻轉）
-- shiny：異色（W65）
function kin_icon_draw(no, x, y, walking, t, face_right, shiny)
  local base = DATA.species[no].sprite * 3
  if shiny then dpal(shiny_map(no)) end
  if not walking then
    spr(IMG.kin_icons, base, x, y, face_right)
  else
    local w = WALK[(t // ICON_STEP) % 4 + 1]
    spr(IMG.kin_icons, base + w[1], x, y + w[2], face_right)
  end
  if shiny then dpal() end
end
