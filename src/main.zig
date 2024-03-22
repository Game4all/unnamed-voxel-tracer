const glfw = @import("engine/glfw.zig");

const app = @import("engine/app.zig");
const std = @import("std");

const App = @import("engine/context.zig").App;

const input = @import("engine/input.zig");

pub const modules = &[_]type{
    input.InputState,
    glfw.GLFWModule,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var application: App = undefined;
    application.init(allocator);
    defer application.deinit();
    application.run();

    // var application: app.App = undefined;
    // try application.init(allocator);
    // defer application.deinit();
    // application.run();
}
