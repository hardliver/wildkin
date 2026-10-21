-- savegame.lua：存檔與讀檔（W49）
--
-- 引擎的 save(欄位, 表格)／loadsave(欄位)（W48）：欄位 0–7，每個 16 KB。Wildkin 用 1–3 三個欄位。
-- 存的東西都是整數、字串、true/false、表格，可以直接存（野伴本來就是 { no, level, exp, moves, hp, … }）。
-- 不存的：地圖、NPC、採集點的位置（每次從地圖檔重建）；畫面上的東西（走來走去的野伴位置）。
-- 存檔格式有版本號 v：之後改格式時，用 v 判斷要怎麼轉換舊存檔。

SAVE_VERSION = 1
SAVE_SLOT = SAVE_SLOT or nil   -- 這一局存在哪個欄位（新遊戲時選、讀檔時決定）
PLAY_FRAMES = PLAY_FRAMES or 0 -- 遊玩時間（幀數，60 幀 = 1 秒）

MAP_NAME = { camp = "新芽營地", route1 = "草原小徑", village = "苔石村", forest = "霧林" }

-- 把現在的遊戲狀態存到 SAVE_SLOT
function game_save()
  save(SAVE_SLOT, {
    v = SAVE_VERSION,
    name = PLAYER_NAME,
    map = world.name,
    x16 = player.x16, y16 = player.y16, dx = player.dir_x, dy = player.dir_y,
    party = party, ranch = RANCH, bag = BAG,
    dex = DEX, flags = FLAGS,
    facility = FACILITY, gathered = GATHERED, day = DAY,
    frames = PLAY_FRAMES, money = MONEY,
  })
end

-- 讀回存檔（沒有、或格式不認得回傳 nil）
function game_read(slot)
  local s = loadsave(slot)
  if type(s) ~= "table" or s.v ~= SAVE_VERSION then return nil end
  return s
end

-- 把讀回來的資料放回全域變數（地圖和主角的位置由 main.lua 的 load_game 處理）
function game_apply(s)
  PLAYER_NAME = s.name
  party, RANCH, BAG = s.party, s.ranch or {}, s.bag or {}
  DEX = s.dex or { seen = {}, caught = {} }
  DEX.seen, DEX.caught = DEX.seen or {}, DEX.caught or {}
  FLAGS = s.flags or {}
  FACILITY = s.facility or {}
  for _, fac in pairs(FACILITY) do fac.workers = fac.workers or {} end
  GATHERED = s.gathered or {}
  DAY = s.day or 1
  PLAY_FRAMES = s.frames or 0
  MONEY = s.money or 0
end

-- 「1:05」：遊玩幾小時幾分
function play_time_text(frames)
  local m = frames // 3600
  return (m // 60) .. ":" .. string.format("%02d", m % 60)
end

-- 欄位清單上顯示的一行摘要
function save_summary(s)
  local caught = 0
  for _ in pairs(s.dex and s.dex.caught or {}) do caught = caught + 1 end
  return {
    s.name .. "　第 " .. (s.day or 1) .. " 天　" .. (MAP_NAME[s.map] or s.map),
    "野伴 " .. #s.party .. " 隻　手冊 " .. caught .. "　遊玩 " .. play_time_text(s.frames or 0),
  }
end
