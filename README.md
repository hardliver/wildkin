# Wildkin 野伴

在 [Comet](https://github.com/hardliver/comet-engine) 引擎上做的 2D 抓怪冒險：
抓野生怪物、讓牠們在基地幫你工作，戰鬥是 Game Boy 時期的回合制。

可以在網頁上玩，之後也能在開源遊戲主機 [Nova One](https://github.com/hardliver/nova-one) 上玩。

> 開發中。企劃見 [docs/design.md](docs/design.md)。

## 資料夾

```
src/            遊戲程式（Lua），分成好幾個檔案方便開發
assets/
  kenney/       Kenney 的免費素材（CC0），只放有用到的
  art/          原創美術（怪物等）
tools/
  build.py      把 src/ 和素材合併成一個遊戲檔 build/wildkin.lua
docs/
  design.md     遊戲企劃
```

Comet 的遊戲是**單一 `.lua` 檔**。為了好開發，原始碼拆成好幾個檔案，
`make` 會把它們合併成 `build/wildkin.lua`，這個檔案就是可以發布、放進 SD 卡的遊戲。

## 和引擎一起開發

這個 repo 和 `comet` 放在同一層資料夾：

```
nova_project/
  comet/      引擎
  wildkin/    這款遊戲
```

遊戲需要引擎新功能時，就到 `comet` 加上去、在 `comet` commit；
回到這裡 `make serve` 會自動用最新的引擎重新編譯。兩邊各自 commit。

## 執行

```
make            # 產生 build/wildkin.lua
make serve      # 編譯引擎 + 遊戲，瀏覽器開 http://localhost:8421
```

需要：Python 3、emscripten（`brew install emscripten`）、旁邊有 `comet` 資料夾。
引擎在別的地方的話：`make serve ENGINE=/path/to/comet`。

## 授權

- `assets/kenney/`：Kenney（[kenney.nl](https://kenney.nl)），CC0，見各資料夾的 `License.txt`
