/*

Copyright (c) 2023 Dave Keeshan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`resetall
`timescale 1ns / 1ps
`default_nettype none

/*
 * AXI4-Lite to AXI4 ID adapter
 */
module axil_axi_boost #
(
    // Width of AXI ID signal
    parameter AXI_ID_WIDTH = 8
) (
    input  wire                        clk,
    input  wire                        rst,

    input  wire [AXI_ID_WIDTH-1:0]     s_axi_awid,
    input  wire                        s_axi_awvalid,
    input  wire [AXI_ID_WIDTH-1:0]     s_axi_arid,
    input  wire                        s_axi_arvalid,
    input  wire                        s_axi_rvalid,
    output wire [AXI_ID_WIDTH-1:0]     s_axi_bid,
    output wire [AXI_ID_WIDTH-1:0]     s_axi_rid,
    output wire                        s_axi_rlast
);


   reg [AXI_ID_WIDTH-1:0] axi_awid_reg;
   reg [AXI_ID_WIDTH-1:0] axi_arid_reg;
   always @(posedge clk) begin : p_clk_id
       if (0 == rst) begin
           axi_awid_reg <= 0;
           axi_arid_reg <= 0;
       end else begin
           if (s_axi_awvalid) begin
               axi_awid_reg <= s_axi_awid;
           end
           if (s_axi_arvalid) begin
               axi_arid_reg <= s_axi_arid;
           end
       end
   end
   assign s_axi_bid = axi_awid_reg;
   assign s_axi_rid = axi_arid_reg;
   assign s_axi_rlast = s_axi_rvalid;

endmodule

`resetall
