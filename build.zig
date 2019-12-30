const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("zig-utilities", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    var main_tests = b.addTest("src/main.zig");
    var growable_array_tests = b.addTest("src/growable_array.zig");
    var zip_tests = b.addTest("src/zip.zig");
    var string_utilities_tests = b.addTest("src/string_utilities.zig");
    var slice_utilities_tests = b.addTest("src/slice_utilities.zig");
    main_tests.setBuildMode(mode);
    growable_array_tests.setBuildMode(mode);
    zip_tests.setBuildMode(mode);
    string_utilities_tests.setBuildMode(mode);
    slice_utilities_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
    test_step.dependOn(&growable_array_tests.step);
    test_step.dependOn(&zip_tests.step);
    test_step.dependOn(&string_utilities_tests.step);
    test_step.dependOn(&slice_utilities_tests.step);
}
