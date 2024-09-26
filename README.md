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

`IN[37]` specifies what `mode` we are in, to determine how outputs behave. The following are common to both modes:

| GPIO   | Dir | Function         |
|-|-|-|
| 35:29  | Out | `digit0`         |
| 4:0    | Out | `count[4:0]`     |

NOTE: This `mode` input on GPIO 37 can be overridden by `LA[67]`.


### Mode 0 outputs: full counter, 1 hex digit (7seg), some debug signals

| GPIO   | Dir | Function               |
|-|-|-|
| 37     | In  | `mode`==0              |
| 36     | In  | `digit_pol`            |
| 35:29  | Out | `digit0`               |
| 28:25  | Out | `la_oenb[67:64]`       |
| 24:21  | Out | `la_data_out[67:64]`   |
| 20     | Out | (Unused)               |
| 19     | Out | `rst`                  |
| 18     | Out | `valid`                |
| 17     | Out | Any `la_write` high?   |
| 16     | Out | Any `wstrb` high?      |
| 15:0   | Out | `count[15:0]`          |

### Mode 1 outputs: 5 LSB of counter, 1 hex digit (7seg), raybox-zero VGA output

| GPIO   | Dir | Function               |
|-|-|-|
| 37     | In  | `mode`==0              |
| 36     | In  | `digit_pol`            |
| 35:29  | Out | `digit0`               |
| 28     | Out | `hsync_n`              |
| 27     | Out | `vsync_n`              |
| 26:21  | Out | RrGgBb                 |
| 20     | Out | SPI1 `vec_sclk`        |
| 19     | Out | SPI1 `vec_mosi`        |
| 18     | Out | SPI1 `vec_csb`         |
| 17     | Out | SPI2 `reg_sclk`        |
| 16     | Out | SPI2 `reg_mosi`        |
| 15     | Out | SPI2 `reg_csb`         |
| 14     | Out | `tex_csb`              |
| 13     | Out | `gen_tex`              |
| 12     | Out | `tex_io0`              |
| 11     | Out | `tex_io1`              |
| 10     | Out | `tex_io2`              |
| 9      | Out | `inc_px`               |
| 8      | Out | `inc_py`               |
| 7      | Out | `tex_sclk`             |
| 6      | Out | `reg`                  |
| 5      | Out | `debug`                |
| 4:0    | Out | `count[4:0]`           |
