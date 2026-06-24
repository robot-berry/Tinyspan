#include <stdint.h>

#define RESULT_BASE  ((volatile uint32_t *)0xFFFD8000UL)
#define DDR_BASE     0x12000000UL
#define DDR_STRIDE   0x00004000UL
#define TEST_COUNT   8U

static inline void barrier(void) {
    __asm__ volatile("dsb sy\nisb" ::: "memory");
}

void main(void) {
    volatile uint32_t *result = RESULT_BASE;
    uint32_t mismatches = 0;

    result[0] = 0x52554E20U; /* RUN */
    result[1] = 0U;
    barrier();

    for (uint32_t i = 0; i < TEST_COUNT; ++i) {
        volatile uint32_t *addr = (volatile uint32_t *)(DDR_BASE + i * DDR_STRIDE);
        uint32_t value = 0xA6000000U | ((i & 0xffU) << 8) | (i & 0xffU);
        *addr = value;
        result[8 + i] = value;
    }
    barrier();

    for (uint32_t i = 0; i < TEST_COUNT; ++i) {
        volatile uint32_t *addr = (volatile uint32_t *)(DDR_BASE + i * DDR_STRIDE);
        uint32_t expected = 0xA6000000U | ((i & 0xffU) << 8) | (i & 0xffU);
        uint32_t actual = *addr;
        result[16 + i] = actual;
        if (actual != expected) {
            mismatches++;
        }
    }
    barrier();

    result[0] = (mismatches == 0U) ? 0x50415353U : 0x4641494CU; /* PASS/FAIL */
    result[1] = mismatches;
    result[2] = DDR_BASE;
    result[3] = DDR_STRIDE;
    result[4] = TEST_COUNT;
    barrier();

    for (;;) {
        __asm__ volatile("wfe");
    }
}
