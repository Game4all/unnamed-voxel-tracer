const glfw = @import("mach_glfw");
const app = @import("engine/app.zig");
const std = @import("std");

pub fn main() !void {
    _ = glfw.init(.{});
    defer glfw.terminate();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var application: app.App = undefined;
    try application.init(allocator);
    defer application.deinit();
    application.run();
}
