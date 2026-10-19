-- npc.lua：地圖上的 NPC
--
-- NPC 放在地圖的物件層（Comet Studio 的地圖編輯器 → 物件 → NPC），每個有：
--   name：名字（程式裡用，英文）
--   tile：圖（地圖格子編號，見 world_spr）
--   talk：對話編號（talk.lua 的 TALK 表格裡找）
-- 進入地圖時，world_enter 之後呼叫 npc_load()，就會把這張地圖的 NPC 都建立起來。
--
-- NPC 預設面向右邊（Kenney 的角色圖都是面向右）。主角跟它說話時，它會轉頭面向主角。

npcs = {}

function npc_load()
  npcs = {}
  for _, o in ipairs(world.objects) do
    if o.type == "npc" then
      local n = {
        name = o.name,
        tile = o.tile,
        talk = o.talk,
        x = o.x * TILE,         -- 圖的左上角（世界座標）；和主角、world_blocked 用一樣的規則
        y = o.y * TILE,
        face_left = false,
      }
      npcs[#npcs + 1] = n
      world_add_blocker(n)      -- NPC 會擋路，不能穿過去
    end
  end
end

-- 世界座標 (px, py) 這一點在哪個 NPC 身上（沒有回傳 nil）。
-- 用整張圖的 16 × 16 範圍判斷，不只是腳：主角站在 NPC 上方往下看時，前方那一點會落在 NPC 的頭上
function npc_at(px, py)
  for _, n in ipairs(npcs) do
    if px >= n.x and px < n.x + TILE and py >= n.y and py < n.y + TILE then return n end
  end
  return nil
end

-- 轉頭面向世界座標 x（通常是主角的中心）
function npc_face(n, x)
  n.face_left = x < n.x + TILE // 2
end

function npc_draw(n)
  world_spr(n.tile, n.x, n.y, n.face_left)
end
