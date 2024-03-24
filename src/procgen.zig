const znoise = @import("znoise");
const std = @import("std");
const util = @import("engine/util.zig");
const Voxel = @import("engine/voxel.zig").Voxel;

pub fn procgen(comptime dim: comptime_int, world: anytype, offsetX: f32, offsetY: f32) void {
    const height_gen = znoise.FnlGenerator{ .fractal_type = .fbm };
    var lcg = util.LCG{ .seed = 0x46AE4F };

    for (0..dim) |x| {
        for (0..dim) |z| {
            for (0..16) |y| {
                world.set(x, y, z, .{
                    .ty = 13,
                    .is_solid = true,
                });
            }
        }
    }

    for (0..dim) |x| {
        for (0..dim) |z| {
            const val = height_gen.noise2((offsetX + @as(f32, @floatFromInt(x))) / 10.0, (offsetY + @as(f32, @floatFromInt(z))) / 10.0);
            const vh: u32 = @intFromFloat(@max(val * @as(f32, @floatFromInt(dim)) * 0.1, 0.0));

            for (0..vh) |h| {
                world.set(x, h, z, .{ .ty = @intCast(21 + lcg.rand() % 3), .is_solid = true });

                if (h <= 15) {
                    world.set(x, h, z, .{ .ty = @intCast(25 + lcg.rand() % 3), .is_solid = true });
                } else if (h == vh - 1 and h > 15) {
                    world.set(x, h, z, .{ .ty = @intCast(lcg.rand() % 6), .is_solid = true });
                }
            }

            if (vh > 16) {
                if (@as(u32, @bitCast(world.get(x, vh, z))) != 0)
                    continue;

                // add future grass blades
                if (lcg.rand() % 5 == 0)
                    world.set(x, vh, z, .{ .ty = @intCast(7 + lcg.rand() % 5) }); //dirt

                if (lcg.rand() % 71 == 0)
                    world.set(x, vh, z, .{ .ty = @intCast(7 + 5), .is_solid = true }); //dirt

                if (lcg.rand() % 420 == 0 and x < 500 and z < 500 and x > 5 and z > 5)
                    place_tree(&lcg, world, x, vh, z);
            }
            _ = lcg.rand();
        }
    }
}

fn place_tree(putil: *util.LCG, world: anytype, x: usize, y: usize, z: usize) void {
    const trunk_height = @mod(putil.rand_usize(), 4) + 4;

    world.set(x + 1, y, z + 1, .{ .ty = 15, .is_solid = true });
    for (0..trunk_height) |offset| {
        world.set(x + 1, y + offset, z + 1, .{ .ty = @intCast(14 + putil.rand() % 3), .is_solid = true }); // 855E42
    }

    for (0..3) |a| {
        for (0..3) |b| {
            for (0..3) |c| {
                world.set(x + a, y + trunk_height + b, z + c, .{ .ty = @intCast(18 + putil.rand() % 2), .is_solid = true }); // tree leaves
            }
        }
    }
}
