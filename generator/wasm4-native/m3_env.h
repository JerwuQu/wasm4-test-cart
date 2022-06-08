#include <stdint.h>

uint16_t m3ApiReadMem16(const char *b) {
    return (b[0] << 8) | b[1];
}
