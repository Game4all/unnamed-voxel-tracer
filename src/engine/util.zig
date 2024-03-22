const std = @import("std");

// Get a unique numeric ID representing the type of the given type.
// https://zig.news/xq/cool-zig-patterns-type-identifier-3mfd
pub fn type_id(comptime T: type) u64 {
    _ = T;
    const S = struct {
        var h: u8 = 0;
    };
    return @intFromPtr(&S.h);
}

/// Peforms a compiletime bubble sorting.
pub fn comptime_sort(comptime ty: type, array: []ty, comptime compare: fn (void, ty, ty) bool) void {
    @setEvalBranchQuota(1000 * array.len);
    for (0..array.len) |_| {
        var swapped = false;
        for (1..array.len) |j| {
            if (!compare({}, array[j - 1], array[j])) {
                const tmp = array[j - 1];
                array[j - 1] = array[j];
                array[j] = tmp;
                swapped = true;
            }
        }

        if (!swapped)
            break;
    }
}

/// A linear congruential generator.
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
