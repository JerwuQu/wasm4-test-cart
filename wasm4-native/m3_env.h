#include <stdint.h>
#include <stddef.h>

uint16_t m3ApiReadMem16(const char *b) {
    return (b[0] << 8) | b[1];
}

void *memset(void *buf, int val, size_t num) {
    while (num--) {
        ((char*)buf)[num] = val;
    }
}
