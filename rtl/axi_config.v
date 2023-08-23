/*

Copyright (c) 2018 Alex Forencich

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
 * AXI4 config write
 */
module axi_config #
(
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of input (slave) interface data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of input (slave) interface wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Width of ID signal
    parameter ID_WIDTH = 8,
    // Propagate awuser signal
    parameter AWUSER_ENABLE = 0,
    // Width of awuser signal
    parameter AWUSER_WIDTH = 1,
    // Propagate wuser signal
    parameter WUSER_ENABLE = 0,
    // Width of wuser signal
    parameter WUSER_WIDTH = 1,
    // Propagate buser signal
    parameter BUSER_ENABLE = 0,
    // Width of buser signal
    parameter BUSER_WIDTH = 1,
    // Propagate aruser signal
    parameter ARUSER_ENABLE = 0,
    // Width of aruser signal
    parameter ARUSER_WIDTH = 1,
    // Propagate ruser signal
    parameter RUSER_ENABLE = 0,
    // Width of ruser signal
    parameter RUSER_WIDTH = 1,
    parameter SINGLE_ADDR = 0,
    parameter REG_DATA = 1
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*
     * AXI slave interface
     */
    input  wire [ID_WIDTH-1:0]      s_axi_awid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_awaddr,
    input  wire [7:0]               s_axi_awlen,
    input  wire [2:0]               s_axi_awsize,
    input  wire [1:0]               s_axi_awburst,
    input  wire                     s_axi_awlock,
    input  wire [3:0]               s_axi_awcache,
    input  wire [2:0]               s_axi_awprot,
    input  wire [3:0]               s_axi_awqos,
    input  wire [3:0]               s_axi_awregion,
    input  wire [AWUSER_WIDTH-1:0]  s_axi_awuser,
    input  wire                     s_axi_awvalid,
    output wire                     s_axi_awready,
    input  wire [DATA_WIDTH-1:0]    s_axi_wdata,
    input  wire [STRB_WIDTH-1:0]    s_axi_wstrb,
    input  wire                     s_axi_wlast,
    input  wire [WUSER_WIDTH-1:0]   s_axi_wuser,
    input  wire                     s_axi_wvalid,
    output wire                     s_axi_wready,
    output wire [ID_WIDTH-1:0]      s_axi_bid,
    output wire [1:0]               s_axi_bresp,
    output wire [BUSER_WIDTH-1:0]   s_axi_buser,
    output wire                     s_axi_bvalid,
    input  wire                     s_axi_bready,

    input  wire [ID_WIDTH-1:0]      s_axi_arid,
    input  wire [ADDR_WIDTH-1:0]    s_axi_araddr,
    input  wire [7:0]               s_axi_arlen,
    input  wire [2:0]               s_axi_arsize,
    input  wire [1:0]               s_axi_arburst,
    input  wire                     s_axi_arlock,
    input  wire [3:0]               s_axi_arcache,
    input  wire [2:0]               s_axi_arprot,
    input  wire [3:0]               s_axi_arqos,
    input  wire [3:0]               s_axi_arregion,
    input  wire [ARUSER_WIDTH-1:0]  s_axi_aruser,
    input  wire                     s_axi_arvalid,
    output wire                     s_axi_arready,
    output wire [ID_WIDTH-1:0]      s_axi_rid,
    output wire [DATA_WIDTH-1:0]    s_axi_rdata,
    output wire [1:0]               s_axi_rresp,
    output wire                     s_axi_rlast,
    output wire [RUSER_WIDTH-1:0]   s_axi_ruser,
    output wire                     s_axi_rvalid,
    input  wire                     s_axi_rready,

    output wire [ADDR_WIDTH-1:0]    raddr,
    output wire                     rd,
    input  wire [DATA_WIDTH-1:0]    rdata,
    input  wire                     rvalid,
    output wire                     wr,
    output wire [ADDR_WIDTH-1:0]    waddr,
    output wire [DATA_WIDTH-1:0]    wdata,
    output wire [STRB_WIDTH-1:0]    wstrb
);
    
    wire w_rd;
    wire w_wr;
    wire[ADDR_WIDTH-1:0] w_raddr;
    wire[ADDR_WIDTH-1:0] w_waddr;
    
    wire w_axi_awvalid;
    wire w_axi_arvalid;
    wire w_axi_awready;
    wire w_axi_arready;

    generate
        if (0 == SINGLE_ADDR) begin
            assign w_axi_awvalid = s_axi_awvalid;
            assign s_axi_awready = w_axi_awready;
            assign w_axi_arvalid = s_axi_arvalid;
            assign s_axi_arready = w_axi_arready;
            assign waddr = w_waddr;
            assign raddr = w_raddr;
        end else begin

            reg f_write_transaction;
            reg d_write_transaction;
            reg f_read_transaction;
            reg d_read_transaction;

            assign w_axi_awvalid = s_axi_awvalid & ~f_read_transaction;
            assign s_axi_awready = w_axi_awready & ~f_read_transaction;
            assign w_axi_arvalid = s_axi_arvalid & ~f_write_transaction & ~d_write_transaction;
            assign s_axi_arready = w_axi_arready & ~f_write_transaction & ~d_write_transaction;
            
            always @* begin
                d_write_transaction = f_write_transaction;
                d_read_transaction = f_read_transaction;
                if (1 == w_axi_awvalid && 1 == w_axi_awready && 0 == f_read_transaction) begin
                    d_write_transaction = 1;
                end
                if (s_axi_wlast) begin
                    d_write_transaction = 0;
                end
                if (1 == w_axi_arvalid && 1 == w_axi_arready && 0 == f_write_transaction) begin
                    d_read_transaction = 1;
                end
                if (s_axi_rlast) begin
                    d_read_transaction = 0;
                end
            end

            always @(posedge clk) begin
                if (rst) begin
                    f_write_transaction <= 0;
                    f_read_transaction <= 0;
                end else begin
                    f_write_transaction <= d_write_transaction;
                    f_read_transaction <= d_read_transaction;
                end
            end

//             always @(posedge clk) begin
//                 if (1 == w_rd && 1 == w_wr) begin
//                     $error("Error: Read and Write are asserted at the same time");
//                     $finish;
//                 end
//             end

            assign waddr = w_waddr;
            assign raddr = w_raddr;
        end
   endgenerate

    axi_config_wr #(
          .ADDR_WIDTH (ADDR_WIDTH)
          , .DATA_WIDTH (DATA_WIDTH)
          , .ID_WIDTH (ID_WIDTH)
    ) i_axi_config_wr (
          .*
          ,.s_axi_awready (w_axi_awready)
          ,.s_axi_awvalid (w_axi_awvalid)
          ,.wr (w_wr)
          ,.waddr (w_waddr)
    );    

    axi_config_rd #(
          .ADDR_WIDTH (ADDR_WIDTH)
          , .DATA_WIDTH (DATA_WIDTH)
          , .ID_WIDTH (ID_WIDTH)
        , .REG_DATA(REG_DATA)
    ) i_axi_config_rd (
          .*
          ,.s_axi_arready (w_axi_arready)
          ,.s_axi_arvalid (w_axi_arvalid)
          ,.rd (w_rd)
          ,.raddr (w_raddr)
    );    

assign wr = w_wr;
assign rd = w_rd;
//assign waddr = w_waddr;
//assign raddr = w_raddr;

endmodule

`resetall
