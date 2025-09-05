# Android恶意脚本防护KPM模块设计文档

## 模块概述

**模块名称**: MalwareProtector KPM  
**版本**: 1.0  
**目标**: 防护针对Android设备的恶意擦除脚本攻击  
**兼容性**: KernelSU/APatch KPM框架  

## 核心功能设计

### 1. 系统调用拦截机制

#### 1.1 目标系统调用
- `sys_write` - 拦截对块设备的写操作
- `sys_openat` - 监控对 `/dev/block/*` 的访问
- `sys_execve` - 检测dd命令执行
- `sys_unlinkat` - 监控设备节点删除
- `sys_mknodat` - 监控设备节点创建

#### 1.2 Hook实现策略
```c
// 使用KernelPatch提供的syscall hook API
static long (*orig_sys_write)(unsigned int fd, const char __user *buf, size_t count);
static long (*orig_sys_openat)(int dfd, const char __user *filename, int flags, umode_t mode);
static long (*orig_sys_execve)(const char __user *filename, const char __user *const __user *argv, const char __user *const __user *envp);

// Hook函数
static long hooked_sys_write(unsigned int fd, const char __user *buf, size_t count);
static long hooked_sys_openat(int dfd, const char __user *filename, int flags, umode_t mode);
static long hooked_sys_execve(const char __user *filename, const char __user *const __user *argv, const char __user *const __user *envp);
```

### 2. 危险操作检测

#### 2.1 dd命令检测
```c
struct dd_detection {
    bool is_dd_command;
    char *input_file;     // if参数
    char *output_file;    // of参数
    bool is_zero_source;  // 是否从/dev/zero读取
    bool is_block_target; // 是否写入块设备
};

// 检测函数
static bool detect_dd_command(const char __user *filename, const char __user *const __user *argv, struct dd_detection *result);
```

#### 2.2 敏感分区识别
```c
// 敏感分区列表
static const char *sensitive_partitions[] = {
    "persist", "vm-persist",
    "modem_a", "modem_b", "modemst1", "modemst2",
    "fsg", "fsc",
    "abl_a", "abl_b",
    "featenabler_a", "featenabler_b",
    "xbl_a", "xbl_b", "xbl_config_a", "xbl_config_b",
    "xbl_ramdump_a", "xbl_ramdump_b",
    "xbl_sc_logs", "xbl_sc_test_mode",
    "vendor_boot_a", "vendor_boot_b",
    "ocdt",
    NULL
};

// 检测函数
static bool is_sensitive_partition(const char *device_path);
static bool is_critical_operation(const char *device_path, int operation_type);
```

### 3. 用户交互机制

#### 3.1 音量键监听
```c
struct user_input {
    int volume_up_pressed;
    int volume_down_pressed;
    unsigned long timestamp;
    bool timeout_reached;
};

// 音量键事件处理
static int volume_key_handler(struct notifier_block *nb, unsigned long action, void *data);
static bool wait_for_user_confirmation(int timeout_seconds);
```

#### 3.2 确认流程
1. 检测到危险操作时暂停执行
2. 通过内核日志或通知机制提示用户
3. 启动5秒倒计时
4. 监听音量键事件：
   - 音量+ : 允许执行
   - 音量- : 拒绝执行
   - 超时 : 默认拒绝

### 4. 决策逻辑

#### 4.1 自动拒绝条件
```c
enum protection_action {
    ACTION_ALLOW,           // 允许执行
    ACTION_DENY_AUTO,       // 自动拒绝
    ACTION_REQUIRE_CONFIRM, // 需要用户确认
    ACTION_LOG_ONLY         // 仅记录日志
};

static enum protection_action evaluate_operation(const char *device_path, int operation_type, struct dd_detection *dd_info) {
    // 1. 检查是否为敏感分区
    if (is_sensitive_partition(device_path)) {
        return ACTION_DENY_AUTO;
    }
    
    // 2. 检查是否为dd零填充操作
    if (dd_info && dd_info->is_dd_command && dd_info->is_zero_source && dd_info->is_block_target) {
        return ACTION_REQUIRE_CONFIRM;
    }
    
    // 3. 检查是否为其他危险操作
    if (is_critical_operation(device_path, operation_type)) {
        return ACTION_REQUIRE_CONFIRM;
    }
    
    return ACTION_ALLOW;
}
```

#### 4.2 处理流程
```c
static long handle_protected_operation(long (*orig_syscall)(...), enum protection_action action, ...) {
    switch (action) {
        case ACTION_ALLOW:
            return orig_syscall(...);
            
        case ACTION_DENY_AUTO:
            log_security_event("Auto-denied sensitive partition access");
            return -EACCES;
            
        case ACTION_REQUIRE_CONFIRM:
            if (wait_for_user_confirmation(5)) {
                log_security_event("User confirmed dangerous operation");
                return orig_syscall(...);
            } else {
                log_security_event("User denied or timeout on dangerous operation");
                return -EACCES;
            }
            
        case ACTION_LOG_ONLY:
            log_security_event("Suspicious operation detected");
            return orig_syscall(...);
    }
}
```

### 5. 日志和监控

#### 5.1 事件记录
```c
struct security_event {
    unsigned long timestamp;
    pid_t pid;
    uid_t uid;
    char comm[TASK_COMM_LEN];
    char operation[64];
    char target_device[256];
    enum protection_action action_taken;
    bool user_confirmed;
};

// 日志函数
static void log_security_event(const char *message);
static void log_detailed_event(struct security_event *event);
```

#### 5.2 统计信息
```c
struct protection_stats {
    atomic_t total_operations;
    atomic_t blocked_operations;
    atomic_t user_confirmed;
    atomic_t auto_denied;
    atomic_t sensitive_partition_access;
};

static struct protection_stats stats;
```

## 技术实现要点

### 1. 内核空间限制
- 不能使用用户空间库函数
- 内存分配使用 `kmalloc`/`kfree`
- 字符串操作使用内核版本函数
- 避免阻塞操作

### 2. 性能优化
- 使用快速路径避免不必要的检查
- 缓存敏感分区列表查找结果
- 最小化字符串比较操作
- 使用原子操作更新统计信息

### 3. 稳定性保证
- 异常处理和错误恢复
- 避免内核panic
- 正确的锁机制
- 模块卸载时的清理工作

### 4. 安全考虑
- 防止绕过检测的攻击
- 保护模块自身不被卸载
- 验证用户空间传入的参数
- 防止竞态条件

## 模块接口设计

### 1. 初始化和清理
```c
static int __init malware_protector_init(void);
static void __exit malware_protector_exit(void);
```

### 2. 配置接口
```c
// 通过proc文件系统提供配置接口
// /proc/malware_protector/config
// /proc/malware_protector/stats
// /proc/malware_protector/log
```

### 3. 控制命令
```c
enum control_cmd {
    CMD_ENABLE_PROTECTION,
    CMD_DISABLE_PROTECTION,
    CMD_ADD_SENSITIVE_PARTITION,
    CMD_REMOVE_SENSITIVE_PARTITION,
    CMD_SET_TIMEOUT,
    CMD_CLEAR_STATS
};
```

## 部署和使用

### 1. 编译要求
- Android内核源码或头文件
- 交叉编译工具链
- KernelPatch开发环境

### 2. 安装方式
- 通过APatch "Embed KPM"功能嵌入
- 通过APatch "Load"功能动态加载
- 编译到内核镜像中

### 3. 配置建议
- 默认启用所有保护功能
- 5秒用户确认超时
- 启用详细日志记录
- 定期检查统计信息

## 测试计划

### 1. 功能测试
- dd命令检测准确性
- 敏感分区识别正确性
- 用户交互响应性
- 自动拒绝机制

### 2. 性能测试
- 系统调用延迟影响
- 内存使用情况
- CPU开销测量

### 3. 安全测试
- 绕过攻击测试
- 模块自保护测试
- 异常情况处理

### 4. 兼容性测试
- 不同Android版本
- 不同设备型号
- 与其他模块共存

## 风险评估

### 1. 技术风险
- 内核API变化导致兼容性问题
- 性能影响过大
- 稳定性问题导致系统崩溃

### 2. 安全风险
- 被恶意软件绕过
- 模块自身被攻击
- 误报导致正常操作被阻止

### 3. 缓解措施
- 充分测试和验证
- 提供紧急禁用机制
- 持续更新和维护
- 用户教育和文档

## 后续改进

### 1. 功能增强
- 支持更多危险命令检测
- 机器学习异常检测
- 网络行为监控
- 实时威胁情报集成

### 2. 用户体验
- 图形化配置界面
- 更友好的通知机制
- 详细的操作指导
- 多语言支持

### 3. 性能优化
- 更高效的检测算法
- 硬件加速支持
- 内存使用优化
- 并发处理改进