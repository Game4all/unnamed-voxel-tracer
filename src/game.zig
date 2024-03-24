const std = @import("std");

const procgen = @import("procgen.zig");

const gfx = @import("engine/graphics/graphics.zig");
const voxel = @import("engine/voxel.zig");
const input = @import("engine/input.zig");
const glfw = @import("engine/glfw.zig");
const audio = @import("engine/audio.zig");

const zmath = @import("zmath");

const context = @import("engine/context.zig");

pub const Game = @This();

pub const name = .game;
pub const priority = .{};

// pipeline images
gbuffer: gfx.GBuffer,

// pipelines
primary_trace_pipeline: gfx.ComputePipeline,
secondary_trace_pipeline: gfx.ComputePipeline,
raster_pipeline: gfx.RasterPipeline,
edit_pipeline: gfx.ComputePipeline,

// camera uniforms
cam_uniforms: gfx.PersistentMappedBuffer,

// voxel map
voxels: voxel.VoxelBrickmap(512, 8),
models: voxel.VoxelModelAtlas,

/// camera
cam: gfx.Camera = .{},

// player position
position: zmath.F32x4 = zmath.f32x4(256.0, 22.0, 256.0, 0.0),
no_clip: bool = false,

// audio
ambient_sound: *audio.zaudio.Sound,
walking_sound: *audio.zaudio.Sound,

pub fn init(ctx: *context.Context) void {
    game_init(ctx.mod(@This()), ctx.mod(context.EngineBaseState).allocator, ctx.mod(glfw.GLFWModule).window, ctx.mod(audio.AudioModule).audio_engine) catch |err| {
        std.log.err("Failed to init game : {}", .{err});
        unreachable;
    };
}

fn game_init(self: *@This(), allocator: std.mem.Allocator, window: glfw.mach_glfw.Window, audio_engine: *audio.zaudio.Engine) !void {
    window.setInputModeCursor(.disabled);

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

    const edit_pipeline = try gfx.ComputePipeline.init(allocator, "assets/shaders/terrain_edit.comp.glsl");
    errdefer edit_pipeline.deinit();

    const raster_pipeline = try gfx.RasterPipeline.init(allocator, "assets/shaders/blit.vertex.glsl", "assets/shaders/blit.fragment.glsl");
    errdefer raster_pipeline.deinit();

    var gbuff = gfx.GBuffer.init(1280, 720);
    errdefer gbuff.deinit();

    const uniforms = gfx.PersistentMappedBuffer.init(gfx.BufferType.Uniform, @sizeOf(gfx.Camera.UniformData), gfx.BufferCreationFlags.MappableWrite | gfx.BufferCreationFlags.MappableRead);

    var voxels = voxel.VoxelBrickmap(512, 8).init();
    procgen.procgen(512, &voxels, 0.0, 0.0);

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

    self.* = .{
        .primary_trace_pipeline = primary_trace_pipeline,
        .secondary_trace_pipeline = secondary_trace_pipeline,
        .raster_pipeline = raster_pipeline,
        .edit_pipeline = edit_pipeline,
        .ambient_sound = ambient_sound,
        .walking_sound = walking_sound,
        .gbuffer = gbuff,
        .cam_uniforms = uniforms,
        .voxels = voxels,
        .models = models,
    };
}

/// Called when the mouse is moved.
pub fn mouse_moved(ctx: *context.Context, _: f64, _: f64) void {
    const input_state = ctx.mod(input.InputState);
    const self = ctx.mod(@This());

    const delta = input_state.mouse_pos - input_state.old_mouse_pos;

    self.cam.rotate(@floatCast(delta[1]), @floatCast(delta[0]));
}

/// basic AF player controller system
fn update_physics(self: *@This(), keyboard: *input.Keyboard) void {
    var velocity = zmath.f32x4(0.0, 0.0, 0.0, 0.0);
    var moved = false;

    if (keyboard.is_pressed(.w)) {
        velocity = velocity + zmath.mul(zmath.f32x4(0.0, 0.0, 1.0, 0.0), self.cam.camera_mat()) * zmath.f32x4(1.0, 0.0, 1.0, 0.0);
    }

    if (keyboard.is_pressed(.s)) {
        velocity = velocity - zmath.mul(zmath.f32x4(0.0, 0.0, 1.0, 0.0), self.cam.camera_mat()) * zmath.f32x4(1.0, 0.0, 1.0, 0.0);
    }

    if (keyboard.is_pressed(.d)) {
        velocity = velocity + zmath.mul(zmath.f32x4(1.0, 0.0, 0.0, 0.0), self.cam.camera_mat()) * zmath.f32x4(1.0, 0.0, 1.0, 0.0);
    }

    if (keyboard.is_pressed(.a)) {
        velocity = velocity - zmath.mul(zmath.f32x4(1.0, 0.0, 0.0, 0.0), self.cam.camera_mat()) * zmath.f32x4(1.0, 0.0, 1.0, 0.0);
    }

    if (keyboard.is_pressed(.space)) {
        velocity = velocity + zmath.f32x4(0.0, 1.6, 0.0, 0.0);
    }

    if (keyboard.is_pressed(.left_shift)) {
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

    self.position = finalPos;
}

/// Called upon window resize.
pub fn window_resized(ctx: *context.Context, width: u32, height: u32) void {
    const self = ctx.mod(@This());
    gfx.resize(width, height);

    const nwidth: u32 = @intFromFloat(@as(f32, @floatFromInt(width)));
    const nheight: u32 = @intFromFloat(@as(f32, @floatFromInt(height)));

    self.gbuffer.resize(nwidth, nheight);
}

pub fn update(ctx: *context.Context) void {
    const self: *@This() = ctx.mod(@This());
    const keyboard = &ctx.mod(input.InputState).keyboard;

    self.update_physics(keyboard);
    self.cam.set_pos(self.position + zmath.f32x4(0.0, 3.0, 0.0, 0.0));

    if (keyboard.any_pressed() and !keyboard.is_pressed(.space)) {
        if (!self.walking_sound.isPlaying())
            self.walking_sound.start() catch unreachable;
    } else {
        if (self.walking_sound.isPlaying())
            self.walking_sound.stop() catch unreachable;
    }
}

/// Prepare uniforms for rendering.
pub fn pre_render(ctx: *context.Context) void {
    const self: *@This() = ctx.mod(@This());

    const camera_data = self.cam_uniforms.get_ptr(gfx.Camera.UniformData);
    camera_data.* = self.cam.as_uniform_data();
}

// Render to the screen.
pub fn render(ctx: *context.Context) void {
    const self: *@This() = ctx.mod(@This());

    self.cam_uniforms.bind(8);
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

pub fn key_pressed(engine: *context.Context, key: glfw.mach_glfw.Key, _: glfw.mach_glfw.Mods) void {
    const self = engine.mod(@This());

    if (key == .r) {
        const allocator = engine.mod(context.EngineBaseState).allocator;

        const primary_trace_pipeline = gfx.ComputePipeline.init(allocator, "assets/shaders/primary.comp.glsl") catch |err| {
            std.log.warn("Failed to reload shaders: {}\n", .{err});
            return;
        };
        const blit_pipeline = gfx.RasterPipeline.init(allocator, "assets/shaders/blit.vertex.glsl", "assets/shaders/blit.fragment.glsl") catch |err| {
            std.log.warn("Failed to reload shaders: {}\n", .{err});
            return;
        };
        const secondary_trace_pipeline = gfx.ComputePipeline.init(allocator, "assets/shaders/secondary.comp.glsl") catch |err| {
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
}

pub fn deinit(self: *context.Context) void {
    var a = self.mod(@This());
    a.gbuffer.deinit();
    a.primary_trace_pipeline.deinit();
    a.secondary_trace_pipeline.deinit();
    a.ambient_sound.stop() catch unreachable;
    a.walking_sound.stop() catch unreachable;
    a.ambient_sound.destroy();
    a.walking_sound.destroy();
}
