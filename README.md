# Caravel User Project CI2409 Counter with 7-seg output

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0) [![UPRJ_CI](https://github.com/efabless/caravel_project_example/actions/workflows/user_project_ci.yml/badge.svg)](https://github.com/efabless/caravel_project_example/actions/workflows/user_project_ci.yml) [![Caravel Build](https://github.com/efabless/caravel_project_example/actions/workflows/caravel_build.yml/badge.svg)](https://github.com/efabless/caravel_project_example/actions/workflows/caravel_build.yml)

This is mostly the same as https://github.com/jeffdi/ci2409_test. General features are:

*   16-bit binary up-counter outputs its lower 8 bits via `GPIO[7:0]` and its upper 8 bits via `GPIO[37:30]`.
*   The lowest 4 bits of the counter are 7-segment-decoded as a hex value, and the 7seg pattern is presented on `GPIO[14:8]` (`digit0_out`).
*   The polarity of the 7seg pattern (active-high or active-low) follows the input level on `GPIO[29]` (`digit_pol_in`)
*   The counter value is internally looped back to `LA[111:96]`
*   While held in reset, all outputs should tri-state (i.e. they are configured as BIDIRECTIONAL and their OEBs switch them to inputs).
*   The counter value can be updated in firmware via a Wishbone write, i.e. a write to any register address in the range `0x30000000..0x30FFFFFF`.
*   Firmware can use some LA pins to override the design's `clk`, `rst`, and `digit_pol_in` input signals, and change bits of the counter value.

Refer to [README](docs/source/index.md) for the standard Caravel User Project documentation which also applies to this example.

## Output mode selection

`IN[36]` specifies what 'mode' we are in, to determine how outputs behave. The following are common to both modes:

| GPIO   | Dir | Function         |
|-|-|-|
| 35:29  | Out | `digit0`         |
| 7:0    | Out | `count[7:0]`     |

NOTE: This `mode` input on GPIO 36 can be overridden by `LA[67]`.


### Mode 0: Full counter and debug output

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

### Mode 1: Half-counter and full 7-seg output

| GPIO   | Dir | Function               |
|-|-|-|
| 37     | In  | `digit_pol`            |
| 36     | In  | `mode`==1              |
| 35:29  | Out | `digit0`               |
| 28:22  | Out | `digit1`               |
| 21:15  | Out | `digit2`               |
| 14:8   | Out | `digit3`               |
| 7:0    | Out | `count[7:0]`           |
