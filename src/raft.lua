-- raft.lua：拖筏渡水（W69，野外技能「灌溉 1」）
--
-- 地圖物件 type = "raft"（Studio：物件 → 木筏）：放在海上的那一格（地圖的圖畫木筏，港灣圖塊第 36 格），
--   to：到哪張地圖，tx、ty：到了站在哪一格
-- 面對木筏按 A：隊伍裡有會灌溉的野伴（霧傘水母、鬚鬚鯰）→ 牠咬著繩子把木筏拖到對岸。
-- 沒有的話提示去哪裡找。和其他野外技能一樣，不佔招式格（content.md）。

local rafts = {}

function raft_load()
  rafts = {}
  for _, o in ipairs(world.objects) do
    if o.type == "raft" then
      rafts[#rafts + 1] = { cx = o.x, cy = o.y, to = o.to, tx = o.tx, ty = o.ty }
    end
  end
end

function raft_at(px, py)
  local cx, cy = px // TILE, py // TILE
  for _, r in ipairs(rafts) do
    if r.cx == cx and r.cy == cy then return r end
  end
  return nil
end

function raft_interact(r)
  local k = field_skill_kin("water")
  if not k then
    dialog_open("一艘木筏綁在岸邊。\n海水太深，自己划不過去。" ..
      "\f" .. field_skill_hint("water"))
    return
  end
  local where = MAP_NAME[r.to] or r.to
  dialog_ask("要讓" .. kin_name(k) .. "拖著木筏，\n到" .. where .. "嗎？", { "出發", "不要" }, function(c)
    if c ~= 1 then return end
    dialog_open(kin_name(k) .. "咬住木筏的繩子，\n慢慢往對岸游……", function()
      transition_start(function()
        warp(r.to, r.tx, r.ty, 0, 1)
      end, false, { hold = 60, caption = "～　～　～" })
    end)
  end)
end
