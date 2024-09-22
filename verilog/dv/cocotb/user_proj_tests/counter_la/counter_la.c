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

void main(){
    // Enable managment gpio as output to use as indicator for finishing configuration  
    ManagmentGpio_outputEnable();
    ManagmentGpio_write(0);
    enableHkSpi(0); // disable housekeeping spi
    // Set all GPIOs to be bidirectional by default...
    GPIOs_configureAll(GPIO_MODE_USER_STD_BIDIRECTIONAL);
    // ...though upper 2 need to be inputs:
    GPIOs_configure(36, GPIO_MODE_USER_STD_INPUT_NOPULL);
    GPIOs_configure(37, GPIO_MODE_USER_STD_INPUT_NOPULL);
    GPIOs_loadConfigs(); // load the configuration 
    ManagmentGpio_write(1); // configuration finished 
    LogicAnalyzer_write(1,7<<16); // Prep counter value 7 in upper 16 bits of LA bank 1.
    // Configure LA [63:32] all as output from CPU:
    LogicAnalyzer_outputEnable(1,0x00000000); // This triggers writing 7 to counter.
    ManagmentGpio_write(0); // configuration finished 
    LogicAnalyzer_outputEnable(1,0xFFFFFFFF); // Done writing.
    return;
}