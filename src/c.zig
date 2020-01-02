const std = @import("std");
const mem = std.mem;
const testing = std.testing;

/// Creates a new struct, automatically zero-initialized, of any type. Useful as a replacement for
/// the `StructType struct = {0};` idiom in C.
pub fn zeroed(comptime T: type) T {
    var bytes = [_]u8{0} ** @sizeOf(T);

    return mem.bytesToValue(T, &bytes);
}

const TestStruct = struct {
    x: f32,
    y: i32,
    c: u8,
    f: ?fn () void,
};

test "`zeroed` zeroes struct" {
    var zeroed_test_struct = zeroed(TestStruct);
    testing.expectEqual(zeroed_test_struct.x, 0.0);
    testing.expectEqual(zeroed_test_struct.y, 0);
    testing.expectEqual(zeroed_test_struct.c, 0);
    testing.expectEqual(zeroed_test_struct.f, null);
}
