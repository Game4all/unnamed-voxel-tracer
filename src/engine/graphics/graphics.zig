const gl = @import("gl45.zig");
const glfw = @import("mach_glfw");
const std = @import("std");

const texture = @import("texture.zig");
const framebuffer = @import("framebuffer.zig");
const buffer = @import("buffer.zig");
const shader = @import("shader.zig");

pub const TextureFormat = texture.TextureFormat;
pub const TextureKind = texture.TextureKind;
pub const TextureUsage = texture.TextureUsage;
pub const Texture = texture.Texture;

pub const Framebuffer = framebuffer.Framebuffer;

pub const ComputePipeline = shader.ComputePipeline;

pub const BufferCreationFlags = buffer.BufferCreationFlags;
pub const BufferMapFlags = buffer.BufferMapFlags;
pub const BufferType = buffer.BufferType;
pub const Buffer = buffer.Buffer;
pub const PersistentMappedBuffer = buffer.PersistentMappedBuffer;

fn getProcAddress(p: glfw.GLProc, proc: [:0]const u8) ?gl.FunctionPointer {
    _ = p;
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
pub fn init(window: glfw.Window) !void {
    glfw.makeContextCurrent(window);
    var glproc: glfw.GLProc = undefined;
    try gl.load(glproc, getProcAddress);

    std.log.info("Graphics initialized", .{});
    std.log.info("OpenGL version {?s}", .{gl.getString(gl.VERSION)});
    std.log.info("GPU: {?s}", .{gl.getString(gl.RENDERER)});
}
