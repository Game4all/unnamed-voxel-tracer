const std = @import("std");
const glfw = @import("mach_glfw");
const gfx = @import("graphics/graphics.zig");

const vec4 = @import("math.zig").vec4;
const vec2 = @import("math.zig").vec2;
const clamp = @import("math.zig").clamp;

/// Camera uniform data.
const CameraData = extern struct {
    position: vec4,
    pitch_yaw: vec2,

    pub fn default() @This() {
        return .{ .position = vec4.from_xyzw(0.0, 2.0, -5.0, 0.0), .pitch_yaw = vec2.from_xy(0.0, 0.0) };
    }
};

pub const App = struct {
    window: glfw.Window,
    allocator: std.heap.GeneralPurposeAllocator(.{}),

    // gl stuff
    framebuffer: gfx.Framebuffer,
    pipeline: gfx.ComputePipeline,
    buffer: gfx.Buffer,
    buffer_ptr: *CameraData,

    /// input shit
    old_mouse_x: f64 = 0.0,
    old_mouse_y: f64 = 0.0,

    pub fn init() !App {
        const window = glfw.Window.create(1280, 720, "voxl", null, null, .{ .srgb_capable = true }) orelse @panic("Failed to open GLFW window.");
        try gfx.init(window);
        gfx.enableDebug();

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        errdefer _ = gpa.deinit();

        var frame = gfx.Framebuffer.init(1280, 720, gfx.TextureFormat.RGBA8);
        errdefer frame.deinit();

        const pipeline = try gfx.ComputePipeline.init(gpa.allocator(), "assets/shaders/test.comp");

        var buff = gfx.Buffer.init(gfx.BufferType.Uniform, @sizeOf(f32), gfx.BufferCreationFlags.MappableWrite | gfx.BufferCreationFlags.MappableRead | gfx.BufferCreationFlags.Persistent);
        var ptr: *CameraData = @alignCast(@ptrCast(buff.map(gfx.BufferMapFlags.Write | gfx.BufferMapFlags.Read | gfx.BufferCreationFlags.Persistent)));
        ptr.* = CameraData.default();

        return .{ .window = window, .allocator = gpa, .framebuffer = frame, .pipeline = pipeline, .buffer = buff, .buffer_ptr = ptr };
    }

    /// Called when the mouse is moved.
    pub fn on_mouse_moved(self: *@This(), xpos: f64, ypos: f64) void {
        const delta_x = xpos - self.old_mouse_x;
        const delta_y = ypos - self.old_mouse_y;

        const new_pitch = clamp(f32, self.buffer_ptr.*.pitch_yaw.elem(0) + @as(f32, @floatCast(delta_y)) * 0.001, -std.math.pi / 2.0, std.math.pi / 2.0);
        const new_yaw = self.buffer_ptr.*.pitch_yaw.elem(1) + @as(f32, @floatCast(delta_x)) * 0.001; //TODO: fix wrong yaw.

        self.buffer_ptr.*.pitch_yaw = vec2.from_xy(new_pitch, new_yaw);

        self.old_mouse_x = xpos;
        self.old_mouse_y = ypos;
    }

    /// Called upon window resize.
    pub fn on_resize(self: *@This(), width: u32, height: u32) void {
        gfx.resize(width, height);
        self.framebuffer.deinit();
        self.framebuffer = gfx.Framebuffer.init(width, height, gfx.TextureFormat.RGBA8);
    }

    /// Called upon key down.
    pub fn on_key_down(self: *@This(), key: glfw.Key, scancode: i32, mods: glfw.Mods) void {
        _ = scancode;
        switch (key) {
            .r => self.reloadShaders(),
            .w => {
                self.buffer_ptr.*.position = vec4.from_xyzw(0.0, 0.0, 0.1, 0.0).add(self.buffer_ptr.*.position);
            },
            .s => {
                self.buffer_ptr.*.position = vec4.from_xyzw(0.0, 0.0, -0.1, 0.0).add(self.buffer_ptr.*.position);
            },
            .a => {
                self.buffer_ptr.*.position = vec4.from_xyzw(-0.1, 0.0, 0.0, 0.0).add(self.buffer_ptr.*.position);
            },
            .d => {
                self.buffer_ptr.*.position = vec4.from_xyzw(0.1, 0.0, 0.0, 0.0).add(self.buffer_ptr.*.position);
            },
            .space => {
                self.buffer_ptr.*.position = vec4.from_xyzw(0.0, 0.1, 0.0, 0.0).add(self.buffer_ptr.*.position);
            },
            else => {
                if (mods.shift) {
                    self.buffer_ptr.*.position = vec4.from_xyzw(0.0, -0.1, 0.0, 0.0).add(self.buffer_ptr.*.position);
                }
            },
        }
    }

    /// Main app loop.
    pub fn run(self: *@This()) void {
        self.window.setUserPointer(self);

        self.window.setFramebufferSizeCallback((struct {
            pub fn handle_resize(window: glfw.Window, width: u32, height: u32) void {
                const app: *App = window.getUserPointer(App) orelse @panic("Failed to get user pointer.");
                app.on_resize(width, height);
            }
        }).handle_resize);

        self.window.setKeyCallback((struct {
            pub fn handle_key(window: glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) void {
                const app: *App = window.getUserPointer(App) orelse @panic("Failed to get user pointer.");
                if (action == .press or action == .repeat) {
                    app.on_key_down(key, scancode, mods);
                }
            }
        }).handle_key);

        self.window.setCursorPosCallback((struct {
            pub fn handle_mouse_move(window: glfw.Window, xpos: f64, ypos: f64) void {
                const app: *App = window.getUserPointer(App) orelse @panic("Failed to get user pointer.");
                app.on_mouse_moved(xpos, ypos);
            }
        }).handle_mouse_move);

        self.window.setInputModeCursor(glfw.Window.InputModeCursor.disabled);

        while (!self.window.shouldClose()) {
            glfw.pollEvents();
            // app logic
            self.update();
            // render
            self.draw();
            // swap buffers and poll events
            self.window.swapBuffers();
        }
    }

    pub fn update(self: *@This()) void {
        _ = self;
        // self.buffer_ptr.* = @floatCast(@sin(glfw.getTime()));
    }

    pub fn draw(self: *@This()) void {
        const wsize = self.window.getFramebufferSize();
        self.buffer.bind(1);
        self.framebuffer.clear(0.0, 0.0, 0.0, 0.0);
        self.framebuffer.color_attachment.bind_image(0, gfx.TextureUsage.Write, null);
        self.pipeline.bind();
        self.pipeline.dispatch(90, 80, 1);
        gfx.clear(0.0, 0.0, 0.0);
        self.framebuffer.blit_to_screen(0, 0, 0, 0, wsize.width, wsize.height);
    }

    /// Reloads the shaders.
    pub fn reloadShaders(self: *@This()) void {
        const pipeline = gfx.ComputePipeline.init(self.allocator.allocator(), "assets/shaders/test.comp") catch |err| {
            std.log.warn("Failed to reload shaders: {}\n", .{err});
            return;
        };
        self.pipeline.deinit();
        self.pipeline = pipeline;
        std.log.debug("Shaders reloaded", .{});
    }

    pub fn deinit(self: *@This()) void {
        self.framebuffer.deinit();
        self.window.destroy();
        _ = self.allocator.deinit();
    }
};
