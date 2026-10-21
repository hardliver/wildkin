// demo.mjs — 打包展示版（W63）：只有遊玩頁，沒有編輯器，可以直接放上 GitHub Pages
//
// 用法（在 wildkin 資料夾）：make demo   （會先 make web 編好引擎，再跑這支）
//   node tools/demo.mjs [引擎資料夾]   → build/demo/
//
// 做的事：
//   1. 從引擎的 build/web 複製遊玩頁需要的檔案（不含 Studio、AI_GUIDE、範例遊戲）
//   2. 遊戲檔放成 game.lua（遊玩頁預設載入）
//   3. 改 index.html：標題「野伴 Wildkin 展示版」、拿掉「打開編輯器」「載入遊戲」，加上「試玩回饋」連結
//   4. 放 feedback.html（試玩回饋表：填完產生一段文字，複製傳給 Neil）

import fs from "fs";
import path from "path";

const engine = process.argv[2] || "../comet";
const web = path.join(engine, "build/web");
const out = "build/demo";
const FILES = ["index.html", "play.js", "play.css", "comet.js", "comet.wasm", "input.js", "touchpad.js", "padmenu.js", "manifest.webmanifest"];

if (!fs.existsSync(path.join(web, "comet.wasm"))) {
    console.error(`找不到 ${web}/comet.wasm：先在引擎資料夾跑 make web`);
    process.exit(1);
}
fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(out, { recursive: true });
for (const f of FILES) fs.copyFileSync(path.join(web, f), path.join(out, f));
fs.copyFileSync("build/wildkin.lua", path.join(out, "game.lua"));
fs.copyFileSync("tools/feedback.html", path.join(out, "feedback.html"));

// index.html：換標題、拿掉開發用的東西、加回饋連結
let html = fs.readFileSync(path.join(out, "index.html"), "utf8");
const must = (re, what) => { if (!re.test(html)) { console.error(`index.html 找不到「${what}」，引擎的遊玩頁改過了？`); process.exit(1); } };
must(/<title>Comet<\/title>/, "<title>");
html = html.replace(/<title>Comet<\/title>/, "<title>野伴 Wildkin 展示版</title>");
must(/<button class="tool" id="btn-load">載入遊戲<\/button>/, "載入遊戲");
html = html.replace(/<button class="tool" id="btn-load">載入遊戲<\/button>/, "");
html = html.replace(/<button class="tool" id="btn-load-touch">載入遊戲<\/button>/, "");
must(/可以把 \.lua 遊戲檔或 \.rep 重播檔拖進這個網頁　·　<a href="studio\.html">打開編輯器<\/a>/, "打開編輯器");
html = html.replace(/可以把 \.lua 遊戲檔或 \.rep 重播檔拖進這個網頁　·　<a href="studio\.html">打開編輯器<\/a>/,
    '玩完（或卡住）請填 <a href="feedback.html" target="_blank">試玩回饋</a>，卡住時按「下載重播」把重播檔一起傳給我');
fs.writeFileSync(path.join(out, "index.html"), html);

// manifest：加到主畫面時的名字
const man = JSON.parse(fs.readFileSync(path.join(out, "manifest.webmanifest"), "utf8"));
man.name = "野伴 Wildkin 展示版";
man.short_name = "野伴";
fs.writeFileSync(path.join(out, "manifest.webmanifest"), JSON.stringify(man, null, 2) + "\n");

const kb = (f) => Math.round(fs.statSync(path.join(out, f)).size / 1024);
console.log(`已產生 ${out}/：遊戲 ${kb("game.lua")} KB、引擎 ${kb("comet.wasm")} KB`);
console.log("本機試玩：python3 " + path.join(engine, "tools/serve.py") + " 8422 " + out + "，開 http://localhost:8422");
console.log("放上網：把 build/demo 裡的檔案放進 GitHub Pages（見 docs/playtest.md）");
