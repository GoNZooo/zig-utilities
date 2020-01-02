const std = @import("std");
const builtin = std.builtin;
const Builder = std.build.Builder;
const Step = std.build.Step;

const files = [_][]const u8{ "main", "growable_array", "strings", "slices", "c" };

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("zig-utilities", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    const test_step = b.step("test", "Run library tests");

    addTests(b, mode, test_step);
}

fn addTests(b: *Builder, mode: builtin.Mode, test_step: *Step) void {
    inline for (files) |file| {
        var file_test = b.addTest("src/" ++ file ++ ".zig");
        file_test.setBuildMode(mode);
        test_step.dependOn(&file_test.step);
    }
}
