# _biquad.zig_

Biquad (second order IIR) filters in Zig

Dual licensed under the 0BSD and MIT licenses.

## Usage

```zig
const biquad = @import("biquad.zig");

const Biquad = biquad.Biquad;
const Coefficients = biquad.Coefficients;
const DirectFormI = biquad.DirectFormI;

const coeffs = Coefficients(f32).lowpass(.{
    .fs = 32_000, // sampling frequency (hz)
    .f0 = 200, // cutoff frequency (hz)
    .q = 0.707107 // quality factor, defaults to 1/sqrt(2)
});

var filter = Biquad(f32, DirectFormI).init(coeffs);

const y = filter.filter(x); // filter an f32 value through the biquad
```
