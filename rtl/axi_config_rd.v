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
 * AXI4 width adapter
 */
module axi_config_rd #
(
    // Width of address bus in bits
    parameter ADDR_WIDTH = 32,
    // Width of input (slave) interface data bus in bits
    parameter DATA_WIDTH = 32,
    // Width of input (slave) interface wstrb (width of data bus in words)
    parameter STRB_WIDTH = (DATA_WIDTH/8),
    // Width of ID signal
    parameter ID_WIDTH = 8,
    // Propagate aruser signal
    parameter ARUSER_ENABLE = 0,
    // Width of aruser signal
    parameter ARUSER_WIDTH = 1,
    // Propagate ruser signal
    parameter RUSER_ENABLE = 0,
    // Width of ruser signal
    parameter RUSER_WIDTH = 1,
    parameter REG_DATA = 1
)
(
    input  wire                     clk,
    input  wire                     rst,

    /*
     * AXI slave interface
     */
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

    output wire                     rd,
    output wire [ADDR_WIDTH-1:0]    raddr,
    input  wire [DATA_WIDTH-1:0]    rdata,
    input  wire                     rvalid

);

parameter WORD_WIDTH = STRB_WIDTH;
parameter WORD_SIZE = DATA_WIDTH/WORD_WIDTH;

// bus width assertions
initial begin
    if (WORD_SIZE * STRB_WIDTH != DATA_WIDTH) begin
        $error("Error: AXI slave interface data width not evenly divisble (instance %m)");
        $finish;
    end
    if (2**$clog2(WORD_WIDTH) != WORD_WIDTH) begin
        $error("Error: AXI slave interface word width must be even power of two (instance %m)");
        $finish;
    end
end

localparam [1:0]
    STATE_IDLE = 2'd0,
    STATE_DATA = 2'd1,
    STATE_DATA_READ = 2'd2,
    STATE_DATA_LAST = 2'd3;

reg [1:0] state_reg = STATE_IDLE, state_next;

reg [ID_WIDTH-1:0] id_reg = {ID_WIDTH{1'b0}}, id_next;
reg [ADDR_WIDTH-1:0] addr_reg = {ADDR_WIDTH{1'b0}}, addr_next;
reg [DATA_WIDTH-1:0] data_reg = {DATA_WIDTH{1'b0}}, data_next;
reg [RUSER_WIDTH-1:0] ruser_reg = {RUSER_WIDTH{1'b0}}, ruser_next;
reg rd_reg = 1'b0, rd_next;
reg [7:0] len_reg = {8{1'b0}}, len_next;

reg s_axi_arready_reg = 1'b0, s_axi_arready_next;
reg  s_axi_rvalid_reg = 1'b0, s_axi_rvalid_next;
reg  s_axi_rlast_reg = 1'b0, s_axi_rlast_next;
reg  [ID_WIDTH-1:0] s_axi_rid_reg = {ID_WIDTH{1'b0}}, s_axi_rid_next;

assign s_axi_arready = s_axi_arready_reg;
//assign s_axi_rdata = data_reg;
assign s_axi_rdata = data_next;
//assign s_axi_rdata = REG_DATA ? data_reg : data_next;
assign s_axi_rvalid = s_axi_rvalid_reg;
assign s_axi_rlast = s_axi_rlast_reg;
assign s_axi_rid = s_axi_rid_reg;
assign s_axi_rresp = 0;
assign s_axi_ruser = ruser_reg;
assign raddr = addr_reg;
assign rd = rd_reg;


always @* begin
    state_next = STATE_IDLE;

    id_next = id_reg;
    addr_next = addr_reg;
    ruser_next = ruser_reg;
    len_next = len_reg;
    rd_next    = 0;

    data_next = data_reg;
    s_axi_rvalid_next = s_axi_rvalid_reg;
    s_axi_rlast_next = s_axi_rlast_reg;
    s_axi_rid_next = s_axi_rid_reg;
    case (state_reg)
        STATE_IDLE: begin
            // idle state; wait for new burst
            s_axi_arready_next = 1;
            s_axi_rvalid_next = 0;
            s_axi_rlast_next = 0;

            if (s_axi_arready_reg && s_axi_arvalid) begin
                s_axi_arready_next = 1'b0;
                id_next = s_axi_arid;
                len_next = s_axi_arlen;
                addr_next = s_axi_araddr;
                rd_next    = 1;
                state_next = STATE_DATA;
            end else begin
                state_next = STATE_IDLE;
            end
        end
        STATE_DATA: begin
            // data state; transfer read data
            s_axi_rvalid_next = 1;
            s_axi_rid_next = id_reg;
            rd_next    = 1;
            if  (0 == len_reg) begin
                s_axi_rlast_next = 1;
                rd_next    = 0;
                state_next = STATE_DATA_LAST;
            end else begin
                state_next = STATE_DATA_READ;
            end
            data_next = rdata;
            addr_next = addr_reg+4;
        end
        STATE_DATA_READ: begin
            state_next = STATE_DATA_READ;
            s_axi_rvalid_next = 1;
            rd_next    = 1;
            if (s_axi_rready) begin
                addr_next = addr_reg+4;
                data_next = rdata;
                if (1 >= len_reg) begin
                    s_axi_rlast_next = 1;
                    state_next = STATE_DATA_LAST;
                end else begin
                    len_next = len_reg-1;
                end
            end
        end
        STATE_DATA_LAST: begin
            s_axi_rlast_next = 1;
            s_axi_rvalid_next = 1;
            if (s_axi_rready) begin
                data_next = rdata;
                state_next = STATE_IDLE;
                s_axi_rlast_next = 0;
                s_axi_rvalid_next = 0;
            end else begin
                state_next = STATE_DATA_LAST;
            end
        end
    endcase
end


always @(posedge clk) begin
    state_reg <= state_next;

    id_reg <= id_next;
    addr_reg <= addr_next;
    data_reg <= data_next;
    ruser_reg <= ruser_next;
    rd_reg    <= rd_next;
    len_reg <= len_next;
    s_axi_arready_reg <= s_axi_arready_next;        
    s_axi_rvalid_reg <= s_axi_rvalid_next;
    s_axi_rlast_reg <= s_axi_rlast_next;
    s_axi_rid_reg <= s_axi_rid_next;

    if (rst) begin
        state_reg <= STATE_IDLE;
        s_axi_arready_reg <= 1'b0;
    end
end

endmodule

`resetall
