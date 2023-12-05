const std = @import("std");
const glfw = @import("mach_glfw");
const gfx = @import("graphics/graphics.zig");
const voxel = @import("voxel.zig");
const procgen = @import("procgen.zig").procgen;
const dotvox = @import("dotvox.zig");
const input = @import("input.zig");

const zmath = @import("zmath");
const clamp = zmath.clamp;

/// Camera uniform data.
const CameraData = extern struct {
    position: zmath.F32x4,
    matrix: zmath.Mat,
    sun_pos: zmath.F32x4,
};

const PlayerAction = enum { Forward, Backward, Right, Left, Up, Down };

pub const App = @This();

window: glfw.Window,
allocator: std.heap.GeneralPurposeAllocator(.{}),

// pipeline images
trace_image: gfx.Texture,
trace_normals: gfx.Texture,
trace_positions: gfx.Texture,

// pipelines
trace_pipeline: gfx.ComputePipeline,
raster_pipeline: gfx.RasterPipeline,
uniforms: gfx.PersistentMappedBuffer,

// voxel map
voxels: voxel.VoxelMap(512, 8),
models: voxel.VoxelMapPalette(8),

/// camera
old_mouse_x: f64 = 0.0,
old_mouse_y: f64 = 0.0,

position: zmath.F32x4 = zmath.f32x4(256.0, 128.0, 256.0, 0.0),

pitch: f32 = 0.0,
yaw: f32 = 0.0,
cam_mat: zmath.Mat = zmath.identity(),

// input
actions: input.Input(PlayerAction) = .{},

pub fn init() !App {
    const window = glfw.Window.create(1280, 720, "voxl", null, null, .{ .srgb_capable = true }) orelse @panic("Failed to open GLFW window.");
    try gfx.init(window);
    gfx.enableDebug();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    errdefer _ = gpa.deinit();

    const trace_pipeline = try gfx.ComputePipeline.init(gpa.allocator(), "assets/shaders/trace.comp.glsl");
    errdefer trace_pipeline.deinit();
    const raster_pipeline = try gfx.RasterPipeline.init(gpa.allocator(), "assets/shaders/blit.vertex.glsl", "assets/shaders/blit.fragment.glsl");
    errdefer raster_pipeline.deinit();

    var trace_image = gfx.Texture.init(.Texture2D, .RGBA8, 1280, 720, 0);
    errdefer trace_image.deinit();

    var trace_normals = gfx.Texture.init(.Texture2D, .RGBA8, 1280, 720, 0);
    errdefer trace_normals.deinit();

    var trace_positions = gfx.Texture.init(.Texture2D, .RGBA32F, 1280, 720, 0);
    errdefer trace_positions.deinit();

    const uniforms = gfx.PersistentMappedBuffer.init(gfx.BufferType.Uniform, @sizeOf(CameraData), gfx.BufferCreationFlags.MappableWrite | gfx.BufferCreationFlags.MappableRead);

    var voxels = voxel.VoxelMap(512, 8).init(0);
    procgen(512, &voxels, 0.0, 0.0);

    var models = voxel.VoxelMapPalette(8).init();

    try models.load_model("assets/grass.vox", gpa.allocator());
    try models.load_model("assets/grass2.vox", gpa.allocator());
    try models.load_model("assets/grass3.vox", gpa.allocator());
    try models.load_model("assets/grass4.vox", gpa.allocator());
    try models.load_model("assets/grass5.vox", gpa.allocator());
    try models.load_model("assets/rock.vox", gpa.allocator());
    try models.load_model("assets/flower.vox", gpa.allocator());
    try models.load_model("assets/flower_pot.vox", gpa.allocator());

    return .{
        .window = window,
        .allocator = gpa,
        .trace_pipeline = trace_pipeline,
        .raster_pipeline = raster_pipeline,
        .trace_image = trace_image,
        .trace_normals = trace_normals,
        .trace_positions = trace_positions,
        .uniforms = uniforms,
        .voxels = voxels,
        .models = models,
    };
}

/// Called when the mouse is moved.
pub fn on_mouse_moved(self: *@This(), xpos: f64, ypos: f64) void {
    const delta_x = xpos - self.old_mouse_x;
    const delta_y = ypos - self.old_mouse_y;

    self.pitch = clamp(self.pitch + @as(f32, @floatCast(delta_y)) * 0.001, -std.math.pi / 2.0, std.math.pi / 2.0);
    self.yaw = self.yaw + @as(f32, @floatCast(delta_x)) * 0.001;

    self.cam_mat = zmath.matFromRollPitchYaw(self.pitch, self.yaw, 0.0);

    self.old_mouse_x = xpos;
    self.old_mouse_y = ypos;
}

/// basic AF player controller system
pub fn update_physics(self: *@This()) void {
    var velocity = zmath.f32x4(0.0, 0.0, 0.0, 0.0);

    if (self.actions.is_pressed(.Forward)) {
        velocity = velocity + zmath.mul(zmath.f32x4(0.0, 0.0, 1.0, 0.0), self.cam_mat) * zmath.f32x4(1.0, 0.0, 1.0, 0.0);
    }

    if (self.actions.is_pressed(.Backward)) {
        velocity = velocity - zmath.mul(zmath.f32x4(0.0, 0.0, 1.0, 0.0), self.cam_mat) * zmath.f32x4(1.0, 0.0, 1.0, 0.0);
    }

    if (self.actions.is_pressed(.Right)) {
        velocity = velocity + zmath.mul(zmath.f32x4(1.0, 0.0, 0.0, 0.0), self.cam_mat) * zmath.f32x4(1.0, 0.0, 1.0, 0.0);
    }

    if (self.actions.is_pressed(.Left)) {
        velocity = velocity - zmath.mul(zmath.f32x4(1.0, 0.0, 0.0, 0.0), self.cam_mat) * zmath.f32x4(1.0, 0.0, 1.0, 0.0);
    }

    if (self.actions.is_pressed(.Up)) {
        velocity = velocity + zmath.f32x4(0.0, 1.6, 0.0, 0.0);
    }

    if (self.actions.is_pressed(.Down)) {
        velocity = velocity - zmath.f32x4(0.0, 1.0, 0.0, 0.0);
    }

    const gravity = zmath.f32x4(0.0, -0.2, 0.0, 0.0);
    var finalPos = self.position + velocity * @as(@Vector(4, f32), @splat(0.2));
    const flooredPos = zmath.floor(finalPos);

    // direction
    if (!self.voxels.is_walkable(@intFromFloat(flooredPos[0]), @intFromFloat(flooredPos[1]), @intFromFloat(flooredPos[2]))) {
        if (self.voxels.is_walkable(@intFromFloat(flooredPos[0]), @intFromFloat(flooredPos[1] + 1), @intFromFloat(flooredPos[2]))) {
            finalPos = self.position + zmath.f32x4(0.0, 1.6, 0.0, 0.0);
        } else {
            finalPos = self.position;
        }
    }

    // gravity
    const afterGrav = finalPos + gravity;
    const flafterGrav = zmath.floor(afterGrav);
    if (self.voxels.get(@intFromFloat(flafterGrav[0]), @intFromFloat(flafterGrav[1]), @intFromFloat(flafterGrav[2])) == 0) {
        finalPos = afterGrav;
    }

    self.uniforms.get(CameraData).*.position = finalPos + zmath.f32x4(0.0, 4.0, 0.0, 0.0);
    self.position = finalPos;
}

/// Called upon window resize.
pub fn on_resize(self: *@This(), width: u32, height: u32) void {
    gfx.resize(width, height);

    self.trace_image.deinit();
    self.trace_image = gfx.Texture.init(.Texture2D, .RGBA8, width, height, 0);

    self.trace_normals.deinit();
    self.trace_normals = gfx.Texture.init(.Texture2D, .RGBA8, width, height, 0);

    self.trace_positions.deinit();
    self.trace_positions = gfx.Texture.init(.Texture2D, .RGBA32F, width, height, 0);
}

/// Called upon key down.
pub fn on_key_down(self: *@This(), key: glfw.Key, scancode: i32, mods: glfw.Mods, action: glfw.Action) void {
    _ = mods;
    _ = scancode;
    switch (key) {
        .r => self.reloadShaders(),
        // camera controls
        .w => {
            if (action == .press) {
                self.actions.press(.Forward);
            } else if (action == .release) {
                self.actions.release(.Forward);
            }
        },
        .s => {
            if (action == .press) {
                self.actions.press(.Backward);
            } else if (action == .release) {
                self.actions.release(.Backward);
            }
        },
        .a => {
            if (action == .press) {
                self.actions.press(.Left);
            } else if (action == .release) {
                self.actions.release(.Left);
            }
        },
        .d => {
            if (action == .press) {
                self.actions.press(.Right);
            } else if (action == .release) {
                self.actions.release(.Right);
            }
        },
        .space => {
            if (action == .press) {
                self.actions.press(.Up);
            } else if (action == .release) {
                self.actions.release(.Up);
            }
        },
        .left_shift => {
            if (action == .press) {
                self.actions.press(.Down);
            } else if (action == .release) {
                self.actions.release(.Down);
            }
        },
        else => {},
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
            if (action == .press or action == .release) {
                app.on_key_down(key, scancode, mods, action);
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
    self.uniforms.get(CameraData).*.matrix = self.cam_mat;
    self.uniforms.get(CameraData).*.sun_pos = zmath.f32x4(400.0, 400.0, 400.0, 0.0);
    self.update_physics();
    self.actions.update();
}

pub fn draw(self: *@This()) void {
    self.uniforms.bind(8);
    self.voxels.bind(9);
    self.models.bind(11);

    self.trace_image.bind_image(0, .Write, null);
    self.trace_normals.bind_image(1, .Write, null);
    self.trace_positions.bind_image(2, .Write, null);
    self.trace_pipeline.bind();
    self.trace_pipeline.dispatch(90, 80, 1);

    gfx.clear(0.0, 0.0, 0.0);

    self.trace_image.bind(0);
    self.trace_normals.bind(1);
    self.trace_positions.bind(2);
    self.raster_pipeline.bind();
    self.raster_pipeline.draw(4);
}

/// Reloads the shaders.
pub fn reloadShaders(self: *@This()) void {
    const trace_pipeline = gfx.ComputePipeline.init(self.allocator.allocator(), "assets/shaders/trace.comp.glsl") catch |err| {
        std.log.warn("Failed to reload shaders: {}\n", .{err});
        return;
    };
    const blit_pipeline = gfx.RasterPipeline.init(self.allocator.allocator(), "assets/shaders/blit.vertex.glsl", "assets/shaders/blit.fragment.glsl") catch |err| {
        std.log.warn("Failed to reload shaders: {}\n", .{err});
        return;
    };

    self.trace_pipeline.deinit();
    self.trace_pipeline = trace_pipeline;

    self.raster_pipeline.deinit();
    self.raster_pipeline = blit_pipeline;

    std.log.debug("Shaders reloaded", .{});
}

pub fn deinit(self: *@This()) void {
    self.trace_image.deinit();
    self.window.destroy();
    self.models.deinit(self.allocator.allocator());
    _ = self.allocator.deinit();
}
