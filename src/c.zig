const std = @import("std");
const mem = std.mem;
const testing = std.testing;

/// Creates a new struct, automatically zero-initialized, of any type. Useful as a replacement for
/// the `StructType struct = {0};` idiom in C.
pub fn zeroed(comptime T: type) T {
    const bytes = [_]u8{0} ** @sizeOf(T);

    return mem.bytesToValue(T, &bytes);
}

const TestStruct = struct {
    x: f32,
    y: i32,
    c: u8,
    f: ?fn () void,
};

/// Takes a void pointer ant casts it to another pointer type.
pub fn castVoidPointer(comptime T: type, ptr: ?*c_void) T {
    return @intToPtr(T, @ptrToInt(ptr));
}

test "`zeroed` zeroes struct" {
    const zeroed_test_struct = zeroed(TestStruct);
    testing.expectEqual(zeroed_test_struct.x, 0.0);
    testing.expectEqual(zeroed_test_struct.y, 0);
    testing.expectEqual(zeroed_test_struct.c, 0);
    testing.expectEqual(zeroed_test_struct.f, null);
}

test "`castVoidPointer` works" {
    const t_pointer = castVoidPointer(*TestStruct, @intToPtr(*c_void, @alignOf(TestStruct) * 42));
    const null_t_pointer = castVoidPointer(?*TestStruct, null);
}
