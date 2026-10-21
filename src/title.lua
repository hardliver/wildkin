-- title.lua：標題畫面（W49）
--
-- 開機 → 標題：天空、草地、三隻初始野伴、標誌（assets/art/logo.png，tools/art/logo.py 產生）
--   有存檔：繼續／新遊戲；沒有存檔：新遊戲
--   繼續 → 選欄位（空的不能選）→ 讀檔
--   新遊戲 → 選要存在哪個欄位（有存檔的要確認）→ 開始
-- 選單用 screens.lua 的堆疊（ui_push），所以對話框、是／否都能直接用。

local title = nil   -- { t = 計時 }，nil = 不在標題畫面

function title_active() return title ~= nil end

local function any_save()
  for i = 1, 3 do if game_read(i) then return true end end
  return false
end

-- 離開標題：轉場全黑時才真的換（看不到切換的瞬間）
local function leave(start)
  transition_start(function()
    ui_clear()
    title = nil
    start()
  end)
end

-- 選欄位。mode = "load"（繼續）／"new"（新遊戲）
local function slot_screen(mode)
  local saves = {}
  for i = 1, 3 do saves[i] = game_read(i) or false end
  local screen = { index = 1 }
  if mode == "load" then
    while not saves[screen.index] do screen.index = screen.index + 1 end   -- 從第一個有存檔的開始
  end
  function screen.update(self)
    if pressed_repeat(UP) then self.index = (self.index - 2) % 3 + 1 end
    if pressed_repeat(DOWN) then self.index = self.index % 3 + 1 end
    if pressed(B) then ui_pop() return end
    if not pressed(A) then return end
    local i, s = self.index, saves[self.index]
    if mode == "load" then
      if not s then return end
      leave(function() load_game(i, s) end)
    elseif s then
      dialog_ask("欄位 " .. i .. " 已經有存檔了。\n新遊戲存檔時會蓋掉，可以嗎？", { "可以", "不要" }, function(c)
        if c == 1 then leave(function() new_game(i) end) end
      end)
    else
      leave(function() new_game(i) end)
    end
  end
  function screen.draw(self)
    ui_box(16, 20, 288, 200)
    text(mode == "load" and "要繼續哪一個？" or "要存在哪一個欄位？", 30, 30, 0)
    for i = 1, 3 do
      local y = 54 + (i - 1) * 54
      local s = saves[i]
      if i == self.index then ui_arrow_right(30, y + 4, 0) end
      text("欄位 " .. i, 42, y, 0)
      if s then
        local lines = save_summary(s)
        text(lines[1], 100, y, 0)
        text(lines[2], 100, y + 18, 5)
      else
        text("（空的）", 100, y, 5)
      end
      if i < 3 then rect(28, y + 44, 264, 1, 6) end
    end
  end
  ui_push(screen)
end

local function main_menu()
  local items = any_save() and { "繼續", "新遊戲" } or { "新遊戲" }
  local m = menu_new({ items = items, x = 0, y = 0, cancel = false })
  m.x, m.y = (SCREEN_W - m.w) // 2, 168
  local screen = { menu = m }
  function screen.update(self)
    local r = menu_update(self.menu)
    if not r then return end
    if items[r] == "繼續" then slot_screen("load") else slot_screen("new") end
  end
  function screen.draw(self) menu_draw(self.menu) end
  ui_push(screen)
end

function title_open()
  title = { t = 0 }
  ui_clear()
  main_menu()
end

-- 離開標題畫面（不經過轉場；除錯指令用）
function title_close()
  title = nil
  ui_clear()
end

function title_update()
  title.t = title.t + 1
  ui_update()
end

local LOGO_W, LOGO_H = 122, 76   -- logo.png 的大小
-- 天空的顏色（自訂調色盤 253–255；戰鬥用 244–252）：上面深、越接近地平線越淡
local C_SKY1, C_SKY2, C_SKY3 = 253, 254, 255
pal(C_SKY1, 110, 178, 228)
pal(C_SKY2, 150, 204, 238)
pal(C_SKY3, 200, 230, 244)
local CLOUDS = { { 30, 30, 40 }, { 150, 18, 56 }, { 250, 44, 36 } }   -- x, y, 寬

function title_draw()
  local t = title.t
  camera()
  rect(0, 0, SCREEN_W, 60, C_SKY1)              -- 天空：三段漸層
  rect(0, 60, SCREEN_W, 30, C_SKY2)
  rect(0, 90, SCREEN_W, 30, C_SKY3)
  for i, c in ipairs(CLOUDS) do                 -- 雲慢慢往左飄
    local x = (c[1] - t // (6 + i * 2)) % (SCREEN_W + 80) - 60
    rect(x, c[2], c[3], 8, 7)
    rect(x + 8, c[2] - 5, c[3] - 20, 6, 7)
  end
  for x = 0, SCREEN_W - 1, 16 do               -- 地平線上一排樹（Tiny Town 的樹）
    local top = (hash(x, 1) % 4 == 0) and 3 or 4   -- 兩格高的樹：上半格 3（橘）／4（綠），下半格 +12
    spr(IMG.town, top, x, 82)
    spr(IMG.town, top + 12, x, 98)
  end
  for y = 112, SCREEN_H - 1, 16 do              -- 草地：Tiny Town 的草地格子
    for x = 0, SCREEN_W - 1, 16 do spr(IMG.town, (hash(x, y) % 5 == 0) and 1 or 0, x, y) end   -- 偶爾一叢草
  end
  -- 三隻初始野伴站在草地上，輪流輕輕跳一下
  local kin = { "01", "03", "05" }
  for i, no in ipairs(kin) do
    local hop = ((t + i * 40) % 120 < 8) and 2 or 0
    spr(IMG.kin_front, DATA.species[no].sprite, 28 + (i - 1) * 100, 92 - hop)
  end
  sspr(IMG.logo, 0, 0, LOGO_W, LOGO_H, (SCREEN_W - LOGO_W) // 2, 8)
end
