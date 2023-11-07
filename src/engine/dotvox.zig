const std = @import("std");
const Allocator = std.mem.Allocator;

const ChunkHeader = extern struct {
    id: [4]u8,
    content_size: u32,
    children_size: u32,
};

/// Size of a model in voxels
pub const ModelSize = extern struct {
    x: u32 = 0,
    y: u32 = 0,
    z: u32 = 0,
};

const Voxel = extern struct {
    x: u8,
    y: u8,
    z: u8,
    color_index: u8,
};

const Palette = extern struct {
    // the palette encoded in ARGB hex
    colors: [256]u32,
};

pub fn read_format(reader: anytype, voxel_data: []u32, size: *ModelSize) !void {
    // Checking file header
    const header = try reader.readBytesNoEof(4);
    if (!std.mem.eql(u8, &header, "VOX ")) {
        return error.VoxFileInvalidHeader;
    }

    // Checking file version
    const format_ver = try reader.readInt(u32, std.builtin.Endian.little);
    _ = format_ver;
    // std.log.debug("Format version: {}", .{format_ver});

    while (true) {
        read_chunk(reader, voxel_data, @constCast(size)) catch |err| switch (err) { // this shouldn't simply return on EOF as this will break on incomplete files
            error.EndOfStream => break,
            else => return err,
        };
    }
}

fn read_chunk(reader: anytype, voxel_data: []u32, size: *ModelSize) !void {
    const chunk_header = try reader.readStruct(ChunkHeader);
    if (std.mem.eql(u8, &chunk_header.id, "MAIN")) { //skip this one
        return;
    } else if (std.mem.eql(u8, &chunk_header.id, "SIZE")) {
        size.* = try reader.readStruct(ModelSize);

        // std.log.debug("Model size: {}x{}x{}", .{ size.x, size.y, size.z });
    } else if (std.mem.eql(u8, &chunk_header.id, "XYZI")) {
        const num_voxels = try reader.readInt(u32, std.builtin.Endian.little);
        // std.log.debug("Number of non-empty voxels: {}", .{num_voxels});
        for (0..num_voxels) |_| {
            // parse the voxel and store it here ...
            const voxel = try reader.readStruct(Voxel);
            // std.log.debug("Voxel at ({}, {}, {}) with color index {}", .{ voxel.x, voxel.y, voxel.z, voxel.color_index });
            const index: usize = @as(usize, @intCast(voxel.x)) + size.y * (@as(usize, @intCast(voxel.z)) + @as(usize, @intCast(voxel.y)) * size.z);
            voxel_data[index] = voxel.color_index;
            // store the voxel somewhere
        }
    } else if (std.mem.eql(u8, &chunk_header.id, "RGBA")) {
        const palette = try reader.readStruct(Palette);
        for (0..voxel_data.len) |i| {
            if (voxel_data[i] != 0) {
                voxel_data[i] = palette.colors[voxel_data[i]];
            }
        }
    } else {
        try reader.skipBytes(chunk_header.content_size, .{});
    }
}
