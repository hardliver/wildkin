-- gather.lua：野外的採集點（W43）
--
-- 地圖的物件層放 type = "gather" 的物件：
--   item：撿到什麼（items.json 的編號，例如 "wood"、"berry"）
--   amount：一次撿幾個
--   tile：畫什麼（地圖格子編號，例如 107 木頭、44 石頭、6 灌木、18 草叢）
-- 面對它按 A 就撿起來。每個採集點「一天一次」：撿過之後要等睡覺過一天（W46）才會再長出來。
-- 莓果灌木（item = "berry"）會擋路，撿過之後只剩灌木（莓果不見）；其他撿過就消失。
--
-- 記錄：GATHERED["地圖:x:y"] = 撿的那一天（DAY）。DAY 在睡覺時 +1（W46），存檔時一起存（W49）

DAY = DAY or 1
GATHERED = GATHERED or {}

local spots = {}   -- 這張地圖的採集點

local function key(o) return world.name .. ":" .. o.x .. ":" .. o.y end

local function ready(o)
  local d = GATHERED[key(o)]
  return d == nil or d < DAY
end

local function blocks(o) return o.item == "berry" end   -- 灌木會擋路

-- 進入地圖時呼叫（npc_load 之後）
function gather_load()
  spots = {}
  for _, o in ipairs(world.objects) do
    if o.type == "gather" then
      local s = { x = o.x * TILE, y = o.y * TILE, cx = o.x, cy = o.y, item = o.item, amount = o.amount or 1, tile = o.tile, o = o }
      spots[#spots + 1] = s
      if blocks(o) then world_add_blocker(s) end
    end
  end
end

-- 世界座標 (px, py) 這一點上的採集點（還能撿的才算；灌木就算撿過也要擋，但不能再撿）
function gather_at(px, py)
  local cx, cy = px // TILE, py // TILE
  for _, s in ipairs(spots) do
    if s.cx == cx and s.cy == cy and ready(s.o) then return s end
  end
  return nil
end

function gather_take(s)
  GATHERED[key(s.o)] = DAY
  bag_add(s.item, s.amount)
  local name = DATA.items[s.item].name
  dialog_open(PLAYER_NAME .. "撿到了" .. name .. " ×" .. s.amount .. "！")
end

-- 地面之後、角色之前畫
function gather_draw()
  for _, s in ipairs(spots) do
    local ok = ready(s.o)
    if s.item == "berry" then
      world_spr(s.tile, s.x, s.y)                -- 灌木一直都在
      if ok then                                 -- 還沒摘：上面有紅色的莓果
        for _, p in ipairs({ { 4, 5 }, { 9, 4 }, { 11, 8 }, { 6, 9 }, { 8, 11 } }) do
          rect(s.x + p[1], s.y + p[2], 2, 2, 8)
          pset(s.x + p[1], s.y + p[2], 14)
        end
      end
    elseif ok then
      world_spr(s.tile, s.x, s.y)
    end
  end
end
