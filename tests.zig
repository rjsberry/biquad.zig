// The contents of this file is dual-licensed under the MIT or 0BSD license.

const std = @import("std");
const math = std.math;
const testing = std.testing;
const ArrayList = std.ArrayList;

const biquad = @import("biquad.zig");
const Biquad = biquad.Biquad;

const FS: f32 = 1_000;
const F0: f32 = 50;

const F1: f32 = 2;
const F2: f32 = 400;

const NUM_SAMPLES: usize = 10_000;

test "two-pole lowpass (direct form i)" {
    var filter = Biquad(f32, biquad.DirectFormI).init(
        biquad.Coefficients(f32).lowpassTwoPole(FS, F0, math.sqrt1_2),
    );

    var allocator = testing.allocator;

    var xsbuf = ArrayList(f32).init(allocator);
    defer xsbuf.deinit();
    var xs = try xsbuf.addManyAsArray(NUM_SAMPLES);
    for (xs, 0..) |*x, i| {
        const t: f32 = @floatFromInt(i);
        x.* = math.sin(2 * math.pi * F1 * t) + math.sin(2 * math.pi * F2 * t);
    }

    var ysbuf = ArrayList(f32).init(allocator);
    defer ysbuf.deinit();
    var ys = try ysbuf.addManyAsArray(NUM_SAMPLES);
    for (xs, ys) |x, *y| {
        y.* = filter.filter(x);
    }

    const t0: usize = @intFromFloat(FS);
    for (ys[t0..], 0..) |y, i| {
        const t: f32 = @floatFromInt(i);
        const expected = math.sin(2 * math.pi * F1 * t);
        try testing.expect(math.approxEqAbs(f32, y, expected, 0.1));
    }
}
