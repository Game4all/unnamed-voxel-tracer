const znoise = @import("znoise");

pub fn procgen(comptime dim: comptime_int, world: anytype) void {
    const gen = znoise.FnlGenerator{ .fractal_type = .fbm };
    for (0..dim) |x| {
        for (0..dim) |z| {
            const val = gen.noise2(@as(f32, @floatFromInt(x)) / 10.0, @as(f32, @floatFromInt(z)) / 10.0);
            const vh: u32 = @intFromFloat(@max(val * @as(f32, @floatFromInt(dim)) * 0.1, 0.0));
            for (0..vh) |h| {
                world.set(x, h, z, 0xFFFFFFFF);
            }
        }
    }
    spawn_trees(dim, world);
}

fn spawn_trees(comptime dim: comptime_int, world: anytype) void {
    const gen = znoise.FnlGenerator{ .fractal_type = .ridged };
    for (0..dim) |x| {
        for (0..dim) |z| {
            const val = gen.noise2(@as(f32, @floatFromInt(x)) / 2.0, @as(f32, @floatFromInt(z)) / 2.0);
            const vh: u32 = @intFromFloat(@max(val * @as(f32, @floatFromInt(dim)) * 0.1, 0.0));
            if (vh > 5) {
                for (0..vh) |h| {
                    world.set(x, h, z, 0xAAAFFFFF);
                }
            }
        }
    }
}
