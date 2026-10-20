// check_data.mjs — 檢查 data/*.json 彼此對得上（make check 用）
//
// 資料檔是手改的（之後用 Studio 的資料表編輯器），容易打錯字：
// 招式名稱拼錯、遭遇表寫了不存在的野伴……這些錯誤要到遊戲跑到那裡才會出事。
// 這支程式一次檢查全部，錯誤列出來、結束代碼 1。
//
// 用法：node tools/check_data.mjs

import fs from "fs";

const read = (name) => JSON.parse(fs.readFileSync(`data/${name}.json`, "utf8"));
const types = read("types"), moves = read("moves"), species = read("species");
const trainers = read("trainers"), items = read("items");
const encounters = read("encounters"), work = read("work");
const errors = [];
const err = (msg) => errors.push(msg);
const isInt = (v) => Number.isInteger(v);
const STATS = ["hp", "atk", "def", "spd"];

// 屬性相剋表
for (const [atk, row] of Object.entries(types.chart)) {
  if (!(atk in types.names)) err(`types.json：相剋表的「${atk}」不是屬性`);
  for (const [def, v] of Object.entries(row)) {
    if (!(def in types.names)) err(`types.json：相剋表 ${atk} → 「${def}」不是屬性`);
    if (![0, 1, 2, 4].includes(v)) err(`types.json：相剋表 ${atk} → ${def} 是 ${v}，只能是 0、1、2、4`);
  }
}

// 招式
for (const [key, m] of Object.entries(moves)) {
  const at = `moves.json 的 ${key}（${m.name}）`;
  if (!m.name) err(`${at}：沒有 name`);
  if (!(m.type in types.names)) err(`${at}：屬性「${m.type}」不存在`);
  if (!isInt(m.power) || m.power < 0) err(`${at}：power 要是 0 以上的整數`);
  if (!isInt(m.accuracy) || m.accuracy < 0 || m.accuracy > 100) err(`${at}：accuracy 要是 0–100（0 = 必定命中）`);
  if (!isInt(m.pp) || m.pp < 1) err(`${at}：pp 要是 1 以上的整數`);
  const e = m.effect;
  if (e) {
    if (!["first", "stat", "drain", "status"].includes(e.kind)) err(`${at}：effect.kind「${e.kind}」不認得`);
    if (e.kind === "stat") {
      if (!["foe", "self"].includes(e.target)) err(`${at}：effect.target 要是 foe 或 self`);
      if (!["atk", "def", "spd"].includes(e.stat)) err(`${at}：effect.stat 要是 atk、def、spd`);
      if (!isInt(e.stages) || e.stages === 0 || Math.abs(e.stages) > 3) err(`${at}：effect.stages 要是 −3～+3（不是 0）`);
    }
    if (e.kind === "status") {
      if (!["burn", "paralyze", "sleep"].includes(e.status)) err(`${at}：effect.status 要是 burn、paralyze、sleep`);
      if (!isInt(e.chance) || e.chance < 1 || e.chance > 100) err(`${at}：effect.chance 要是 1–100`);
    }
  }
  if (m.power === 0 && !e) err(`${at}：不造成傷害的招式一定要有 effect`);
}

// 戰鬥圖有幾格：直接讀 PNG 檔頭的寬度（第 16–19 byte）
const pngWidth = (f) => fs.readFileSync(f).readUInt32BE(16);
const frontCount = pngWidth("assets/art/kin_front.png") / 64, backCount = pngWidth("assets/art/kin_back.png") / 32;
const spriteUsed = {};

// 野伴
for (const [no, s] of Object.entries(species)) {
  const at = `species.json 的 ${no}（${s.name}）`;
  if (!/^\d\d$/.test(no)) err(`${at}：編號要是兩位數字，例如 "07"`);
  if (!(s.type in types.names)) err(`${at}：屬性「${s.type}」不存在`);
  for (const k of STATS) if (!isInt(s.base?.[k]) || s.base[k] < 1) err(`${at}：base.${k} 要是正整數`);
  if (!isInt(s.sprite) || s.sprite < 0 || s.sprite >= frontCount || s.sprite >= backCount)
    err(`${at}：sprite 要是 0–${Math.min(frontCount, backCount) - 1}（kin_front.png／kin_back.png 的第幾格）`);
  else if (spriteUsed[s.sprite]) err(`${at}：sprite ${s.sprite} 已經給 ${spriteUsed[s.sprite]} 用了`);
  else spriteUsed[s.sprite] = no;
  if (!isInt(s.catch) || s.catch < 1 || s.catch > 255) err(`${at}：catch 要是 1–255`);
  if (s.evolve !== undefined) {
    if (!(s.evolve.to in species)) err(`${at}：evolve.to「${s.evolve.to}」不在 species.json`);
    if (!isInt(s.evolve.level) || s.evolve.level < 2 || s.evolve.level > 50) err(`${at}：evolve.level 要是 2–50`);
  }
  if (!isInt(s.exp) || s.exp < 1) err(`${at}：exp 要是正整數`);
  for (const [w, lv] of Object.entries(s.work || {})) {
    if (!(w in work)) err(`${at}：工作特性「${w}」不在 work.json`);
    if (!isInt(lv) || lv < 1 || lv > 3) err(`${at}：工作 ${w} 的等級要是 1–3`);
  }
  if (!Array.isArray(s.learn) || s.learn.length === 0) err(`${at}：learn 至少要有一招`);
  else {
    if (s.learn[0][0] !== 1) err(`${at}：第 1 級一定要會至少一招`);
    let last = 0;
    for (const [lv, mv] of s.learn) {
      if (!(mv in moves)) err(`${at}：學會的招式「${mv}」不在 moves.json`);
      if (!isInt(lv) || lv < last) err(`${at}：learn 要依等級由小到大排`);
      last = lv;
    }
  }
}

// 遭遇表
for (const [area, t] of Object.entries(encounters)) {
  const at = `encounters.json 的 ${area}`;
  if (!isInt(t.rate) || t.rate < 0 || t.rate > 255) err(`${at}：rate 要是 0–255`);
  for (const e of t.list) {
    if (!(e.species in species)) err(`${at}：野伴「${e.species}」不在 species.json`);
    if (!isInt(e.min) || !isInt(e.max) || e.min < 1 || e.max < e.min || e.max > 50) err(`${at} 的 ${e.species}：等級要 1 ≤ min ≤ max ≤ 50`);
    if (!isInt(e.weight) || e.weight < 1) err(`${at} 的 ${e.species}：weight 要是正整數`);
  }
}

if (errors.length) {
  console.log(`資料檔有 ${errors.length} 個問題：`);
  for (const e of errors) console.log("  ✗ " + e);
  process.exit(1);
}
// 訓練家
for (const [id, t] of Object.entries(trainers)) {
  const at = `trainers.json 的 ${id}`;
  if (typeof t.name !== "string" || !t.name) err(`${at}：要有 name`);
  for (const k of ["intro", "win", "after"]) if (typeof t[k] !== "string") err(`${at}：要有 ${k}（台詞）`);
  if (!isInt(t.sight) || t.sight < 0 || t.sight > 8) err(`${at}：sight 要是 0–8（往面向看幾格）`);
  if (!isInt(t.notice) || t.notice < 0 || t.notice > 3) err(`${at}：notice 要是 0–3（靠近幾格內一定發現）`);
  if (!Array.isArray(t.party) || t.party.length < 1 || t.party.length > 6) err(`${at}：party 要有 1–6 隻`);
  else for (const p of t.party) {
    if (p.species !== "rival" && !(p.species in species)) err(`${at}：野伴「${p.species}」不在 species.json（"rival" = 剋制主角初始野伴的那一隻）`);
    if (!isInt(p.level) || p.level < 1 || p.level > 50) err(`${at}：等級要 1–50`);
  }
}

// 道具
const sorts = {};
for (const [id, it] of Object.entries(items)) {
  const at = `items.json 的 ${id}`;
  if (typeof it.name !== "string" || typeof it.desc !== "string") err(`${at}：要有 name、desc`);
  if (!["heal", "ball", "material"].includes(it.kind)) err(`${at}：kind 只能是 heal、ball、material`);
  if (it.kind === "heal" && (!isInt(it.amount) || it.amount < 1)) err(`${at}：heal 要有 amount（正整數）`);
  if (it.kind === "ball" && (!isInt(it.rate) || it.rate < 1)) err(`${at}：ball 要有 rate（倍率，100 = 一般）`);
  if (!isInt(it.price) || it.price < 0) err(`${at}：price 要是 0 以上的整數`);
  if (!isInt(it.sort)) err(`${at}：sort（背包裡的順序）要是整數`);
  else if (sorts[it.sort]) err(`${at}：sort ${it.sort} 和 ${sorts[it.sort]} 重複`); else sorts[it.sort] = id;
}

console.log(`✓ 資料檔：${Object.keys(species).length} 種野伴、${Object.keys(moves).length} 招、${Object.keys(encounters).length} 張遭遇表、${Object.keys(trainers).length} 位訓練家、${Object.keys(items).length} 種道具，彼此都對得上`);
