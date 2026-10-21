-- day.lua：睡覺過一天（W46）
--
-- 營地有主角的帳篷（地圖物件 type = "bed"，2×2 格、擋路）。面對它按 A → 「要睡到明天早上嗎？」→
-- 畫面暗下來（Zzz……）→ 全黑的時候結算 → 亮起來 → 報告：
--   1. DAY + 1：野外的採集點重新長出來（gather.lua 看 GATHERED 的日期）
--   2. 隊伍全部回復（HP、招式次數、狀態）
--   3. 設施產出（facility.lua 的 facility_day_end）：派駐的野伴每隻吃 1 份飼料，吃不到的那隻產量減半
-- 時間只用「天」，不用真實時間：結果完全由存檔決定（design.md）

local BED_SPRITE = 6   -- facilities.png 第 6 格：帳篷
local beds = {}

function bed_load()
  beds = {}
  for _, o in ipairs(world.objects) do
    if o.type == "bed" then
      beds[#beds + 1] = { cx = o.x, cy = o.y, x = o.x * TILE, y = o.y * TILE }
      for dy = 0, 1 do
        for dx = 0, 1 do mset(world.map, "solid", o.x + dx, o.y + dy, 1) end
      end
    end
  end
end

function bed_at(px, py)
  local cx, cy = px // TILE, py // TILE
  for _, b in ipairs(beds) do
    if cx >= b.cx and cx <= b.cx + 1 and cy >= b.cy and cy <= b.cy + 1 then return b end
  end
  return nil
end

function bed_draw()
  for _, b in ipairs(beds) do spr(IMG.facilities, BED_SPRITE, b.x, b.y) end
end

-- 結算（全黑的時候呼叫），回傳早上要說的話
local function day_end()
  -- 今天撿過的採集點，明天會再長出來
  local regrow = 0
  for k, d in pairs(GATHERED) do
    if d >= DAY then regrow = regrow + 1 end
  end
  GATHERED = {}   -- 過了一天，全部都能再撿（順便讓存檔不要越存越大）
  DAY = DAY + 1
  for _, k in ipairs(party) do kin_heal(k) end
  for _, fac in pairs(FACILITY) do
    for _, k in ipairs(fac.workers) do kin_heal(k) end
  end

  local lines = { "天亮了，第 " .. DAY .. " 天。\n野伴們都恢復精神了！" }
  local report, workers, hungry = facility_day_end()
  if #report > 0 then
    lines[#lines + 1] = "設施的產出：\n" .. table.concat(report, "\n")
  end
  if workers > 0 then
    local fed = workers - hungry
    if fed > 0 then lines[#lines + 1] = "派駐的野伴吃掉了飼料 ×" .. fed .. "。" end
    if hungry > 0 then
      lines[#lines + 1] = "飼料不夠！有 " .. hungry .. " 隻野伴餓著肚子工作，\n產量少了一半。（飼料可以在工作台做）"
    end
  end
  if regrow > 0 then lines[#lines + 1] = "野外的採集點又長出來了。" end
  return table.concat(lines, "\n")
end

function bed_interact(b)
  dialog_ask("要睡到明天早上嗎？", { "睡覺", "不要" }, function(c)
    if c ~= 1 then return end
    dialog_open(PLAYER_NAME .. "鑽進睡袋。\n腰發出了「喀」的一聲。", function()
      local morning
      transition_start(function() morning = day_end() end, false,
        { hold = 90, caption = "Zzz……", on_end = function() dialog_open(morning) end })
    end)
  end)
end
