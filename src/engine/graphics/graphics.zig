const gl = @import("gl45.zig");
const glfw = @import("zglfw");
const std = @import("std");

const texture = @import("texture.zig");
const buffer = @import("buffer.zig");
const shader = @import("shader.zig");

pub const TextureFormat = texture.TextureFormat;
pub const TextureKind = texture.TextureKind;
pub const TextureUsage = texture.TextureUsage;
pub const Texture = texture.Texture;

pub const ComputePipeline = shader.ComputePipeline;
pub const RasterPipeline = shader.RasterPipeline;

pub const BufferCreationFlags = buffer.BufferCreationFlags;
pub const BufferMapFlags = buffer.BufferMapFlags;
pub const BufferType = buffer.BufferType;
pub const Buffer = buffer.Buffer;
pub const PersistentMappedBuffer = buffer.PersistentMappedBuffer;

pub const GBuffer = @import("gbuffer.zig").GBuffer;
pub const Camera = @import("camera.zig").Camera;

pub const GpuBlockAllocator = @import("gpu_block_allocator.zig").GpuBlockAllocator;
pub const GLProc = *allowzero opaque {};

fn getProcAddress(_: GLProc, proc: [:0]const u8) ?gl.FunctionPointer {
    return glfw.getProcAddress(proc);
}

/// Clears the screen with the given color.
pub fn clear(r: f32, g: f32, b: f32) void {
    gl.clearColor(r, g, b, 1.0);
    gl.clear(gl.COLOR_BUFFER_BIT);
}

pub fn resize(width: u32, height: u32) void {
    gl.viewport(0, 0, @intCast(width), @intCast(height));
}

pub fn enableDebug() void {
    gl.enable(gl.DEBUG_OUTPUT);
    gl.debugMessageCallback(&(struct {
        pub fn callback(source: gl.GLenum, _type: gl.GLenum, id: gl.GLuint, severity: gl.GLenum, length: gl.GLsizei, message: [*:0]const u8, userParam: ?*anyopaque) callconv(.C) void {
            _ = severity;
            _ = userParam;
            _ = length;
            _ = id;
            _ = _type;
            _ = source;

            std.log.warn("OpenGL: {?s}", .{message});
        }
    }).callback, null);
}

/// Loads OpenGL functions for the given window.
pub fn init(window: *glfw.Window) !void {
    glfw.makeContextCurrent(window);
    const glproc: GLProc = @ptrFromInt(0);
    try gl.load(glproc, getProcAddress);
    try gl.GL_ARB_bindless_texture.load(glproc, getProcAddress);

    std.log.info("", .{});
    std.log.info("-------------------------------------------------------------------", .{});
    std.log.info("OpenGL graphics initialized", .{});
    std.log.info("OpenGL version {?s}", .{gl.getString(gl.VERSION)});
    std.log.info("GPU: {?s}", .{gl.getString(gl.RENDERER)});
    var ssbo_max: i32 = 0;
    gl.getIntegerv(gl.MAX_SHADER_STORAGE_BLOCK_SIZE, &ssbo_max);
    std.log.info("Max SSBO size: {}mb", .{@divFloor(ssbo_max, 1024 * 1024)});
    std.log.info("-------------------------------------------------------------------", .{});
}
