# MalwareProtector KPM Module Makefile
# 用于构建Android恶意脚本防护KPM模块

# 模块信息
MODULE_NAME := malware_protector
MODULE_VERSION := 1.0

# 源文件
obj-m += $(MODULE_NAME).o
$(MODULE_NAME)-objs := malware_protector.o

# 编译标志
ccflags-y += -DMODULE_NAME=\"$(MODULE_NAME)\"
ccflags-y += -DMODULE_VERSION=\"$(MODULE_VERSION)\"
ccflags-y += -Wall -Wextra -Werror
ccflags-y += -O2

# 内核源码路径 (需要根据实际环境调整)
KERNEL_SRC ?= /lib/modules/$(shell uname -r)/build

# Android内核路径 (交叉编译时使用)
ANDROID_KERNEL_SRC ?= /path/to/android/kernel

# 交叉编译工具链
CROSS_COMPILE ?= aarch64-linux-android-
ARCH ?= arm64

# 构建目标
all: native

# 本地构建 (用于测试)
native:
	@echo "Building $(MODULE_NAME) for native kernel..."
	make -C $(KERNEL_SRC) M=$(PWD) modules
	@echo "Build completed: $(MODULE_NAME).ko"

# Android交叉编译
android:
	@echo "Cross-compiling $(MODULE_NAME) for Android..."
	@if [ ! -d "$(ANDROID_KERNEL_SRC)" ]; then \
		echo "Error: Android kernel source not found at $(ANDROID_KERNEL_SRC)"; \
		echo "Please set ANDROID_KERNEL_SRC to the correct path"; \
		exit 1; \
	fi
	make -C $(ANDROID_KERNEL_SRC) \
		ARCH=$(ARCH) \
		CROSS_COMPILE=$(CROSS_COMPILE) \
		M=$(PWD) modules
	@echo "Android build completed: $(MODULE_NAME).ko"

# 生成KPM文件 (需要KernelPatch工具)
kpm: android
	@echo "Converting $(MODULE_NAME).ko to KPM format..."
	@if command -v kpimg >/dev/null 2>&1; then \
		kpimg -i $(MODULE_NAME).ko -o $(MODULE_NAME).kpm; \
		echo "KPM file generated: $(MODULE_NAME).kmp"; \
	else \
		echo "Warning: kpimg tool not found, manual conversion required"; \
		echo "Please use KernelPatch tools to convert $(MODULE_NAME).ko to .kpm format"; \
	fi

# 清理
clean:
	@echo "Cleaning build files..."
	make -C $(KERNEL_SRC) M=$(PWD) clean
	rm -f *.kpm
	@echo "Clean completed"

# 安装到本地系统 (仅用于测试)
install: native
	@echo "Installing $(MODULE_NAME) module..."
	sudo insmod $(MODULE_NAME).ko
	@echo "Module installed. Check dmesg for output."

# 卸载模块
uninstall:
	@echo "Uninstalling $(MODULE_NAME) module..."
	sudo rmmod $(MODULE_NAME)
	@echo "Module uninstalled"

# 显示模块信息
info:
	@echo "Module Name: $(MODULE_NAME)"
	@echo "Version: $(MODULE_VERSION)"
	@echo "Source Files: malware_protector.c"
	@echo "Header Files: kputils.h kpmodule.h"
	@echo "Target: $(ARCH) architecture"
	@echo "Cross Compile: $(CROSS_COMPILE)"

# 检查依赖
check-deps:
	@echo "Checking build dependencies..."
	@if [ "$(ARCH)" = "arm64" ] && ! command -v $(CROSS_COMPILE)gcc >/dev/null 2>&1; then \
		echo "Error: Cross compiler $(CROSS_COMPILE)gcc not found"; \
		echo "Please install Android NDK or appropriate toolchain"; \
		exit 1; \
	fi
	@if [ ! -f "$(KERNEL_SRC)/Makefile" ]; then \
		echo "Error: Kernel source not found at $(KERNEL_SRC)"; \
		echo "Please install kernel headers or set KERNEL_SRC correctly"; \
		exit 1; \
	fi
	@echo "Dependencies check passed"

# 代码风格检查
checkpatch:
	@echo "Running code style check..."
	@if [ -f "$(KERNEL_SRC)/scripts/checkpatch.pl" ]; then \
		$(KERNEL_SRC)/scripts/checkpatch.pl --no-tree -f malware_protector.c; \
	else \
		echo "checkpatch.pl not found, skipping style check"; \
	fi

# 生成文档
docs:
	@echo "Generating documentation..."
	@if command -v doxygen >/dev/null 2>&1; then \
		doxygen Doxyfile 2>/dev/null || echo "Doxyfile not found, skipping"; \
	else \
		echo "doxygen not found, skipping documentation generation"; \
	fi

# 打包发布
package: kmp
	@echo "Creating release package..."
	mkdir -p release/$(MODULE_NAME)-$(MODULE_VERSION)
	cp $(MODULE_NAME).kpm release/$(MODULE_NAME)-$(MODULE_VERSION)/
	cp malicious_script_analysis.md release/$(MODULE_NAME)-$(MODULE_VERSION)/
	cp protection_module_design.md release/$(MODULE_NAME)-$(MODULE_VERSION)/
	cp README.md release/$(MODULE_NAME)-$(MODULE_VERSION)/ 2>/dev/null || true
	cp INSTALL.md release/$(MODULE_NAME)-$(MODULE_VERSION)/ 2>/dev/null || true
	cd release && tar -czf $(MODULE_NAME)-$(MODULE_VERSION).tar.gz $(MODULE_NAME)-$(MODULE_VERSION)
	@echo "Release package created: release/$(MODULE_NAME)-$(MODULE_VERSION).tar.gz"

# 帮助信息
help:
	@echo "MalwareProtector KPM Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  all        - Build for native kernel (default)"
	@echo "  native     - Build for native kernel"
	@echo "  android    - Cross-compile for Android"
	@echo "  kpm        - Generate KPM file from Android build"
	@echo "  clean      - Clean build files"
	@echo "  install    - Install module (native only)"
	@echo "  uninstall  - Uninstall module"
	@echo "  info       - Show module information"
	@echo "  check-deps - Check build dependencies"
	@echo "  checkpatch - Run code style check"
	@echo "  docs       - Generate documentation"
	@echo "  package    - Create release package"
	@echo "  help       - Show this help"
	@echo ""
	@echo "Environment variables:"
	@echo "  KERNEL_SRC         - Path to kernel source (default: /lib/modules/\$$(uname -r)/build)"
	@echo "  ANDROID_KERNEL_SRC - Path to Android kernel source"
	@echo "  CROSS_COMPILE      - Cross compiler prefix (default: aarch64-linux-android-)"
	@echo "  ARCH               - Target architecture (default: arm64)"
	@echo ""
	@echo "Examples:"
	@echo "  make android ANDROID_KERNEL_SRC=/path/to/android/kernel"
	@echo "  make kpm ANDROID_KERNEL_SRC=/path/to/android/kernel"
	@echo "  make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-"

.PHONY: all native android kpm clean install uninstall info check-deps checkpatch docs package help