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

DIGIT_POL_IN = 37
MODE_IN = 36

async def mgmt_gpio_pulse(caravelEnv):
    await caravelEnv.wait_mgmt_gpio(1)
    await caravelEnv.wait_mgmt_gpio(0)

def counter_value(caravelEnv):
    return int(caravelEnv.monitor_gpio(15,0).binstr,2)

def hex_from_7seg(pattern):
    seg_map = {
        '0111111': 0x0,
        '0000110': 0x1,
        '1011011': 0x2,
        '1001111': 0x3,
        '1100110': 0x4,
        '1101101': 0x5,
        '1111101': 0x6,
        '0000111': 0x7,
        '1111111': 0x8,
        '1101111': 0x9,
        '1110111': 0xA,
        '1111100': 0xB,
        '0111001': 0xC,
        '1011110': 0xD,
        '1111001': 0xE,
        '1110001': 0xF
    }
    return seg_map.get(pattern)

# Read and interpret 7seg hex digit patterns to get counter value:
def counter_hex_digits(caravelEnv, lowest_only = False):
    if lowest_only:
        digit_ios = [ (35,29) ] # digit0.
    else:
        digit_ios = [ (14,8), (21,15), (28,22), (35,29) ] # digit3 down to digit0.
    counter = 0
    for r in digit_ios:
        counter <<= 4
        o = caravelEnv.monitor_gpio(*r).binstr
        n = hex_from_7seg(o)
        if n is None:
            cocotb.log.error(f"Invalid 7seg digit {o} in {caravelEnv.monitor_gpio(37,0)}")
            return -1
        counter |= n
    return counter

@cocotb.test()
@report_test
async def counter_wb(dut):
    caravelEnv = await test_configure(dut,timeout_cycles=50000)

    # Hold digit_pol_in high:
    caravelEnv.drive_gpio_in(DIGIT_POL_IN, 1)
    # Hold mode low (for full counter output):
    caravelEnv.drive_gpio_in(MODE_IN, 0)

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
    cocotb.log.info(f"[TEST] Testing 100 counts in mode 0...")
    for i in range(100):
        actual = counter_value(caravelEnv)
        if expected != actual:
            cocotb.log.error(f"[TEST] Counter has wrong value: expected={expected} actual={actual}")
        # Check lowest 7seg hex digit:
        digit0_expected = expected & 0xF
        digit0_actual = counter_hex_digits(caravelEnv, lowest_only=True)
        if digit0_expected != digit0_actual:
            cocotb.log.error(f"[TEST] digit0 output is wrong: expected={digit0_expected} actual={digit0_actual}")
        await cocotb.triggers.ClockCycles(caravelEnv.clk,1)
        expected +=1

    # Now test 10,000 counts in mode 1 (to test all 4 hex digits)...
    # Hold mode high (for 4x digits output):
    cocotb.log.info(f"[TEST] Testing 10,000 counts in mode 1 (all 4 hex digits)...")
    caravelEnv.drive_gpio_in(MODE_IN, 1)
    for i in range(10000):
        await cocotb.triggers.ClockCycles(caravelEnv.clk,1)
        if expected == 0xFFFF: # rollover
            expected = 0
        else:
            expected +=1
        actual = counter_hex_digits(caravelEnv, lowest_only=False)
        if expected != actual:
            cocotb.log.error(f"[TEST] 4x Hex digits output is wrong: expected={expected} actual={actual} full={caravelEnv.monitor_gpio(37,0)}")
