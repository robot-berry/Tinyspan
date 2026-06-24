#include <stdint.h>

#ifndef RESULT_BASE
#define RESULT_BASE 0xFFFD8000UL
#endif

#ifndef OUTPUT_BASE
#define OUTPUT_BASE 0x11000000UL
#endif

#ifndef REFERENCE_BASE
#define REFERENCE_BASE 0x14000000UL
#endif

#ifndef PIXEL_COUNT
#define PIXEL_COUNT 921600UL
#endif

#define STATUS_RUN  0x52554E20U
#define STATUS_PASS 0x50415353U
#define STATUS_FAIL 0x4641494CU

static inline void barrier(void) {
    __asm__ volatile("dsb sy\nisb" ::: "memory");
}

static inline uint32_t absdiff_u8(uint32_t a, uint32_t b) {
    return (a > b) ? (a - b) : (b - a);
}

void main(void) {
    volatile uint32_t *result = (volatile uint32_t *)RESULT_BASE;
    volatile uint32_t *out = (volatile uint32_t *)OUTPUT_BASE;
    volatile const uint8_t *ref = (volatile const uint8_t *)REFERENCE_BASE;
    uint32_t mismatch_bytes = 0U;
    uint32_t max_diff = 0U;
    uint32_t first_mismatch = 0xffffffffU;
    uint32_t first_expected = 0U;
    uint32_t first_actual = 0U;
    uint32_t sample_count = 0U;

    result[0] = STATUS_RUN;
    result[1] = 0U;
    result[2] = (uint32_t)(PIXEL_COUNT * 3UL);
    result[3] = 0U;
    result[4] = 0xffffffffU;
    result[5] = 0U;
    result[6] = 0U;
    result[7] = (uint32_t)OUTPUT_BASE;
    result[8] = (uint32_t)REFERENCE_BASE;
    result[9] = (uint32_t)PIXEL_COUNT;
    result[10] = 0U;
    barrier();

    for (uint32_t i = 0U; i < (uint32_t)PIXEL_COUNT; ++i) {
        uint32_t expected =
            (((uint32_t)ref[i * 3U + 0U]) << 16) |
            (((uint32_t)ref[i * 3U + 1U]) << 8) |
            (((uint32_t)ref[i * 3U + 2U]) << 0);
        uint32_t actual = out[i] & 0x00ffffffU;

        uint32_t er = (expected >> 16) & 0xffU;
        uint32_t eg = (expected >> 8) & 0xffU;
        uint32_t eb = expected & 0xffU;
        uint32_t ar = (actual >> 16) & 0xffU;
        uint32_t ag = (actual >> 8) & 0xffU;
        uint32_t ab = actual & 0xffU;
        uint32_t dr = absdiff_u8(er, ar);
        uint32_t dg = absdiff_u8(eg, ag);
        uint32_t db = absdiff_u8(eb, ab);
        uint32_t pixel_mismatch = 0U;

        if (dr != 0U) {
            mismatch_bytes++;
            pixel_mismatch = 1U;
            if (dr > max_diff) { max_diff = dr; }
        }
        if (dg != 0U) {
            mismatch_bytes++;
            pixel_mismatch = 1U;
            if (dg > max_diff) { max_diff = dg; }
        }
        if (db != 0U) {
            mismatch_bytes++;
            pixel_mismatch = 1U;
            if (db > max_diff) { max_diff = db; }
        }

        if (pixel_mismatch != 0U) {
            if (first_mismatch == 0xffffffffU) {
                first_mismatch = i;
                first_expected = expected;
                first_actual = actual;
            }
            if (sample_count < 8U) {
                uint32_t base = 32U + sample_count * 4U;
                result[base + 0U] = i;
                result[base + 1U] = expected;
                result[base + 2U] = actual;
                result[base + 3U] = ((dr & 0xffU) << 16) | ((dg & 0xffU) << 8) | (db & 0xffU);
                sample_count++;
            }
        }
    }
    barrier();

    result[0] = (mismatch_bytes == 0U) ? STATUS_PASS : STATUS_FAIL;
    result[1] = mismatch_bytes;
    result[2] = (uint32_t)(PIXEL_COUNT * 3UL);
    result[3] = max_diff;
    result[4] = first_mismatch;
    result[5] = first_expected;
    result[6] = first_actual;
    result[7] = (uint32_t)OUTPUT_BASE;
    result[8] = (uint32_t)REFERENCE_BASE;
    result[9] = (uint32_t)PIXEL_COUNT;
    result[10] = sample_count;
    barrier();

    for (;;) {
        __asm__ volatile("wfe");
    }
}
