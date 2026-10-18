-- dialog.lua：畫面下方的對話框
--
-- 用法：
--   dialog_open("很長的一段話……", function() 對話結束後要做的事 end)
--   dialog_ask("要出發了嗎？", { "是", "否" }, function(i) 選了第 i 項 end)
--   _update 裡：if dialog_active() then dialog_update() return end
--   _draw 最後：dialog_draw()
--
-- 功能：自動換行、每頁 2 行、逐字出現、▼ 提示下一頁。
--   字還在出現時按 A 或 B → 整頁立刻顯示
--   整頁都出現了按 A 或 B → 下一頁；最後一頁按完就關閉
-- 文字裡可以用 \n 強制換行，用 \f 強制換頁

-- 框的位置和大小（畫面下方，GB 風格：白底黑框）
local BOX_X, BOX_Y, BOX_W, BOX_H = 4, 184, 312, 52
local PAD_X = 10                   -- 文字離框的左右距離
local LINE_Y = { 192, 208 }        -- 兩行字的 y（行距 16）
local TEXT_W = BOX_W - PAD_X * 2   -- 一行最寬 292 像素 ≈ 22 個中文字
local LINES_PER_PAGE = #LINE_Y

local FRAMES_PER_CHAR = 2          -- 每 2 幀多出現一個字（每秒 30 字）

-- 不能放在行首的標點（避頭點）
local NO_LINE_START = {}
for _, ch in ipairs({ "，", "。", "、", "！", "？", "：", "；", "」", "』", "）", "…", ",", ".", "!", "?" }) do
  NO_LINE_START[ch] = true
end
-- 不能放在行尾的符號（避尾點）：開頭的括號、引號要和後面的字在同一行
local NO_LINE_END = {}
for _, ch in ipairs({ "「", "『", "（", "(" }) do
  NO_LINE_END[ch] = true
end

local dlg = nil   -- 目前的對話：nil 代表沒有對話
-- dlg = {
--   pages     = { { "第一行", "第二行" }, ... }
--   page      = 第幾頁
--   shown     = 這一頁已經出現了幾個字
--   total     = 這一頁總共幾個字
--   tick      = 計時（幀）
--   on_done   = 結束時呼叫的函式（可以是 nil）
--   choices   = dialog_ask 的選項（dialog_open 是 nil）
--   menu      = 最後一頁出現完之後顯示的選單
-- }

-- 把字串拆成一個一個字（UTF-8：中文一個字佔 3 byte，不能用 s:sub(i, i)）
local function chars(s)
  local t = {}
  for _, cp in utf8.codes(s) do t[#t + 1] = utf8.char(cp) end
  return t
end

-- 一段文字（沒有 \n、\f）→ 好幾行，每行不超過 TEXT_W
local function wrap(paragraph, lines)
  local line, width = {}, 0
  for _, ch in ipairs(chars(paragraph)) do
    local w = textw(ch)
    if width + w > TEXT_W and #line > 0 then
      -- 要換行了。從這一行的尾巴「借」幾個字到下一行：
      --   這個字是不能放行首的標點（，。）→ 把上一個字一起帶下去
      --   這一行最後是不能放行尾的符號（「）→ 也帶下去
      local carry = {}
      if NO_LINE_START[ch] and #line > 1 then
        table.insert(carry, 1, table.remove(line))
      end
      while #line > 1 and NO_LINE_END[line[#line]] do
        table.insert(carry, 1, table.remove(line))
      end
      lines[#lines + 1] = table.concat(line)
      line = carry
      width = 0
      for _, c in ipairs(carry) do width = width + textw(c) end
    end
    line[#line + 1] = ch
    width = width + w
  end
  lines[#lines + 1] = table.concat(line)
end

-- 整段文字 → 一頁一頁，每頁最多 LINES_PER_PAGE 行
local function paginate(text)
  local pages = {}
  for block in (text .. "\f"):gmatch("(.-)\f") do          -- \f：強制換頁
    local lines = {}
    for paragraph in (block .. "\n"):gmatch("(.-)\n") do  -- \n：強制換行
      wrap(paragraph, lines)
    end
    for i = 1, #lines, LINES_PER_PAGE do
      local page = {}
      for j = i, math.min(i + LINES_PER_PAGE - 1, #lines) do page[#page + 1] = lines[j] end
      pages[#pages + 1] = page
    end
  end
  return pages
end

local function start_page(n)
  dlg.page = n
  dlg.shown = 0
  dlg.tick = 0
  dlg.total = 0
  for _, line in ipairs(dlg.pages[n]) do dlg.total = dlg.total + utf8.len(line) end
end

function dialog_open(text, on_done)
  dlg = { pages = paginate(text), on_done = on_done }
  start_page(1)
end

-- 問問題：最後一頁的字出現完之後，在框的右上方出現選單。
-- 問題的文字會留在框裡，玩家看得到自己在回答什麼。選完呼叫 on_choice(第幾項)
function dialog_ask(text, choices, on_choice)
  dlg = { pages = paginate(text), choices = choices, on_choice = on_choice }
  start_page(1)
end

function dialog_active()
  return dlg ~= nil
end

function dialog_update()
  if not dlg then return end
  local ok = pressed(A) or pressed(B)

  if dlg.shown < dlg.total then
    -- 字還在出現
    if ok then
      dlg.shown = dlg.total                      -- 按 A：整頁立刻顯示
    else
      dlg.tick = dlg.tick + 1
      if dlg.tick % FRAMES_PER_CHAR == 0 then dlg.shown = dlg.shown + 1 end
    end
  elseif dlg.choices and dlg.page == #dlg.pages then
    -- 問題的最後一頁：交給選單
    if not dlg.menu then
      local m = menu_new({ items = dlg.choices, x = 0, y = 0, cancel = false })
      m.x = BOX_X + BOX_W - m.w                -- 靠右、疊在對話框上面
      m.y = BOX_Y - m.h + 3
      dlg.menu = m
    end
    local r = menu_update(dlg.menu)
    if r then
      local choose = dlg.on_choice
      dlg = nil
      choose(r)
    end
  elseif ok then
    if dlg.page < #dlg.pages then
      start_page(dlg.page + 1)                   -- 下一頁
    else
      local done = dlg.on_done                   -- 最後一頁：關閉
      dlg = nil
      if done then done() end                    -- 先關再呼叫：on_done 裡可以馬上開新的對話
    end
  end
end

-- 畫框：GB 風格的白底、黑色雙線框
function ui_box(x, y, w, h)
  rect(x, y, w, h, 0)
  rect(x + 1, y + 1, w - 2, h - 2, 7)
  rect(x + 2, y + 2, w - 4, h - 4, 0)
  rect(x + 3, y + 3, w - 6, h - 6, 7)
end

-- 往下的小三角形（寬 7、高 4），提示「還有下一頁」
function ui_arrow_down(x, y, c)
  for i = 0, 3 do rect(x + i, y + i, 7 - i * 2, 1, c) end
end

-- 往右的小三角形（寬 4、高 7），選單的游標
function ui_arrow_right(x, y, c)
  for i = 0, 3 do rect(x + i, y + i, 1, 7 - i * 2, c) end
end

function dialog_draw()
  if not dlg then return end
  camera()   -- 對話框固定在畫面上，不跟著地圖捲動
  ui_box(BOX_X, BOX_Y, BOX_W, BOX_H)

  -- 只畫已經出現的字
  local left = dlg.shown
  for i, line in ipairs(dlg.pages[dlg.page]) do
    if left <= 0 then break end
    local n = utf8.len(line)
    local part = line
    if left < n then part = line:sub(1, utf8.offset(line, left + 1) - 1) end  -- 前 left 個字
    text(part, BOX_X + PAD_X, LINE_Y[i], 0)
    left = left - n
  end

  if dlg.menu then
    menu_draw(dlg.menu)
    return
  end

  -- 整頁都出現了：▼ 每半秒閃一次
  if dlg.shown >= dlg.total and frame() % 60 < 30 then
    ui_arrow_down(BOX_X + BOX_W - 16, BOX_Y + BOX_H - 11, 0)
  end
end
