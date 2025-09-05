@echo off
REM MalwareProtector KPM Windows构建脚本
REM 用于在Windows环境中构建KPM模块

setlocal enabledelayedexpansion

REM 脚本信息
set SCRIPT_NAME=MalwareProtector KPM Builder (Windows)
set SCRIPT_VERSION=1.0
set MODULE_NAME=malware_protector

REM 颜色定义 (Windows CMD)
set RED=[91m
set GREEN=[92m
set YELLOW=[93m
set BLUE=[94m
set NC=[0m

REM 显示帮助信息
if "%1"=="--help" goto :show_help
if "%1"=="-h" goto :show_help
if "%1"=="help" goto :show_help

echo %BLUE%[INFO]%NC% %SCRIPT_NAME% v%SCRIPT_VERSION%
echo.

REM 检查WSL是否可用
wsl --version >nul 2>&1
if %errorlevel% neq 0 (
    echo %RED%[ERROR]%NC% WSL未安装或不可用
    echo %YELLOW%[INFO]%NC% 请安装WSL2以使用Linux构建环境
    echo %YELLOW%[INFO]%NC% 或者使用Docker进行构建
    goto :show_alternatives
)

echo %GREEN%[SUCCESS]%NC% 检测到WSL环境
echo.

REM 检查参数
set BUILD_TARGET=kmp
set ANDROID_KERNEL_PATH=
set VERBOSE=

:parse_args
if "%1"=="" goto :start_build
if "%1"=="android" set BUILD_TARGET=android
if "%1"=="kmp" set BUILD_TARGET=kmp
if "%1"=="native" set BUILD_TARGET=native
if "%1"=="clean" set BUILD_TARGET=clean
if "%1"=="--android-kernel" (
    shift
    set ANDROID_KERNEL_PATH=%1
)
if "%1"=="-a" (
    shift
    set ANDROID_KERNEL_PATH=%1
)
if "%1"=="--verbose" set VERBOSE=--verbose
if "%1"=="-v" set VERBOSE=--verbose
shift
goto :parse_args

:start_build
echo %BLUE%[INFO]%NC% 构建目标: %BUILD_TARGET%
if not "%ANDROID_KERNEL_PATH%"=="" (
    echo %BLUE%[INFO]%NC% Android内核路径: %ANDROID_KERNEL_PATH%
)
echo.

REM 转换Windows路径为WSL路径
set WSL_PROJECT_PATH=/mnt/c/Users/%USERNAME%/Desktop/KPM
if not "%ANDROID_KERNEL_PATH%"=="" (
    REM 简单的路径转换 (假设在C盘)
    set WSL_KERNEL_PATH=!ANDROID_KERNEL_PATH:C:=/mnt/c!
    set WSL_KERNEL_PATH=!WSL_KERNEL_PATH:\=/!
) else (
    set WSL_KERNEL_PATH=
)

REM 构建命令
set BUILD_CMD=cd %WSL_PROJECT_PATH% ^&^& chmod +x build.sh ^&^& ./build.sh %BUILD_TARGET%
if not "%WSL_KERNEL_PATH%"=="" (
    set BUILD_CMD=!BUILD_CMD! --android-kernel !WSL_KERNEL_PATH!
)
if not "%VERBOSE%"=="" (
    set BUILD_CMD=!BUILD_CMD! %VERBOSE%
)

echo %BLUE%[INFO]%NC% 在WSL中执行构建...
echo %YELLOW%[CMD]%NC% wsl bash -c "%BUILD_CMD%"
echo.

REM 执行构建
wsl bash -c "%BUILD_CMD%"
set BUILD_RESULT=%errorlevel%

echo.
if %BUILD_RESULT% equ 0 (
    echo %GREEN%[SUCCESS]%NC% 构建完成!
    echo.
    echo %BLUE%[INFO]%NC% 生成的文件:
    if exist "%~dp0%MODULE_NAME%.ko" echo   - %MODULE_NAME%.ko (内核模块)
    if exist "%~dp0%MODULE_NAME%.kpm" echo   - %MODULE_NAME%.kpm (KPM模块)
    if exist "%~dp0release\" echo   - release\ (发布包目录)
    echo.
    echo %BLUE%[INFO]%NC% 下一步:
    echo   1. 将 %MODULE_NAME%.kpm 复制到Android设备
    echo   2. 使用KernelSU或APatch Manager安装模块
    echo   3. 重启设备激活模块
) else (
    echo %RED%[ERROR]%NC% 构建失败 (退出码: %BUILD_RESULT%)
    echo.
    echo %YELLOW%[INFO]%NC% 常见问题解决:
    echo   1. 确保已安装Android NDK
    echo   2. 设置正确的Android内核源码路径
    echo   3. 检查WSL环境和依赖工具
    echo.
    echo %YELLOW%[INFO]%NC% 获取帮助: %0 --help
)

goto :end

:show_help
echo %SCRIPT_NAME% v%SCRIPT_VERSION%
echo.
echo 用法: %0 [目标] [选项]
echo.
echo 目标:
echo   kmp        - 生成KPM文件 (默认)
echo   android    - Android交叉编译
echo   native     - 本地内核编译
echo   clean      - 清理构建文件
echo.
echo 选项:
echo   -a, --android-kernel PATH  指定Android内核源码路径
echo   -v, --verbose              详细输出
echo   -h, --help                 显示此帮助信息
echo.
echo 示例:
echo   %0 kmp --android-kernel C:\android\kernel
echo   %0 android -a C:\AOSP\kernel\common
echo   %0 clean
echo.
echo 环境要求:
echo   - Windows 10/11 with WSL2
echo   - Android NDK (推荐r25c+)
echo   - Android内核源码
echo.
goto :end

:show_alternatives
echo.
echo %YELLOW%[INFO]%NC% 替代构建方案:
echo.
echo 1. 安装WSL2:
echo    - 在PowerShell中运行: wsl --install
echo    - 重启计算机
echo    - 安装Ubuntu: wsl --install -d Ubuntu
echo.
echo 2. 使用Docker:
echo    - 安装Docker Desktop
echo    - 运行: docker run -it --rm -v "%cd%":/workspace ubuntu:20.04
echo    - 在容器中安装构建依赖并编译
echo.
echo 3. 使用Linux虚拟机:
echo    - 安装VirtualBox或VMware
echo    - 创建Ubuntu虚拟机
echo    - 在虚拟机中进行构建
echo.
echo 4. 使用GitHub Actions (推荐):
echo    - 将代码推送到GitHub仓库
echo    - 配置CI/CD自动构建
echo    - 下载构建产物
echo.

:end
endlocal
pause