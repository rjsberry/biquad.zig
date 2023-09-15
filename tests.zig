// The contents of this file is dual-licensed under the MIT or 0BSD license.

const std = @import("std");
const math = std.math;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const biquad = @import("biquad.zig");
const Biquad = biquad.Biquad;

const FS: comptime_float = 1000;
const NUM_SAMPLES: usize = 2048;

test "two-pole lowpass (direct form i) f32" {
    var t = Test(f32, biquad.DirectFormI).init(
        biquad.Coefficients(f32).lowpassTwoPole(.{ .fs = FS, .f0 = 100 }),
        testing.allocator,
    );

    try t.run(.{
        .freq_in = &[_]f32{ 2, 5, 10, 200, 300, 400 },
        .freq_out = &[_]f32{ 2, 5, 10 },
        .tolerance = 0.1,
    });
}

test "two-pole lowpass (direct form ii) f32" {
    var t = Test(f32, biquad.DirectFormII).init(
        biquad.Coefficients(f32).lowpassTwoPole(.{ .fs = FS, .f0 = 100 }),
        testing.allocator,
    );

    try t.run(.{
        .freq_in = &[_]f32{ 2, 5, 10, 200, 300, 400 },
        .freq_out = &[_]f32{ 2, 5, 10 },
        .tolerance = 0.1,
    });
}

test "two-pole lowpass (transposed direct form ii) f32" {
    var t = Test(f32, biquad.TransposedDirectFormII).init(
        biquad.Coefficients(f32).lowpassTwoPole(.{ .fs = FS, .f0 = 100 }),
        testing.allocator,
    );

    try t.run(.{
        .freq_in = &[_]f32{ 2, 5, 10, 200, 300, 400 },
        .freq_out = &[_]f32{ 2, 5, 10 },
        .tolerance = 0.1,
    });
}

fn Test(comptime T: type, comptime S: *const fn (type) type) type {
    return struct {
        const Self = @This();

        biquad: Biquad(T, S),
        allocator: Allocator,

        pub fn init(
            coeffs: biquad.Coefficients(T),
            allocator: Allocator,
        ) Self {
            return Self{
                .biquad = Biquad(T, S).init(coeffs),
                .allocator = allocator,
            };
        }

        pub fn run(self: *Self, args: struct {
            freq_in: []const T,
            freq_out: []const T,
            tolerance: T,
        }) !void {
            var xsbuf = ArrayList(T).init(self.allocator);
            defer xsbuf.deinit();
            var xs = try xsbuf.addManyAsArray(NUM_SAMPLES);
            @memset(xs, 0);

            signal(T, args.freq_in, xs);
            const max = elemMax(T, xs);
            elemDiv(T, xs, max);

            var ysbuf = ArrayList(T).init(self.allocator);
            defer ysbuf.deinit();
            var ys = try ysbuf.addManyAsArray(NUM_SAMPLES);
            @memset(ys, 0);

            signal(T, args.freq_out, ys);
            elemDiv(T, ys, max);

            for (xs, ys) |x, y| {
                const sample = self.biquad.filter(x);
                try testing.expect(math.approxEqAbs(
                    T,
                    y,
                    sample,
                    args.tolerance,
                ));
            }
        }
    };
}

fn signal(comptime T: type, freqs: []const T, buf: []T) void {
    for (freqs) |freq| {
        for (buf, 0..) |*sample, i| {
            const t: T = @floatFromInt(i);
            sample.* += math.sin(2 * math.pi * freq * t / FS);
        }
    }
}

fn elemMax(comptime T: type, buf: []const T) T {
    var max: T = 0;
    for (buf) |sample| {
        const abs = @fabs(sample);
        if (abs > max) {
            max = abs;
        }
    }
    return max;
}

fn elemDiv(comptime T: type, buf: []T, denom: T) void {
    for (buf) |*sample| {
        sample.* /= denom;
    }
}
