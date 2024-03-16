const std = @import("std");

const mach_glfw = @import("mach_glfw");
const zmath = @import("zmath");
const znoise = @import("znoise");
const zaudio = @import("zaudio");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "voxl",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // mach glfw dependency
    const glfw = b.dependency("mach_glfw", .{
        .target = target,
        .optimize = optimize,
    });

    // magicavoxel model loader
    const zvox = b.dependency("zvox", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zvox", zvox.module("zvox"));
    exe.root_module.addImport("mach_glfw", glfw.module("mach-glfw"));

    // zig-gamedev libs.
    const zmath_pkg = zmath.package(b, target, optimize, .{});
    zmath_pkg.link(exe);

    const znoise_pkg = znoise.package(b, target, optimize, .{});
    znoise_pkg.link(exe);

    const zaudio_pkg = zaudio.package(b, target, optimize, .{});
    zaudio_pkg.link(exe);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
