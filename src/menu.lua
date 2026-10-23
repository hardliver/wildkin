-- menu.lua：選單（戰鬥指令、招式、背包、是／否……）
--
-- 用法：
--   local m = menu_new({ items = { "戰鬥", "野伴", "背包", "逃跑" }, cols = 2, x = 180, y = 184 })
--   _update 裡：local r = menu_update(m)
--     r == nil：還在選
--     r >= 1  ：選了第 r 項（按 A）
--     r == 0  ：取消（按 B；cancel = false 的選單按 B 沒反應）
--   _draw 裡：menu_draw(m)
--
-- 每個選單是一個獨立的表格，畫面上可以同時有好幾個（例如戰鬥指令＋招式清單）。

local ROW_H = 16      -- 一行的高度（字高 14 + 間隔 2）
local PAD = 9         -- 框到內容的距離
local CURSOR_W = 10   -- 游標佔的寬度（小三角形 4 像素 + 間隔）
local COL_GAP = 12    -- 兩欄之間的距離

-- opts：items（選項文字的陣列）、cols（幾欄，預設 1）、x、y（框的左上角）、
--       cancel（按 B 能不能取消，預設 true）、index（游標一開始在第幾項，預設 1）
function menu_new(opts)
  local m = {
    items = opts.items,
    cols = opts.cols or 1,
    x = opts.x, y = opts.y,
    cancel = opts.cancel ~= false,
    index = opts.index or 1,
  }
  -- 每一格的寬度 = 最長的選項 + 游標
  local widest = 0
  for _, s in ipairs(m.items) do widest = math.max(widest, textw(s)) end
  m.cell_w = CURSOR_W + widest
  m.rows = (#m.items + m.cols - 1) // m.cols          -- 無條件進位：5 項 2 欄 = 3 列
  m.w = PAD * 2 + m.cols * m.cell_w + (m.cols - 1) * COL_GAP
  m.h = PAD * 2 + m.rows * ROW_H - 2
  return m
end

-- 第 i 項在第幾列、第幾欄（從 0 數）
local function cell(m, i)
  return (i - 1) // m.cols, (i - 1) % m.cols
end

function menu_update(m)
  local row, col = cell(m, m.index)
  local new_row, new_col = row, col
  if pressed_repeat(UP)    then new_row = row - 1 end
  if pressed_repeat(DOWN)  then new_row = row + 1 end
  if pressed_repeat(LEFT)  then new_col = col - 1 end
  if pressed_repeat(RIGHT) then new_col = col + 1 end

  -- 移到的位置要在範圍內、而且那一格有選項（最後一列可能沒排滿）；不行就不動
  local i = new_row * m.cols + new_col + 1
  if new_row >= 0 and new_col >= 0 and new_col < m.cols and i >= 1 and i <= #m.items then
    if i ~= m.index then snd("cursor") end
    m.index = i
  end

  if pressed(A) then snd("select") return m.index end
  if pressed(B) and m.cancel then snd("cancel") return 0 end
  return nil
end

function menu_draw(m)
  camera()
  ui_box(m.x, m.y, m.w, m.h)
  for i, s in ipairs(m.items) do
    local row, col = cell(m, i)
    local x = m.x + PAD + col * (m.cell_w + COL_GAP)
    local y = m.y + PAD + row * ROW_H
    if i == m.index then ui_arrow_right(x, y + 4, 0) end
    text(s, x + CURSOR_W, y, 0)
  end
end
