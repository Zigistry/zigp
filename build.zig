const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ansi_module = b.addModule("ansi", .{
        .root_source_file = .{ .cwd_relative = "src/libs/ansi_codes.zig" },
        .target = target,
        .optimize = optimize,
    });

    const search_module = b.addModule("search", .{
        .root_source_file = .{ .cwd_relative = "src/packages/search.zig" },
        .target = target,
        .optimize = optimize,
    });

    search_module.addImport("ansi", ansi_module);

    const main_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    main_module.addImport("search", search_module);
    main_module.addImport("ansi", ansi_module);

    const exe = b.addExecutable(.{
        .name = "zigp",
        .root_module = main_module,
    });

    exe.linkLibC();

    b.installArtifact(exe);

    const search_test_module = b.addModule("search-tests", .{ .root_source_file = .{ .cwd_relative = "tests/search_test.zig" }, .target = target, .optimize = optimize });
    search_test_module.addImport("search", search_module);

    const search_tests = b.addTest(.{
        .root_module = search_test_module,
    });

    const run_search_tests = b.addRunArtifact(search_tests);

    // Test steps
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_search_tests.step);

    const search_test_step = b.step("test-search", "Run search tests only");
    search_test_step.dependOn(&run_search_tests.step);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
