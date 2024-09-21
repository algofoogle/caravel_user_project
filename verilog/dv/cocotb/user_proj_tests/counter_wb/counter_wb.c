// SPDX-FileCopyrightText: 2023 Efabless Corporation

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

//      http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


#include <firmware_apis.h>

void pulse_gpio() {
    ManagmentGpio_write(1);
    ManagmentGpio_write(0);
}

void main(){
    // Enable SoC's "gpio" pin as output to use as indicator for finishing configuration:
    ManagmentGpio_write(0); // Start with mgmt gpio at 0.
    ManagmentGpio_outputEnable();
    pulse_gpio(); // Signal start of config.

    // Disable housekeeping SPI:
    enableHkSpi(0);

    // Signal via la_oenb[66:65] that we want to override the rst & pol signals:
    // 64: clk - 1 = keep free-running
    // 65: rst - 0 = override rst signal
    // 66: pol - 0 = override digit_pol_in
    LogicAnalyzer_outputEnable(2, 0b001);
    // NOTE: Inverse is written to la_oenb registers, but this gets inverted in-circuit?

    // Hold pol high, and hold rst asserted:
    LogicAnalyzer_write(2,0b110); // rst high

    pulse_gpio(); // Signal initial LA config done.

    // Set our preferred GPIO modes:
    reg_mprj_io_0  = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // count[0]
    reg_mprj_io_1  = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // count[1]
    reg_mprj_io_2  = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // count[2]
    reg_mprj_io_3  = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // count[3]
    reg_mprj_io_4  = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // count[4]
    reg_mprj_io_5  = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // count[5]
    reg_mprj_io_6  = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // count[6]
    reg_mprj_io_7  = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // count[7]
    reg_mprj_io_8  = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // digit0_out[0]
    reg_mprj_io_9  = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // digit0_out[1]
    reg_mprj_io_10 = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // digit0_out[2]
    reg_mprj_io_11 = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // digit0_out[3]
    reg_mprj_io_12 = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // digit0_out[4]
    reg_mprj_io_13 = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // digit0_out[5]
    reg_mprj_io_14 = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // digit0_out[6]

    reg_mprj_io_15 = GPIO_MODE_MGMT_STD_INPUT_NOPULL;   // Unused
    reg_mprj_io_16 = GPIO_MODE_MGMT_STD_INPUT_NOPULL;   // Unused
    reg_mprj_io_17 = GPIO_MODE_MGMT_STD_INPUT_NOPULL;   // Unused
    reg_mprj_io_18 = GPIO_MODE_MGMT_STD_INPUT_NOPULL;   // Unused
    reg_mprj_io_19 = GPIO_MODE_MGMT_STD_INPUT_NOPULL;   // Unused
    reg_mprj_io_20 = GPIO_MODE_MGMT_STD_INPUT_NOPULL;   // Unused
    reg_mprj_io_21 = GPIO_MODE_MGMT_STD_INPUT_NOPULL;   // Unused
    reg_mprj_io_22 = GPIO_MODE_MGMT_STD_INPUT_NOPULL;   // Unused
    reg_mprj_io_23 = GPIO_MODE_MGMT_STD_INPUT_NOPULL;   // Unused
    reg_mprj_io_24 = GPIO_MODE_MGMT_STD_INPUT_NOPULL;   // Unused
    reg_mprj_io_25 = GPIO_MODE_MGMT_STD_INPUT_NOPULL;   // Unused
    reg_mprj_io_26 = GPIO_MODE_MGMT_STD_INPUT_NOPULL;   // Unused
    reg_mprj_io_27 = GPIO_MODE_MGMT_STD_INPUT_NOPULL;   // Unused
    reg_mprj_io_28 = GPIO_MODE_MGMT_STD_INPUT_NOPULL;   // Unused

    reg_mprj_io_29 = GPIO_MODE_USER_STD_INPUT_NOPULL;   // digit_pol_in
    reg_mprj_io_30 = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // count[8]
    reg_mprj_io_31 = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // count[9]
    reg_mprj_io_32 = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // count[10]
    reg_mprj_io_33 = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // count[11]
    reg_mprj_io_34 = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // count[12]
    reg_mprj_io_35 = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // count[13]
    reg_mprj_io_36 = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // count[14]
    reg_mprj_io_37 = GPIO_MODE_USER_STD_BIDIRECTIONAL;  // count[15]

    // Load the above configuration:
    GPIOs_loadConfigs();

    pulse_gpio(); // Signal GPIO config done.
    //NOTE: Since rst is asserted,
    // BIDIRECTIONAL pins should all be inputs now, thus hi-z in the TB.

    // Enable user project Wishbone interface...
    // This necessary when reading or writing between Wishbone and user project.
    // If interface isn't enabled, no wb_ack can be received by the CPU,
    // and the command will hang for 1 million cycles before timing out:
    User_enableIF();

    // Reset counter, by pulsing rst via LA.
    // NOTE: pol is held high (active-high LED segment outputs).
    LogicAnalyzer_write(2,0b100); // rst low
    LogicAnalyzer_write(2,0b110); // rst high
    LogicAnalyzer_write(2,0b100); // rst low again

    // Signal that configuration is finished and rst has been released.
    pulse_gpio();

    // Writing to ANY address inside user project address space
    // reloads the counter value:
    USER_writeWord(0x7, 0x88);

    // Signal that we have updated the counter value via Wishbone.
    pulse_gpio();

    return;
}