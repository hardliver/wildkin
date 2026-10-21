-- prologue.lua：序章用的兩個畫面（W54）
--   name_entry_open(預設名字, 選完)：取名（從字表選字，最多 4 個字）
--   starter_pick_open(選完)：選初始野伴（三隻並排）
-- 劇本在 scenes.lua；這兩個畫面用 screens.lua 的堆疊（ui_push），劇情等它們關掉才往下走。

-- ============================================================
-- 取名
-- ============================================================
-- 字型只收「原始碼和資料檔裡出現過的字」，所以能選的字要寫在這裡（約 200 個常用名字用字）
local NAME_CHARS = "大志小明偉建國華文德立俊傑宏家豪信安平和成功忠孝仁義勇強毅剛輝光榮耀龍鳳麟虎翔飛宇航海洋山川林森木水火金石玉珍寶貴富昌盛興旺福祥瑞吉慶喜樂欣怡美麗秀雅婷靜淑惠芳香蘭梅菊竹松柏青春夏秋冬晨曦陽月星雲雨雪風天地人中正心思念真善誠恩愛賢良慧聰穎敏博學士君子民聖宗彥哲瑋維霖凱翰承恆皓軒睿昊澤浩宸祐廷佑柔佳晴雯蓉萱芸琪瑜瑩潔婉玲倩妤涵彤妍宜庭若語詩書琴一二三阿世永長新嘉振豐達育遠清泉鴻鵬智勝銘鈞錦耕農田穗苔野伴友"
local COLS, ROWS = 12, 7
local MAX_LEN = 4
local CELL_W, CELL_H, GRID_X, GRID_Y = 22, 17, 28, 64

local function split(s)
  local t = {}
  for _, c in utf8.codes(s) do t[#t + 1] = utf8.char(c) end
  return t
end

function name_entry_open(default, on_done)
  local chars = split(NAME_CHARS)
  local per_page = COLS * ROWS
  local pages = (#chars + per_page - 1) // per_page
  local s = { name = split(default), page = 1, cx = 1, cy = 1 }   -- cy = ROWS + 1：「完成」
  local function char_at(cx, cy) return chars[(s.page - 1) * per_page + (cy - 1) * COLS + cx] end
  local function finish()
    local name = table.concat(s.name)
    if name == "" then name = default end
    ui_pop()
    on_done(name)
  end
  function s.update(self)
    if pressed_repeat(LEFT) then self.cx = (self.cx - 2) % COLS + 1 end
    if pressed_repeat(RIGHT) then self.cx = self.cx % COLS + 1 end
    if pressed_repeat(UP) then self.cy = (self.cy - 2) % (ROWS + 1) + 1 end
    if pressed_repeat(DOWN) then self.cy = self.cy % (ROWS + 1) + 1 end
    if pressed(L) then self.page = (self.page - 2) % pages + 1 end
    if pressed(R) then self.page = self.page % pages + 1 end
    if pressed(B) and #self.name > 0 then table.remove(self.name) end
    if pressed(START) then finish() return end
    if pressed(A) then
      if self.cy == ROWS + 1 then finish() return end
      local c = char_at(self.cx, self.cy)
      if c and #self.name < MAX_LEN then self.name[#self.name + 1] = c end
    end
  end
  function s.draw(self)
    ui_box(4, 4, 312, 232)
    text("請寫上你的名字", 18, 14, 0)
    -- 名字的 4 格
    local bx = 160 - MAX_LEN * 11
    for i = 1, MAX_LEN do
      local x = bx + (i - 1) * 22
      rect(x, 52, 18, 1, 5)
      if self.name[i] then text(self.name[i], x + 3, 36, 0) end
      if i == #self.name + 1 and frame() % 40 < 20 then rect(x, 51, 18, 2, 12) end   -- 下一個字的位置閃爍
    end
    -- 字表
    for cy = 1, ROWS do
      for cx = 1, COLS do
        local c = char_at(cx, cy)
        if c then
          local x, y = GRID_X + (cx - 1) * CELL_W, GRID_Y + (cy - 1) * CELL_H
          if cx == self.cx and cy == self.cy then rect(x - 3, y - 1, CELL_W - 2, CELL_H - 1, 6) end
          text(c, x, y, 0)
        end
      end
    end
    -- 「完成」
    local fy = GRID_Y + ROWS * CELL_H + 2
    if self.cy == ROWS + 1 then ui_arrow_right(GRID_X, fy + 4, 0) end
    text("完成", GRID_X + 10, fy, 0)
    local pg = self.page .. "/" .. pages .. "　L・R 換頁"
    text(pg, 304 - textw(pg), fy, 5)
    text("A 選字　B 刪掉一個字　START 完成", 18, 212, 5)
  end
  ui_push(s)
end

-- ============================================================
-- 選初始野伴
-- ============================================================

local STARTERS = {
  { no = "01", desc = "頭上的芽角每年春天會換新。" },
  { no = "03", desc = "尾巴尖是悶燒的炭，冬天抱著很暖。" },
  { no = "05", desc = "用鬍鬚感覺水流，從不迷路。" },
}
local TYPE_COLOR = { grass = 11, fire = 9, water = 12 }

function starter_pick_open(on_done)
  local s = { index = 1 }
  function s.update(self)
    if pressed_repeat(LEFT) then self.index = (self.index - 2) % #STARTERS + 1 end
    if pressed_repeat(RIGHT) then self.index = self.index % #STARTERS + 1 end
    if pressed(A) then
      local st = STARTERS[self.index]
      local name = DATA.species[st.no].name
      dialog_ask("就選" .. name .. "嗎？", { "是", "否" }, function(c)
        if c == 1 then
          ui_pop()
          on_done(st.no)
        end
      end)
    end
  end
  function s.draw(self)
    ui_box(4, 4, 312, 112)
    for i, st in ipairs(STARTERS) do
      local x = 22 + (i - 1) * 100
      local sel = i == self.index
      if sel then rect(x - 4, 12, 72, 72, 6) end
      local hop = (sel and frame() % 30 < 6) and 2 or 0
      spr(IMG.kin_front, DATA.species[st.no].sprite, x, 16 - hop)
      if sel then
        for k = 0, 3 do rect(x + 28 + k, 90 + k, 8 - k * 2, 1, 0) end   -- 下面的小箭頭（往上指）
      end
    end
    -- 說明
    local st = STARTERS[self.index]
    local sp = DATA.species[st.no]
    ui_box(4, 120, 312, 64)
    text(sp.name, 16, 130, 0)
    local tn = DATA.types.names[sp.type]
    local tx = 24 + textw(sp.name)
    rect(tx, 131, textw(tn) + 8, 15, TYPE_COLOR[sp.type] or 13)
    text(tn, tx + 4, 130, 7)
    local works = {}
    for w, lv in pairs(sp.work or {}) do works[#works + 1] = DATA.work[w] .. " " .. lv end
    table.sort(works)
    local wt = "工作：" .. table.concat(works, "、")
    text(wt, 304 - textw(wt), 130, 5)
    text(st.desc, 16, 152, 0)
  end
  ui_push(s)
end
