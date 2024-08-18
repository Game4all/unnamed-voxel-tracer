const glfw = @import("glfw.zig");
const gfx = @import("graphics/graphics.zig");
const std = @import("std");

const Context = @import("context.zig").Context;
const EngineBase = @import("context.zig").EngineBaseState;

pub const GlobalUniforms = extern struct {
    // current time.
    time: f32,
    // delta time since last frame.
    delta_time: f32,
};

/// Provides an OpenGL based renderer.
pub const OpenGLRenderer = struct {
    pub const name = .renderer;
    pub const priority = .{
        .update = std.math.maxInt(isize), // run rendering at the very end.
        .init = glfw.GLFWModule.priority.init + 1,
    };

    global_uniforms: gfx.PersistentMappedBuffer(GlobalUniforms),

    pub fn init(engine: *Context) void {
        const window = engine.mod(glfw.GLFWModule).window;
        gfx.init(window) catch |err| {
            std.log.err("Failed to initialize OpenGL renderer: {}", .{err});
            unreachable;
        };
        gfx.enableDebug();

        engine.mod(@This()).global_uniforms = gfx.PersistentMappedBuffer(GlobalUniforms).init(.Uniform, @sizeOf(GlobalUniforms), gfx.BufferCreationFlags.MappableWrite | gfx.BufferCreationFlags.MappableRead);
    }

    //Update the global uniforms
    pub fn pre_render(engine: *Context) void {
        const uniforms = &engine.mod(@This()).global_uniforms;
        const engine_base = engine.mod(EngineBase);
        const time = engine_base.last_update;

        const seconds: f32 = @as(f32, @floatFromInt(time.since(time))) / @as(f32, @floatFromInt(std.time.ns_per_s));

        uniforms.deref().* = .{
            .time = seconds,
            .delta_time = @floatCast(engine_base.delta_seconds),
        };
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
