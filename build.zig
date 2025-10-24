const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the library module
    const result_module = b.addModule("result", .{
        .root_source_file = b.path("src/result.zig"),
    });

    // Tests
    const lib_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/result.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Examples
    const example = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/basic.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    example.root_module.addImport("result", result_module);

    const install_example = b.addInstallArtifact(example, .{});
    const example_step = b.step("example", "Build and install example");
    example_step.dependOn(&install_example.step);

    const run_example = b.addRunArtifact(example);
    const run_example_step = b.step("run-example", "Run the example");
    run_example_step.dependOn(&run_example.step);
}
