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
