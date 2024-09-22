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

    // Signal via la_oenb[67:65] which signals we want to override:
    // 64: clk : 1 = keep free-running
    // 65: rst : 0 = override rst signal
    // 66: pol : 0 = override digit_pol_in
    // 67: mode: 1 = use external mode_in
    LogicAnalyzer_outputEnable(2, 0b1001);
    // NOTE: Inverse is written to la_oenb registers, but this gets inverted in-circuit?

    // Hold pol high, and hold rst asserted:
    LogicAnalyzer_write(2,0b1110); // rst high

    pulse_gpio(); // Signal initial LA config done.

    // Set all GPIOs to be bidirectional by default...
    GPIOs_configureAll(GPIO_MODE_USER_STD_BIDIRECTIONAL);
    // ...though upper 2 need to be inputs:
    GPIOs_configure(36, GPIO_MODE_USER_STD_INPUT_NOPULL);
    GPIOs_configure(37, GPIO_MODE_USER_STD_INPUT_NOPULL);

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
    LogicAnalyzer_write(2,0b1100); // rst low
    LogicAnalyzer_write(2,0b1110); // rst high
    LogicAnalyzer_write(2,0b1100); // rst low again

    // Signal that configuration is finished and rst has been released.
    pulse_gpio();

    // Writing to ANY address inside user project address space
    // reloads the counter value:
    USER_writeWord(0x7, 0x88);

    // Signal that we have updated the counter value via Wishbone.
    pulse_gpio();

    return;
}