# SPDX-FileCopyrightText: 2023 Efabless Corporation

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# SPDX-License-Identifier: Apache-2.0


from caravel_cocotb.caravel_interfaces import test_configure
from caravel_cocotb.caravel_interfaces import report_test
import cocotb

async def mgmt_gpio_pulse(caravelEnv):
    await caravelEnv.wait_mgmt_gpio(1)
    await caravelEnv.wait_mgmt_gpio(0)

def counter_value(caravelEnv):
    return int((caravelEnv.monitor_gpio(37,30).binstr + caravelEnv.monitor_gpio(7,0).binstr),2)

@cocotb.test()
@report_test
async def counter_wb(dut):
    caravelEnv = await test_configure(dut,timeout_cycles=26000)

    # io_in[29]=1: hold digit_pol_in is high.
    caravelEnv.drive_gpio_in(29, 1)

    cocotb.log.info(f"[TEST] Start counter_wb test")
    await caravelEnv.release_csb()

    # Wait for each stage of the firmware to signal its completion
    # via pulses on the management gpio pin:
    await mgmt_gpio_pulse(caravelEnv)
    cocotb.log.info(f"[TEST] Pulse 1: MGMT gpio start pulse")
    await mgmt_gpio_pulse(caravelEnv)
    cocotb.log.info(f"[TEST] Pulse 2: Initial LA config done")
    await mgmt_gpio_pulse(caravelEnv)
    cocotb.log.info(f"[TEST] Pulse 3: GPIO config done")
    await mgmt_gpio_pulse(caravelEnv)
    cocotb.log.info(f"[TEST] Pulse 4: Configuration done; counter rst released")

    # Value we expect the firmware will write to the counter, via Wishbone:
    overwrite_val = 7

    # Read current counter value
    # (expect a value >7, as it has been counting since we
    # released rst and pulsed the mgmt gpio, and that takes quite a few cycles):
    expected = counter_value(caravelEnv)
    cocotb.log.info(f"[TEST] Sampled counter value: {expected}")

    await cocotb.triggers.ClockCycles(caravelEnv.clk,1)

    # Track expected counter value with actual counter value...
    while True:
        actual = counter_value(caravelEnv)
        if expected == 0xFFFF: # rollover
            expected = 0
        else: 
            expected +=1
        # If actual counter value differs from expected, then
        # it hopefully means the firmware code updated the actual counter value...
        if actual != expected:
            cocotb.log.info(f"[TEST] Expected vs. actual counter differs: expected={expected} actual={actual}")
            if actual == overwrite_val:
                cocotb.log.info(f"[TEST] Counter value was overwritten by Wishbone to: {actual}")
                # Now wait until counter has started counting again
                # (so we know Wishbone writing is finished)
                expected = actual +1
                while True:
                    actual = counter_value(caravelEnv)
                    if expected == actual:
                        #SMELL: Make sure actual hasn't overshot or gone the wrong direction.
                        break
                    await cocotb.triggers.ClockCycles(caravelEnv.clk,1)
                # OK; counter is running again.
                cocotb.log.info(f"[TEST] Counter is now {actual}; started running again")
                break
            else: 
                cocotb.log.error(f"[TEST] Counter got wrong value before overwrite happened: expected={expected} actual={actual}")
        await cocotb.triggers.ClockCycles(caravelEnv.clk,1)

    # Now ensure counter continues to track for 100 more counts:
    for i in range(100):
        actual = counter_value(caravelEnv)
        if expected != actual:
            cocotb.log.error(f"[TEST] Counter has wrong value: expected={expected} actual={actual}")
        await cocotb.triggers.ClockCycles(caravelEnv.clk,1)
        expected +=1
