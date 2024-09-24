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

    wire mode_in        = io_in[37];    // 0 = Binary output on out[37:22]; 1 = 4x 7seg hex output on out[37:10]
    wire digit_pol_in   = io_in[36];    // Polarity for segments of digit0: 0=active-low, 1=active-high
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

    // Logic below lets 'mode' select between two different sets of output
    // for all chip GPIOs 35 down to 0:
    assign io_out[35:0] = mode ? mode1_outs : mode0_outs;
    assign io_oeb[35:0] = mode ? mode1_oebs : mode0_oebs;

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

    wire [35:0] mode0_oebs;
    assign mode0_oebs[35:0]     = 36'b0; // All outputs.

    wire [35:0] mode1_outs;
    assign mode1_outs[35:29]    = digit_segments[0];
    assign mode1_outs[28:21]    = rb_vga_out;   // uo[7:0]
    assign mode1_outs[20:18]    = 3'b000;       // Input: SPI1
    assign mode1_outs[17:15]    = 3'b000;       // Input: SPI2
    assign mode1_outs[14]       = rb_tex_csb;
    assign mode1_outs[13]       = rb_tex_sclk;
    assign mode1_outs[12]       = rb_tex_out0;  // Bidir: tex_io0
    assign mode1_outs[11]       = 1'b0;         // Input: tex_io1
    assign mode1_outs[10]       = 1'b0;         // Input: tex_io2
    assign mode1_outs[9]        = 1'b0;         // Input: inc_px
    assign mode1_outs[8]        = 1'b0;         // Input: inc_py
    assign mode1_outs[7]        = 1'b0;         // Input: gen_tex
    assign mode1_outs[6]        = 1'b0;         // Input: reg
    assign mode1_outs[5]        = 1'b0;         // Input: debug
    assign mode1_outs[4:0]      = count[4:0];

    wire [35:0] mode1_oebs;
    assign mode1_oebs[35:29]    = 7'b0000000;   // digit0
    assign mode1_oebs[28:21]    = 8'b00000000;  // rb_vga_out
    assign mode1_oebs[20:18]    = 3'b111;       // Input: SPI1
    assign mode1_oebs[17:15]    = 3'b111;       // Input: SPI2
    assign mode1_oebs[14]       = 1'b0;         // rb_tex_csb
    assign mode1_oebs[13]       = 1'b0;         // rb_tex_sclk
    assign mode1_oebs[12]       = rb_tex_oeb0;  // Bidir
    assign mode1_oebs[11:5]     = 7'b1111111;   // All inputs.
    assign mode1_oebs[4:0]      = 5'b00000;     // count[4:0]

    wire        rb_tex_csb;
    wire        rb_tex_sclk;
    wire        rb_tex_out0;
    wire        rb_tex_oeb0;
    wire        rb_i_debug_m    = (~la_oenb[68]) ? la_data_in[68] : 1'b0;
    wire        rb_i_debug_t    = (~la_oenb[69]) ? la_data_in[69] : 1'b0;
    wire        rb_i_vec_sclk   = (~la_oenb[70]) ? la_data_in[70] : io_in[20];
    wire        rb_i_vec_mosi   = (~la_oenb[71]) ? la_data_in[71] : io_in[19];
    wire        rb_i_vec_ss_n   = (~la_oenb[72]) ? la_data_in[72] : io_in[18];
    wire        rb_i_reg_sclk   = (~la_oenb[73]) ? la_data_in[73] : io_in[17];
    wire        rb_i_reg_mosi   = (~la_oenb[74]) ? la_data_in[74] : io_in[16];
    wire        rb_i_reg_ss_n   = (~la_oenb[75]) ? la_data_in[75] : io_in[15];
    wire        rb_i_inc_px     = (~la_oenb[76]) ? la_data_in[76] : io_in[9];
    wire        rb_i_inc_py     = (~la_oenb[77]) ? la_data_in[77] : io_in[8];
    wire        rb_i_gen_tex    = (~la_oenb[78]) ? la_data_in[78] : io_in[7];
    wire        rb_i_reg        = (~la_oenb[79]) ? la_data_in[79] : io_in[6];
    wire        rb_i_debug_v    = (~la_oenb[80]) ? la_data_in[80] : io_in[5];
    wire [3:0]  rb_i_tex_in;
    assign      rb_i_tex_in = {
                                  1'b0,
                                  (~la_oenb[81]) ? la_data_in[81] : io_in[12],
                                  (~la_oenb[82]) ? la_data_in[82] : io_in[11],
                                  (~la_oenb[83]) ? la_data_in[83] : io_in[10]
                                };

    // LA
    assign la_data_out = {{(128-BITS){1'b0}}, count};
    // LA probes [63:32] are for controlling the count register  
    assign la_write = ~la_oenb[63:64-BITS] & ~{BITS{valid}};
    // LA probes [65:64] are for controlling the count clk & reset  
    assign clk      = (~la_oenb[64]) ? la_data_in[64] : wb_clk_i;
    assign rst      = (~la_oenb[65]) ? la_data_in[65] : wb_rst_i;
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
        .wdata(wdata),
        .wstrb(wstrb),
        .la_write(la_write),
        .la_input(la_data_in[63:64-BITS]),
        .count(count)
    );

    wire [9:0] hpos;
    wire [9:0] vpos;

    rbzero rbzero(
        .clk        (clk),
        .reset      (rst),

        // SPI peripheral interface for updating vectors:
        .i_sclk     (rb_i_vec_sclk),
        .i_mosi     (rb_i_vec_mosi),
        .i_ss_n     (rb_i_vec_ss_n),

        // SPI peripheral interface for everything else:
        .i_reg_sclk (rb_i_reg_sclk),
        .i_reg_mosi (rb_i_reg_mosi),
        .i_reg_ss_n (rb_i_reg_ss_n),

        // SPI controller interface for reading SPI flash memory (i.e. textures):
        .o_tex_csb  (rb_tex_csb),
        .o_tex_sclk (rb_tex_sclk),
        .o_tex_out0 (rb_tex_out0),
        .o_tex_oeb0 (rb_tex_oeb0), // Direction control for io[0] (WARNING: OEb, not OE).
        .i_tex_in   (rb_i_tex_in), //NOTE: io[3] is unused, currently.
        
        // Debug/demo signals:
        .i_debug_m  (rb_i_debug_m), // Map debug overlay
        .i_debug_t  (rb_i_debug_t), // Trace debug overlay
        .i_debug_v  (rb_i_debug_v), // Vectors debug overlay
        .i_inc_px   (rb_i_inc_px),
        .i_inc_py   (rb_i_inc_py),
        .i_gen_tex  (rb_i_gen_tex), // 1=Use bitwise-generated textures instead of SPI texture memory.
        // .o_vinf     (vinf),
        // .o_hmax     (hmax),
        // .o_vmax     (vmax),
        // VGA outputs:
        // .o_hblank   (uio_out[0]),
        // .o_vblank   (uio_out[1]),
        .hpos       (hpos),
        .vpos       (vpos),
        .hsync_n    (hsync_n), // Unregistered.
        .vsync_n    (vsync_n), // Unregistered.
        .rgb        (rgb)
    );

    wire  [5:0] rgb;
    wire        vsync_n;
    wire        hsync_n;
    reg   [7:0] registered_vga_output;
    wire  [7:0] unregistered_vga_output = {hsync_n, vsync_n, rgb};

    always @(posedge clk) registered_vga_output <= unregistered_vga_output;

    wire [7:0] rb_vga_out = rb_i_reg ? registered_vga_output : unregistered_vga_output;

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
