#include <stddef.h>

void *memset(void *buf, int val, size_t num) {
    while (num--) {
        ((char*)buf)[num] = val;
    }
    return buf;
}
