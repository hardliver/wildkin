# CLAUDE.md — Wildkin 野伴

給 Claude 的工作說明。每次開工先讀這份，再讀 `docs/tasks.md` 找下一個任務。
**一律用中文（繁體）回覆和寫說明。**

## 這是什麼

2D 抓怪冒險遊戲：抓野伴、讓牠們在基地工作，戰鬥是 Game Boy 時期寶可夢式的回合制。
跑在作者自己寫的 [Comet 引擎](https://github.com/hardliver/comet-engine) 上，
目標平台是網頁（手機也能玩）和開源遊戲主機 Nova One（Pico 2 W）。

作者 Neil：Python 強、C 和 Lua 還在學。這是興趣兼作品集，**他要看得懂每一段程式**。

## 先讀的文件

| 檔案 | 內容 |
|---|---|
| `docs/tasks.md` | 任務清單，依順序做；**唯一的進度來源** |
| `docs/design.md` | 系統設計（規則、數值、架構） |
| `docs/content.md` | 內容企劃（野伴、地圖、訓練家、道具） |
| `docs/story.md` | 劇本 |
| `docs/playtest.md` | 試玩版與回饋表 |
| `../comet/docs/AI_GUIDE.md` | 引擎 API 說明（寫 Lua 前必讀） |

## 資料夾與建置

```
comet.json   要合併哪些原始碼、依什麼順序（新增 .lua 一定要加進 sources，順序有意義）
src/         遊戲 Lua，合併成單一檔 build/wildkin.lua
data/        遊戲資料 JSON（只能有整數、文字、true/false；不能有小數和 null）
maps/        地圖 JSON
assets/      kenney/（CC0 素材）、art/（原創美術）
tools/       check_data.mjs（資料一致性檢查）、art/ 和 maps/（產生圖和地圖的 Python）
tests/       遊戲邏輯測試（接在遊戲檔後面，用引擎的 Mac 版無頭跑）
```

指令（在這個資料夾）：
- `make` — 產生 `build/wildkin.lua`
- `make check` — 資料檢查 + 邏輯測試（只需要 node 和 cc，**每次改完都要跑、要過**）
- `make serve` — 網頁版，需要 emscripten

### 引擎的位置

Makefile 預設引擎在旁邊的 `../comet`。
- 作者電腦上：`nova_project/comet/` 和 `nova_project/wildkin/` 同一層。
- **雲端工作階段**：repo 可能被 clone 成 `comet-engine`。開工先確認：
  - 有 `../comet-engine` 沒有 `../comet` → 所有 make 加 `ENGINE=../comet-engine`
  - 兩個都沒有 → 在上一層 `git clone https://github.com/hardliver/comet-engine comet`
- 雲端沒有 emscripten 時不要花時間安裝，用 `make check` 驗證即可，並在回報中說明沒跑網頁版。

## 已定案的設計（不要自行改變）

- **戰鬥**：Game Boy 時期寶可夢式回合制。招式要有看得到的動作與特效（`battle_fx.lua`），不能只有血條下降。
- **移動**：自由的類比移動（任意角度），不是格子步進。
- **操作**：電腦用 WASD；完整支援現代手把（雙搖桿任意角度、十字鍵、ABXY）。
- **美術**：Kenney 素材（Tiny Town、Tiny Dungeon）為主，缺的由 Claude 用 `tools/art/` 的 Python 畫。
  - 野伴：細緻、不要太可愛也不要寫實動物；參考帕魯的造型方式，**每隻有自己的身體結構**（不是同一副骨架換皮）；不要半瞇眼／斜眼的「得意臉」；進化型可以像原型但不能太像。
- **內容參考**：初代 Game Boy 寶可夢、帕魯、Dokimon 的精神，**不能用任何寶可夢的名稱、角色、圖像或專有設計**。
- **主角**：暗指中年版小智——冒險部分照舊，穿插中年笑點（房貸、車貸、工作、還沒結婚、保險、健檢、中年毛病）；同樣不能侵權。
- **世界要有生命感**：角色有呼吸感、草會隨風動。**做不自然就寧可不做。**
- **沒有伺服器**：不做任何需要架設或託管伺服器的功能。
- **開發用加速**放在 Comet Studio，不放進遊戲。
- 晝夜、季節跟現實時間連動等屬於之後的計畫，任務清單排到才做。

## 工作方式

1. **一次只做一個任務**，依 `docs/tasks.md` 的順序。不確定規格時先問，不要自己發明。
2. 遊戲需要引擎新功能時，去 `comet` 改（通用 API，不要寫進 Wildkin 專用的東西），在 comet repo 另外 commit。
3. 改完跑 `make check`；新的遊戲邏輯盡量加測試到 `tests/`。
4. 做完在 `docs/tasks.md` 打勾、寫完成日期（YYYY-MM-DD）。
5. Commit 訊息以任務編號開頭，例如 `W72：野伴睡覺時的呼吸動畫`。
6. **寫完要教**：在最後的回報（雲端時寫在 PR 說明）用中文說明——
   - 做了什麼、改了哪些檔案
   - 關鍵的程式為什麼這樣寫
   - 結構為什麼這樣設計、考慮過但沒用的做法
   - 怎麼驗證的（跑了哪些測試、沒跑哪些）

### Git 規則

- **作者電腦上**：直接 commit 到 `main`，**不要 push**（作者自己 push）。
- **雲端工作階段**：開分支工作，**不要動 `main`、不要合併**；推送該分支。
  需要同時改引擎時，兩個 repo 用**同一個分支名稱**。作者看過後自己合併。

## Lua 注意事項

- 座標、大小、顏色都是整數（用 `//`）。
- 不能用 `io`、`os`、`require`、`dofile`、`loadfile`、`debug`、`math.random`（用引擎的 `rnd`）。
- 錯誤訊息會換算回原本的檔案和行號，除錯時看那個。
- 主機資源有限（Pico 2 W）：避免每幀產生大量暫存表格、避免沒必要的大圖。
