# MalwareProtector KPM 模块

一个用于防护Android恶意脚本的KernelPatch模块，专门针对危险的dd命令和敏感分区操作进行拦截和保护。

## 功能特性

- **系统调用拦截**: 拦截execve、execveat等系统调用，检测危险命令
- **敏感分区保护**: 自动保护关键系统分区，防止恶意擦除
- **用户交互确认**: 检测到危险操作时弹出确认对话框
- **物理按键控制**: 音量+确认执行，音量-拒绝执行
- **超时保护**: 5秒内无操作自动拒绝执行
- **安全日志**: 记录所有拦截事件和用户决策
- **实时监控**: 提供proc接口查看模块状态和统计信息

## 保护的敏感分区

模块会自动拒绝对以下分区的危险操作：

- `persist`, `vm-persist` - 持久化数据分区
- `modem_a`, `modem_b` - 基带固件分区
- `modemst1`, `modemst2` - 基带配置分区
- `fsg`, `fsc` - 文件系统配置分区
- `abl_a`, `abl_b` - Android Bootloader分区
- `featenabler_a`, `featenabler_b` - 功能启用分区
- `xbl_a`, `xbl_b` - 扩展Bootloader分区
- `xbl_config_a`, `xbl_config_b` - XBL配置分区
- `xbl_ramdump_a`, `xbl_ramdump_b` - XBL内存转储分区
- `xbl_sc_logs`, `xbl_sc_test_mode` - XBL安全日志分区
- `vendor_boot_a`, `vendor_boot_b` - 厂商启动分区
- `ocdt` - 设备配置表分区

## 系统要求

- Android设备已root (KernelSU或APatch)
- 内核版本 4.14+ (推荐 5.4+)
- 架构支持: arm64, arm
- 可用内存: 至少2MB

## 构建环境

### 依赖工具

- GCC交叉编译工具链
- Android NDK (推荐r25c+)
- Make工具
- Linux内核头文件

### Ubuntu/Debian安装依赖

```bash
sudo apt update
sudo apt install build-essential make gcc

# 安装Android NDK
wget https://dl.google.com/android/repository/android-ndk-r25c-linux.zip
unzip android-ndk-r25c-linux.zip
export NDK_ROOT=$PWD/android-ndk-r25c
export PATH=$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH
```

## 编译安装

### 1. 克隆或下载源码

```bash
# 如果从git仓库克隆
git clone <repository-url>
cd MalwareProtector-KPM

# 或者直接使用现有源码目录
cd /path/to/KPM
```

### 2. 配置构建环境

```bash
# 设置Android内核源码路径
export ANDROID_KERNEL_SRC=/path/to/android/kernel

# 设置交叉编译工具链
export CROSS_COMPILE=aarch64-linux-android-
export ARCH=arm64

# 或者使用NDK工具链
export CROSS_COMPILE=$NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android31-
```

### 3. 编译模块

#### 使用Makefile

```bash
# 为Android交叉编译
make android

# 生成KPM文件
make kpm

# 本地内核编译 (用于测试)
make native

# 清理构建文件
make clean
```

#### 使用构建脚本

```bash
# 给脚本执行权限
chmod +x build.sh

# 构建KPM文件
./build.sh kpm --android-kernel /path/to/android/kernel

# 查看帮助
./build.sh --help

# 创建发布包
./build.sh package
```

### 4. 验证构建结果

构建成功后会生成以下文件：

- `malware_protector.ko` - 内核模块文件
- `malware_protector.kpm` - KPM模块文件
- `release/malware_protector-1.0.tar.gz` - 发布包

## 安装部署

### KernelSU安装

1. 将`malware_protector.kpm`文件复制到设备
2. 使用KernelSU Manager安装模块
3. 重启设备激活模块

### APatch安装

1. 将`malware_protector.kpm`文件复制到设备
2. 使用APatch Manager加载模块
3. 或者在刷入APatch时嵌入模块

### 手动安装 (开发测试)

```bash
# 推送文件到设备
adb push malware_protector.kpm /data/local/tmp/

# 通过adb shell安装
adb shell
su
# 使用相应的KPM管理工具加载模块
```

## 使用说明

### 模块状态检查

```bash
# 检查模块是否加载
lsmod | grep malware_protector

# 查看模块统计信息
cat /proc/malware_protector/stats

# 查看内核日志
dmesg | grep malware_protector
```

### 配置选项

模块支持通过proc接口进行配置：

```bash
# 启用/禁用模块
echo 1 > /proc/malware_protector/enabled
echo 0 > /proc/malware_protector/enabled

# 设置确认超时时间 (秒)
echo 10 > /proc/malware_protector/timeout

# 查看拦截日志
cat /proc/malware_protector/log
```

### 用户交互

当检测到危险操作时：

1. 屏幕会显示确认对话框
2. 按音量+键确认执行
3. 按音量-键拒绝执行
4. 5秒内无操作自动拒绝
5. 所有操作都会记录到日志

## 测试验证

### 功能测试

```bash
# 测试dd命令拦截
dd if=/dev/zero of=/dev/block/bootdevice/by-name/persist bs=1024 count=1

# 测试敏感分区保护
dd if=/dev/zero of=/dev/block/mmcblk0p1 bs=1024 count=1

# 查看拦截统计
cat /proc/malware_protector/stats
```

### 性能测试

```bash
# 运行性能测试脚本
./build.sh test

# 检查系统性能影响
top -p $(pgrep -f malware_protector)
```

## 故障排除

### 常见问题

1. **模块加载失败**
   - 检查内核版本兼容性
   - 确认架构匹配 (arm64/arm)
   - 查看dmesg错误信息

2. **编译错误**
   - 检查交叉编译工具链
   - 确认内核源码路径
   - 验证依赖工具安装

3. **功能异常**
   - 检查模块是否正确加载
   - 验证proc接口权限
   - 查看内核日志输出

### 调试模式

```bash
# 启用详细日志
echo 1 > /proc/malware_protector/debug

# 查看详细调试信息
dmesg -w | grep malware_protector
```

## 开发说明

### 源码结构

```
.
├── malware_protector.c    # 主模块源码
├── kputils.h             # KPM工具函数头文件
├── kpmodule.h            # KPM模块框架头文件
├── Makefile              # 构建配置
├── build.sh              # 自动构建脚本
├── README.md             # 项目说明
├── malicious_script_analysis.md  # 恶意脚本分析
└── protection_module_design.md   # 模块设计文档
```

### 自定义配置

可以通过修改源码中的配置来自定义保护策略：

```c
// 添加新的敏感分区
static const char* sensitive_partitions[] = {
    "your_partition",
    // ...
};

// 修改超时时间
#define DEFAULT_TIMEOUT_SECONDS 5

// 添加新的危险命令
static const char* dangerous_commands[] = {
    "your_command",
    // ...
};
```

## 安全注意事项

1. **权限管理**: 模块需要root权限，请确保设备安全
2. **性能影响**: 模块会拦截系统调用，可能轻微影响性能
3. **兼容性**: 不同内核版本可能需要适配
4. **更新维护**: 定期更新模块以应对新的威胁

## 许可证

本项目采用GPL 2.0许可证，详见LICENSE文件。

## 贡献

欢迎提交Issue和Pull Request来改进项目。

## 联系方式

如有问题或建议，请通过以下方式联系：

- 提交GitHub Issue
- 发送邮件到项目维护者

---

**警告**: 本模块仅用于安全防护目的，请勿用于非法用途。使用前请充分测试，确保不会影响系统正常运行。