pub const glfw = @import("zglfw");

const Window = glfw.Window;
const Key = glfw.Key;
const MouseButton = glfw.MouseButton;
const Action = glfw.Action;
const Mods = glfw.Mods;

const std = @import("std");

const Context = @import("context.zig").Context;

/// Provides windowing and input with the GLFW library.
pub const GLFWModule = struct {
    pub const name = .glfw;
    pub const priority = .{
        .init = std.math.minInt(isize),
        .deinit = std.math.maxInt(isize),
        // glfw should always pump events first thing in the frame.
        .update = std.math.minInt(isize),
    };

    window: *Window,

    pub fn update(engine: *Context) void {
        glfw.pollEvents();

        if (engine.mod(@This()).window.shouldClose()) {
            engine.ctx.engine.execution_state = .stopping;
        }
    }

    pub fn init(engine: *Context) void {
        glfw.init() catch @panic("Failed to init GLFW");

        engine.ctx.glfw.window = Window.create(1280, 720, "voxelite", null) catch @panic("Failed to create GLFW window.");
        engine.ctx.glfw.window.setUserPointer(engine);

        _ = engine.ctx.glfw.window.setFramebufferSizeCallback((struct {
            pub fn handle_resize(window: *Window, width: c_int, height: c_int) callconv(.c) void {
                const app = window.getUserPointer(Context) orelse @panic("Failed to get user pointer.");
                app.signal(.window_resized, .{ @as(u32, @intCast(width)), @as(u32, @intCast(height)) });
            }
        }).handle_resize);

        _ = engine.ctx.glfw.window.setKeyCallback((struct {
            pub fn handle_key(window: *Window, key: Key, scancode: c_int, action: Action, mods: Mods) callconv(.c) void {
                _ = scancode;
                const app = window.getUserPointer(Context) orelse @panic("Failed to get user pointer.");

                if (key == .unknown)
                    return;

                if (action == .press)
                    app.signal(.key_pressed, .{ key, mods });
                if (action == .release)
                    app.signal(.key_released, .{ key, mods });
            }
        }).handle_key);

        _ = engine.ctx.glfw.window.setMouseButtonCallback((struct {
            pub fn handle_mouse_click(window: *Window, button: MouseButton, action: Action, mods: Mods) callconv(.c) void {
                const app = window.getUserPointer(Context) orelse @panic("Failed to get user pointer.");

                if (action == .press)
                    app.signal(.mouse_pressed, .{ button, mods });

                if (action == .release)
                    app.signal(.mouse_released, .{ button, mods });
            }
        }).handle_mouse_click);

        _ = engine.ctx.glfw.window.setCursorPosCallback((struct {
            pub fn handle_mouse_move(window: *Window, xpos: f64, ypos: f64) callconv(.c) void {
                const app = window.getUserPointer(Context) orelse @panic("Failed to get user pointer.");
                app.signal(.mouse_moved, .{ xpos, ypos });
            }
        }).handle_mouse_move);
    }

    pub fn deinit(engine: *Context) void {
        engine.ctx.glfw.window.destroy();
        glfw.terminate();
    }
};
