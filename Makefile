# 用法（在 wildkin 資料夾裡）：
#   make         產生遊戲檔 build/wildkin.lua
#   make serve   編譯引擎 + 遊戲，瀏覽器開 http://localhost:8421
#   make clean   清除編譯結果
#
# 引擎預設在旁邊的 ../comet；在別的地方的話：make serve ENGINE=/path/to/comet

ENGINE ?= ../comet
PORT ?= 8421

# 合併 comet.json 列出的原始碼（用引擎附的工具，和 Comet Studio 的合併結果相同）
# 地圖、圖片改了也要重新合併
build/wildkin.lua: comet.json $(wildcard src/*.lua maps/*.json assets/*/*.png assets/*/*/*.png)
	node $(ENGINE)/tools/cart.mjs .

# 1. 用引擎自己的 Makefile 編譯網頁版（引擎有改過才會重新編譯）
# 2. 把引擎的網頁檔案複製過來，遊戲檔放成 game.lua（遊玩頁預設載入的檔名）
serve: build/wildkin.lua
	$(MAKE) -C $(ENGINE) web
	mkdir -p build/web
	cp -R $(ENGINE)/build/web/. build/web/
	cp build/wildkin.lua build/web/game.lua
	@echo "電腦：http://localhost:$(PORT)"
	@for i in en0 en1 en2; do ip=$$(ipconfig getifaddr $$i 2>/dev/null) && echo "手機：http://$$ip:$(PORT)"; done; true
	python3 $(ENGINE)/tools/serve.py $(PORT) build/web

clean:
	rm -rf build

.PHONY: serve clean
