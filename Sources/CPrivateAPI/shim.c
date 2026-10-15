#include "CPrivateAPI.h"
#include <string.h>

typedef struct { char major, minor, build, reserved[1]; uint16_t release; } SMCVersion;
typedef struct { uint16_t version, length; uint32_t cpuPLimit, gpuPLimit, memPLimit; } SMCPLimitData;
typedef struct { uint32_t dataSize, dataType; char dataAttributes; } SMCKeyInfo;
typedef struct {
    uint32_t key;
    SMCVersion vers;
    SMCPLimitData pLimitData;
    SMCKeyInfo keyInfo;
    char result, status, data8;
    uint32_t data32;
    unsigned char bytes[32];
} SMCKeyData;

_Static_assert(sizeof(SMCKeyData) == 80, "SMCKeyData must be 80 bytes");

static uint32_t smc_key(const char *s) {
    return ((uint32_t)(uint8_t)s[0] << 24) | ((uint32_t)(uint8_t)s[1] << 16)
         | ((uint32_t)(uint8_t)s[2] << 8) | (uint32_t)(uint8_t)s[3];
}

int smc_open(uint32_t *conn) {
    if (!conn) return -1;
    io_service_t service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"));
    if (service == IO_OBJECT_NULL) return -1;
    io_connect_t c = IO_OBJECT_NULL;
    kern_return_t kr = IOServiceOpen(service, mach_task_self(), 0, &c);
    IOObjectRelease(service);
    if (kr != KERN_SUCCESS) return -1;
    *conn = c;
    return 0;
}

void smc_close(uint32_t conn) {
    if (conn != IO_OBJECT_NULL) IOServiceClose(conn);
}

static int smc_call(uint32_t conn, SMCKeyData *in, SMCKeyData *out) {
    size_t size = sizeof(SMCKeyData);
    memset(out, 0, sizeof(SMCKeyData));
    if (IOConnectCallStructMethod(conn, 2, in, sizeof(SMCKeyData), out, &size) != KERN_SUCCESS) return -1;
    return out->result == 0 ? 0 : -1;
}

int smc_read(uint32_t conn, const char key[4], char out_type[5], uint8_t out_bytes[32], uint32_t *out_size) {
    if (!key || !out_type || !out_bytes || !out_size) return -1;
    SMCKeyData in, out;
    memset(&in, 0, sizeof in);
    in.key = smc_key(key);
    in.data8 = 9; // read key info
    if (smc_call(conn, &in, &out) != 0) return -1;
    uint32_t size = out.keyInfo.dataSize;
    uint32_t type = out.keyInfo.dataType;
    if (size > 32) size = 32;
    in.keyInfo.dataSize = out.keyInfo.dataSize;
    in.data8 = 5; // read bytes
    if (smc_call(conn, &in, &out) != 0) return -1;
    out_type[0] = (char)(type >> 24); out_type[1] = (char)(type >> 16);
    out_type[2] = (char)(type >> 8);  out_type[3] = (char)type;
    out_type[4] = 0;
    memcpy(out_bytes, out.bytes, 32);
    *out_size = size;
    return 0;
}
