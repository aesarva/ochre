#ifndef CPrivateAPI_h
#define CPrivateAPI_h

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/hidsystem/IOHIDEventSystemClient.h>
#include <IOKit/hidsystem/IOHIDServiceClient.h>
#include <stdint.h>

CF_ASSUME_NONNULL_BEGIN

// Private IOHIDEventSystemClient API (temperature sensors). The SDK already
// declares IOHIDEventSystemClientRef / IOHIDServiceClientRef (as CF-bridged
// types, so ARC manages them), CopyServices and CopyProperty; only the
// functions missing from public headers are declared here.
typedef CFTypeRef IOHIDEventRef;

CF_RETURNS_RETAINED IOHIDEventSystemClientRef _Nullable IOHIDEventSystemClientCreate(CFAllocatorRef _Nullable allocator);
int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef matching);
CF_RETURNS_RETAINED IOHIDEventRef _Nullable IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t type, int32_t options, int64_t timestamp);
double IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

// AppleSMC access. All functions return 0 on success.
int smc_open(uint32_t *conn);
void smc_close(uint32_t conn);
// key: 4 ASCII chars. out_type: 4 chars + NUL. out_bytes: up to 32 bytes.
int smc_read(uint32_t conn, const char key[_Nonnull 4], char out_type[_Nonnull 5], uint8_t out_bytes[_Nonnull 32], uint32_t *out_size);

CF_ASSUME_NONNULL_END

#endif
