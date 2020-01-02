const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const ArrayList = std.ArrayList;

/// Splits a slice into several slices based on newline characters. This uses an `ArrayList`
/// internally so it's possible that you may want to use something less inefficient for your
/// specific use case.
/// The caller is responsible for calling `allocator.free()` when they're done with the memory.
pub fn splitIntoLines(allocator: *mem.Allocator, string: []const u8) ![]const []const u8 {
    var lines = ArrayList([]const u8).init(allocator);
    var newline_iterator = mem.separate(string, "\n");

    while (newline_iterator.next()) |line| {
        var trimmed_line = mem.trim(u8, line, "\n\r");
        if (!mem.eql(u8, trimmed_line, "")) (try lines.append(trimmed_line));
    }

    return lines.toSliceConst();
}

test "`splitIntoLines` splits into lines" {
    const string = "Hello, Joe!\nHello, Mike!\r\nLet's patch in Robert!";
    const lines = try splitIntoLines(std.heap.page_allocator, string);
    testing.expectEqual(lines.len, 3);
    testing.expectEqualSlices(u8, lines[0], "Hello, Joe!");
    testing.expectEqualSlices(u8, lines[1], "Hello, Mike!");
    testing.expectEqualSlices(u8, lines[2], "Let's patch in Robert!");
}
