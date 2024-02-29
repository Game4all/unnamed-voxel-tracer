const std = @import("std");
const glfw = @import("mach_glfw");
const gfx = @import("graphics/graphics.zig");
const voxel = @import("voxel.zig");
const procgen = @import("procgen.zig").procgen;
const input = @import("input.zig");
const zaudio = @import("zaudio");
const zmath = @import("zmath");

/// Camera uniform data.
const CameraData = extern struct {
    position: zmath.F32x4,
    matrix: zmath.Mat,
    sun_pos: zmath.F32x4,
    fov: f32,
    frame: u32,
    accum: u32,
};

pub const App = @This();

window: glfw.Window,
allocator: std.mem.Allocator,

// pipeline images
gbuffer: gfx.GBuffer,

// pipelines
primary_trace_pipeline: gfx.ComputePipeline,
secondary_trace_pipeline: gfx.ComputePipeline,
raster_pipeline: gfx.RasterPipeline,
uniforms: gfx.PersistentMappedBuffer,

// rendering scale
scale_factor: f32 = 1.0,

// voxel map
voxels: voxel.VoxelBrickmap(512, 8),
models: voxel.VoxelModelAtlas,

/// camera
cam: gfx.Camera = .{},
old_mouse_x: f64 = 0.0,
old_mouse_y: f64 = 0.0,

// player position
position: zmath.F32x4 = zmath.f32x4(256.0, 22.0, 256.0, 0.0),
no_clip: bool = false,

// time
do_daynight_cycle: bool = true,

// input
actions: input.PlayerInput = .{},

// audio
audio_engine: *zaudio.Engine,
ambient_sound: *zaudio.Sound,
walking_sound: *zaudio.Sound,

pub fn init(allocator: std.mem.Allocator) !App {
    const window = glfw.Window.create(1280, 720, "voxl", null, null, .{ .srgb_capable = true }) orelse @panic("Failed to open GLFW window.");
    try gfx.init(window);
    gfx.enableDebug();

    zaudio.init(allocator);
    errdefer zaudio.deinit();

    const audio_engine = try zaudio.Engine.create(null);
    errdefer audio_engine.destroy();

    // ambient bird sounds
    const ambient_sound = try audio_engine.createSoundFromFile("assets/sounds/ambient1.mp3", .{
        .flags = .{
            .stream = true,
            .no_pitch = true,
        },
    });
    errdefer ambient_sound.destroy();
    ambient_sound.setLooping(true);
    try ambient_sound.start();

    const walking_sound = try audio_engine.createSoundFromFile("assets/sounds/footstep.mp3", .{
        .flags = .{
            .stream = true,
            .no_pitch = true,
        },
    });
    errdefer walking_sound.destroy();
    walking_sound.setLooping(true);

    const primary_trace_pipeline = try gfx.ComputePipeline.init(allocator, "assets/shaders/primary.comp.glsl");
    errdefer primary_trace_pipeline.deinit();

    const secondary_trace_pipeline = try gfx.ComputePipeline.init(allocator, "assets/shaders/secondary.comp.glsl");
    errdefer secondary_trace_pipeline.deinit();

    const raster_pipeline = try gfx.RasterPipeline.init(allocator, "assets/shaders/blit.vertex.glsl", "assets/shaders/blit.fragment.glsl");
    errdefer raster_pipeline.deinit();

    var gbuff = gfx.GBuffer.init(1280, 720);
    errdefer gbuff.deinit();

    const uniforms = gfx.PersistentMappedBuffer.init(gfx.BufferType.Uniform, @sizeOf(CameraData), gfx.BufferCreationFlags.MappableWrite | gfx.BufferCreationFlags.MappableRead);

    var voxels = voxel.VoxelBrickmap(512, 8).init(0);
    procgen(512, &voxels, 0.0, 0.0);

    var models = voxel.VoxelModelAtlas.init();

    try models.load_block_model("assets/models.vox", allocator);
    try models.load_block_model("assets/grass.vox", allocator);
    try models.load_block_model("assets/grass2.vox", allocator);
    try models.load_block_model("assets/grass3.vox", allocator);
    try models.load_block_model("assets/grass4.vox", allocator);
    try models.load_block_model("assets/grass5.vox", allocator);
    try models.load_block_model("assets/rock.vox", allocator);
    try models.load_block_model("assets/flower.vox", allocator);
    try models.load_block_model("assets/water.vox", allocator);
    try models.load_block_model("assets/tree.vox", allocator);
    try models.load_block_model("assets/leaves.vox", allocator);
    try models.load_block_model("assets/dirt.vox", allocator);
    try models.load_block_model("assets/sand.vox", allocator);
    // try models.load_model("assets/chicken.vox", allocator, 32);
    // try models.load_model("assets/flower_pot.vox", allocator);

    return .{
        .window = window,
        .allocator = allocator,
        .primary_trace_pipeline = primary_trace_pipeline,
        .secondary_trace_pipeline = secondary_trace_pipeline,
        .raster_pipeline = raster_pipeline,
        .audio_engine = audio_engine,
        .ambient_sound = ambient_sound,
        .walking_sound = walking_sound,
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

    self.cam.rotate(@floatCast(delta_y), @floatCast(delta_x));

    self.old_mouse_x = xpos;
    self.old_mouse_y = ypos;
    self.uniforms.get_ptr(CameraData).*.accum = 1;
}

/// basic AF player controller system
pub fn update_physics(self: *@This()) void {
    var velocity = zmath.f32x4(0.0, 0.0, 0.0, 0.0);
    var moved = false;

    if (self.actions.is_pressed(.Forward)) {
        velocity = velocity + zmath.mul(zmath.f32x4(0.0, 0.0, 1.0, 0.0), self.cam.camera_mat()) * zmath.f32x4(1.0, 0.0, 1.0, 0.0);
    }

    if (self.actions.is_pressed(.Backward)) {
        velocity = velocity - zmath.mul(zmath.f32x4(0.0, 0.0, 1.0, 0.0), self.cam.camera_mat()) * zmath.f32x4(1.0, 0.0, 1.0, 0.0);
    }

    if (self.actions.is_pressed(.Right)) {
        velocity = velocity + zmath.mul(zmath.f32x4(1.0, 0.0, 0.0, 0.0), self.cam.camera_mat()) * zmath.f32x4(1.0, 0.0, 1.0, 0.0);
    }

    if (self.actions.is_pressed(.Left)) {
        velocity = velocity - zmath.mul(zmath.f32x4(1.0, 0.0, 0.0, 0.0), self.cam.camera_mat()) * zmath.f32x4(1.0, 0.0, 1.0, 0.0);
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
    if (self.voxels.is_walkable(@intFromFloat(flafterGrav[0]), @intFromFloat(flafterGrav[1]), @intFromFloat(flafterGrav[2])) and !self.no_clip) {
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

    const action_key: input.PlayerAction = switch (key) {
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
        .F11 => {
            if (action == .press) {
                const primary_mon = glfw.Monitor.getPrimary() orelse @panic("Failed to get primary monitor ");
                const video_mode = primary_mon.getVideoMode() orelse @panic("Failed to get video mode");

                if (self.window.getMonitor()) |_| {
                    self.window.setMonitor(null, @intCast(video_mode.getWidth() / 4), @intCast(video_mode.getHeight() / 4), video_mode.getWidth() / 2, video_mode.getHeight() / 2, video_mode.getRefreshRate());
                } else {
                    self.window.setMonitor(primary_mon, 0, 0, video_mode.getWidth(), video_mode.getHeight(), video_mode.getRefreshRate());
                }
            }

            return;
        },
        .c => {
            if (action == .press) {
                self.do_daynight_cycle = !self.do_daynight_cycle;
                std.log.info("Day-night cycles : {}", .{self.do_daynight_cycle});
            }
            return;
        },
        .f => {
            if (action == .press)
                self.no_clip = !self.no_clip;

            std.log.info("Noclip : {}", .{self.no_clip});
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
    self.cam.incrementFov(@floatCast(yoffset));
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

    camera_data.matrix = self.cam.camera_mat();
    camera_data.sun_pos = zmath.f32x4(7.52185881e-01, 6.58950984e-01, 7.52185881e-01, 0.0e+00);

    camera_data.position = self.position + zmath.f32x4(0.0, 3.0, 0.0, 0.0);
    camera_data.fov = self.cam.fov;
    camera_data.frame = camera_data.frame + 1;
    camera_data.accum = camera_data.accum + 1;

    if (self.actions.any_pressed() and !self.actions.is_pressed(.Up)) {
        if (!self.walking_sound.isPlaying())
            self.walking_sound.start() catch unreachable;
    } else {
        if (self.walking_sound.isPlaying())
            self.walking_sound.stop() catch unreachable;
    }

    self.actions.update();
}

pub fn draw(self: *@This()) void {
    self.uniforms.bind(8);
    self.voxels.bind(9);
    self.models.bind(6);

    self.gbuffer.bind_images(0);

    const workgroup_size_x = @divFloor(self.gbuffer.albedo.width, 32) + 1;
    const workgroup_size_y = @divFloor(self.gbuffer.albedo.height, 32) + 1;

    self.primary_trace_pipeline.bind();
    self.primary_trace_pipeline.dispatch(workgroup_size_x, workgroup_size_y, 1);

    self.secondary_trace_pipeline.bind();
    self.secondary_trace_pipeline.dispatch(workgroup_size_x, workgroup_size_y, 1);

    gfx.clear(0.0, 0.0, 0.0);

    self.gbuffer.bind_textures(0);

    self.raster_pipeline.bind();
    self.raster_pipeline.draw(4);
}

/// Reloads the shaders.
pub fn reloadShaders(self: *@This()) void {
    const primary_trace_pipeline = gfx.ComputePipeline.init(self.allocator, "assets/shaders/primary.comp.glsl") catch |err| {
        std.log.warn("Failed to reload shaders: {}\n", .{err});
        return;
    };
    const blit_pipeline = gfx.RasterPipeline.init(self.allocator, "assets/shaders/blit.vertex.glsl", "assets/shaders/blit.fragment.glsl") catch |err| {
        std.log.warn("Failed to reload shaders: {}\n", .{err});
        return;
    };
    const secondary_trace_pipeline = gfx.ComputePipeline.init(self.allocator, "assets/shaders/secondary.comp.glsl") catch |err| {
        std.log.warn("Failed to reload shaders: {}\n", .{err});
        return;
    };

    self.primary_trace_pipeline.deinit();
    self.primary_trace_pipeline = primary_trace_pipeline;

    self.raster_pipeline.deinit();
    self.raster_pipeline = blit_pipeline;

    self.secondary_trace_pipeline.deinit();
    self.secondary_trace_pipeline = secondary_trace_pipeline;

    std.log.debug("Shaders reloaded", .{});
}

pub fn deinit(self: *@This()) void {
    self.gbuffer.deinit();
    self.window.destroy();

    self.primary_trace_pipeline.deinit();
    self.secondary_trace_pipeline.deinit();

    self.ambient_sound.stop() catch unreachable;
    self.walking_sound.stop() catch unreachable;

    self.ambient_sound.destroy();
    self.walking_sound.destroy();
    self.audio_engine.destroy();
    zaudio.deinit();
}
