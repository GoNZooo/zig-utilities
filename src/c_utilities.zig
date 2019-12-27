const std = @import("std");
const mem = std.mem;

/// Creates a new struct, automatically zero-initialized, of any type. Useful as a replacement for
/// the `StructType struct = {0};` idiom in C.
pub fn zeroInit(comptime T: type) T {
    var bytes = [_]u8{0} ** @sizeOf(T);

    return mem.bytesToValue(T, &bytes);
}
