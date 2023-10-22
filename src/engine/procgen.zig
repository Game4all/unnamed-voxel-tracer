const znoise = @import("znoise");

pub fn procgen(comptime dim: comptime_int, world: anytype) void {
    for (0..dim) |x| {
        for (0..dim) |z| {
            for (0..15) |y| {
                world.set(x, y, z, 0x00E6D8AD); // ADD8E6
            }
        }
    }

    const gen = znoise.FnlGenerator{ .fractal_type = .fbm };
    for (0..dim) |x| {
        for (0..dim) |z| {
            const val = gen.noise2(@as(f32, @floatFromInt(x)) / 10.0, @as(f32, @floatFromInt(z)) / 10.0);
            const vh: u32 = @intFromFloat(@max(val * @as(f32, @floatFromInt(dim)) * 0.1, 0.0));
            for (0..vh) |h| {
                world.set(x, h, z, 0x0000ff00);
            }
        }
    }
}
