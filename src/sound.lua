-- sound.lua：音效和音樂（W77）
--
-- 聲音的資料在 audio/sfx.json（tools/audio/make_sfx.py 產生，也可以在 Studio 的音效編輯器改），
-- comet.json 的 "sfx" 合併進遊戲：SFX、MUSIC 兩個表格。引擎的 sfx(名字)、music(名字) 播放（comet AI_GUIDE「音效與音樂」）。
--
-- 遊戲裡一律用這兩個函式，不直接叫引擎的：
--   snd(名字)          播一個音效（tools/check_data.mjs 會檢查程式裡用到的名字 sfx.json 裡都有）
--   play_music(名字)   換音樂；和正在播的一樣就不重新開始（走進同一種地圖，音樂接著播）
-- 聲音不影響遊戲的結果（重播、測試都一樣），所以放心在任何地方叫

local current = nil   -- 正在播的音樂

function snd(name)
  sfx(name)
end

function play_music(name)
  if name == current then return end
  current = name
  if name then music(name) else music() end
end

-- 每張地圖的音樂（沒列的用原野）
MUSIC_OF_MAP = {
  camp = "field", route1 = "field", coast = "field", ridge = "field",
  village = "town", harbor = "town",
  forest = "forest", summit = "forest",
  mine = "cave", volcano = "cave", factory = "cave", office = "cave",
}

-- 回到地圖時（換地圖、戰鬥結束）：照這張地圖換音樂
function map_music()
  play_music(MUSIC_OF_MAP[world.name] or "field")
end

-- 走路的腳步聲：每走幾幀一聲（騎車快一點）；草叢裡的聲音比較明顯
local step_t = 0
function step_sound()
  if not player.walking then
    step_t = 0
    return
  end
  step_t = step_t + 1
  if step_t % (player.riding and 10 or 16) ~= 1 then return end
  local cx, cy = player_cell()
  snd(in_grass(cx, cy) and "step_grass" or "step")   -- in_grass：encounter.lua
end
