#ifndef CORE_PORTME_H
#define CORE_PORTME_H

#include <stdint.h>

typedef uint8_t   ee_u8;
typedef int16_t   ee_s16;
typedef uint16_t  ee_u16;
typedef int32_t   ee_s32;
typedef uint32_t  ee_u32;
typedef uint32_t  ee_ptr_int;
typedef uint32_t  ee_size_t;
typedef ee_u32    CORE_TICKS;
typedef ee_u32    CORETIMETYPE;

#define NULL           ((void *)0)
#define align_mem(x)   (void *)(4 + (((ee_ptr_int)(x)-1) & ~3))

#define SEED_METHOD           SEED_VOLATILE
#define MEM_METHOD            MEM_STATIC
#define MULTITHREAD           1
#define USE_FORK              0
#define USE_PTHREAD           0
#define USE_SOCKET            0
#define HAS_FLOAT             0
#define HAS_TIME_H            0
#define USE_CLOCK             0
#define HAS_STDIO             0
#define HAS_PRINTF            0
#define MAIN_HAS_NOARGC       1
#define MAIN_HAS_NORETURN     0

#ifndef ITERATIONS
#define ITERATIONS            1
#endif

#ifndef COMPILER_VERSION
#define COMPILER_VERSION      "GCC"
#endif
#ifndef COMPILER_FLAGS
#define COMPILER_FLAGS        "rv32i -O2"
#endif
#define MEM_LOCATION          "STATIC"

extern ee_u32 default_num_contexts;

typedef struct CORE_PORTABLE_S { ee_u8 portable_id; } core_portable;

void portable_init(core_portable *p, int *argc, char *argv[]);
void portable_fini(core_portable *p);
int  ee_printf(const char *fmt, ...);

#endif /* CORE_PORTME_H */
