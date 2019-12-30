const std = @import("std");
const mem = std.mem;
const testing = std.testing;

pub fn filterSlice(
    comptime T: type,
    allocator: *mem.Allocator,
    slice: []T,
    predicate: fn (x: T) bool,
) ![]T {
    var filtered = try allocator.alloc(T, slice.len);
    var matching: usize = 0;
    for (slice) |x| {
        if (predicate(x)) {
            filtered[matching] = x;
            matching += 1;
        }
    }
    filtered = allocator.shrink(filtered, matching);

    return filtered;
}

test "`filterSlice` works" {
    const slice = &[_]u32{ 1, 2, 3, 4, 5 };
    const filtered = try filterSlice(u32, std.heap.page_allocator, slice, isEven);
    testing.expectEqualSlices(u32, filtered, &[_]u32{ 2, 4 });
}

fn isEven(x: u32) bool {
    return x % 2 == 0;
}
