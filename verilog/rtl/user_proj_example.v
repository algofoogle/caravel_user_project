// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module user_proj_example #(
    parameter BITS = 16
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input               wb_clk_i,       // Core/Wishbone system clock.
    input               wb_rst_i,       // Core/Wishbone reset signal (active high).
    input               wbs_stb_i,
    input               wbs_cyc_i,
    input               wbs_we_i,
    input [3:0]         wbs_sel_i,
    input [31:0]        wbs_dat_i,
    input [31:0]        wbs_adr_i,
    output              wbs_ack_o,
    output [31:0]       wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0]      la_data_in,
    output [127:0]      la_data_out,
    input  [127:0]      la_oenb,

    // IOs
    input  [37:0]       io_in,
    output [37:0]       io_out,         // This 'reg' will synth to wires because of how it's used.
    output [37:0]       io_oeb,         // This 'reg' will synth to wires because of how it's used.

    // IRQ
    output [2:0] irq
);
    wire clk;
    wire rst;

    wire digit_pol_in   = io_in[37];    // Polarity for segments of digit0: 0=active-low, 1=active-high
    wire mode_in        = io_in[36];    // 0 = Binary output on out[37:22]; 1 = 4x 7seg hex output on out[37:10]
    assign io_out[37:36] = 2'b00;
    assign io_oeb[37:36] = 2'b11;

    wire [BITS-1:0] rdata; 
    wire [BITS-1:0] wdata;
    wire [BITS-1:0] count;

    wire valid;
    wire [3:0] wstrb;
    wire [BITS-1:0] la_write;

    // WB MI A
    assign valid = wbs_cyc_i && wbs_stb_i; 
    assign wstrb = wbs_sel_i & {4{wbs_we_i}};
    assign wbs_dat_o = {{(32-BITS){1'b0}}, rdata};
    assign wdata = wbs_dat_i[BITS-1:0];

    // Convert each nibble of count to a 7-segment hex digit output:
    wire [6:0] digit_segments [3:0];
    decode_7seg_hex digit [3:0] (
        .value(count),
        .polarity({4{digit_pol}}),
        .segments({
            digit_segments[3],
            digit_segments[2],
            digit_segments[1],
            digit_segments[0]
        })
    );
    //NOTE: decode_7seg_hex is instanced 4 times.
    // Each digit[n] converts 4 bits of 'count' to a digit_segments[n] instance.

    // IRQs (can be disabled in software):
    // IRQ0: Count hit zero:
    assign irq[0] = (count == 0);
    // IRQ1: Count hit a value equal to upper bits of LA bank 2:
    assign irq[1] = (count == la_data_in[95:96-BITS]);
    // IRQ2: Sensitive to changes on mode_in:
    assign irq[2] = mode_in;

    assign io_oeb[35:0] = {36{rst}}; // Tri-state outputs while rst is asserted.

    // Logic below lets 'mode' select between two different sets of output
    // for all chip GPIOs 35 down to 0:
    assign io_out[35:0] = mode ? mode1_outs : mode0_outs;
    wire [35:0] mode0_outs;
    assign mode0_outs[35:29]    = digit_segments[0];
    assign mode0_outs[28:25]    = la_oenb[67:64];
    assign mode0_outs[24:21]    = la_data_out[67:64];
    assign mode0_outs[20]       = 1'b0;
    assign mode0_outs[19]       = rst;
    assign mode0_outs[18]       = valid;
    assign mode0_outs[17]       = (|la_write);
    assign mode0_outs[16]       = (|wstrb);
    assign mode0_outs[15:0]     = count[15:0];
    wire [35:0] mode1_outs;
    assign mode1_outs[35:29]    = digit_segments[0];
    assign mode1_outs[28:22]    = digit_segments[1];
    assign mode1_outs[21:15]    = digit_segments[2];
    assign mode1_outs[14:8]     = digit_segments[3];
    assign mode1_outs[7:0]      = count[7:0];

    // LA
    assign la_data_out = {{(128-BITS){1'b0}}, count};
    // LA probes [63:32] are for controlling the count register  
    assign la_write = ~la_oenb[63:64-BITS] & ~{BITS{valid}};
    // LA probes [65:64] are for controlling the count clk & reset  
    assign clk      = (~la_oenb[64]) ? la_data_in[64]: wb_clk_i;
    assign rst      = (~la_oenb[65]) ? la_data_in[65]: wb_rst_i;
    // LA [66] can override digit_pol_in:
    wire digit_pol  = (~la_oenb[66]) ? la_data_in[66] : digit_pol_in;
    // LA [67] can override mode_in:
    wire mode       = (~la_oenb[67]) ? la_data_in[67] : mode_in;

    counter #(
        .BITS(BITS)
    ) counter(
        .clk(clk),
        .reset(rst),
        .ready(wbs_ack_o),
        .valid(valid),
        .rdata(rdata),
        .wdata(wbs_dat_i[BITS-1:0]),
        .wstrb(wstrb),
        .la_write(la_write),
        .la_input(la_data_in[63:64-BITS]),
        .count(count)
    );

endmodule


module counter #(
    parameter BITS = 16
)(
    input clk,
    input reset,
    input valid,
    input [3:0] wstrb,
    input [BITS-1:0] wdata,
    input [BITS-1:0] la_write,  // LA write mask: Which counter bits LA wants to overwrite.
    input [BITS-1:0] la_input,  // LA write data: Value of each bit we're writing.
    output reg ready,
    output reg [BITS-1:0] rdata,
    output reg [BITS-1:0] count
);

    always @(posedge clk) begin
        if (reset) begin
            count <= {BITS{1'b0}};
            ready <= 1'b0;
        end else begin
            //NOTE: By Verilog convention, on the next clock cycle
            // 'ready' and 'count' will take whichever is the LAST
            // assignment in the logic below.
            ready <= 1'b0;
            if (~|la_write) begin
                // By default, counter increments:
                count <= count + 1'b1;
            end
            if (valid && !ready) begin
                ready <= 1'b1;  // Valid WB transaction, so ACK it.
                rdata <= count; // Assume a WB read by default.
                // Handle WB writing 1 or both bytes of our 16-bit counter:
                if (wstrb[0]) count[7:0]   <= wdata[7:0];
                if (wstrb[1]) count[15:8]  <= wdata[15:8];
                //SMELL: Above assumes BITS==16.
            end else if (|la_write) begin
                // LA is being used to override either the full 'count' value,
                // or some masked pattern of its bits within its next value
                // (if la_write is not 0xFFFF):
                count <= ((count+1) & ~la_write) | (la_input & la_write);
            end
        end
    end

endmodule
`default_nettype wire


//   -- 0 --
//  |       |
//  5       1
//  |       |
//   -- 6 --
//  |       |
//  4       2
//  |       |
//   -- 3 --

module decode_7seg_hex(
    input [3:0]     value,
    input           polarity, // 0=active-low segments, 1=active-high segments
    output [6:0]    segments
);
    reg [6:0] s; // Should synth to a wire because of how it's used below...
    assign segments = polarity ? s : ~s;
    always @(*) case (value)
                 //   6543210
        4'h0:  s = 7'b0111111;
        4'h1:  s = 7'b0000110;
        4'h2:  s = 7'b1011011;
        4'h3:  s = 7'b1001111;
        4'h4:  s = 7'b1100110;
        4'h5:  s = 7'b1101101;
        4'h6:  s = 7'b1111101;
        4'h7:  s = 7'b0000111;
        4'h8:  s = 7'b1111111;
        4'h9:  s = 7'b1101111;
        4'hA:  s = 7'b1110111;
        4'hB:  s = 7'b1111100; // NOTE: 'b' looks very similar to '6'
        4'hC:  s = 7'b0111001;
        4'hD:  s = 7'b1011110;
        4'hE:  s = 7'b1111001;
        4'hF:  s = 7'b1110001;
    endcase

endmodule
