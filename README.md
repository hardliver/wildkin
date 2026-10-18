# Wildkin 野伴

在 [Comet](https://github.com/hardliver/comet-engine) 引擎上做的 2D 抓怪冒險：
抓野生怪物、讓牠們在基地幫你工作，戰鬥是 Game Boy 時期的回合制。

可以在網頁上玩，之後也能在開源遊戲主機 [Nova One](https://github.com/hardliver/nova-one) 上玩。

> 開發中。企劃見 [docs/design.md](docs/design.md)。

## 資料夾

```
comet.json      專案設定：要合併哪些原始碼、依什麼順序
src/            遊戲程式（Lua），分成好幾個檔案方便開發
assets/
  kenney/       Kenney 的免費素材（CC0），只放有用到的
  art/          原創美術（怪物等）
docs/
  design.md     遊戲企劃
```

Comet 的遊戲是**單一 `.lua` 檔**。為了好開發，原始碼拆成好幾個檔案，
依 `comet.json` 的順序合併成 `build/wildkin.lua`，這個檔案就是可以發布、放進 SD 卡的遊戲。
新增原始碼檔時，記得加進 `comet.json` 的 `sources`（用 Comet Studio 的「＋ 新檔案」會自動加）。

## 和引擎一起開發

這個 repo 和 `comet` 放在同一層資料夾：

```
nova_project/
  comet/      引擎
  wildkin/    這款遊戲
```

遊戲需要引擎新功能時，就到 `comet` 加上去、在 `comet` commit；
回到這裡 `make serve` 會自動用最新的引擎重新編譯。兩邊各自 commit。

## 開發方式

**方式一：Comet Studio（推薦）**

1. 在 `comet` 資料夾執行 `make serve`，用 Chrome 開 `http://localhost:8420/studio.html`
2. 按「📁 開啟資料夾」，選這個 `wildkin` 資料夾
3. 直接在網頁上改程式，自動存回檔案、自動重新執行；也會同時更新 `build/wildkin.lua`

也可以用 VS Code 等編輯器改檔案，Studio 偵測到修改會自動重新載入。

**方式二：命令列**

```
make            # 產生 build/wildkin.lua
make serve      # 編譯引擎 + 遊戲，瀏覽器開 http://localhost:8421
```

需要：Node.js、emscripten（`brew install emscripten`，會一起裝好 Node.js）、旁邊有 `comet` 資料夾。
引擎在別的地方的話：`make serve ENGINE=/path/to/comet`。

## 授權

- `assets/kenney/`：Kenney（[kenney.nl](https://kenney.nl)），CC0，見各資料夾的 `License.txt`
