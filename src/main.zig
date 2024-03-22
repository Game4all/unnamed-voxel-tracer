const glfw = @import("engine/glfw.zig");
const input = @import("engine/input.zig");
const game = @import("engine/game.zig").Game;
const std = @import("std");

const App = @import("engine/context.zig").App;

pub const modules = &[_]type{
    input.InputState,
    glfw.GLFWModule,
    game.Game,
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
