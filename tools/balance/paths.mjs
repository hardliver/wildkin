// paths.mjs：主線路上會踩過幾格草叢（W78 全遊戲平衡用）
//
// 用法（在 wildkin 資料夾）：node tools/balance/paths.mjs
//
// 對每張有野生野伴的地圖，照劇情要走的路（入口 → 要找的人 → 出口），用 BFS 找最短路，
// 數路上「走進」幾格草叢／淺灘。每走進一格擲一次 rnd(256) < rate（encounter.lua），
// 所以 預期遇敵次數 = 草叢格數 × rate ÷ 256。
//
// 「一般玩家」第一次到一個地區（不刻意練等）：
//   主線路的草叢走 MAIN_TIMES 趟（來回、找人、回頭拿東西），旁邊的草叢（洞窟、山脊的側邊）走過 SIDE_SHARE 的格子（到處逛、採集、抓手冊）
// 結果抄進 tools/balance/curve.lua 的 PLAYTHROUGH 的 wild。
//
// 工廠、辦公室沒有野生的野伴，不列。
// 只是估計：不算 NPC 擋路、不算玩家繞路；被擋住的路（block 物件：伐木、落石）當作已經打通。

import fs from "fs";

const MAIN_TIMES = 2;
const SIDE_SHARE = 0.5;

const enc = JSON.parse(fs.readFileSync("data/encounters.json", "utf8"));

// 每張地圖要走的路：一串格子座標（劇情順序）。座標取自地圖的 objects（門、NPC），旁邊一格站得到的地方
const ROUTES = {
  route1: [[[9, 1], [10, 40], [9, 43]], "營地 → 阿穗 → 苔石村"],
  forest: [[[1, 14], [47, 15], [52, 12], [1, 15]], "村子 → 阿穗 → 柏伯 → 回村子"],
  mine: [[[42, 14], [7, 14], [1, 14]], "村子 → 高處長 → 港灣鎮"],
  harbor: [[[38, 14], [25, 19], [4, 11], [9, 19]], "礦坑 → 阿穗 → 礁嬤 → 竹筏"],
  coast: [[[55, 10], [3, 4]], "竹筏 → 火山洞"],
  volcano: [[[36, 28], [13, 15], [10, 4], [16, 13]], "海岸 → 范經理 → 炭爺 → 升降梯"],
  ridge: [[[9, 43], [14, 20], [14, 1]], "辦公室 → 阿穗 → 山頂"],
};

function grid(m, name) {
  const L = m.layers[name];
  return L ? L : null;
}

// BFS：從 a 到 b 的最短路（四方向），回傳路上的格子（不含起點）
function bfs(m, a, b) {
  const W = m.width, H = m.height, solid = grid(m, "solid");
  const prev = new Map();
  const key = (x, y) => y * W + x;
  const q = [a];
  prev.set(key(a[0], a[1]), null);
  while (q.length) {
    const [x, y] = q.shift();
    if (x === b[0] && y === b[1]) break;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
      if (solid && solid[ny][nx]) continue;
      const k = key(nx, ny);
      if (prev.has(k)) continue;
      prev.set(k, [x, y]);
      q.push([nx, ny]);
    }
  }
  if (!prev.has(key(b[0], b[1]))) return null;
  const path = [];
  for (let c = b; c && !(c[0] === a[0] && c[1] === a[1]); c = prev.get(key(c[0], c[1]))) path.push(c);
  return path.reverse();
}

let ok = true;
for (const [name, [points, desc]] of Object.entries(ROUTES)) {
  const m = JSON.parse(fs.readFileSync(`maps/${name}.json`, "utf8"));
  const grass = grid(m, "grass"), shore = grid(m, "shore");
  let steps = 0, wild = 0, all = 0;
  for (let y = 0; y < m.height; y++) for (let x = 0; x < m.width; x++) if ((grass && grass[y][x]) || (shore && shore[y][x])) all++;
  for (let i = 1; i < points.length; i++) {
    const p = bfs(m, points[i - 1], points[i]);
    if (!p) { console.log(`✗ ${name}：${points[i - 1]} 到 ${points[i]} 走不到`); ok = false; continue; }
    steps += p.length;
    for (const [x, y] of p) if ((grass && grass[y][x]) || (shore && shore[y][x])) wild++;
  }
  const rate = enc[name] ? enc[name].rate : 0;
  const side = Math.max(0, all - wild);
  const expect = ((wild * MAIN_TIMES + side * SIDE_SHARE) * rate / 256).toFixed(1);
  console.log(`${name.padEnd(8)} ${desc}：走 ${steps} 格，路上草叢 ${wild} 格、旁邊 ${side} 格 → 一般玩家遇敵約 ${expect} 次`);
}
if (!ok) process.exit(1);
