/*
 * KPUtils.h - KernelPatch Utilities Header
 * 
 * 这个头文件定义了KPM模块开发所需的基本接口和数据结构
 * 注意：这是一个模拟的头文件，实际使用时需要根据具体的KPM框架调整
 */

#ifndef _KPUTILS_H
#define _KPUTILS_H

#include <linux/types.h>
#include <linux/syscalls.h>

// KPM模块版本信息
#define KPM_API_VERSION "1.0"

// 系统调用Hook相关定义
typedef long (*syscall_handler_t)(void);

// Hook函数原型
int kp_hook_syscall(int syscall_nr, void *new_handler, void **orig_handler);
int kp_unhook_syscall(int syscall_nr);

// 内联Hook相关
int kp_hook_function(void *target_func, void *new_func, void **orig_func);
int kp_unhook_function(void *target_func);

// 内存保护相关
int kp_set_memory_rw(unsigned long addr, int numpages);
int kp_set_memory_ro(unsigned long addr, int numpages);

// 符号查找
unsigned long kp_lookup_symbol(const char *name);

// 日志输出
#define kp_info(fmt, ...) printk(KERN_INFO "[KPM] " fmt, ##__VA_ARGS__)
#define kp_warn(fmt, ...) printk(KERN_WARNING "[KPM] " fmt, ##__VA_ARGS__)
#define kp_err(fmt, ...) printk(KERN_ERR "[KPM] " fmt, ##__VA_ARGS__)

// 错误码定义
#define KP_SUCCESS 0
#define KP_ERROR_INVALID_PARAM -1
#define KP_ERROR_HOOK_FAILED -2
#define KP_ERROR_SYMBOL_NOT_FOUND -3
#define KP_ERROR_MEMORY_PROTECT -4

#endif /* _KPUTILS_H */