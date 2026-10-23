# 音效和音樂的產生器（W77）：python3 tools/audio/make_sfx.py → audio/sfx.json
# 產生一次之後，也可以在 Comet Studio 的音效編輯器裡改（重跑這支程式會蓋掉 Studio 的修改）。
#
# 格式見 comet 的 docs/AI_GUIDE.md「音效與音樂」：每個音符 [音高, 波形, 音量, 效果]，音高 0 = C2。
# 這裡用「音名字串」寫旋律，比較好讀：
#   "C4 E4 G4 . C5 - - ."   一格一個音：C4、E4……；"." 休止；"-" 延長上一個音（同一個音繼續響）
#   音名後面可以加：~ 滑音（從上一個音滑過來）、v 抖音、> 漸弱。例如 "G4~"、"C5>"
# 波形：0 三角（柔和）、1 方波（GB）、2 窄方波（尖）、3 鋸齒（粗）、4 雜訊（打擊）
import json, os

TRI, SQ, PULSE, SAW, NOISE = 0, 1, 2, 3, 4
NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def pitch(name):
    """「C#4」→ 音高編號（C2 = 0）"""
    p = NAMES[name[0]]
    rest = name[1:]
    if rest.startswith("#"):
        p += 1
        rest = rest[1:]
    elif rest.startswith("b"):
        p -= 1
        rest = rest[1:]
    return (int(rest) - 2) * 12 + p


def notes(text, wave, vol):
    """音名字串 → 音符陣列"""
    out = []
    for tok in text.split():
        if tok == ".":
            out.append([out[-1][0] if out else 24, wave, 0, 0])
            continue
        if tok == "-":
            last = next((n for n in reversed(out) if n[2] > 0), [24, wave, vol, 0])
            out.append([last[0], wave, vol, 0])
            continue
        fx = 0
        if tok[-1] in "~v>":
            fx = {"~": 1, "v": 2, ">": 3}[tok[-1]]
            tok = tok[:-1]
        out.append([pitch(tok), wave, vol, fx])
    assert 1 <= len(out) <= 32, (text, len(out))
    return out


SFX, MUSIC = {}, {}


def sfx(name, speed, text, wave, vol, loop=None):
    s = {"speed": speed, "notes": notes(text, wave, vol)}
    if loop:
        s["loop"] = loop
    SFX[name] = s


def drums(name, speed, pattern):
    """打擊：k = 低的雜訊（大鼓）、h = 高的雜訊（鈸）、s = 中間（小鼓）、. 休止。都會漸弱"""
    out = []
    for c in pattern.replace(" ", ""):
        if c == "k": out.append([6, NOISE, 6, 3])
        elif c == "s": out.append([30, NOISE, 4, 3])
        elif c == "h": out.append([52, NOISE, 2, 3])
        else: out.append([30, NOISE, 0, 0])
    SFX[name] = {"speed": speed, "notes": out}


def song(name, patterns, loop=0):
    MUSIC[name] = {"patterns": [p + [""] * (4 - len(p)) for p in patterns]}
    if loop is not None:
        MUSIC[name]["loop"] = loop


# ============================================================
# 音效
# ============================================================
# 選單、對話
sfx("cursor", 2, "C5", PULSE, 3)
sfx("select", 2, "E5 A5", PULSE, 4)
sfx("cancel", 2, "A4 E4", PULSE, 3)
sfx("page", 2, "G5", TRI, 3)
# 地圖
SFX["step"] = {"speed": 2, "notes": [[18, NOISE, 1, 3]]}                  # 腳步：很小聲的沙沙
SFX["step_grass"] = {"speed": 3, "notes": [[30, NOISE, 2, 3]]}            # 草叢裡：比較明顯
sfx("door", 3, "C4 G3 C3>", SQ, 4)
sfx("item", 4, "C5 E5 G5 C6 - -", PULSE, 4)                               # 得到東西
sfx("encounter", 2, "C5 B4 Bb4 A4 G#4 G4 F#4 F4 E4 D#4 D4 C#4", SQ, 5)   # 遇到野伴：往下掉的一串
sfx("heal", 5, "C5 E5 G5 E5 G5 C6 - -", TRI, 5)
sfx("bike", 2, "E5 G5", PULSE, 3)
# 戰鬥：招式（依屬性）、被打、倒下
SFX["hit"] = {"speed": 2, "notes": [[12, NOISE, 7, 3], [8, NOISE, 5, 3]]}
SFX["hit_super"] = {"speed": 2, "notes": [[14, NOISE, 7, 0], [10, NOISE, 7, 3], [6, NOISE, 6, 3]]}
SFX["hit_weak"] = {"speed": 2, "notes": [[20, NOISE, 4, 3]]}
sfx("faint", 4, "G4 E4 C4 G3 E3 C3>", SQ, 5)
sfx("move_normal", 2, "C4 G4~", SQ, 4)
sfx("move_fire", 2, "C3 E3 G3 C4 E4 G4", SAW, 5)
SFX["move_fire"]["notes"] = [[n[0], SAW if i % 2 == 0 else NOISE, 5, 0] for i, n in enumerate(SFX["move_fire"]["notes"])]
sfx("move_water", 3, "G4 C5 E5 C5 G4 E4>", TRI, 5)
sfx("move_grass", 2, "E5 G5 B5 E6 B5 G5", PULSE, 3)
SFX["move_electric"] = {"speed": 1, "notes": [[50, NOISE, 6, 0], [44, SQ, 5, 0], [52, NOISE, 6, 0], [40, SQ, 5, 0], [54, NOISE, 6, 0], [46, SQ, 5, 3]]}
SFX["move_rock"] = {"speed": 3, "notes": [[10, NOISE, 7, 3], [4, NOISE, 6, 3], [8, NOISE, 5, 3]]}
sfx("stat_up", 2, "C5 E5 G5 C6", PULSE, 4)
sfx("stat_down", 2, "C6 G5 E5 C5", PULSE, 4)
# 野伴球、經驗、升級
sfx("throw", 2, "C5 D5 E5 F5 G5 A5 B5 C6", TRI, 4)
SFX["shake"] = {"speed": 3, "notes": [[18, NOISE, 4, 3], [30, NOISE, 0, 0], [22, NOISE, 3, 3]]}
sfx("caught", 5, "C5 E5 G5 C6 . G5 C6 - - -", SQ, 5)
sfx("break", 2, "C6 G5 C5 G4>", PULSE, 5)
sfx("levelup", 4, "C5 E5 G5 C6 E6 - - -", PULSE, 5)
sfx("run", 2, "C4 E4 G4 C5", TRI, 4)
sfx("evolve", 6, "C4v E4v G4v C5v E5v G5v C6 - - -", TRI, 5)

# ============================================================
# 音樂
# ============================================================
# 標題：C 大調，慢慢的、有點懷舊（25 年前出發的那一天）
sfx("t_lead1", 10, "E4 - G4 - C5 - - - B4 - A4 - G4 - - - A4 - G4 - E4 - D4 - C4 - D4 - E4 - - -", PULSE, 4)
sfx("t_lead2", 10, "E4 - G4 - C5 - - - D5 - E5 - D5 - - - C5 - B4 - A4 - G4 - E4 - D4 - C4 - - -", PULSE, 4)
sfx("t_bass1", 10, "C3 - - - G3 - - - F3 - - - C3 - - - F3 - - - C3 - - - G2 - - - C3 - - -", TRI, 5)
sfx("t_bass2", 10, "C3 - - - G3 - - - A2 - - - E3 - - - F3 - - - G3 - - - G2 - - - C3 - - -", TRI, 5)
song("title", [["t_lead1", "t_bass1"], ["t_lead2", "t_bass2"]])

# 原野：輕快（營地、草原小徑、海岸、山脊）
sfx("f_lead1", 8, "C5 . E5 . G5 - E5 . F5 . A5 . G5 - - . E5 . G5 . C6 - B5 . A5 . G5 . E5 - - .", PULSE, 4)
sfx("f_lead2", 8, "F5 . E5 . D5 - C5 . D5 . E5 . G5 - - . A5 . G5 . E5 - D5 . C5 . D5 . C5 - - .", PULSE, 4)
sfx("f_bass1", 8, "C3 . G3 . C3 . G3 . F3 . C4 . F3 . C4 . C3 . G3 . C3 . G3 . G2 . D3 . G2 . D3 .", TRI, 5)
sfx("f_bass2", 8, "F3 . C4 . F3 . C4 . C3 . G3 . C3 . G3 . F3 . C4 . G2 . D3 . C3 . G3 . C3 . . .", TRI, 5)
drums("f_drum", 8, "h.h.h.h.h.h.h.h.h.h.h.h.h.h.h.h.")
song("field", [["f_lead1", "f_bass1", "f_drum"], ["f_lead2", "f_bass2", "f_drum"]])

# 城鎮：F 大調，慢一點、溫暖（苔石村、港灣鎮）
sfx("v_lead1", 11, "A4 - C5 - F5 - - - E5 - D5 - C5 - - - D5 - C5 - A4 - G4 - F4 - G4 - A4 - - -", TRI, 5)
sfx("v_lead2", 11, "A4 - C5 - F5 - - - G5 - A5 - G5 - - - F5 - E5 - D5 - C5 - A4 - G4 - F4 - - -", TRI, 5)
sfx("v_bass1", 11, "F2 - - - C3 - - - Bb2 - - - F2 - - - Bb2 - - - F2 - - - C3 - - - C3 - - -", TRI, 4)
sfx("v_bass2", 11, "F2 - - - C3 - - - D3 - - - A2 - - - Bb2 - - - C3 - - - C3 - - - F2 - - -", TRI, 4)
sfx("v_harm", 11, "F4 . . . A4 . . . D4 . . . F4 . . . D4 . . . F4 . . . E4 . . . F4 . . .", PULSE, 2)
song("town", [["v_lead1", "v_bass1", "v_harm"], ["v_lead2", "v_bass2", "v_harm"]])

# 森林：A 小調，空靈（霧林、山頂聖所）
sfx("w_lead1", 12, "A4v - - - C5 - E5 - D5v - - - . . . . E5 - G5 - E5 - D5 - C5v - - - . . . .", TRI, 4)
sfx("w_lead2", 12, "A4v - - - B4 - C5 - E5v - - - . . . . D5 - C5 - B4 - G4 - A4v - - - . . . .", TRI, 4)
sfx("w_pad", 12, "A2 - - - - - - - F2 - - - - - - - C3 - - - - - - - E2 - - - - - - -", TRI, 3)
sfx("w_bell", 12, ". . . . . . . . . . . . A5> . . . . . . . . . . . . . . . E6> . . .", PULSE, 2)
song("forest", [["w_lead1", "w_pad", "w_bell"], ["w_lead2", "w_pad", "w_bell"]])

# 洞窟：D 小調，低沉（舊礦坑、火山洞、鐵輪工廠）
sfx("c_drone", 14, "D2 - - - - - - - - - - - - - - - C2 - - - - - - - - - - - Bb2 - - -", SQ, 3)
sfx("c_drip1", 14, ". . . . D5> . . . . . . . . . A4> . . . . . F5> . . . . . . . . . . .", TRI, 3)
sfx("c_drip2", 14, ". . A4> . . . . . . . . . E5> . . . . . . . . . D5> . . . . . C5> . . .", TRI, 3)
drums("c_drum", 14, "k...............k.......k.......")
song("cave", [["c_drone", "c_drip1", "c_drum"], ["c_drone", "c_drip2", "c_drum"]])

# 野生戰：E 小調，快、緊張
sfx("b_lead1", 5, "E5 - E5 . G5 - E5 . A5 - G5 . E5 - D5 . E5 - E5 . G5 - B5 . A5 - G5 . F#5 - - .", PULSE, 4)
sfx("b_lead2", 5, "C6 - B5 . A5 - G5 . A5 - B5 . G5 - E5 . F#5 - G5 . A5 - F#5 . E5 - - - - - - .", PULSE, 4)
sfx("b_bass", 5, "E3 E3 E4 E3 E3 E3 E4 E3 C3 C3 C4 C3 C3 C3 C4 C3 D3 D3 D4 D3 D3 D3 D4 D3 B2 B2 B3 B2 B2 B2 B3 B2", SQ, 4)
drums("b_drum", 5, "k.h.s.h.k.h.s.h.k.h.s.h.k.k.s.h.")
song("battle", [["b_lead1", "b_bass", "b_drum"], ["b_lead2", "b_bass", "b_drum"]])

# 訓練家戰：更快、更有氣勢（阿穗、守護者、鐵輪幹部、社長）
sfx("r_lead1", 4, "A4 - C5 - E5 - A5 - G5 - E5 - C5 - E5 - F5 - - - E5 - D5 - C5 - B4 - - -", SQ, 4)
sfx("r_lead2", 4, "A4 - C5 - E5 - A5 - B5 - C6 - B5 - A5 - G5 - - - A5 - - - - - - - . . . .", SQ, 4)
sfx("r_bass", 4, "A2 A3 A2 A3 A2 A3 A2 A3 F2 F3 F2 F3 F2 F3 F2 F3 G2 G3 G2 G3 G2 G3 G2 G3 E2 E3 E2 E3 E2 E3 E2 E3", SAW, 4)
drums("r_drum", 4, "k.hsk.hsk.hsk.hsk.hsk.hsk.hskkss")
song("trainer", [["r_lead1", "r_bass", "r_drum"], ["r_lead2", "r_bass", "r_drum"]])

# 勝利：短短一段、不循環
sfx("win_lead", 6, "C5 . C5 . C5 . C5 - - - G#4 - - - A#4 - - - C5 - A#4 . C5 - - - - - - - . .", PULSE, 5)
sfx("win_bass", 6, "C3 . . . . . . . . . G#2 - - - A#2 - - - C3 - - - - - - - - - - - . .", TRI, 5)
song("victory", [["win_lead", "win_bass"]], loop=None)

# 結局、片尾：慢的標題曲
sfx("e_lead", 14, "E4 - G4 - C5 - - - B4 - A4 - G4 - - - A4 - G4 - E4 - D4 - C4 - - - - -", TRI, 4)
sfx("e_bass", 14, "C3 - - - G3 - - - F3 - - - C3 - - - F3 - - - C3 - - - G2 - - - C3 - - -", TRI, 3)
song("ending", [["e_lead", "e_bass"]])

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../audio/sfx.json")
os.makedirs(os.path.dirname(out), exist_ok=True)


def line(v):
    return json.dumps(v, ensure_ascii=False, separators=(",", ":")).replace(",", ", ").replace(":", ": ")


def block(obj):
    return "{\n" + ",\n".join(f"    {json.dumps(k)}: {line(v)}" for k, v in obj.items()) + "\n  }"


# 和 Studio 音效編輯器存的格式一樣（sfxedit.js 的 formatSfx）：一個音效一行
open(out, "w").write('{\n  "sfx": ' + block(SFX) + ',\n  "music": ' + block(MUSIC) + "\n}\n")
print("ok", out, len(SFX), "個音效、", len(MUSIC), "首音樂")
