const std = @import("std");
const zmath = @import("zig-gamedev/libs/zmath/build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "voxl",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // mach glfw dependency
    const glfw = b.dependency("mach_glfw", .{
        .target = target,
        .optimize = optimize,
    });

    exe.addModule("mach_glfw", glfw.module("mach-glfw"));
    @import("mach_glfw").link(glfw.builder, exe);

    // math library dependency

    const zmath_pkg = zmath.package(b, target, optimize, .{});
    zmath_pkg.link(exe);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // // tests

    // const tests = b.addTest(.{
    //     .name = "math",
    //     .root_source_file = .{ .path = "src/engine/math.zig" },
    // });

    // const test_run_step = b.step("test", "Run the tests");
    // test_run_step.dependOn(&tests.step);
}
