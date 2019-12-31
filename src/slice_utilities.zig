const std = @import("std");
const mem = std.mem;
const testing = std.testing;

/// Filters a slice of `T` and puts the result into a new allocated and resized slice.
/// The caller is responsible for freeing the allocated memory.
pub fn filter(
    comptime T: type,
    allocator: *mem.Allocator,
    slice: []const T,
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

/// Maps a function `f` over a slice of `A`s to create a slice of `B`s. `A` and `B` may or may not
/// be the same type; the only requirement is that they match the type of `f`.
/// The caller is responsible for freeing the allocated memory.
pub fn map(
    comptime A: type,
    comptime B: type,
    allocator: *mem.Allocator,
    as: []const A,
    f: fn (x: A) B,
) ![]B {
    var bs = try allocator.alloc(B, as.len);

    for (as) |a, i| {
        bs[i] = f(a);
    }

    return bs;
}

test "`filter` works" {
    const slice = &[_]u32{ 1, 2, 3, 4, 5 };
    const filtered = try filter(u32, std.heap.page_allocator, slice, isEven);
    testing.expectEqualSlices(u32, filtered, &[_]u32{ 2, 4 });
}

test "`map` works" {
    const slice = &[_]u32{ 1, 2, 3, 4, 5 };
    const mappedPlusOne = try map(u32, u32, std.heap.page_allocator, slice, addOne);
    const mappedIsEven = try map(u32, bool, std.heap.page_allocator, slice, isEven);

    testing.expectEqualSlices(u32, mappedPlusOne, &[_]u32{ 2, 3, 4, 5, 6 });
    testing.expectEqualSlices(bool, mappedIsEven, &[_]bool{ false, true, false, true, false });
}

fn isEven(x: u32) bool {
    return x % 2 == 0;
}

fn addOne(x: u32) u32 {
    return x + 1;
}
