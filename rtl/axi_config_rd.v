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
module axi_config_rd #(
    // Width of address bus in bits
    parameter ADDR_WIDTH    = 32,
    // Width of input (slave) interface data bus in bits
    parameter DATA_WIDTH    = 32,
    // Width of input (slave) interface wstrb (width of data bus in words)
    parameter STRB_WIDTH    = (DATA_WIDTH / 8),
    // Width of ID signal
    parameter ID_WIDTH      = 8,
    // Propagate aruser signal
    parameter ARUSER_ENABLE = 0,
    // Width of aruser signal
    parameter ARUSER_WIDTH  = 1,
    // Propagate ruser signal
    parameter RUSER_ENABLE  = 0,
    // Width of ruser signal
    parameter RUSER_WIDTH   = 1,
    parameter REG_DATA      = 1
) (
    input wire clk,
    input wire rst,

    /*
     * AXI slave interface
     */
    input  wire [    ID_WIDTH-1:0] s_axi_arid,
    input  wire [  ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire [             7:0] s_axi_arlen,
    input  wire [             2:0] s_axi_arsize,
    input  wire [             1:0] s_axi_arburst,
    input  wire                    s_axi_arlock,
    input  wire [             3:0] s_axi_arcache,
    input  wire [             2:0] s_axi_arprot,
    input  wire [             3:0] s_axi_arqos,
    input  wire [             3:0] s_axi_arregion,
    input  wire [ARUSER_WIDTH-1:0] s_axi_aruser,
    input  wire                    s_axi_arvalid,
    output wire                    s_axi_arready,
    output wire [    ID_WIDTH-1:0] s_axi_rid,
    output wire [  DATA_WIDTH-1:0] s_axi_rdata,
    output wire [             1:0] s_axi_rresp,
    output wire                    s_axi_rlast,
    output wire [ RUSER_WIDTH-1:0] s_axi_ruser,
    output wire                    s_axi_rvalid,
    input  wire                    s_axi_rready,

    output wire                  rd,
    output wire [ADDR_WIDTH-1:0] raddr,
    output wire [ADDR_WIDTH-1:0] raddr_next,
    input  wire [DATA_WIDTH-1:0] rdata,
    input  wire                  rvalid

);

    //localparam G_INCR = DATA_WIDTH>>3;
    localparam G_INCR = 4;
    localparam G_FIFO_DEPTH = 4;
    localparam WORD_WIDTH = STRB_WIDTH;
    localparam WORD_SIZE = DATA_WIDTH / WORD_WIDTH;

    // bus width assertions
    initial begin
        if (WORD_SIZE * STRB_WIDTH != DATA_WIDTH) begin
            $error("Error: AXI slave interface data width not evenly divisble (instance %m)");
            $finish;
        end
        if (2 ** $clog2(WORD_WIDTH) != WORD_WIDTH) begin
            $error("Error: AXI slave interface word width must be even power of two (instance %m)");
            $finish;
        end
    end

    localparam [2:0]
    STATE_IDLE = 3'd0,
    STATE_DLY = 3'd1,
    STATE_DATA = 3'd2,
    STATE_DATA_READ = 3'd3,
    STATE_DATA_LAST = 3'd4;

    reg [2:0] state_reg = STATE_IDLE, state_next;



    reg [DATA_WIDTH-1:0] ydata_reg [G_FIFO_DEPTH-1:0];
    reg [DATA_WIDTH-1:0] ydata_next[G_FIFO_DEPTH-1:0];
    reg [$clog2(G_FIFO_DEPTH)-1:0] rindex_reg = 0, rindex_next;
    reg [$clog2(G_FIFO_DEPTH)-1:0] windex_reg = 0, windex_next;

    reg [ID_WIDTH-1:0] id_reg = {ID_WIDTH{1'b0}}, id_next;
    reg [ADDR_WIDTH-1:0] addr_reg = {ADDR_WIDTH{1'b0}}, addr_next;
    reg [DATA_WIDTH-1:0] xdata_reg = {DATA_WIDTH{1'b0}}, xdata_next;
    reg [DATA_WIDTH-1:0] data_reg = {DATA_WIDTH{1'b0}}, data_next;
    reg [DATA_WIDTH-1:0] data_skid_reg = {DATA_WIDTH{1'b0}}, data_skid_next;
    reg [RUSER_WIDTH-1:0] ruser_reg = {RUSER_WIDTH{1'b0}}, ruser_next;
    reg rd_reg = 1'b0, rd_next;
    reg [7:0] len_reg = {8{1'b0}}, len_next;

    reg s_axi_arready_reg = 1'b0, s_axi_arready_next;
    reg s_axi_rvalid_reg = 1'b0, s_axi_rvalid_next;
    reg s_axi_rlast_reg = 1'b0, s_axi_rlast_next;
    reg [ID_WIDTH-1:0] s_axi_rid_reg = {ID_WIDTH{1'b0}}, s_axi_rid_next;

    assign s_axi_arready = s_axi_arready_reg;
    assign s_axi_rdata   = ydata_reg[rindex_reg];
    assign s_axi_rvalid  = s_axi_rvalid_reg;
    assign s_axi_rlast   = s_axi_rlast_reg;
    assign s_axi_rid     = s_axi_rid_reg;
    assign s_axi_rresp   = 0;
    assign s_axi_ruser   = ruser_reg;
    assign raddr_next    = addr_next;
    assign raddr         = addr_reg;
    assign rd            = rd_reg;


    always @* begin
        state_next        = state_reg;

        id_next           = id_reg;
        addr_next         = addr_reg;
        ruser_next        = ruser_reg;
        len_next          = len_reg;
        rd_next           = 0;
        rindex_next       = rindex_reg;

        s_axi_arready_next = s_axi_arready_reg;
        s_axi_rvalid_next = s_axi_rvalid_reg;
        s_axi_rlast_next  = s_axi_rlast_reg;
        s_axi_rid_next    = s_axi_rid_reg;



        case (state_reg)
            STATE_IDLE: begin
                s_axi_arready_next = 1;
                s_axi_rvalid_next  = 0;
                s_axi_rlast_next   = 0;

                if (s_axi_arready_reg && s_axi_arvalid) begin
                    s_axi_arready_next = 1'b0;
                    id_next            = s_axi_arid;
                    len_next           = s_axi_arlen;
                    addr_next          = s_axi_araddr;
                    rd_next            = 1;
                    state_next         = STATE_DLY;
                end
            end

            STATE_DLY: begin
                state_next = STATE_DATA;
                if (0 != len_reg) begin
                    rd_next     = 1;
                    addr_next   = addr_reg + G_INCR;
                    rindex_next = 0;
                end
            end

            STATE_DATA: begin
                s_axi_rvalid_next = 1;
                s_axi_rid_next    = id_reg;
                if (2 >= len_reg) begin
                    rd_next = 0;
                end else begin
                    rd_next = 1;
                end
                if (0 == len_reg) begin
                    s_axi_rlast_next = 1;
                    state_next       = STATE_DATA_LAST;
                end else begin
                    addr_next  = addr_reg + G_INCR;
                    state_next = STATE_DATA_READ;
                end
            end


            STATE_DATA_READ: begin
                s_axi_rvalid_next = 1;
                if (s_axi_rready) begin
                    rindex_next = (rindex_reg + 1) % G_FIFO_DEPTH;
                    if (2 >= len_reg) begin
                        rd_next = 0;
                    end else begin
                        rd_next = 1;
                    end
                    addr_next = addr_reg + G_INCR;
                    if (1 >= len_reg) begin
                        s_axi_rlast_next = 1;
                        state_next       = STATE_DATA_LAST;
                    end else begin
                        len_next = len_reg - 1;
                    end
                end
            end
            STATE_DATA_LAST: begin
                s_axi_rlast_next  = 1;
                s_axi_rvalid_next = 1;
                if (s_axi_rready) begin
                    state_next        = STATE_IDLE;
                    s_axi_rlast_next  = 0;
                    s_axi_rvalid_next = 0;
                end
            end
            default: state_next = STATE_IDLE;
        endcase
    end

    integer i;
    // assign ydata_reg0 = ydata_reg[0];
    // assign ydata_reg1 = ydata_reg[1];
    // assign ydata_reg2 = ydata_reg[2];
    // assign ydata_reg3 = ydata_reg[3];
    always @* begin
        windex_next = windex_reg;
        for (i = 0; i < G_FIFO_DEPTH; i = i + 1) begin
            ydata_next[i] = ydata_reg[i];
        end
        if (STATE_IDLE == state_reg) begin
            windex_next = 0;
        end else if (rvalid) begin
            windex_next            = (windex_reg + 1) % G_FIFO_DEPTH;
            ydata_next[windex_reg] = rdata;
        end
    end


    always @(posedge clk) begin
        state_reg  <= state_next;

        id_reg     <= id_next;
        addr_reg   <= addr_next;
        data_reg   <= data_next;
        ruser_reg  <= ruser_next;
        rd_reg     <= rd_next;
        //rd_dly    <= rd_reg;
        len_reg    <= len_next;
        rindex_reg <= rindex_next;
        windex_reg <= windex_next;
        for (i = 0; i < G_FIFO_DEPTH; i = i + 1) begin
            ydata_reg[i] <= ydata_next[i];
        end
        s_axi_arready_reg <= s_axi_arready_next;
        s_axi_rvalid_reg  <= s_axi_rvalid_next;
        s_axi_rlast_reg   <= s_axi_rlast_next;
        s_axi_rid_reg     <= s_axi_rid_next;

        if (rst) begin
            state_reg         <= STATE_IDLE;
            s_axi_arready_reg <= 1'b0;
        end
    end

endmodule

`resetall
