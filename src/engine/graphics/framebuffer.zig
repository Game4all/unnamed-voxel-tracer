const tex = @import("texture.zig");
const gl = @import("gl45.zig");

pub const TextureFormat = tex.TextureFormat;

pub const Framebuffer = struct {
    /// The color attachment texture of the framebuffer
    color_attachment: tex.Texture,
    handle: c_uint,

    pub fn init(w: u32, h: u32, format: tex.TextureFormat) Framebuffer {
        const color = tex.Texture.init(tex.TextureKind.Texture2D, format, w, h, 1);
        var fb: c_uint = undefined;
        gl.createFramebuffers(1, &fb);
        gl.namedFramebufferTexture(fb, gl.COLOR_ATTACHMENT0, color.handle, 0);

        return .{ .color_attachment = color, .handle = fb };
    }

    pub fn blit(self: *Framebuffer, dst: *Framebuffer, srcX: u32, srcY: u32, dstX: u32, dstY: u32, w: u32, h: u32) void {
        gl.blitNamedFramebuffer(self.handle, dst.handle, srcX, srcY, w, h, dstX, dstY, w, h, gl.COLOR_BUFFER_BIT, gl.NEAREST);
    }

    /// Blits the framebuffer to screen
    pub fn blit_to_screen(self: *Framebuffer, srcX: u32, srcY: u32, dstX: u32, dstY: u32, w: u32, h: u32) void {
        gl.blitNamedFramebuffer(self.handle, 0, @intCast(srcX), @intCast(srcY), @intCast(w), @intCast(h), @intCast(dstX), @intCast(dstY), @intCast(w), @intCast(h), gl.COLOR_BUFFER_BIT, gl.NEAREST);
    }

    /// Clears the framebuffer to specified color.
    pub fn clear(self: *Framebuffer, r: f32, g: f32, b: f32, a: f32) void {
        gl.clearNamedFramebufferfv(self.handle, gl.COLOR, 0, &[_]f32{ r, g, b, a });
    }

    pub fn deinit(self: *Framebuffer) void {
        gl.deleteFramebuffers(1, &self.handle);
        self.handle = undefined;
        self.color_attachment.deinit();
    }
};
