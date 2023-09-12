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

// Language: SystemVerilog

`resetall `timescale 1ns / 1ps

/*
 * AXI4 config write
 */
module axi_config #(
    // Width of address bus in bits
    integer ADDR_WIDTH = 32
    // Width of input (slave) interface data bus in bits
    , integer DATA_WIDTH = 32
    // Width of input (slave) interface wstrb (width of data bus in words)
    , integer STRB_WIDTH = (DATA_WIDTH / 8)
    // Width of ID signal
    , integer ID_WIDTH = 8
    // Propagate awuser signal
    , integer AWUSER_ENABLE = 0
    // Width of awuser signal
    , integer AWUSER_WIDTH = 1
    // Propagate wuser signal
    , integer WUSER_ENABLE = 0
    // Width of wuser signal
    , integer WUSER_WIDTH = 1
    // Propagate buser signal
    , integer BUSER_ENABLE = 0
    // Width of buser signal
    , integer BUSER_WIDTH = 1
    // Propagate aruser signal
    , integer ARUSER_ENABLE = 0
    // Width of aruser signal
    , integer ARUSER_WIDTH = 1
    // Propagate ruser signal
    , integer RUSER_ENABLE = 0
    // Width of ruser signal
    , integer RUSER_WIDTH = 1
    , integer SINGLE_ADDR = 0
    , integer REG_DATA = 1
) (
      input                     clk
    , input                     rst
    , input  [    ID_WIDTH-1:0] s_axi_awid
    , input  [  ADDR_WIDTH-1:0] s_axi_awaddr
    , input  [             7:0] s_axi_awlen
    , input  [             2:0] s_axi_awsize
    , input  [             1:0] s_axi_awburst
    , input                     s_axi_awlock
    , input  [             3:0] s_axi_awcache
    , input  [             2:0] s_axi_awprot
    , input  [             3:0] s_axi_awqos
    , input  [             3:0] s_axi_awregion
    , input  [AWUSER_WIDTH-1:0] s_axi_awuser
    , input                     s_axi_awvalid
    , output                    s_axi_awready
    , input  [  DATA_WIDTH-1:0] s_axi_wdata
    , input  [  STRB_WIDTH-1:0] s_axi_wstrb
    , input                     s_axi_wlast
    , input  [ WUSER_WIDTH-1:0] s_axi_wuser
    , input                     s_axi_wvalid
    , output                    s_axi_wready
    , output [    ID_WIDTH-1:0] s_axi_bid
    , output [             1:0] s_axi_bresp
    , output [ BUSER_WIDTH-1:0] s_axi_buser
    , output                    s_axi_bvalid
    , input                     s_axi_bready
    , input  [    ID_WIDTH-1:0] s_axi_arid
    , input  [  ADDR_WIDTH-1:0] s_axi_araddr
    , input  [             7:0] s_axi_arlen
    , input  [             2:0] s_axi_arsize
    , input  [             1:0] s_axi_arburst
    , input                     s_axi_arlock
    , input  [             3:0] s_axi_arcache
    , input  [             2:0] s_axi_arprot
    , input  [             3:0] s_axi_arqos
    , input  [             3:0] s_axi_arregion
    , input  [ARUSER_WIDTH-1:0] s_axi_aruser
    , input                     s_axi_arvalid
    , output                    s_axi_arready
    , output [    ID_WIDTH-1:0] s_axi_rid
    , output [  DATA_WIDTH-1:0] s_axi_rdata
    , output [             1:0] s_axi_rresp
    , output                    s_axi_rlast
    , output [ RUSER_WIDTH-1:0] s_axi_ruser
    , output                    s_axi_rvalid
    , input                     s_axi_rready
    , output [  ADDR_WIDTH-1:0] raddr
    , output                    rd
    , input  [  DATA_WIDTH-1:0] rdata
    , input                     rvalid
    , output                    wr
    , output [  ADDR_WIDTH-1:0] waddr
    , output [  DATA_WIDTH-1:0] wdata
    , output [  STRB_WIDTH-1:0] wstrb
);

    logic                  w_rd;
    logic                  w_wr;
    logic [ADDR_WIDTH-1:0] w_raddr;
    logic [ADDR_WIDTH-1:0] w_waddr;

    logic                  w_axi_awvalid;
    logic                  w_axi_arvalid;
    logic                  w_axi_awready;
    logic                  w_axi_arready;

    generate
        if (0 == SINGLE_ADDR) begin
            assign w_axi_awvalid = s_axi_awvalid;
            assign s_axi_awready = w_axi_awready;
            assign w_axi_arvalid = s_axi_arvalid;
            assign s_axi_arready = w_axi_arready;
            assign waddr = w_waddr;
            assign raddr = w_raddr;
        end else begin

            logic f_write_transaction;
            logic d_write_transaction;
            logic f_read_transaction;
            logic d_read_transaction;

            assign w_axi_awvalid = s_axi_awvalid & ~f_read_transaction;
            assign s_axi_awready = w_axi_awready & ~f_read_transaction;
            assign w_axi_arvalid = s_axi_arvalid & ~f_write_transaction & ~d_write_transaction;
            assign s_axi_arready = w_axi_arready & ~f_write_transaction & ~d_write_transaction;

            always @* begin
                d_write_transaction = f_write_transaction;
                d_read_transaction  = f_read_transaction;
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
                    f_read_transaction  <= 0;
                end else begin
                    f_write_transaction <= d_write_transaction;
                    f_read_transaction  <= d_read_transaction;
                end
            end
            assign waddr = w_waddr;

`ifndef SYNTHESIS
            always @(posedge clk) begin
                if (1 == w_rd && 1 == w_wr) begin
                    $error("Error: Read and Write are asserted at the same time");
                    $finish;
                end
            end
`endif
            assign raddr = w_raddr;
        end
    endgenerate

    axi_config_wr #(
          .ADDR_WIDTH(ADDR_WIDTH)
        , .DATA_WIDTH(DATA_WIDTH)
        , .ID_WIDTH  (ID_WIDTH)
    ) i_axi_config_wr (
        .*
        , .s_axi_awready(w_axi_awready)
        , .s_axi_awvalid(w_axi_awvalid)
        , .wr           (w_wr)
        , .waddr        (w_waddr)
    );

    axi_config_rd #(
          .ADDR_WIDTH(ADDR_WIDTH)
        , .DATA_WIDTH(DATA_WIDTH)
        , .ID_WIDTH  (ID_WIDTH)
        , .REG_DATA  (REG_DATA)
    ) i_axi_config_rd (
        .*
        , .s_axi_arready(w_axi_arready)
        , .s_axi_arvalid(w_axi_arvalid)
        , .rd           (w_rd)
        , .raddr        (w_raddr)
    );

    assign wr = w_wr;
    assign rd = w_rd;
    //assign waddr = w_waddr;
    //assign raddr = w_raddr;

endmodule

`resetall
