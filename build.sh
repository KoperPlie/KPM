#!/bin/bash

# MalwareProtector KPM 自动构建脚本
# 用于自动化编译和打包KPM模块

set -e  # 遇到错误立即退出

# 脚本信息
SCRIPT_NAME="MalwareProtector KPM Builder"
SCRIPT_VERSION="1.0"
MODULE_NAME="malware_protector"
MODULE_VERSION="1.0"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

用法: $0 [选项] [目标]

目标:
  native     - 为本地内核构建 (默认)
  android    - 为Android交叉编译
  kpm        - 生成KPM文件
  clean      - 清理构建文件
  package    - 创建发布包
  install    - 安装模块到本地系统
  uninstall  - 卸载模块
  test       - 运行测试

选项:
  -k, --kernel-src PATH     指定内核源码路径
  -a, --android-kernel PATH 指定Android内核源码路径
  -t, --toolchain PREFIX    指定交叉编译工具链前缀
  -A, --arch ARCH           指定目标架构 (arm64/arm)
  -j, --jobs N              并行编译任务数
  -v, --verbose             详细输出
  -h, --help                显示此帮助信息

环境变量:
  KERNEL_SRC         - 内核源码路径
  ANDROID_KERNEL_SRC - Android内核源码路径
  CROSS_COMPILE      - 交叉编译工具链前缀
  ARCH               - 目标架构
  JOBS               - 并行任务数

示例:
  $0 android -a /path/to/android/kernel
  $0 kpm --android-kernel /path/to/android/kernel
  $0 native --kernel-src /usr/src/linux
  $0 package

EOF
}

# 检查依赖
check_dependencies() {
    log_info "检查构建依赖..."
    
    local missing_deps=()
    
    # 检查基本工具
    for tool in make gcc; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_deps+=("$tool")
        fi
    done
    
    # 检查交叉编译工具链 (如果需要)
    if [[ "$TARGET" == "android" || "$TARGET" == "kpm" ]] && [[ "$ARCH" == "arm64" ]]; then
        if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
            log_warning "交叉编译器 ${CROSS_COMPILE}gcc 未找到"
            log_info "请安装Android NDK或相应的工具链"
        fi
    fi
    
    # 检查内核源码
    if [[ "$TARGET" == "native" ]]; then
        if [[ ! -f "$KERNEL_SRC/Makefile" ]]; then
            log_warning "内核源码未找到: $KERNEL_SRC"
            log_info "在WSL/Windows环境中，建议使用Android交叉编译模式"
            log_info "使用命令: $0 android --android-kernel /path/to/android/kernel"
            log_info "或者: $0 kpm --android-kernel /path/to/android/kernel"
            if [[ "$TARGET" == "native" ]]; then
                log_error "本地编译需要内核源码，切换到Android模式或设置正确的KERNEL_SRC路径"
                exit 1
            fi
        fi
    elif [[ "$TARGET" == "android" || "$TARGET" == "kmp" ]]; then
        if [[ -z "$ANDROID_KERNEL_SRC" ]]; then
            log_error "Android内核源码路径未设置"
            log_info "请使用 --android-kernel 参数指定Android内核源码路径"
            log_info "或设置环境变量: export ANDROID_KERNEL_SRC=/path/to/android/kernel"
            exit 1
        elif [[ ! -f "$ANDROID_KERNEL_SRC/Makefile" ]]; then
            log_error "Android内核源码未找到: $ANDROID_KERNEL_SRC"
            log_info "请确认路径正确或下载Android内核源码"
            exit 1
        fi
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "缺少依赖: ${missing_deps[*]}"
        log_info "请安装缺少的依赖后重试"
        exit 1
    fi
    
    log_success "依赖检查通过"
}

# 构建模块
build_module() {
    local target="$1"
    
    log_info "开始构建 $MODULE_NAME 模块 (目标: $target)..."
    
    case "$target" in
        "native")
            make native KERNEL_SRC="$KERNEL_SRC" -j"$JOBS"
            ;;
        "android")
            make android \
                ANDROID_KERNEL_SRC="$ANDROID_KERNEL_SRC" \
                ARCH="$ARCH" \
                CROSS_COMPILE="$CROSS_COMPILE" \
                -j"$JOBS"
            ;;
        "kpm")
            make kpm \
                ANDROID_KERNEL_SRC="$ANDROID_KERNEL_SRC" \
                ARCH="$ARCH" \
                CROSS_COMPILE="$CROSS_COMPILE" \
                -j"$JOBS"
            ;;
        *)
            log_error "未知的构建目标: $target"
            exit 1
            ;;
    esac
    
    log_success "构建完成"
}

# 清理构建文件
clean_build() {
    log_info "清理构建文件..."
    make clean
    rm -rf release/
    log_success "清理完成"
}

# 创建发布包
create_package() {
    log_info "创建发布包..."
    
    # 确保有KPM文件
    if [[ ! -f "${MODULE_NAME}.kpm" ]]; then
        log_warning "KPM文件不存在，尝试构建..."
        build_module "kpm"
    fi
    
    make package
    log_success "发布包创建完成"
}

# 安装模块
install_module() {
    log_info "安装模块到本地系统..."
    
    if [[ ! -f "${MODULE_NAME}.ko" ]]; then
        log_info "模块文件不存在，开始构建..."
        build_module "native"
    fi
    
    make install
    log_success "模块安装完成"
    log_info "使用 'dmesg | tail' 查看模块输出"
    log_info "使用 'cat /proc/${MODULE_NAME}/stats' 查看统计信息"
}

# 卸载模块
uninstall_module() {
    log_info "卸载模块..."
    make uninstall
    log_success "模块卸载完成"
}

# 运行测试
run_tests() {
    log_info "运行测试..."
    
    # 检查模块是否已加载
    if lsmod | grep -q "$MODULE_NAME"; then
        log_info "模块已加载，检查功能..."
        
        # 检查proc文件是否存在
        if [[ -f "/proc/${MODULE_NAME}/stats" ]]; then
            log_success "Proc接口正常"
            cat "/proc/${MODULE_NAME}/stats"
        else
            log_warning "Proc接口未找到"
        fi
        
        # 检查内核日志
        if dmesg | tail -20 | grep -q "$MODULE_NAME"; then
            log_success "内核日志正常"
        else
            log_warning "内核日志中未找到模块信息"
        fi
    else
        log_warning "模块未加载，无法运行功能测试"
    fi
    
    log_success "测试完成"
}

# 显示构建信息
show_build_info() {
    log_info "构建信息:"
    echo "  模块名称: $MODULE_NAME"
    echo "  模块版本: $MODULE_VERSION"
    echo "  目标架构: $ARCH"
    echo "  交叉编译: $CROSS_COMPILE"
    echo "  并行任务: $JOBS"
    echo "  内核源码: $KERNEL_SRC"
    if [[ -n "$ANDROID_KERNEL_SRC" ]]; then
        echo "  Android内核: $ANDROID_KERNEL_SRC"
    fi
}

# 默认值
TARGET="kmp"  # 在Windows/WSL环境中默认使用kmp模式
KERNEL_SRC="${KERNEL_SRC:-/lib/modules/$(uname -r)/build}"
ANDROID_KERNEL_SRC="${ANDROID_KERNEL_SRC:-}"
CROSS_COMPILE="${CROSS_COMPILE:-aarch64-linux-android-}"
ARCH="${ARCH:-arm64}"
JOBS="${JOBS:-$(nproc)}"
VERBOSE=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -k|--kernel-src)
            KERNEL_SRC="$2"
            shift 2
            ;;
        -a|--android-kernel)
            ANDROID_KERNEL_SRC="$2"
            shift 2
            ;;
        -t|--toolchain)
            CROSS_COMPILE="$2"
            shift 2
            ;;
        -A|--arch)
            ARCH="$2"
            shift 2
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        native|android|kpm|clean|package|install|uninstall|test)
            TARGET="$1"
            shift
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 设置详细输出
if [[ "$VERBOSE" == "true" ]]; then
    set -x
fi

# 主程序
main() {
    log_info "$SCRIPT_NAME v$SCRIPT_VERSION"
    
    show_build_info
    
    case "$TARGET" in
        "clean")
            clean_build
            ;;
        "package")
            check_dependencies
            create_package
            ;;
        "install")
            check_dependencies
            install_module
            ;;
        "uninstall")
            uninstall_module
            ;;
        "test")
            run_tests
            ;;
        *)
            check_dependencies
            build_module "$TARGET"
            ;;
    esac
    
    log_success "操作完成!"
}

# 错误处理
trap 'log_error "构建过程中发生错误，退出码: $?"' ERR

# 运行主程序
main "$@"