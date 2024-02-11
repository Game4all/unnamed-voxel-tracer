const std = @import("std");
const znoise = @import("znoise");
const gfx = @import("graphics/graphics.zig");
const zvox = @import("zvox");

inline fn posToIndex(dim: usize, x: usize, y: usize, z: usize) usize {
    return x + dim * (y + z * dim);
}

///
pub fn VoxelBrickmap(comptime dim: comptime_int, comptime chsize: comptime_int) type {
    const chsize_sq = chsize * chsize * chsize;

    return struct {
        voxels: gfx.GpuBlockAllocator(chsize_sq),
        chunks: gfx.PersistentMappedBuffer,
        block_index: usize = 0,
        max_block_index: usize = 0,

        pub fn init(_: u32) @This() {
            var chunks = gfx.PersistentMappedBuffer.init(gfx.BufferType.Storage, (dim / chsize) * (dim / chsize) * (dim / chsize) * @sizeOf(u32), gfx.BufferCreationFlags.MappableWrite | gfx.BufferCreationFlags.MappableRead);
            @memset(chunks.get_raw([*]u32)[0..(chunks.buffer.size / @sizeOf(u32))], 0);
            return .{
                .voxels = gfx.GpuBlockAllocator(chsize_sq).init(dim),
                .chunks = chunks,
            };
        }

        pub fn clear(self: *@This(), _: u32) void {
            @memset(self.chunks.get_raw([*]u32)[0..(self.chunks.buffer.size / @sizeOf(u32))], 0);
            self.voxels.clear();
        }

        /// Attempts to grab the memory block for the specified chunk location if it is set
        pub fn get_block_for_chunk(self: *@This(), chx: usize, chy: usize, chz: usize) usize {
            const index = self.chunks.get_ptr([(dim / chsize) * (dim / chsize) * (dim / chsize)]u32)[posToIndex((dim / chsize), chx, chy, chz)];
            if (index > 0) {
                return @as(usize, @intCast(index - 1));
            } else {
                const idx = self.voxels.alloc();
                self.chunks.get_ptr([(dim / chsize) * (dim / chsize) * (dim / chsize)]u32)[posToIndex((dim / chsize), chx, chy, chz)] = @as(u32, @intCast(idx)) + 1;
                return idx;
            }
        }

        pub fn set(self: *@This(), x: usize, y: usize, z: usize, voxel: u32) void {
            const blk = self.get_block_for_chunk(x / chsize, y / chsize, z / chsize);
            self.voxels.get_slice(blk)[(x % chsize) + ((y % chsize) + (z % chsize) * chsize) * chsize] = voxel;
        }

        pub fn get(self: *@This(), x: usize, y: usize, z: usize) u32 {
            const index: usize = @intCast(self.chunks.get_raw([*]u32)[posToIndex((dim / chsize), x / chsize, y / chsize, z / chsize)]);
            if (index > 0) {
                return self.voxels.get_slice(index - 1)[(x % chsize) + ((y % chsize) + (z % chsize) * chsize) * chsize];
            } else {
                return 0;
            }
        }

        pub fn is_walkable(self: *@This(), x: usize, y: usize, z: usize) bool {
            const voxel = self.get(x, y, z);
            return (voxel & 0x10000000) == 0 or voxel == 0;
        }

        pub fn bind(self: *@This(), base_binding: u32) void {
            self.voxels.buffer.bind(base_binding);
            self.chunks.bind(base_binding + 1);
        }
    };
}

pub const VoxelMapPalette = struct {
    buffer: gfx.PersistentMappedBuffer,
    textures: std.ArrayListUnmanaged(gfx.Texture) = .{},

    pub fn init() @This() {
        return @This(){ .buffer = gfx.PersistentMappedBuffer.init(gfx.BufferType.Storage, 8 * @sizeOf(u64), gfx.BufferCreationFlags.MappableWrite) };
    }

    fn load_single_model(self: *@This(), allocator: std.mem.Allocator, mdl: *zvox.Model, palette: *zvox.Palette) !void {
        const storage = try allocator.alloc(u32, 8 * 8 * 8 * @sizeOf(u32));
        defer allocator.free(storage);
        @memset(storage, 0);

        for (mdl.voxels) |vxl| {
            storage[posToIndex(8, @intCast(vxl.x), @intCast(vxl.z), @intCast(vxl.y))] = palette.colors[vxl.color - 1];
        }

        var tex = gfx.Texture.init(gfx.TextureKind.Texture3D, gfx.TextureFormat.RGBA8, 8, 8, 8);
        tex.set_data(@ptrCast(storage));

        const buffsize = self.buffer.buffer.size / @sizeOf(u64);
        if (self.textures.items.len >= buffsize) {
            try self.buffer.resize(self.buffer.buffer.size * 4);
        }

        self.buffer.get_raw([*]u64)[self.textures.items.len] = tex.get_image_handle(gfx.TextureUsage.Read, 0);
        try self.textures.append(allocator, tex);
    }

    /// Loads the specified model which is assumed to be 8x8x8
    pub fn load_model(
        self: *@This(),
        model: []const u8,
        allocator: std.mem.Allocator,
    ) !void {
        var file = try std.fs.cwd().openFile(model, .{});
        defer file.close();

        var voxfile = try zvox.VoxFile.from_reader(file.reader(), allocator);
        defer voxfile.deinit(allocator);

        for (voxfile.models) |*mdl| {
            try self.load_single_model(allocator, mdl, &voxfile.palette);
        }

        std.log.debug("Loaded {} models from {s} ", .{ voxfile.models.len, model });
    }

    pub fn bind(self: *@This(), idx: u32) void {
        self.buffer.bind(idx);
    }

    pub fn deinit(self: *@This(), gpa: std.mem.Allocator) void {
        for (self.textures.items) |*item| {
            item.deinit();
        }
        self.textures.deinit(gpa);
    }
};
