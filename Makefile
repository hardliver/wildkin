# 用法（在 wildkin 資料夾裡）：
#   make         產生遊戲檔 build/wildkin.lua
#   make serve   編譯引擎 + 遊戲，瀏覽器開 http://localhost:8421
#   make check   自動測試：資料檔彼此對得上、遊戲邏輯（tests/*.lua）
#   make clean   清除編譯結果
#
# 引擎預設在旁邊的 ../comet；在別的地方的話：make serve ENGINE=/path/to/comet

ENGINE ?= ../comet
PORT ?= 8421

# 合併 comet.json 列出的原始碼（用引擎附的工具，和 Comet Studio 的合併結果相同）
# 地圖、圖片、Comet 的合併工具改了，都要重新合併
build/wildkin.lua: comet.json $(wildcard src/*.lua maps/*.json data/*.json assets/*/*.png assets/*/*/*.png) $(ENGINE)/platform/web/cart.js $(ENGINE)/tools/cart.mjs
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

# 自動測試：
# 1. 資料檔：招式、野伴、遭遇表彼此對得上（打錯字在這裡就會發現）
# 2. 遊戲邏輯：tests/*.lua 接在遊戲檔後面，用引擎的 Mac 版無頭模擬器執行（不開視窗）
check: build/wildkin.lua
	node tools/check_data.mjs
	$(MAKE) -C $(ENGINE) build/mac
	cat build/wildkin.lua tests/*.lua > build/test.lua
	$(ENGINE)/build/mac build/test.lua build/test.ppm

clean:
	rm -rf build

.PHONY: serve check clean
