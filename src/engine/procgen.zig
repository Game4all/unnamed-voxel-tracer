const znoise = @import("znoise");
const std = @import("std");

pub const LCG = struct {
    seed: u32,

    pub fn rand(self: *@This()) u32 {
        self.seed = @addWithOverflow(@mulWithOverflow(self.seed, 1103515245).@"0", 12345).@"0";

        return self.seed;
    }
};

pub fn procgen(comptime dim: comptime_int, world: anytype, offsetX: f32, offsetY: f32) void {
    const height_gen = znoise.FnlGenerator{ .fractal_type = .fbm };
    var lcg = LCG{ .seed = 0x46AE4F };

    for (0..dim) |x| {
        for (0..dim) |z| {
            for (0..15) |y| {
                world.set(x, y, z, 0x00E6D8AD); // ADD8E6
            }
        }
    }

    for (0..dim) |x| {
        for (0..dim) |z| {
            const val = height_gen.noise2((offsetX + @as(f32, @floatFromInt(x))) / 10.0, (offsetY + @as(f32, @floatFromInt(z))) / 10.0);
            const vh: u32 = @intFromFloat(@max(val * @as(f32, @floatFromInt(dim)) * 0.1, 0.0));

            for (0..vh) |h| {
                world.set(x, h, z, 0x0000ff00); // grass
            }

            // add future grass blades
            if (lcg.rand() % 31 == 0 and vh > 15) {
                world.set(x, vh, z, 0x0153769b); //dirt
            }
        }
    }
}
