const std = @import("std");
const znoise = @import("znoise");
const gfx = @import("graphics/graphics.zig");
const zvox = @import("zvox");

/// A 32-bit value encoding information about a voxel
pub const Voxel = packed struct(u32) {
    ty: u28,
    is_solid: bool = false,

    __unused_bit_1: bool = false,
    __unused_bit_2: bool = false,
    __unused_bit_3: bool = false,

    pub const EMPTY = @This(){
        .ty = 0,
        .is_solid = false,
    };
};

inline fn posToIndex(dim: usize, x: usize, y: usize, z: usize) usize {
    return x + dim * (y + z * dim);
}

pub fn VoxelBrickmap(comptime dim: comptime_int, comptime chsize: comptime_int) type {
    const chsize_sq = chsize * chsize * chsize;

    return struct {
        voxels: gfx.GpuBlockAllocator(chsize_sq),
        chunks: gfx.PersistentMappedBuffer([*]u32),

        pub fn init() @This() {
            var chunks = gfx.PersistentMappedBuffer([*]u32).init(gfx.BufferType.Storage, (dim / chsize) * (dim / chsize) * (dim / chsize) * @sizeOf(u32), gfx.BufferCreationFlags.MappableWrite | gfx.BufferCreationFlags.MappableRead);
            @memset(chunks.deref()[0..chunks.len()], 0);
            return .{
                .voxels = gfx.GpuBlockAllocator(chsize_sq).init(dim),
                .chunks = chunks,
            };
        }

        pub fn clear(self: *@This(), _: u32) void {
            @memset(self.chunks.deref()[0..self.chunks.len()], 0);
            self.voxels.clear();
        }

        /// Attempts to grab the memory block for the specified chunk location if it is set
        pub fn get_block_for_chunk(self: *@This(), chx: usize, chy: usize, chz: usize) usize {
            const index = self.chunks.deref()[posToIndex((dim / chsize), chx, chy, chz)];
            if (index > 0) {
                return @as(usize, @intCast(index - 1));
            } else {
                const idx = self.voxels.alloc();
                self.chunks.deref()[posToIndex((dim / chsize), chx, chy, chz)] = @as(u32, @intCast(idx)) + 1;
                return idx;
            }
        }

        pub fn set(self: *@This(), x: usize, y: usize, z: usize, voxel: Voxel) void {
            const blk = self.get_block_for_chunk(x / chsize, y / chsize, z / chsize);
            self.voxels.get_slice(blk)[(x % chsize) + ((y % chsize) + (z % chsize) * chsize) * chsize] = @bitCast(voxel);
        }

        pub fn get(self: *@This(), x: usize, y: usize, z: usize) Voxel {
            const index: usize = @intCast(self.chunks.deref()[posToIndex((dim / chsize), x / chsize, y / chsize, z / chsize)]);
            if (index > 0) {
                return @bitCast(self.voxels.get_slice(index - 1)[(x % chsize) + ((y % chsize) + (z % chsize) * chsize) * chsize]);
            } else {
                return Voxel.EMPTY;
            }
        }

        pub fn is_walkable(self: *@This(), x: usize, y: usize, z: usize) bool {
            const voxel = self.get(x, y, z);
            return (voxel.is_solid) == false or @as(u32, @bitCast(voxel)) == 0;
        }

        pub fn bind(self: *@This(), base_binding: u32) void {
            self.voxels.buffer.bind(base_binding);
            self.chunks.bind(base_binding + 1);
        }
    };
}

pub const VoxelModelAtlas = struct {
    block_atlas: gfx.Texture,
    current_index: usize = 0,

    pub fn init() @This() {
        return .{
            .block_atlas = gfx.Texture.init(.Texture3D, .RGBA8, 256, 256, 256),
        };
    }

    fn load_single_block_model(self: *@This(), allocator: std.mem.Allocator, mdl: *zvox.Model, palette: *zvox.Palette) !void {
        const storage = try allocator.alloc(u32, mdl.size.x * mdl.size.y * mdl.size.z * @sizeOf(u32));
        defer allocator.free(storage);
        @memset(storage, 0);

        // base loc in space.
        const base_x = @mod(self.current_index, 32);
        const base_y = @mod(self.current_index / 32, 32);
        const base_z = @mod(self.current_index / 1024, 1024);

        // std.log.info("Start coords: {}:{}:{} (index={})", .{ base_x * 8, base_y * 8, base_z * 8, self.current_index });

        for (mdl.voxels) |vxl| {
            storage[posToIndex(8, @intCast(vxl.x), @intCast(vxl.z), @intCast(vxl.y))] = palette.colors[vxl.color - 1];
        }

        self.block_atlas.set_data_offset(base_x * 8, base_y * 8, base_z * 8, 8, 8, 8, @ptrCast(storage));
        self.current_index += 1;
    }

    /// Loads block models from the specified file which are assumed to be 8x8x8.
    pub fn load_block_model(self: *@This(), model: []const u8, allocator: std.mem.Allocator) !void {
        var file = try std.fs.cwd().openFile(model, .{});
        defer file.close();

        var voxfile = try zvox.VoxFile.from_reader(file.reader(), allocator);
        defer voxfile.deinit(allocator);

        for (voxfile.models) |*mdl| {
            try self.load_single_block_model(allocator, mdl, &voxfile.palette);
        }

        std.log.debug("Loaded {} models from {s} ", .{ voxfile.models.len, model });
    }

    pub fn bind(self: *@This(), idx: u32) void {
        self.block_atlas.bind_image(idx, .Read, null);
    }
};
