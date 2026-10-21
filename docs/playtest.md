# 展示版試玩（W63）

## 打包

```sh
cd wildkin
make demo          # 編好引擎（make web）、合併遊戲，產生 build/demo/
python3 ../comet/tools/serve.py 8422 build/demo   # 本機先玩一次：http://localhost:8422
```

`build/demo/` 只有遊玩頁（沒有編輯器、除錯指令），加上試玩回饋表 `feedback.html`。

## 放上網（GitHub Pages，免費）

1. 在 GitHub 開一個新的 repo，例如 `wildkin-demo`（公開）
2. 把 `build/demo/` 裡的檔案全部放進去（網頁上直接拖檔案上傳也可以）
3. repo 的 Settings → Pages → Branch 選 `main`、資料夾 `/ (root)` → Save
4. 一兩分鐘後網址是 `https://你的帳號.github.io/wildkin-demo/`

> GitHub Pages 是 https，手把和手機的虛擬按鍵都能用。存檔存在試玩者自己的瀏覽器裡。

## 找 3 個人試玩

- 最好是**沒看過這個遊戲的人**，至少一個平常不太玩遊戲的
- 只給網址和一句話：「玩到不想玩為止，卡住或玩完填回饋表」。**不要在旁邊教**，卡住的地方就是要找的東西
- 可以的話在旁邊看（或請他錄螢幕），記下：
  - 在哪裡停下來不知道要做什麼（多久？最後怎麼想通的？）
  - 有沒有打開任務日誌（Select／Tab）、START 選單
  - 哪場戰鬥輸了、輸幾次
  - 什麼時候笑了、什麼時候開始滑手機
- 卡住或壞掉時請他按「下載重播」，把 `.rep` 檔傳回來：拖進遊玩頁就能重看他的整段操作

## 回饋整理

收到的回饋貼進 `docs/playtest-notes.md`（每人一節），再整理成要改的任務放進 tasks.md。
