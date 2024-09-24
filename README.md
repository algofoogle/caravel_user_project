# Caravel User Project CI2409 Counter with 7-seg output

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0) [![UPRJ_CI](https://github.com/efabless/caravel_project_example/actions/workflows/user_project_ci.yml/badge.svg)](https://github.com/efabless/caravel_project_example/actions/workflows/user_project_ci.yml) [![Caravel Build](https://github.com/efabless/caravel_project_example/actions/workflows/caravel_build.yml/badge.svg)](https://github.com/efabless/caravel_project_example/actions/workflows/caravel_build.yml)

This is mostly the same as https://github.com/jeffdi/ci2409_test. General features are:

*   Simple 16-bit binary up-counter is the core of the design.
*   `GPIO[35:0]` are all outputs, but actual set of outputs is selected by `GPIO[36]` (`mode` input).
*   Via `mode` select between:
    0.  Counter's hex value is output as 4x 7seg digits, with `count[7:0]` available too.
    1.  Counter's 16-bit binary value is output, plus lowest hex 7seg, and several debug signals.
*   Polarity of the 7seg pattern (active-high or active-low) follows the input level on `GPIO[37]` (`digit_pol`)
*   The counter value is internally looped back to `LA[111:96]`
*   While held in reset, all outputs should tri-state (i.e. they are configured as BIDIRECTIONAL and their OEBs switch them to inputs).
*   The counter value can be updated in firmware via a Wishbone write, i.e. a write to any register address in the range `0x30000000..0x30FFFFFF`.
*   Firmware can use LA to override either the full 'count' value (if using a write mask of 0xFFFF), or otherwise some masked pattern of bits within its next value.
*   Firmware can use LA to override the design's `clk`, `rst`, and `digit_pol` input signals.
*   Internal IRQs are available for:
    0.  Whenever counter hits 0.
    1.  Whenever counter hits a value present on `LA[95:80]`
    2.  Whenever `mode` changes.

Refer to [README](docs/source/index.md) for the standard Caravel User Project documentation which also applies to this example.

## Output mode selection

`IN[36]` specifies what `mode` we are in, to determine how outputs behave. The following are common to both modes:

| GPIO   | Dir | Function         |
|-|-|-|
| 35:29  | Out | `digit0`         |
| 7:0    | Out | `count[7:0]`     |

NOTE: This `mode` input on GPIO 36 can be overridden by `LA[67]`.


### Mode 0 outputs: full counter, 1 hex digit (7seg), some debug signals

| GPIO   | Dir | Function               |
|-|-|-|
| 37     | In  | `digit_pol`            |
| 36     | In  | `mode`==0              |
| 35:29  | Out | `digit0`               |
| 28:25  | Out | `la_oenb[67:64]`       |
| 24:21  | Out | `la_data_out[67:64]`   |
| 20     | Out | (Unused)               |
| 19     | Out | `rst`                  |
| 18     | Out | `valid`                |
| 17     | Out | Any `la_write` high?   |
| 16     | Out | Any `wstrb` high?      |
| 15:0   | Out | `count[15:0]`          |

### Mode 1 outputs: 8 LSB of counter, 4 hex digits (7seg)

| GPIO   | Dir | Function               |
|-|-|-|
| 37     | In  | `digit_pol`            |
| 36     | In  | `mode`==1              |
| 35:29  | Out | `digit0`               |
| 28:22  | Out | `digit1`               |
| 21:15  | Out | `digit2`               |
| 14:8   | Out | `digit3`               |
| 7:0    | Out | `count[7:0]`           |


### Mode 0: Counter 4x 7seg

*   37: mode==0
*   36: pol
*   35:29: digit0
*   28:0: ...etc...

### Mode 1: raybox-zero

*   37: mode==1
*   36: pol
*   35:29: digit0
*   28:21: VGA outs
*   20:18: SPI1
*   17:15: SPI2
*   14:10: tex SPI
*   9: inc_px
*   8: inc_py
*   7: gen_tex
*   6: reg
*   5: debug
*   4:0: counter[4:0] (or HKSPI)

