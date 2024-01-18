const glfw = @import("mach_glfw");
const app = @import("engine/app.zig");
const std = @import("std");

pub fn main() !void {
    _ = glfw.init(.{});
    defer glfw.terminate();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var application = try app.App.init(gpa.allocator());
    defer application.deinit();
    application.run();
}
