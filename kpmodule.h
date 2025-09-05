/*
 * KPModule.h - KernelPatch Module Framework Header
 * 
 * 这个头文件定义了KPM模块框架的基本接口
 * 注意：这是一个模拟的头文件，实际使用时需要根据具体的KPM框架调整
 */

#ifndef _KPMODULE_H
#define _KPMODULE_H

#include <linux/module.h>
#include <linux/init.h>

// KPM模块信息结构
struct kpm_info {
    const char *name;
    const char *version;
    const char *author;
    const char *description;
    const char *license;
};

// KPM模块初始化和清理函数类型
typedef int (*kpm_init_func_t)(void);
typedef void (*kmp_exit_func_t)(void);

// KPM模块注册宏
#define KPM_MODULE_INFO(info_struct) \
    static struct kpm_info __kpm_info __attribute__((section(".kpm_info"))) = info_struct

#define KPM_INIT(init_func) \
    static kpm_init_func_t __kmp_init __attribute__((section(".kpm_init"))) = init_func

#define KPM_EXIT(exit_func) \
    static kmp_exit_func_t __kmp_exit __attribute__((section(".kpm_exit"))) = exit_func

// 便利宏定义
#define KPM_MODULE_LICENSE(license) MODULE_LICENSE(license)
#define KPM_MODULE_AUTHOR(author) MODULE_AUTHOR(author)
#define KPM_MODULE_DESCRIPTION(desc) MODULE_DESCRIPTION(desc)
#define KPM_MODULE_VERSION(version) MODULE_VERSION(version)

// KPM模块状态
enum kpm_state {
    KPM_STATE_UNLOADED,
    KPM_STATE_LOADING,
    KPM_STATE_LOADED,
    KPM_STATE_UNLOADING,
    KPM_STATE_ERROR
};

// KPM模块控制接口
int kpm_load_module(const char *module_path);
int kpm_unload_module(const char *module_name);
enum kpm_state kpm_get_module_state(const char *module_name);

// 模块间通信接口
int kpm_send_message(const char *target_module, int msg_type, void *data, size_t data_len);
int kpm_register_message_handler(int msg_type, int (*handler)(void *data, size_t data_len));

// 资源管理
void* kpm_alloc_memory(size_t size);
void kpm_free_memory(void *ptr);

#endif /* _KPMODULE_H */