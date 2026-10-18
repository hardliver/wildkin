#!/usr/bin/env python3
"""把 Wildkin 的原始碼合併成一個 Comet 遊戲檔。

Comet 規定一款遊戲是一個 .lua 檔；開發時拆成好幾個檔案比較好管理，
這個工具負責把它們接起來：

    src/ 裡的檔案（依 SOURCES 的順序） → build/wildkin.lua

之後也會在這裡把圖片素材轉成遊戲檔裡的資料。

用法：python3 tools/build.py
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "wildkin.lua"

# 合併順序：先放被別人用到的，main.lua（有 _init、_update、_draw）放最後。
# 新增檔案時加進這個清單。
SOURCES = [
    "main.lua",
]

HEADER = """\
-- Wildkin 野伴
-- id: hardliver/wildkin
-- 這個檔案由 tools/build.py 自動產生，請修改 src/ 裡的檔案，不要直接改這裡
"""


def main():
    parts = [HEADER]
    for name in SOURCES:
        path = ROOT / "src" / name
        code = path.read_text(encoding="utf-8")
        # 每段前面標出來自哪個檔案，出錯時比較好找
        parts.append(f"\n-- ==================== src/{name} ====================\n")
        parts.append(code)

    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text("".join(parts), encoding="utf-8")
    lines = sum(p.count("\n") for p in parts)
    print(f"已產生 {OUT.relative_to(ROOT)}（{len(SOURCES)} 個檔案，{lines} 行）")


if __name__ == "__main__":
    main()
