const std = @import("std");
const glfw = @import("mach_glfw");
const gfx = @import("graphics/graphics.zig");
const voxel = @import("voxel.zig");
const procgen = @import("procgen.zig").procgen;
const dotvox = @import("dotvox.zig");
const input = @import("input.zig");

const GBuffer = @import("gbuffer.zig").GBuffer;

const zmath = @import("zmath");
const clamp = zmath.clamp;

/// Camera uniform data.
const CameraData = extern struct {
    position: zmath.F32x4,
    matrix: zmath.Mat,
    sun_pos: zmath.F32x4,
    fov: f32,
    frame: u32,
    accum: u32,
};

const PlayerAction = enum { Forward, Backward, Right, Left, Up, Down };

pub const App = @This();

window: glfw.Window,
allocator: std.heap.GeneralPurposeAllocator(.{}),

// pipeline images
// trace_image: gfx.Texture,
// trace_normal: gfx.Texture,
gbuffer: GBuffer,

// pipelines
trace_pipeline: gfx.ComputePipeline,
raster_pipeline: gfx.RasterPipeline,
uniforms: gfx.PersistentMappedBuffer,

// rendering scale
scale_factor: f32 = 1.0,

// voxel map
voxels: voxel.VoxelBrickmap(512, 8),
models: voxel.VoxelMapPalette(8),

/// camera
old_mouse_x: f64 = 0.0,
old_mouse_y: f64 = 0.0,
fov: f32 = std.math.pi / 2.0,

position: zmath.F32x4 = zmath.f32x4(256.0, 22.0, 256.0, 0.0),

pitch: f32 = 0.0,
yaw: f32 = 0.0,
cam_mat: zmath.Mat = zmath.identity(),

// time
do_daynight_cycle: bool = true,

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

    var gbuff = GBuffer.init(1280, 720);
    errdefer gbuff.deinit();

    const uniforms = gfx.PersistentMappedBuffer.init(gfx.BufferType.Uniform, @sizeOf(CameraData), gfx.BufferCreationFlags.MappableWrite | gfx.BufferCreationFlags.MappableRead);

    var voxels = voxel.VoxelBrickmap(512, 8).init(0);
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
        .gbuffer = gbuff,
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
    self.uniforms.get_ptr(CameraData).*.accum = 1;
}

/// basic AF player controller system
pub fn update_physics(self: *@This()) void {
    var velocity = zmath.f32x4(0.0, 0.0, 0.0, 0.0);
    var moved = false;

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

    moved = moved or std.simd.countTrues(velocity != zmath.f32x4(0.0, 0.0, 0.0, 0.0)) > 0;

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
    if (self.voxels.is_walkable(@intFromFloat(flafterGrav[0]), @intFromFloat(flafterGrav[1]), @intFromFloat(flafterGrav[2]))) {
        finalPos = afterGrav;
        moved = true;
    }

    if (moved) {
        self.uniforms.get_ptr(CameraData).*.accum = 1;
    }

    self.position = finalPos;
}

/// Called upon window resize.
pub fn on_resize(self: *@This(), width: u32, height: u32) void {
    gfx.resize(width, height);

    const nwidth: u32 = @intFromFloat(@as(f32, @floatFromInt(width)) * self.scale_factor);
    const nheight: u32 = @intFromFloat(@as(f32, @floatFromInt(height)) * self.scale_factor);

    self.gbuffer.resize(nwidth, nheight);
}

/// Called upon key down.
pub fn on_key_down(self: *@This(), key: glfw.Key, scancode: i32, mods: glfw.Mods, action: glfw.Action) void {
    _ = mods;
    _ = scancode;

    const action_key: PlayerAction = switch (key) {
        .r => {
            self.reloadShaders();
            return;
        },
        .F2, .F3 => {
            if (key == .F2 and action == .press) {
                self.scale_factor = @min(@max(self.scale_factor - 0.25, 0.25), 1.0);
            } else if (key == .F3 and action == .press) {
                self.scale_factor = @min(@max(self.scale_factor + 0.25, 0.25), 1.0);
            }

            const size = self.window.getSize();
            self.on_resize(size.width, size.height);
            std.log.info("Render scale is now: {}x", .{self.scale_factor});

            return;
        },
        .c => {
            if (action == .press) {
                self.do_daynight_cycle = !self.do_daynight_cycle;
                std.log.info("Day-night cycles : {}", .{self.do_daynight_cycle});
            }
            return;
        },
        .w => .Forward,
        .s => .Backward,
        .a => .Left,
        .d => .Right,
        .space => .Up,
        .left_shift => .Down,
        else => return,
    };

    if (action == .press) {
        self.actions.press(action_key);
    } else if (action == .release) {
        self.actions.release(action_key);
    }
}

pub fn on_scroll(self: *@This(), xoffset: f64, yoffset: f64) void {
    _ = xoffset;
    self.fov = clamp(self.fov + @as(f32, @floatCast(yoffset)) * 0.1, 0.314, 2.4);
    self.uniforms.get_ptr(CameraData).*.accum = 1;
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

    self.window.setScrollCallback((struct {
        pub fn handle_scroll(window: glfw.Window, xoffset: f64, yoffset: f64) void {
            const app: *App = window.getUserPointer(App) orelse @panic("Failed to get user pointer.");
            app.on_scroll(xoffset, yoffset);
        }
    }).handle_scroll);

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
    self.update_physics();

    const camera_data = self.uniforms.get_ptr(CameraData);
    const time: f64 = glfw.getTime();

    camera_data.matrix = self.cam_mat;
    if (self.do_daynight_cycle)
        camera_data.sun_pos = zmath.f32x4(@floatCast(@cos(time)), @floatCast(@sin(time)), 0.0, 0.0);

    camera_data.position = self.position + zmath.f32x4(0.0, 3.0, 0.0, 0.0);
    camera_data.fov = self.fov;
    camera_data.frame = camera_data.frame + 1;
    camera_data.accum = camera_data.accum + 1;

    self.actions.update();
}

pub fn draw(self: *@This()) void {
    self.uniforms.bind(8);
    self.voxels.bind(9);
    self.models.bind(11);

    self.gbuffer.bind_images(0);
    self.trace_pipeline.bind();

    const workgroup_size_x = @divFloor(self.gbuffer.albedo.width, 32) + 1;
    const workgroup_size_y = @divFloor(self.gbuffer.albedo.height, 32) + 1;
    self.trace_pipeline.dispatch(workgroup_size_x, workgroup_size_y, 1);

    gfx.clear(0.0, 0.0, 0.0);

    self.gbuffer.bind_textures(0);

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
    self.gbuffer.deinit();
    self.window.destroy();
    self.models.deinit(self.allocator.allocator());
    _ = self.allocator.deinit();
}
