SHELL := /bin/bash

ROOT_DIR := $(abspath .)
CLAWCONSOLE_DIR := $(ROOT_DIR)/clawconsole
CLAWOPS_DIR := $(ROOT_DIR)/clawops
OUTPUT_DIR := $(ROOT_DIR)/output
WINDOWS_STAGE_SCRIPT := $(ROOT_DIR)/scripts/stage-windows-package.sh
DEBUG_OUT := $(OUTPUT_DIR)/debug
RELEASE_OUT := $(OUTPUT_DIR)/release
WINDOWS_GNU_OUT := $(OUTPUT_DIR)/windows-gnu
WINDOWS_MSVC_OUT := $(OUTPUT_DIR)/windows-msvc

UNAME_S := $(shell uname -s)
ifeq ($(OS),Windows_NT)
EXE_EXT := .exe
WINDOWS_PACKAGE_TARGET := msvc
else
EXE_EXT :=
WINDOWS_PACKAGE_TARGET := gnu
endif

CLAWCONSOLE_DEBUG_BIN := $(CLAWCONSOLE_DIR)/src-tauri/target/debug/clawstation$(EXE_EXT)
CLAWCONSOLE_RELEASE_BIN := $(CLAWCONSOLE_DIR)/src-tauri/target/release/clawstation$(EXE_EXT)
CLAWOPS_DEBUG_BIN := $(CLAWOPS_DIR)/target/debug/clawops$(EXE_EXT)
CLAWOPS_RELEASE_BIN := $(CLAWOPS_DIR)/target/release/clawops$(EXE_EXT)
CLAWCONSOLE_WINDOWS_GNU_BIN := $(CLAWCONSOLE_DIR)/src-tauri/target/x86_64-pc-windows-gnu/release/clawstation.exe
CLAWCONSOLE_WINDOWS_MSVC_BIN := $(CLAWCONSOLE_DIR)/src-tauri/target/x86_64-pc-windows-msvc/release/clawstation.exe
CLAWCONSOLE_WINDOWS_GNU_WEBVIEW2 := $(CLAWCONSOLE_DIR)/src-tauri/target/x86_64-pc-windows-gnu/release/WebView2Loader.dll
CLAWCONSOLE_WINDOWS_MSVC_WEBVIEW2 := $(CLAWCONSOLE_DIR)/src-tauri/target/x86_64-pc-windows-msvc/release/WebView2Loader.dll
CLAWOPS_WINDOWS_GNU_BIN := $(CLAWOPS_DIR)/target/x86_64-pc-windows-gnu/release/clawops.exe
CLAWOPS_WINDOWS_MSVC_BIN := $(CLAWOPS_DIR)/target/x86_64-pc-windows-msvc/release/clawops.exe
WINDOWS_GNU_GCC := $(shell command -v x86_64-w64-mingw32-gcc 2>/dev/null)
WINDOWS_README := $(ROOT_DIR)/packaging/windows-README.txt
WINDOWS_GNU_ZIP := $(OUTPUT_DIR)/ClawStation-windows-x86_64-gnu.zip
WINDOWS_MSVC_ZIP := $(OUTPUT_DIR)/ClawStation-windows-x86_64-msvc.zip

.PHONY: help build build-release build-windows build-windows-gnu build-windows-msvc package-windows package-windows-gnu package-windows-msvc check test stage-debug stage-release stage-windows-gnu stage-windows-msvc clean clean-output run run-release force

help:
	@printf "%s\n" \
		"make build          - 编译 ClawStation + clawops 调试版，并输出到 output/debug/" \
		"make build-release  - 编译 ClawStation + clawops 发布版，并输出到 output/release/" \
		"make build-windows  - 编译 Windows 发布版，并输出到 output/windows-*/" \
		"make package-windows - 编译并打包 Windows 发布 zip (Linux/WSL -> gnu, Windows -> msvc)" \
		"make check          - 运行 ClawStation / clawops 的 cargo check" \
		"make test           - 运行 clawops 测试" \
		"make run            - 运行 output/debug/bin/clawstation" \
		"make run-release    - 运行 output/release/bin/clawstation" \
		"make clean          - 清理 ClawStation / clawops 构建产物及 output/" \
		"make clean-output   - 清理根目录 output/"

build: force stage-debug

build-release: force stage-release

build-windows: stage-windows-$(WINDOWS_PACKAGE_TARGET)

build-windows-gnu: force stage-windows-gnu

build-windows-msvc: force stage-windows-msvc

package-windows: package-windows-$(WINDOWS_PACKAGE_TARGET)

package-windows-gnu: $(WINDOWS_GNU_ZIP)

package-windows-msvc: $(WINDOWS_MSVC_ZIP)

check:
	cd "$(CLAWCONSOLE_DIR)" && cargo check --manifest-path src-tauri/Cargo.toml
	cd "$(CLAWOPS_DIR)" && cargo check

test:
	cd "$(CLAWOPS_DIR)" && cargo test -q

$(CLAWCONSOLE_DEBUG_BIN):
	cd "$(CLAWCONSOLE_DIR)" && cargo tauri build --debug --no-bundle

$(CLAWCONSOLE_RELEASE_BIN):
	cd "$(CLAWCONSOLE_DIR)" && cargo tauri build --no-bundle

$(CLAWOPS_DEBUG_BIN):
	$(MAKE) -C "$(CLAWOPS_DIR)" build

$(CLAWOPS_RELEASE_BIN):
	$(MAKE) -C "$(CLAWOPS_DIR)" build-release

$(CLAWCONSOLE_WINDOWS_GNU_BIN):
	cd "$(CLAWCONSOLE_DIR)" && $(MAKE) tauri-build-windows-gnu-release

$(CLAWCONSOLE_WINDOWS_MSVC_BIN):
	cd "$(CLAWCONSOLE_DIR)" && $(MAKE) tauri-build-windows-msvc-release

$(CLAWOPS_WINDOWS_GNU_BIN):
	$(MAKE) -C "$(CLAWOPS_DIR)" build-windows-gnu-release

$(CLAWOPS_WINDOWS_MSVC_BIN):
	$(MAKE) -C "$(CLAWOPS_DIR)" build-windows-msvc-release

stage-debug:
	cd "$(CLAWCONSOLE_DIR)" && cargo tauri build --debug --no-bundle
	$(MAKE) -C "$(CLAWOPS_DIR)" build
	mkdir -p "$(DEBUG_OUT)/bin" "$(DEBUG_OUT)/web"
	cp "$(CLAWCONSOLE_DEBUG_BIN)" "$(DEBUG_OUT)/bin/"
	cp "$(CLAWOPS_DEBUG_BIN)" "$(DEBUG_OUT)/bin/"
	rsync -a --delete "$(CLAWCONSOLE_DIR)/dist/" "$(DEBUG_OUT)/web/"
	@printf "%s\n" \
		"构建完成：" \
		"  $(DEBUG_OUT)/bin/clawstation$(EXE_EXT)" \
		"  $(DEBUG_OUT)/bin/clawops$(EXE_EXT)" \
		"  $(DEBUG_OUT)/web/"

stage-release:
	cd "$(CLAWCONSOLE_DIR)" && cargo tauri build --no-bundle
	$(MAKE) -C "$(CLAWOPS_DIR)" build-release
	mkdir -p "$(RELEASE_OUT)/bin" "$(RELEASE_OUT)/web"
	cp "$(CLAWCONSOLE_RELEASE_BIN)" "$(RELEASE_OUT)/bin/"
	cp "$(CLAWOPS_RELEASE_BIN)" "$(RELEASE_OUT)/bin/"
	rsync -a --delete "$(CLAWCONSOLE_DIR)/dist/" "$(RELEASE_OUT)/web/"
	@printf "%s\n" \
		"构建完成：" \
		"  $(RELEASE_OUT)/bin/clawstation$(EXE_EXT)" \
		"  $(RELEASE_OUT)/bin/clawops$(EXE_EXT)" \
		"  $(RELEASE_OUT)/web/"

stage-windows-gnu:
	cd "$(CLAWCONSOLE_DIR)" && $(MAKE) tauri-build-windows-gnu-release
	$(MAKE) -C "$(CLAWOPS_DIR)" build-windows-gnu-release
	bash "$(WINDOWS_STAGE_SCRIPT)" \
		"$(WINDOWS_GNU_OUT)" \
		"$(WINDOWS_README)" \
		"$(CLAWCONSOLE_WINDOWS_GNU_BIN)" \
		"$(CLAWCONSOLE_WINDOWS_GNU_WEBVIEW2)" \
		"$(CLAWOPS_WINDOWS_GNU_BIN)" \
		"$(WINDOWS_GNU_GCC)"
	@printf "%s\n" \
		"Windows GNU 发布包 staging 完成：" \
		"  $(WINDOWS_GNU_OUT)/clawstation.exe" \
		"  $(WINDOWS_GNU_OUT)/clawops.exe" \
		"  $(WINDOWS_GNU_OUT)/README.txt"

stage-windows-msvc:
	cd "$(CLAWCONSOLE_DIR)" && $(MAKE) tauri-build-windows-msvc-release
	$(MAKE) -C "$(CLAWOPS_DIR)" build-windows-msvc-release
	bash "$(WINDOWS_STAGE_SCRIPT)" \
		"$(WINDOWS_MSVC_OUT)" \
		"$(WINDOWS_README)" \
		"$(CLAWCONSOLE_WINDOWS_MSVC_BIN)" \
		"$(CLAWCONSOLE_WINDOWS_MSVC_WEBVIEW2)" \
		"$(CLAWOPS_WINDOWS_MSVC_BIN)" \
		""
	@printf "%s\n" \
		"Windows MSVC 发布包 staging 完成：" \
		"  $(WINDOWS_MSVC_OUT)/clawstation.exe" \
		"  $(WINDOWS_MSVC_OUT)/clawops.exe" \
		"  $(WINDOWS_MSVC_OUT)/README.txt"

$(WINDOWS_GNU_ZIP): stage-windows-gnu
	rm -f "$(WINDOWS_GNU_ZIP)"
	cd "$(WINDOWS_GNU_OUT)" && zip -rq "$(abspath $(WINDOWS_GNU_ZIP))" .
	@printf "打包完成：%s\n" "$(WINDOWS_GNU_ZIP)"

$(WINDOWS_MSVC_ZIP): stage-windows-msvc
	rm -f "$(WINDOWS_MSVC_ZIP)"
	cd "$(WINDOWS_MSVC_OUT)" && zip -rq "$(abspath $(WINDOWS_MSVC_ZIP))" .
	@printf "打包完成：%s\n" "$(WINDOWS_MSVC_ZIP)"

run: stage-debug
	cd "$(DEBUG_OUT)/bin" && ./clawstation$(EXE_EXT)

run-release: stage-release
	cd "$(RELEASE_OUT)/bin" && ./clawstation$(EXE_EXT)

clean:
	$(MAKE) -C "$(CLAWCONSOLE_DIR)" clean
	$(MAKE) -C "$(CLAWOPS_DIR)" clean
	rm -rf "$(OUTPUT_DIR)"

clean-output:
	rm -rf "$(OUTPUT_DIR)"

force:
