const gl = @import("gl45.zig");

// supported texture formats
pub const TextureFormat = enum(gl.GLenum) {
    RGBA8 = gl.RGBA8,
    RGBA16F = gl.RGBA16F,
    RGBA32F = gl.RGBA32F,
    R32F = gl.R32F,
    R16F = gl.R16F,
    R8 = gl.R8,
    RG8 = gl.RG8,
    RG16F = gl.RG16F,
    RG32F = gl.RG32F,
    RGB8 = gl.RGB8,
    RGB16F = gl.RGB16F,
    RGB32F = gl.RGB32F,
    SRGB8 = gl.SRGB8,
    SRGB8_ALPHA8 = gl.SRGB8_ALPHA8,
};

// supported texture usages
pub const TextureUsage = enum(gl.GLenum) {
    Read = gl.READ_ONLY,
    Write = gl.WRITE_ONLY,
    ReadWrite = gl.READ_WRITE,
};

pub const TextureKind = enum(gl.GLenum) {
    Texture2D = gl.TEXTURE_2D,
    Texture2DArray = gl.TEXTURE_2D_ARRAY,
    Texture3D = gl.TEXTURE_3D,
};

pub const Texture = struct {
    handle: c_uint,
    width: u32,
    height: u32,
    depth: u32,
    format: TextureFormat,
    kind: TextureKind,

    /// Creates a new texture with the given parameters
    pub fn init(kind: TextureKind, fmt: TextureFormat, width: u32, height: u32, depth_or_layers: u32) Texture {
        var tex_handle: c_uint = undefined;
        gl.createTextures(@intFromEnum(kind), 1, &tex_handle);

        switch (kind) {
            inline TextureKind.Texture2D => {
                gl.textureStorage2D(tex_handle, 1, @intFromEnum(fmt), @intCast(width), @intCast(height));
            },
            inline TextureKind.Texture3D, TextureKind.Texture2DArray => {
                gl.textureStorage3D(tex_handle, 1, @intFromEnum(fmt), @intCast(width), @intCast(height), @intCast(depth_or_layers));
            },
        }

        return Texture{
            .handle = tex_handle,
            .width = width,
            .height = height,
            .depth = depth_or_layers,
            .format = fmt,
            .kind = kind,
        };
    }

    pub fn set_data(self: *Texture, data: *anyopaque) void {
        gl.textureSubImage3D(self.handle, 0, @intCast(0), @intCast(0), @intCast(0), @intCast(self.width), @intCast(self.height), @intCast(self.depth), gl.RGBA, gl.UNSIGNED_BYTE, data);
    }

    /// Binds the texture to the given texture unit for rendering operations.
    pub fn bind(self: *Texture, unit: u32) void {
        gl.bindTextureUnit(@intCast(unit), self.handle);
    }

    /// Binds the image to the given texture unit for rendering operations.
    pub fn bind_image(self: *Texture, unit: u32, usage: TextureUsage, layer: ?u32) void {
        const is_layered = brk: {
            switch (self.kind) {
                inline TextureKind.Texture2D => break :brk false,
                inline TextureKind.Texture3D, TextureKind.Texture2DArray => {
                    break :brk layer == null;
                },
            }
        };
        gl.bindImageTexture(@intCast(unit), self.handle, 0, @intFromBool(is_layered), @intCast(layer orelse 0), @intFromEnum(usage), @intFromEnum(self.format));
    }

    /// Returns an opaque handle to the texture for bindless image access.
    pub fn get_image_handle(self: *Texture, usage: TextureUsage, layer: ?u32) u64 {
        const is_layered = brk: {
            switch (self.kind) {
                inline TextureKind.Texture2D => break :brk false,
                inline TextureKind.Texture3D, TextureKind.Texture2DArray => break :brk layer == null,
            }
        };

        const handle = gl.GL_ARB_bindless_texture.getImageHandleARB(self.handle, 0, @intFromBool(is_layered), @intCast(layer orelse 0), @intFromEnum(self.format));
        if (gl.GL_ARB_bindless_texture.isImageHandleResidentARB(handle) == 0) {
            gl.GL_ARB_bindless_texture.makeImageHandleResidentARB(handle, @intFromEnum(usage));
        }

        return handle;
    }

    /// Deletes the texture
    pub fn deinit(self: *Texture) void {
        gl.deleteTextures(1, &self.handle);
        self.handle = undefined;
    }
};
