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
                world.set(x, y, z, 0x11000000 + 13); // ADD8E6
            }
        }
    }

    for (0..dim) |x| {
        for (0..dim) |z| {
            const val = height_gen.noise2((offsetX + @as(f32, @floatFromInt(x))) / 10.0, (offsetY + @as(f32, @floatFromInt(z))) / 10.0);
            const vh: u32 = @intFromFloat(@max(val * @as(f32, @floatFromInt(dim)) * 0.1, 0.0));

            for (0..vh) |h| {
                world.set(x, h, z, 0x11000000 + 21 + lcg.rand() % 3);
                if (h == vh - 1)
                    world.set(x, h, z, 0x11000000 + lcg.rand() % 6);
            }

            if (vh > 15) {
                if (world.get(x, vh, z) != 0)
                    continue;

                // add future grass blades
                if (lcg.rand() % 5 == 0)
                    world.set(x, vh, z, 0x01000000 + 7 + lcg.rand() % 5); //dirt

                if (lcg.rand() % 71 == 0)
                    world.set(x, vh, z, 0x11000000 + 7 + 5); //dirt

                if (lcg.rand() % 420 == 0 and x < 500 and z < 500 and x > 5 and z > 5)
                    place_tree(&lcg, world, x, vh, z);
            }
            _ = lcg.rand();
        }
    }
}

fn place_tree(prng: *LCG, world: anytype, x: usize, y: usize, z: usize) void {
    const trunk_height = @mod(prng.rand_usize(), 4) + 4;

    world.set(x + 1, y, z + 1, 0x11000000 + 15);
    for (0..trunk_height) |offset| {
        world.set(x + 1, y + offset, z + 1, 0x11000000 + 14 + prng.rand() % 3); // 855E42
    }

    for (0..3) |a| {
        for (0..3) |b| {
            for (0..3) |c| {
                world.set(x + a, y + trunk_height + b, z + c, 0x11000000 + 18 + prng.rand() % 2); // tree leaves
            }
        }
    }
}
