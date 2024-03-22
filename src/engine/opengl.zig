const glfw = @import("glfw.zig");
const gfx = @import("graphics/graphics.zig");
const std = @import("std");

const Context = @import("context.zig").Context;

/// Provides an OpenGL based renderer.
pub const OpenGLRenderer = struct {
    pub const name = .renderer;
    pub const priority = .{
        .update = 0xFFFFFFF, // run rendering at the very end.
        .init = glfw.GLFWModule.priority.init + 1,
    };

    pub fn init(engine: *Context) void {
        const window = engine.mod(glfw.GLFWModule).window;
        gfx.init(window) catch |err| {
            std.log.err("Failed to initialize OpenGL renderer: {}", .{err});
            unreachable;
        };
        gfx.enableDebug();
    }

    pub fn update(engine: *Context) void {
        const window = engine.mod(glfw.GLFWModule).window;
        engine.signal(.pre_render, .{});
        engine.signal(.render, .{});
        engine.signal(.post_render, .{});
        window.swapBuffers();
    }
};
