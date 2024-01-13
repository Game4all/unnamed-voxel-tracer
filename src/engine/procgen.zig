const znoise = @import("znoise");
const std = @import("std");

pub const LCG = struct {
    seed: u32,

    pub inline fn rand(self: *@This()) u32 {
        self.seed = @addWithOverflow(@mulWithOverflow(self.seed, 1103515245).@"0", 12345).@"0";

        return self.seed;
    }

    pub inline fn rand_usize(self: *@This()) usize {
        return @intCast(self.rand());
    }
};

pub fn procgen(comptime dim: comptime_int, world: anytype, offsetX: f32, offsetY: f32) void {
    const height_gen = znoise.FnlGenerator{ .fractal_type = .fbm };
    var lcg = LCG{ .seed = 0x46AE4F };

    for (0..dim) |x| {
        for (0..dim) |z| {
            for (0..16) |y| {
                world.set(x, y, z, 0x00E6D8AD); // ADD8E6
            }
        }
    }

    for (0..dim) |x| {
        for (0..dim) |z| {
            const val = height_gen.noise2((offsetX + @as(f32, @floatFromInt(x))) / 10.0, (offsetY + @as(f32, @floatFromInt(z))) / 10.0);
            const vh: u32 = @intFromFloat(@max(val * @as(f32, @floatFromInt(dim)) * 0.1, 0.0));

            for (0..vh) |h| {
                world.set(x, h, z, 0x0000fc7c); // grass 7CFC00
            }

            if (vh > 15) {
                if (world.get(x, vh, z) != 0)
                    continue;

                // add future grass blades
                if (lcg.rand() % 5 == 0)
                    world.set(x, vh, z, 0x01000000 + lcg.rand() % 4); //dirt

                if (lcg.rand() % 71 == 0)
                    world.set(x, vh, z, 0x01000000 + 4); //dirt

                // stones
                if (lcg.rand() % 2120 == 0) {
                    world.set(x, vh, z, 0x01000000 + 5); //dirt
                    continue;
                }

                if (lcg.rand() % 420 == 0 and x < 500 and z < 500 and x > 5 and z > 5)
                    place_tree(&lcg, world, x, vh, z);
            }
        }
    }
}

fn place_tree(prng: *LCG, world: anytype, x: usize, y: usize, z: usize) void {
    const trunk_height = @mod(prng.rand_usize(), 4) + 4;

    for (0..trunk_height) |offset| {
        world.set(x + 1, y + offset, z + 1, 0x425E85); // 855E42
    }

    for (0..3) |a| {
        for (0..3) |b| {
            for (0..3) |c| {
                world.set(x + a, y + trunk_height + b, z + c, 0x013822); // tree leaves
            }
        }
    }
}
