const glfw = @import("mach_glfw");
const app = @import("engine/app.zig");

pub fn main() !void {
    _ = glfw.init(.{});
    defer glfw.terminate();

    var application = try app.App.init();
    defer application.deinit();
    application.run();
}
