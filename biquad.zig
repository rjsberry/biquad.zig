// The contents of this file is dual-licensed under the MIT or 0BSD license.

//! Biquad (second order IIR) filters.

const std = @import("std");

const debug = std.debug;
const fmt = std.fmt;
const math = std.math;
const mem = std.mem;

/// Biquad -- a second order IIR filter.
///
/// Biquads work with any floating-point type `T`. You will also need to pick a
/// section `S`:
///
/// * `DirectFormI` -- Stable to online coefficient recalculation but the most
///   computationally expensive. You can safely update the cutoff frequency of
///   the filter at runtime.
///
/// * `DirectFormII` -- Computationally simpler than `DirectFormI` but may be
///   susceptible to overflow for large input values as gain is generally
///   applied before attenuation.
///
/// * `TransposedDirectFormII` -- May produce some anomalies when retuned
///   online but is computationally efficient and numerically "robust". This
///   robustness comes from fact that attenuation of the input signal often
///   occurs before gain.
pub fn Biquad(
    comptime T: type,
    comptime S: *const fn (comptime type) type,
) type {
    comptime {
        assertFloat(T);
        switch (S) {
            DirectFormI, DirectFormII, TransposedDirectFormII => {},
            else => {
                @compileError(fmt.comptimePrint(
                    "type `{}` is not a valid biquad section",
                    .{@typeName(S)},
                ));
            },
        }
    }

    return struct {
        const Self = @This();

        coeffs: Coefficients(T),
        section: S(T),

        /// Initializes the biquad with the given coefficients.
        pub fn init(coeffs: Coefficients(T)) Self {
            return Self{
                .coeffs = coeffs,
                .section = mem.zeroInit(S(T), .{}),
            };
        }

        /// Filters a value through the biquad.
        pub fn filter(self: *Self, x: T) T {
            return self.section.filter(x, &self.coeffs);
        }
    };
}

/// The coefficients inside every biquad.
///
/// Normalized such that in the Z-domain:
///
/// ```text
/// H(z) = (b0 + b1*z^-1 + b2*z^-2) / (1 + a1*z^-1 + a2*z^-2)
/// ```
pub fn Coefficients(comptime T: type) type {
    comptime assertFloat(T);

    return struct {
        const Self = @This();

        b0: T,
        b1: T,
        b2: T,
        a1: T,
        a2: T,

        /// Calculates the coefficients for a two-pole low-pass filter.
        ///
        /// * `fs` -- sampling frequency (Hz)
        /// * `f0` -- cutoff frequency (Hz)
        /// * `q` -- quality factor
        pub fn lowpassTwoPole(fs: T, f0: T, q: T) Self {
            debug.assert(f0 < (2.0 * fs));
            debug.assert(q >= 0.0);

            const omega = 2.0 * math.pi * (f0 / fs);
            const omega_s = math.sin(omega);
            const omega_c = math.cos(omega);
            const alpha = omega_s / (2.0 * q);

            const a0 = 1.0 + alpha;

            var self: Self = undefined;
            self.a1 = (-2.0 * omega_c) / a0;
            self.a2 = (1.0 - alpha) / a0;
            self.b0 = ((1.0 - omega_c) * 0.5) / a0;
            self.b1 = (1.0 - omega_c) / a0;
            self.b2 = ((1.0 - omega_c) * 0.5) / a0;
            return self;
        }
    };
}

/// The direct form I biquad realization.
pub fn DirectFormI(comptime T: type) type {
    comptime assertFloat(T);

    return struct {
        const Self = @This();

        x1: T = 0.0,
        x2: T = 0.0,
        y1: T = 0.0,
        y2: T = 0.0,

        /// Filters a value through the section.
        pub fn filter(self: *Self, x: T, coeffs: *const Coefficients(T)) T {
            const y = coeffs.b0 * x +
                coeffs.b1 * self.x1 +
                coeffs.b2 * self.x2 -
                coeffs.a1 * self.y1 -
                coeffs.a2 * self.y2;

            self.x2 = self.x1;
            self.y2 = self.y1;
            self.x1 = x;
            self.y1 = y;

            return y;
        }
    };
}

/// The direct form II biquad realization.
pub fn DirectFormII(comptime T: type) type {
    comptime assertFloat(T);

    return struct {
        const Self = @This();

        v1: T = 0.0,
        v2: T = 0.0,

        /// Filters a value through the section.
        pub fn filter(self: *Self, x: T, coeffs: *const Coefficients(T)) T {
            const w = x - coeffs.a1 * self.v1 - coeffs.a2 * self.v2;
            const y = coeffs.b0 * w + coeffs.b1 * self.v1 + coeffs.b2 * self.v2;

            self.v2 = self.v1;
            self.v1 = w;

            return y;
        }
    };
}

/// The transposed direct form II biquad realization.
pub fn TransposedDirectFormII(comptime T: type) type {
    comptime assertFloat(T);

    return struct {
        const Self = @This();

        s1: T = 0.0,
        s2: T = 0.0,

        /// Filters a value through the section.
        pub fn filter(self: *Self, x: T, coeffs: *const Coefficients(T)) T {
            const y = self.s1 + coeffs.b0 * x;

            self.s1 = self.s2 + coeffs.b1 * x - coeffs.a1 * y;
            self.s2 = coeffs.b2 * x - coeffs.a2 * y;

            return y;
        }
    };
}

/// Produces a compile error if `T` is not a float.
fn assertFloat(comptime T: type) void {
    if (@typeInfo(T) != .Float) {
        @compileError(fmt.comptimePrint(
            "type `{}` is not a float",
            .{@typeName(T)},
        ));
    }
}
