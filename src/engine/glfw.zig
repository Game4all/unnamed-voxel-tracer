pub const mach_glfw = @import("mach_glfw");

const Window = mach_glfw.Window;
const Key = mach_glfw.Key;
const MouseButton = mach_glfw.MouseButton;
const Action = mach_glfw.Action;
const Mods = mach_glfw.Mods;

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

    window: Window,

    pub fn update(engine: *Context) void {
        mach_glfw.pollEvents();

        if (engine.mod(@This()).window.shouldClose()) {
            engine.ctx.engine.execution_state = .stopping;
        }
    }

    pub fn init(engine: *Context) void {
        if (!mach_glfw.init(.{}))
            @panic("Failed to init GLFW");

        engine.ctx.glfw.window = Window.create(1280, 720, "voxelite", null, null, .{}) orelse @panic("Failed to create GLFW window.");
        engine.ctx.glfw.window.setUserPointer(engine);

        engine.ctx.glfw.window.setFramebufferSizeCallback((struct {
            pub fn handle_resize(window: Window, width: u32, height: u32) void {
                const app = window.getUserPointer(Context) orelse @panic("Failed to get user pointer.");
                app.signal(.window_resized, .{ width, height });
            }
        }).handle_resize);

        engine.ctx.glfw.window.setKeyCallback((struct {
            pub fn handle_key(window: Window, key: Key, scancode: i32, action: Action, mods: Mods) void {
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

        engine.ctx.glfw.window.setMouseButtonCallback((struct {
            pub fn handle_mouse_click(window: Window, button: MouseButton, action: Action, mods: Mods) void {
                const app = window.getUserPointer(Context) orelse @panic("Failed to get user pointer.");

                if (action == .press)
                    app.signal(.mouse_pressed, .{ button, mods });

                if (action == .release)
                    app.signal(.mouse_released, .{ button, mods });
            }
        }).handle_mouse_click);

        engine.ctx.glfw.window.setCursorPosCallback((struct {
            pub fn handle_mouse_move(window: Window, xpos: f64, ypos: f64) void {
                const app = window.getUserPointer(Context) orelse @panic("Failed to get user pointer.");
                app.signal(.mouse_moved, .{ xpos, ypos });
            }
        }).handle_mouse_move);
    }

    pub fn deinit(engine: *Context) void {
        engine.ctx.glfw.window.destroy();
        mach_glfw.terminate();
    }
};
