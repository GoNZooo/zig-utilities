const std = @import("std");
const mem = std.mem;
const testing = std.testing;

/// Determines whether a predicate is true for all members of a slice.
pub fn all(comptime T: type, ts: []const T, predicate: fn (t: T) bool) bool {
    for (ts) |t| {
        if (!predicate(t)) return false;
    }

    return true;
}

/// Determines whether a predicate is true for any member of a slice.
pub fn any(comptime T: type, ts: []const T, predicate: fn (t: T) bool) bool {
    for (ts) |t| {
        if (predicate(t)) return true;
    }

    return false;
}

/// Filters a slice of `T` and puts the result into a new allocated and resized slice.
/// The caller is responsible for freeing the allocated memory.
pub fn filter(
    comptime T: type,
    allocator: *mem.Allocator,
    slice: []const T,
    predicate: fn (x: T) bool,
) ![]T {
    const filtered = try allocator.alloc(T, slice.len);
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
    const bs = try allocator.alloc(B, as.len);

    for (as) |a, i| {
        bs[i] = f(a);
    }

    return bs;
}

/// Takes two slices of memory and a zipped result slice:
/// `try zipMemory(u8, allocator, &[_]u32{1, 2, 3}, &[_]u32{4, 5, 6})` gives:
/// `[]u32{ 1, 4, 2, 5, 3, 6 }`
/// The original slices is left untouched and the caller is responsible for the new memory.
pub fn zip(comptime T: type, allocator: *mem.Allocator, as: []const T, bs: []const T) ![]T {
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
pub fn unzip(comptime T: type, allocator: *mem.Allocator, memory: []const T) !UnzipResult(T) {
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

test "`zip` works as documented" {
    const a = &[_]u32{ 1, 2, 3 };
    const b = &[_]u32{ 4, 5, 6 };

    const zipped = try zip(u32, std.heap.page_allocator, a, b);

    testing.expectEqualSlices(u32, zipped, &[_]u32{ 1, 4, 2, 5, 3, 6 });
}

test "`unzipMemory` works as documented" {
    const original_slice = &[_]u32{ 1, 4, 2, 5, 3, 6 };
    const unzipped = try unzip(u32, std.heap.page_allocator, original_slice);
    testing.expectEqualSlices(u32, unzipped.a, &[_]u32{ 1, 2, 3 });
    testing.expectEqualSlices(u32, unzipped.b, &[_]u32{ 4, 5, 6 });
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

test "`all` works" {
    const slice = &[_]u32{ 1, 2, 3, 4, 5 };
    const even = try filter(u32, std.heap.page_allocator, slice, isEven);
    testing.expect(all(u32, even, isEven));
    testing.expect(!all(u32, even, isOdd));
}

test "`any` works" {
    const slice = &[_]u32{ 1, 2, 3, 4, 5 };
    const even = try filter(u32, std.heap.page_allocator, slice, isEven);
    testing.expect(any(u32, even, isEven));
    testing.expect(!any(u32, even, isOdd));
    testing.expect(any(u32, slice, isOne));
    testing.expect(!any(u32, even, isOne));
}

fn isEven(x: u32) bool {
    return x % 2 == 0;
}

fn isOdd(x: u32) bool {
    return x % 2 == 1;
}

fn isOne(x: u32) bool {
    return x == 1;
}

fn addOne(x: u32) u32 {
    return x + 1;
}
