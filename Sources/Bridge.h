// Mopad — C 桥接头文件
// MultitouchSupport 为苹果私有框架，运行时通过 dlopen/dlsym 加载；此处只声明结构体与函数指针类型。
#pragma once
#include <CoreFoundation/CoreFoundation.h>
#include <stdint.h>
#include <stdbool.h>

typedef struct { float x; float y; } MTPoint;
typedef struct { MTPoint position; MTPoint velocity; } MTVector;

// 单个触点（96 字节）
typedef struct {
    int32_t  frame;
    double   timestamp;
    int32_t  identifier;
    int32_t  state;        // 1 未追踪 2 进入 3 悬停 4 按下 5 接触中 6 抬起 7 残留 8 离开
    int32_t  fingerId;
    int32_t  handId;
    MTVector normalized;   // 0~1 归一化坐标
    float    zTotal;       // 接触面积
    int32_t  field9;
    float    angle;
    float    majorAxis;
    float    minorAxis;
    MTVector absolute;
    int32_t  field14;
    int32_t  field15;
    float    zDensity;
} MTTouch;

_Static_assert(sizeof(MTTouch) == 96, "MTTouch layout mismatch");

typedef void *MTDeviceRef;
typedef int (*MTContactCallback)(MTDeviceRef device, const MTTouch *touches, int32_t count, double timestamp, int32_t frame);

typedef CFArrayRef (*MTDeviceCreateListFn)(void);
typedef void    (*MTRegisterContactFrameCallbackFn)(MTDeviceRef, MTContactCallback);
typedef void    (*MTUnregisterContactFrameCallbackFn)(MTDeviceRef, MTContactCallback);
typedef int32_t (*MTDeviceStartFn)(MTDeviceRef, int32_t);
typedef int32_t (*MTDeviceStopFn)(MTDeviceRef);
typedef int32_t (*MTDeviceGetFamilyIDFn)(MTDeviceRef, int32_t *);
typedef int32_t (*MTDeviceGetDeviceIDFn)(MTDeviceRef, uint64_t *);
typedef int32_t (*MTDeviceGetSensorSurfaceDimensionsFn)(MTDeviceRef, int32_t *, int32_t *);
typedef bool    (*MTDeviceIsBuiltInFn)(MTDeviceRef);

// PreferencePanesSupport：即时切换自然滚动
typedef void (*SetSwipeScrollDirectionFn)(bool);

// IOKit HID 事件系统（IOKit 已导出，头文件未公开）
typedef void *IOHIDEventSystemClientRef;
extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreateSimpleClient(CFAllocatorRef allocator);
extern Boolean IOHIDEventSystemClientSetProperty(IOHIDEventSystemClientRef client, CFStringRef key, CFTypeRef property);
extern CFTypeRef IOHIDEventSystemClientCopyProperty(IOHIDEventSystemClientRef client, CFStringRef key) CF_RETURNS_RETAINED;
