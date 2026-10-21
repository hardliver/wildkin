-- fieldskill.lua：野外技能（W56）
--
-- 地圖物件 type = "block"（Studio：物件 → 擋路物）：擋住路的東西，要用野外技能打開。
--   tile：畫什麼（地圖格子編號）；need：需要的工作特性（work.json 的編號 lumber，或中文「伐木」）
-- 面對它按 A：隊伍、牧場、或派在設施工作的野伴裡，有會這項工作的 → 問要不要用 → 打開。
-- 野伴不用放在隊伍裡也能用（content.md：比 GB 的秘傳學習器佔招式格方便）。
-- 連在一起、需要同一個技能的擋路物一次全部打開（兩格高的倒木）。
-- 記錄：FLAGS["cut:地圖:x:y"] = true（存檔一起存），之後進這張地圖就不會再出現。

local blocks = {}

-- 擋路物的動作說明：要用什麼字
local ACT = {
  lumber = { verb = "砍開", doing = "喀滋喀滋地啃了起來……", done = "被砍開了！", gift = { "wood", 3 } },
  mine   = { verb = "撞碎", doing = "把身體捲成球，撞了上去……", done = "被撞碎了！", gift = { "stone", 3 } },
}

local function work_key(need)
  if DATA.work[need] then return need end
  for k, name in pairs(DATA.work) do
    if name == need then return k end
  end
  return need
end

local function key(b) return "cut:" .. world.name .. ":" .. b.cx .. ":" .. b.cy end

function block_load()
  blocks = {}
  for _, o in ipairs(world.objects) do
    if o.type == "block" then
      local b = { cx = o.x, cy = o.y, x = o.x * TILE, y = o.y * TILE, tile = o.tile, need = work_key(o.need or "lumber") }
      if not FLAGS[key(b)] then
        blocks[#blocks + 1] = b
        mset(world.map, "solid", o.x, o.y, 1)
      end
    end
  end
end

function block_at(px, py)
  local cx, cy = px // TILE, py // TILE
  for _, b in ipairs(blocks) do
    if b.cx == cx and b.cy == cy then return b end
  end
  return nil
end

-- 會這項工作的野伴（隊伍優先，再來是派在設施的、牧場的）。沒有回傳 nil
function field_skill_kin(work)
  local function can(k)
    local w = kin_species(k).work
    return w and w[work]
  end
  for _, k in ipairs(party) do if can(k) then return k end end
  for _, fac in pairs(FACILITY) do
    for _, k in ipairs(fac.workers) do if can(k) then return k end end
  end
  for _, k in ipairs(RANCH) do if can(k) then return k end end
  return nil
end

-- 從 b 開始，連在一起、同一個技能的擋路物
local function connected(b)
  local group, seen = { b }, { [b] = true }
  local i = 1
  while i <= #group do
    local a = group[i]
    for _, c in ipairs(blocks) do
      if not seen[c] and c.need == a.need and math.abs(c.cx - a.cx) + math.abs(c.cy - a.cy) == 1 then
        seen[c] = true
        group[#group + 1] = c
      end
    end
    i = i + 1
  end
  return group
end

function block_interact(b)
  local work = DATA.work[b.need] or b.need
  local what = (b.need == "lumber") and "一棵很大的倒木。" or (b.need == "mine" and "大石頭擋住了路。" or "擋住路的東西。")
  local k = field_skill_kin(b.need)
  if not k then
    if b.need == "mine" then   -- W67 舊礦坑：提示去哪裡找（礫殼犰狳住在礦坑前段）
      dialog_open(what .. "\n要找會" .. work .. "的野伴。\f（礦坑裡好像有背著石頭殼的野伴，\n說不定撞得開……）")
    else
      dialog_open(what .. "\n要找會" .. work .. "的野伴。")
    end
    return
  end
  local act = ACT[b.need] or { verb = "打開", doing = "努力了一下……", done = "被打開了！" }
  local name = kin_name(k)
  dialog_ask(what .. "\n要讓" .. name .. act.verb .. "嗎？", { "是", "否" }, function(c)
    if c ~= 1 then return end
    cutscene_start(function()
      say(name .. act.doing)
      for _, x in ipairs(connected(b)) do
        FLAGS[key(x)] = true
        mset(world.map, "solid", x.cx, x.cy, 0)
        for i, y in ipairs(blocks) do
          if y == x then table.remove(blocks, i) break end
        end
      end
      say((b.need == "lumber" and "倒木" or (b.need == "mine" and "大石頭" or "擋路的東西")) .. act.done)
      if b.need == "mine" then set_flag("mine_rock1") end
      if act.gift then give(act.gift[1], act.gift[2]) end
      if world.name == "village" and b.need == "lumber" then
        say("守衛：哇，比找伐木工人快多了。\n也比較便宜。")
      end
    end)
  end)
end

-- 地面之後畫（和採集點一起）
function block_draw()
  for _, b in ipairs(blocks) do world_spr(b.tile, b.x, b.y) end
end
