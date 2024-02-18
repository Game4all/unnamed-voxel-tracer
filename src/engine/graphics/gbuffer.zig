const gfx = @import("graphics.zig");

pub const GBuffer = struct {
    albedo: gfx.Texture,
    normal: gfx.Texture,
    position: gfx.Texture,
    illumination: gfx.Texture,

    pub fn init(width: u32, height: u32) @This() {
        const albedo = gfx.Texture.init(.Texture2D, .RGBA8, width, height, 0);
        const normal = gfx.Texture.init(.Texture2D, .RGBA8, width, height, 0);
        const position = gfx.Texture.init(.Texture2D, .RGBA32F, width, height, 0);
        const illumination = gfx.Texture.init(.Texture2D, .RGBA8, width, height, 0);

        return .{ .albedo = albedo, .normal = normal, .position = position, .illumination = illumination };
    }

    pub fn resize(self: *@This(), width: u32, height: u32) void {
        self.albedo.deinit();
        self.albedo = gfx.Texture.init(.Texture2D, .RGBA8, width, height, 0);

        self.normal.deinit();
        self.normal = gfx.Texture.init(.Texture2D, .RGBA8, width, height, 0);

        self.position.deinit();
        self.position = gfx.Texture.init(.Texture2D, .RGBA32F, width, height, 0);

        self.illumination.deinit();
        self.illumination = gfx.Texture.init(.Texture2D, .RGBA8, width, height, 0);
    }

    pub fn bind_images(self: *@This(), base_buffer: u32) void {
        inline for (.{ &self.albedo, &self.normal, &self.position, &self.illumination }, 0..) |tex, idx| {
            tex.bind_image(base_buffer + @as(u32, @intCast(idx)), .ReadWrite, null);
        }
    }

    pub fn bind_textures(self: *@This(), base_buffer: u32) void {
        inline for (.{ &self.albedo, &self.normal, &self.position, &self.illumination }, 0..) |tex, idx| {
            tex.bind(base_buffer + @as(u32, @intCast(idx)));
        }
    }

    pub fn deinit(self: *@This()) void {
        inline for (.{
            &self.albedo,
            &self.normal,
            &self.position,
        }) |tex| {
            tex.deinit();
        }
    }
};
