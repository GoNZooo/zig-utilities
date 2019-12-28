const std = @import("std");
const mem = std.mem;
const testing = std.testing;

// @TODO: maybe rename this to `interleave.zig` and use `{,de}interleave`?

/// Takes two slices of memory and a zipped result slice:
/// `try zipMemory(u8, allocator, &[_]u32{1, 2, 3}, &[_]u32{4, 5, 6})` gives:
/// `[]u32{ 1, 4, 2, 5, 3, 6 }`
/// The original slices is left untouched and the caller is responsible for the new memory.
pub fn zipMemory(comptime T: type, allocator: *mem.Allocator, as: []const T, bs: []const T) ![]T {
    std.debug.assert(as.len == bs.len);

    const zippedMemory = try allocator.alloc(T, as.len + bs.len);

    for (as) |a, source_index| {
        const destination_index = 2 * source_index;
        zippedMemory[destination_index] = a;
        zippedMemory[destination_index + 1] = bs[source_index];
    }

    return zippedMemory;
}

pub fn UnzipResult(comptime T: type) type {
    return struct {
        a: []T,
        b: []T,
    };
}

/// Takes a slice of memory and creates two result slices:
/// `try unzipMemory(u8, allocator, &[_]u32{1, 4, 2, 5, 3, 6})` gives:
/// `UnzipResult{.a = []u32{1, 2, 3}, .b = []u32{4, 5, 6}}`
/// The original slice is left untouched and the caller is responsible for the new memory.
pub fn unzipMemory(comptime T: type, allocator: *mem.Allocator, memory: []const T) !UnzipResult(T) {
    std.debug.assert(memory.len % 2 == 0);

    const a = try allocator.alloc(T, memory.len / 2);
    const b = try allocator.alloc(T, memory.len / 2);
    var a_index: usize = 0;
    var b_index: usize = 0;

    for (memory) |x, i| {
        if (i % 2 == 0) {
            a[a_index] = x;
            a_index += 1;
        } else {
            b[b_index] = x;
            b_index += 1;
        }
    }

    return UnzipResult(T){
        .a = a,
        .b = b,
    };
}

test "`zipMemory` works as documented" {
    const a = &[_]u32{ 1, 2, 3 };
    const b = &[_]u32{ 4, 5, 6 };

    const zipped = try zipMemory(u32, std.heap.page_allocator, a, b);

    testing.expectEqualSlices(u32, zipped, &[_]u32{ 1, 4, 2, 5, 3, 6 });
}

test "`unzipMemory` works as documented" {
    const original_slice = &[_]u32{ 1, 4, 2, 5, 3, 6 };
    const unzipped = try unzipMemory(u32, std.heap.page_allocator, original_slice);
    testing.expectEqualSlices(u32, unzipped.a, &[_]u32{ 1, 2, 3 });
    testing.expectEqualSlices(u32, unzipped.b, &[_]u32{ 4, 5, 6 });
}
