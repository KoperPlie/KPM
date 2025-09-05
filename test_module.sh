#!/bin/bash

# MalwareProtector KPM 模块测试脚本
# 用于验证模块功能和性能

set -e

# 脚本信息
TEST_SCRIPT_NAME="MalwareProtector KPM Tester"
TEST_SCRIPT_VERSION="1.0"
MODULE_NAME="malware_protector"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 测试结果统计
TEST_TOTAL=0
TEST_PASSED=0
TEST_FAILED=0
TEST_SKIPPED=0

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

log_test() {
    echo -e "${PURPLE}[TEST]${NC} $1"
}

# 测试结果函数
test_pass() {
    ((TEST_TOTAL++))
    ((TEST_PASSED++))
    log_success "✓ $1"
}

test_fail() {
    ((TEST_TOTAL++))
    ((TEST_FAILED++))
    log_error "✗ $1"
}

test_skip() {
    ((TEST_TOTAL++))
    ((TEST_SKIPPED++))
    log_warning "⊘ $1"
}

# 显示帮助信息
show_help() {
    cat << EOF
$TEST_SCRIPT_NAME v$TEST_SCRIPT_VERSION

用法: $0 [选项] [测试类型]

测试类型:
  all        - 运行所有测试 (默认)
  basic      - 基础功能测试
  security   - 安全防护测试
  performance - 性能测试
  stress     - 压力测试
  cleanup    - 清理测试环境

选项:
  -v, --verbose     详细输出
  -q, --quiet       静默模式
  -s, --simulate    模拟模式 (不执行危险操作)
  -t, --timeout N   设置测试超时时间 (秒)
  -h, --help        显示此帮助信息

示例:
  $0 basic              # 运行基础测试
  $0 security --simulate # 模拟安全测试
  $0 all --verbose      # 详细运行所有测试

EOF
}

# 检查模块状态
check_module_status() {
    log_test "检查模块加载状态"
    
    if lsmod | grep -q "$MODULE_NAME"; then
        test_pass "模块已加载"
        return 0
    else
        test_fail "模块未加载"
        return 1
    fi
}

# 检查proc接口
check_proc_interface() {
    log_test "检查proc接口"
    
    local proc_dir="/proc/$MODULE_NAME"
    
    if [[ -d "$proc_dir" ]]; then
        test_pass "Proc目录存在: $proc_dir"
    else
        test_fail "Proc目录不存在: $proc_dir"
        return 1
    fi
    
    # 检查各个proc文件
    local proc_files=("stats" "enabled" "timeout" "log")
    
    for file in "${proc_files[@]}"; do
        if [[ -f "$proc_dir/$file" ]]; then
            test_pass "Proc文件存在: $file"
        else
            test_fail "Proc文件不存在: $file"
        fi
    done
}

# 检查模块配置
check_module_config() {
    log_test "检查模块配置"
    
    local proc_dir="/proc/$MODULE_NAME"
    
    # 检查模块是否启用
    if [[ -f "$proc_dir/enabled" ]]; then
        local enabled=$(cat "$proc_dir/enabled" 2>/dev/null || echo "0")
        if [[ "$enabled" == "1" ]]; then
            test_pass "模块已启用"
        else
            test_warning "模块已禁用"
        fi
    fi
    
    # 检查超时配置
    if [[ -f "$proc_dir/timeout" ]]; then
        local timeout=$(cat "$proc_dir/timeout" 2>/dev/null || echo "0")
        if [[ "$timeout" -gt 0 ]]; then
            test_pass "超时配置正常: ${timeout}秒"
        else
            test_fail "超时配置异常: ${timeout}秒"
        fi
    fi
}

# 测试统计信息
test_statistics() {
    log_test "测试统计信息"
    
    local stats_file="/proc/$MODULE_NAME/stats"
    
    if [[ -f "$stats_file" ]]; then
        local stats=$(cat "$stats_file" 2>/dev/null)
        if [[ -n "$stats" ]]; then
            test_pass "统计信息可读"
            if [[ "$VERBOSE" == "true" ]]; then
                echo "统计信息:"
                echo "$stats" | sed 's/^/  /'
            fi
        else
            test_fail "统计信息为空"
        fi
    else
        test_fail "统计文件不存在"
    fi
}

# 测试日志功能
test_logging() {
    log_test "测试日志功能"
    
    local log_file="/proc/$MODULE_NAME/log"
    
    if [[ -f "$log_file" ]]; then
        # 清空日志
        echo "" > "$log_file" 2>/dev/null || true
        
        # 触发一个日志事件 (如果可能)
        # 这里可以添加触发日志的测试代码
        
        test_pass "日志接口可访问"
    else
        test_fail "日志文件不存在"
    fi
}

# 基础功能测试
run_basic_tests() {
    log_info "运行基础功能测试..."
    
    check_module_status || return 1
    check_proc_interface
    check_module_config
    test_statistics
    test_logging
}

# 安全防护测试
run_security_tests() {
    log_info "运行安全防护测试..."
    
    if [[ "$SIMULATE" == "true" ]]; then
        log_warning "模拟模式：不执行实际的危险操作"
    fi
    
    # 测试dd命令拦截
    test_dd_interception
    
    # 测试敏感分区保护
    test_sensitive_partition_protection
    
    # 测试用户交互
    test_user_interaction
}

# 测试dd命令拦截
test_dd_interception() {
    log_test "测试dd命令拦截"
    
    if [[ "$SIMULATE" == "true" ]]; then
        test_skip "模拟模式：跳过dd命令测试"
        return
    fi
    
    # 创建临时测试文件
    local test_file="/tmp/test_dd_target"
    touch "$test_file"
    
    # 测试安全的dd命令 (应该被允许)
    if timeout 10 dd if=/dev/zero of="$test_file" bs=1024 count=1 >/dev/null 2>&1; then
        test_pass "安全dd命令正常执行"
    else
        test_warning "安全dd命令被拦截或失败"
    fi
    
    # 清理
    rm -f "$test_file"
    
    # 注意：不测试危险的dd命令，因为可能真的损坏系统
    test_skip "危险dd命令测试 (为安全跳过)"
}

# 测试敏感分区保护
test_sensitive_partition_protection() {
    log_test "测试敏感分区保护"
    
    # 检查敏感分区列表
    local sensitive_partitions=(
        "persist" "vm-persist" "modem_a" "modem_b"
        "modemst1" "modemst2" "fsg" "fsc"
        "abl_a" "abl_b" "featenabler_a" "featenabler_b"
        "xbl_a" "xbl_b" "xbl_config_a" "xbl_config_b"
        "vendor_boot_a" "vendor_boot_b" "ocdt"
    )
    
    log_info "检查敏感分区保护列表..."
    
    for partition in "${sensitive_partitions[@]}"; do
        # 检查分区是否存在
        if find /dev -name "*$partition*" 2>/dev/null | grep -q .; then
            if [[ "$VERBOSE" == "true" ]]; then
                log_info "发现敏感分区: $partition"
            fi
        fi
    done
    
    test_pass "敏感分区保护列表检查完成"
}

# 测试用户交互
test_user_interaction() {
    log_test "测试用户交互机制"
    
    # 这里只能测试接口是否存在，无法自动测试实际的按键交互
    test_skip "用户交互测试需要手动验证"
    
    log_info "手动测试步骤:"
    echo "  1. 执行危险dd命令"
    echo "  2. 观察是否弹出确认对话框"
    echo "  3. 测试音量+/-按键响应"
    echo "  4. 测试5秒超时机制"
}

# 性能测试
run_performance_tests() {
    log_info "运行性能测试..."
    
    test_syscall_overhead
    test_memory_usage
    test_cpu_usage
}

# 测试系统调用开销
test_syscall_overhead() {
    log_test "测试系统调用开销"
    
    # 测试大量系统调用的性能影响
    local start_time=$(date +%s.%N)
    
    for i in {1..1000}; do
        /bin/true >/dev/null 2>&1
    done
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    if [[ "$duration" != "0" ]]; then
        test_pass "系统调用性能测试完成 (${duration}秒)"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "  平均每次调用: $(echo "scale=6; $duration / 1000" | bc -l)秒"
        fi
    else
        test_skip "无法计算性能数据"
    fi
}

# 测试内存使用
test_memory_usage() {
    log_test "测试内存使用"
    
    # 检查模块内存使用
    if [[ -f "/proc/modules" ]]; then
        local mem_info=$(grep "$MODULE_NAME" /proc/modules 2>/dev/null || echo "")
        if [[ -n "$mem_info" ]]; then
            local mem_size=$(echo "$mem_info" | awk '{print $2}')
            test_pass "模块内存使用: ${mem_size} bytes"
        else
            test_fail "无法获取模块内存信息"
        fi
    else
        test_skip "无法访问/proc/modules"
    fi
}

# 测试CPU使用
test_cpu_usage() {
    log_test "测试CPU使用"
    
    # 简单的CPU使用测试
    test_skip "CPU使用测试需要长期监控"
    
    log_info "建议使用以下命令监控CPU使用:"
    echo "  top -p \$(pgrep -f $MODULE_NAME)"
    echo "  htop"
}

# 压力测试
run_stress_tests() {
    log_info "运行压力测试..."
    
    test_concurrent_syscalls
    test_high_frequency_operations
}

# 测试并发系统调用
test_concurrent_syscalls() {
    log_test "测试并发系统调用"
    
    if [[ "$SIMULATE" == "true" ]]; then
        test_skip "模拟模式：跳过并发测试"
        return
    fi
    
    # 启动多个并发进程
    local pids=()
    
    for i in {1..10}; do
        (
            for j in {1..100}; do
                /bin/true >/dev/null 2>&1
            done
        ) &
        pids+=("$!")
    done
    
    # 等待所有进程完成
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    test_pass "并发系统调用测试完成"
}

# 测试高频操作
test_high_frequency_operations() {
    log_test "测试高频操作"
    
    # 快速连续执行命令
    local start_time=$(date +%s)
    
    for i in {1..1000}; do
        echo "test" >/dev/null 2>&1
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    test_pass "高频操作测试完成 (${duration}秒)"
}

# 清理测试环境
cleanup_test_environment() {
    log_info "清理测试环境..."
    
    # 清理临时文件
    rm -f /tmp/test_*
    
    # 重置模块配置
    local proc_dir="/proc/$MODULE_NAME"
    if [[ -d "$proc_dir" ]]; then
        echo "1" > "$proc_dir/enabled" 2>/dev/null || true
        echo "5" > "$proc_dir/timeout" 2>/dev/null || true
        echo "" > "$proc_dir/log" 2>/dev/null || true
    fi
    
    log_success "测试环境清理完成"
}

# 显示测试结果
show_test_results() {
    echo
    log_info "测试结果汇总:"
    echo "  总计: $TEST_TOTAL"
    echo -e "  通过: ${GREEN}$TEST_PASSED${NC}"
    echo -e "  失败: ${RED}$TEST_FAILED${NC}"
    echo -e "  跳过: ${YELLOW}$TEST_SKIPPED${NC}"
    
    if [[ $TEST_FAILED -eq 0 ]]; then
        log_success "所有测试通过!"
        return 0
    else
        log_error "有 $TEST_FAILED 个测试失败"
        return 1
    fi
}

# 默认值
TEST_TYPE="all"
VERBOSE=false
QUIET=false
SIMULATE=false
TIMEOUT=30

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -s|--simulate)
            SIMULATE=true
            shift
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        all|basic|security|performance|stress|cleanup)
            TEST_TYPE="$1"
            shift
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 设置静默模式
if [[ "$QUIET" == "true" ]]; then
    exec >/dev/null 2>&1
fi

# 主程序
main() {
    log_info "$TEST_SCRIPT_NAME v$TEST_SCRIPT_VERSION"
    
    if [[ "$SIMULATE" == "true" ]]; then
        log_warning "运行在模拟模式"
    fi
    
    case "$TEST_TYPE" in
        "basic")
            run_basic_tests
            ;;
        "security")
            run_security_tests
            ;;
        "performance")
            run_performance_tests
            ;;
        "stress")
            run_stress_tests
            ;;
        "cleanup")
            cleanup_test_environment
            ;;
        "all")
            run_basic_tests
            run_security_tests
            run_performance_tests
            # run_stress_tests  # 可选，因为可能耗时较长
            ;;
        *)
            log_error "未知的测试类型: $TEST_TYPE"
            exit 1
            ;;
    esac
    
    show_test_results
}

# 错误处理
trap 'log_error "测试过程中发生错误，退出码: $?"' ERR

# 运行主程序
main "$@"