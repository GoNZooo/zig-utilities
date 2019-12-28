const std = @import("std");
const testing = std.testing;
const direct_allocator = std.heap.direct_allocator;
const mem = std.mem;
const fmt = std.fmt;
const rand = std.rand;
const assert = std.debug.assert;

pub const GrowableArrayInitOptions = struct {
    initial_capacity: ?usize = null,
};

pub const DeleteOptions = struct {
    shrink: bool = false,
};

pub fn GrowableArrayIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        __current: ?usize,
        __max_length: usize,
        __data: []T,
        __starting_position: usize,

        pub fn next(self: *Self) ?T {
            self.__current = if (self.__current) |c| c + 1 else 0;

            return if (self.__current.? >= self.__max_length) null else self.__data[self.__current.?];
        }

        pub fn previous(self: *Self) ?T {
            if (self.__current) |*current| {
                if (current.* > 0) current.* -= 1 else return null;

                return self.__data[current.*];
            } else {
                self.__current = self.__starting_position;

                return if (self.__current.? >= 0) self.__data[self.__current.?] else null;
            }
        }

        pub fn peek(self: Self) ?T {
            if (self.__current) |current| {
                return if (current >= self.__max_length) null else self.__data[current];
            } else {
                return null;
            }
        }

        // @TODO: add `step` parameter for length of `next`
        pub fn peekNext(self: Self) ?T {
            if (self.__current) |current| {
                return if (current + 1 >= self.__max_length) null else self.__data[current + 1];
            } else {
                return self.__data[0];
            }
        }

        // @TODO: add `step` parameter for length of `previous`
        pub fn peekPrevious(self: Self) ?T {
            if (self.__current) |current| {
                if (current > 0) {
                    return self.__data[current - 1];
                } else {
                    return null;
                }
            } else {
                return self.__data[self.__starting_position];
            }
        }

        pub fn position(self: Self) usize {
            return if (self.__current) |c| c else self.__starting_position;
        }
    };
}

pub fn GrowableArray(comptime T: type) type {
    // @TODO: Figure out if a way of calculating new capacity is general enough where it should be
    // the default instead of "only what's needed". Alternatively, create different modes, i.e.;
    // `.Eager`: Eagerly allocates more space for more characters to be added. Some constant here?
    // `.Strict`: Allocates strictly what's necessary.
    // `.Bracketed([]u32)`(?):
    //     Set up different key brackets that are allocated up to, with fallback constant value for
    //     when we enter non-bracketed territory.
    return struct {
        const Self = @This();
        const Slice = []T;
        const ConstSlice = []const T;

        allocator: *mem.Allocator,
        capacity: usize,
        count: usize,

        // @NOTE: Regard as private
        __chars: []T,

        /// Initializes the array, optionally allocating the amount of characters specified as the
        /// `initial_capacity` in `options`.
        /// The caller is responsible for calling `successful_return_value.deinit()`.
        pub fn init(
            allocator: *mem.Allocator,
            options: GrowableArrayInitOptions,
        ) !GrowableArray(T) {
            const capacity = if (options.initial_capacity) |c| c else 0;
            var chars = try allocator.alloc(T, capacity);

            return Self{
                .__chars = chars,
                .capacity = capacity,
                .allocator = allocator,
                .count = 0,
            };
        }

        /// Deinitializes the array, clearing all values inside of it and freeing the memory used.
        pub fn deinit(self: *Self) void {
            // @TODO: Determine whether or not it's better to have invalid memory here so that it
            // can be caught, instead of producing a valid empty slice.
            self.allocator.free(self.__chars);
            self.__chars = &[_]T{};
            self.capacity = 0;
            self.count = 0;
        }

        /// Copies a const slice of type `T`, meaning this can be used to create an array from a
        /// const array value.
        /// The caller is responsible for calling `successful_return_value.deinit()`.
        pub fn copyConst(allocator: *mem.Allocator, slice: ConstSlice) !Self {
            var chars = try mem.dupe(allocator, T, slice);

            return Self{
                .__chars = chars,
                .capacity = slice.len,
                .allocator = allocator,
                .count = slice.len,
            };
        }

        /// Appends a `[]const T` onto a `GrowableArray(T)`, mutating the appended to array.
        /// The allocator remains the same as the appended to string and the caller is not the owner
        /// of the memory.
        /// If the current capacity of the string is enough to hold the new string no new memory
        /// will be allocated.
        pub fn append(self: *Self, slice: ConstSlice) !void {
            const new_capacity = self.getRequiredCapacity(slice);
            var chars = self.__chars;
            if (new_capacity > self.capacity) {
                chars = try self.allocator.realloc(self.__chars, new_capacity);
            }
            mem.copy(T, chars[self.count..], slice);
            self.__chars = chars;
            self.capacity = new_capacity;
            self.count = self.count + slice.len;
        }

        /// Appends a `[]const T` onto a `GrowableArray(T)`, creating a new `GrowableArray(T)` from
        /// it. The copy will ignore the capacity of the original array.
        /// The caller is responsible for calling `successful_return_value.deinit()`.
        pub fn appendCopy(self: Self, allocator: *mem.Allocator, slice: ConstSlice) !Self {
            var chars = try mem.concat(
                allocator,
                T,
                &[_][]const T{ self.__chars[0..self.count], slice },
            );

            return Self{
                .__chars = chars,
                .capacity = chars.len,
                .allocator = allocator,
                .count = chars.len,
            };
        }

        /// Copies the contents of `slice` into the `GrowableArray` at `position` (0-indexed).
        /// Since this modifies an already existing array the responsibility of freeing memory
        /// still lies in the user of the `GrowableArray`.
        pub fn insertSlice(self: *Self, position: usize, slice: ConstSlice) !void {
            const new_capacity = self.getRequiredCapacity(slice);
            var characters = self.__chars;
            if (new_capacity > self.capacity) {
                characters = try self.allocator.realloc(characters, new_capacity);
            }
            const slice_to_copy_forward = characters[position..self.count];
            const new_start_position = position + slice.len;
            mem.copy(
                T,
                characters[new_start_position..(new_start_position + slice_to_copy_forward.len)],
                slice_to_copy_forward,
            );
            mem.copy(T, characters[position..(position + slice.len)], slice);

            self.capacity = new_capacity;
            self.count += slice.len;
            self.__chars = characters;
        }

        /// Copies the contents of `slice` into a copy of `GrowableArray` at `position` (0-indexed).
        /// The caller is responsible for calling `successful_return_value.deinit()`.
        pub fn insertSliceCopy(
            self: Self,
            allocator: *mem.Allocator,
            position: usize,
            slice: ConstSlice,
        ) !Self {
            const capacity = self.count + slice.len;
            var characters = try allocator.alloc(T, self.count + slice.len);
            const slice_to_copy_forward = self.__chars[position..self.count];
            const new_start_position = position + slice.len;
            mem.copy(T, characters[0..position], self.__chars[0..position]);
            mem.copy(
                T,
                characters[new_start_position..(new_start_position + slice_to_copy_forward.len)],
                slice_to_copy_forward,
            );
            mem.copy(
                T,
                characters[position..(position + slice.len)],
                slice,
            );

            return Self{
                .__chars = characters,
                .capacity = capacity,
                .count = characters.len,
                .allocator = allocator,
            };
        }

        /// Deletes a slice inside the array, from `start` to but not including `end` (0-indexed).
        /// The memory is conditionally shrunk based on the `shrink` member in `options` being
        /// `true` or `false.
        pub fn delete(self: *Self, start: usize, end: usize, options: DeleteOptions) void {
            assert(start <= end);
            const slice_to_remove = self.__chars[start..end];
            const slice_after_removed_space = self.__chars[end..self.count];

            mem.copy(T, self.__chars[start..self.count], slice_after_removed_space);

            const count = self.count - slice_to_remove.len;

            if (options.shrink) {
                self.__chars = self.allocator.shrink(self.__chars, count);
                self.capacity = count;
            }
            self.count = count;
        }

        /// Deletes a slice inside the array, from `start` to but not including `end` (0-indexed)
        /// and returns a new `GrowableArray`.
        /// The caller is responsible for calling `successful_return_value.deinit()`.
        pub fn deleteCopy(self: Self, allocator: *mem.Allocator, start: usize, end: usize) !Self {
            assert(start <= end);
            const slice_to_remove = self.__chars[start..end];
            const slice_after_removed_space = self.__chars[end..self.count];
            var characters = try allocator.alloc(T, self.count - slice_to_remove.len);

            mem.copy(T, characters[0..start], self.__chars[0..start]);
            mem.copy(T, characters[start..], slice_after_removed_space);

            return Self{
                .__chars = characters,
                .count = characters.len,
                .capacity = characters.len,
                .allocator = allocator,
            };
        }

        /// Returns a mutable copy of the contents of the `GrowableArray(T)`.
        /// caller is responsible for calling `successful_return_value.deinit()`.
        pub fn sliceCopy(self: Self, allocator: *mem.Allocator) !Slice {
            var chars = try mem.dupe(allocator, T, self.__chars[0..self.count]);

            return chars;
        }

        /// Returns an immutable copy of the contents of the `GrowableArray(T)`.
        pub fn sliceConst(self: Self) ConstSlice {
            return self.__chars[0..self.count];
        }

        pub fn iteratorConst(self: Self) GrowableArrayIterator(T) {
            return GrowableArrayIterator(T){
                .__starting_position = 0,
                .__current = null,
                .__max_length = self.count,
                .__data = self.__chars,
            };
        }

        pub fn iteratorAt(self: Self, column: usize) GrowableArrayIterator(T) {
            return GrowableArrayIterator(T){
                .__current = null,
                .__starting_position = column,
                .__max_length = self.count,
                .__data = self.__chars,
            };
        }

        pub fn iteratorFromEnd(self: Self) GrowableArrayIterator(T) {
            return GrowableArrayIterator(T){
                .__current = null,
                .__starting_position = self.count - 1,
                .__max_length = self.count,
                .__data = self.__chars,
            };
        }

        pub fn isEmpty(self: Self) bool {
            return self.count == 0;
        }

        pub fn format(
            self: Self,
            comptime format_string: []const u8,
            options: fmt.FormatOptions,
            context: var,
            comptime Errors: type,
            output: fn (context: @TypeOf(context), format_string: []const u8) Errors!void,
        ) Errors!void {
            return fmt.format(context, Errors, output, "{}", .{self.__chars[0..self.count]});
        }

        fn getRequiredCapacity(self: Self, slice: ConstSlice) usize {
            return std.math.max(self.capacity, self.count + slice.len);
        }
    };
}

test "`append` with an already high enough capacity doesn't change capacity" {
    const initial_capacity = 80;
    var string = try GrowableArray(u8).init(direct_allocator, GrowableArrayInitOptions{
        .initial_capacity = initial_capacity,
    });

    testing.expectEqual(string.count, 0);
    testing.expectEqual(string.capacity, initial_capacity);

    const added_slice = "hello";
    try string.append(added_slice);
    testing.expectEqual(string.capacity, initial_capacity);
    testing.expectEqual(string.count, added_slice.len);
}

test "`appendCopy` doesn't bring unused space with it" {
    const initial_capacity = 80;
    var string = try GrowableArray(u8).init(direct_allocator, GrowableArrayInitOptions{
        .initial_capacity = initial_capacity,
    });

    testing.expectEqual(string.count, 0);
    testing.expectEqual(string.capacity, initial_capacity);

    const added_slice = "hello";
    const string2 = try string.appendCopy(direct_allocator, added_slice);
    testing.expectEqual(string2.capacity, added_slice.len);
    testing.expectEqual(string2.count, added_slice.len);
    testing.expectEqualSlices(u8, string2.sliceConst(), added_slice);
}

test "`appendCopy` doesn't disturb original string, `copyConst` copies static strings" {
    var string2 = try GrowableArray(u8).copyConst(direct_allocator, "hello");
    try string2.append(" there");
    var string3 = try string2.appendCopy(direct_allocator, "wat");

    testing.expectEqualSlices(
        u8,
        string2.sliceConst(),
        string3.__chars[0..string2.sliceConst().len],
    );
    testing.expectEqualSlices(u8, string2.sliceConst(), "hello there");
    testing.expect(&string2.sliceConst()[0] != &string3.sliceConst()[0]);
    testing.expect(string3.capacity == 14);
    string3.deinit();
    testing.expect(string3.capacity == 0);
    testing.expect(string2.capacity == 11);
}

test "`insertSlice` inserts a string into an already created string" {
    var string = try GrowableArray(u8).copyConst(direct_allocator, "hello!");
    try string.insertSlice(5, "lo");
    testing.expectEqualSlices(u8, string.sliceConst(), "hellolo!");
    try string.insertSlice(5, ", bo");
    testing.expectEqualSlices(u8, string.sliceConst(), "hello, bolo!");
}

test "`insertSliceCopy` inserts a string into a copy of a `GrowableArray`" {
    var string = try GrowableArray(u8).copyConst(direct_allocator, "hello!");
    const string2 = try string.insertSliceCopy(direct_allocator, 5, "lo");
    testing.expectEqualSlices(u8, string2.sliceConst(), "hellolo!");
    const string3 = try string2.insertSliceCopy(direct_allocator, 5, ", bo");
    testing.expectEqualSlices(u8, string3.sliceConst(), "hello, bolo!");
}

test "`delete` deletes" {
    var string = try GrowableArray(u8).copyConst(direct_allocator, "hello!");
    string.delete(1, 4, DeleteOptions{});
    testing.expectEqualSlices(u8, string.sliceConst(), "ho!");
    testing.expectEqual(string.capacity, 6);
}

test "`delete` deletes and shrinks if given the option" {
    var string = try GrowableArray(u8).copyConst(direct_allocator, "hello!");
    string.delete(1, 4, DeleteOptions{ .shrink = true });
    testing.expectEqualSlices(u8, string.sliceConst(), "ho!");
    testing.expectEqual(string.capacity, 3);
}

test "`format` returns a custom format instead of everything" {
    var string2 = try GrowableArray(u8).copyConst(direct_allocator, "hello");
    var format_output = try fmt.allocPrint(
        direct_allocator,
        "{}! {}!",
        .{ string2, @as(u1, 1) },
    );

    testing.expectEqualSlices(u8, format_output, "hello! 1!");
}

test "`deleteCopy` deletes" {
    var string = try GrowableArray(u8).copyConst(direct_allocator, "hello, bolo!");
    const string2 = try string.deleteCopy(direct_allocator, 1, 4);
    testing.expectEqualSlices(u8, string2.sliceConst(), "ho, bolo!");
    testing.expectEqual(string2.capacity, 9);

    const string3 = try string2.deleteCopy(direct_allocator, 2, 8);
    testing.expectEqualSlices(u8, string3.sliceConst(), "ho!");
    testing.expectEqual(string3.capacity, 3);
}

// @TODO: add iterator tests
