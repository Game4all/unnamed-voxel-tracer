const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "voxl",
        .root_source_file = b.path("src/main.zig"),
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

    const zmath = b.dependency("zmath", .{
        .target = target,
        .optimize = optimize,
    });

    const zaudio = b.dependency("zaudio", .{
        .target = target,
        .optimize = optimize,
    });

    const znoise = b.dependency("znoise", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zvox", zvox.module("zvox"));
    exe.root_module.addImport("mach_glfw", glfw.module("mach-glfw"));
    exe.root_module.addImport("zmath", zmath.module("root"));
    exe.root_module.addImport("zaudio", zaudio.module("root"));
    exe.root_module.addImport("znoise", znoise.module("root"));

    exe.linkLibrary(zaudio.artifact("miniaudio"));
    exe.linkLibrary(znoise.artifact("FastNoiseLite"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
