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

    /// Handle toggling fullscreen by pressing F11
    pub fn key_pressed(engine: *Context, key: glfw.mach_glfw.Key, _: glfw.mach_glfw.Mods) void {
        if (key == .F11) {
            const window = engine.mod(glfw.GLFWModule).window;
            const primary_mon = glfw.mach_glfw.Monitor.getPrimary() orelse @panic("Failed to get primary monitor ");
            const video_mode = primary_mon.getVideoMode() orelse @panic("Failed to get video mode");

            if (window.getMonitor()) |_| {
                window.setMonitor(null, @intCast(video_mode.getWidth() / 4), @intCast(video_mode.getHeight() / 4), video_mode.getWidth() / 2, video_mode.getHeight() / 2, video_mode.getRefreshRate());
            } else {
                window.setMonitor(primary_mon, 0, 0, video_mode.getWidth(), video_mode.getHeight(), video_mode.getRefreshRate());
            }
        }
    }
};
