// SPDX-FileCopyrightText: 2025 IObundle
//
// SPDX-License-Identifier: MIT

// Language: Verilog 2001
`timescale 1ns / 1ps

/*
 * AXIS to AHB adapter
 */
module iob_axis2ahb #(
   // Width of address bus in bits
   parameter ADDR_WIDTH   = 32,
   // Width of input (slave/master) AXIS/AHB interface data bus in bits
   parameter DATA_WIDTH   = 32,
   // Width of input (slave/master) AXIS/AHB interface wstrb (width of data bus in words)
   parameter STRB_WIDTH   = (DATA_WIDTH / 8),
   // Width of AXI ID signal
   parameter AXI_ID_WIDTH = 8
) (
   `include "iob_axis2ahb_io.vs"
);
   localparam [2:0] HSIZE = $clog2(DATA_WIDTH/8);
   localparam [2:0] BURST_SINGLE = 3'b0, BURST_INCR = 3'b1;
   localparam [DATA_WIDTH-1:0] ADDR_STEP = DATA_WIDTH/8; // byte addressable memory

   localparam STATE_W = 2;
   localparam [STATE_W-1:0] WAIT_CONFIG = 0, WAIT_DATA = 1; 
   localparam [STATE_W-1:0] TRANSFER = 3, LAST_DATA = 4;
   localparam [1:0] TRANS_IDLE = 2'd0, TRANS_BUSY = 2'd1, TRANS_NONSEQ = 2'd2, TRANS_SEQ = 2'd3;

   // Constant Outputs
   // AHB
   assign m_ahb_mastlock_o = 1'b0;
   assign m_ahb_prot_o     = 4'b0011;
   assign m_ahb_size_o     = HSIZE; // always full data width
   assign m_ahb_sel_o      = 1'b1;
   // Managers can perform single transfers using:
   // undefined length burst (INCR) with length of 1.
   assign m_ahb_burst_o    - 3'b1;

   // COMPUTE AHB OUTPUTS

   // haddr
   reg [ADDR_WIDTH-1:0] haddr_nxt;
   iob_reg_r #(
      .DATA_W (ADDR_WIDTH),
      .RST_VAL(0)
   ) iob_reg_haddr (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (rst_i),
      .data_i(haddr_nxt),
      .data_o(m_ahb_addr_o)
   );

   // htrans
   reg [2-1:0] htrans_nxt;
   iob_reg_r #(
      .DATA_W (2),
      .RST_VAL(0)
   ) iob_reg_haddr (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (rst_i),
      .data_i(htrans_nxt),
      .data_o(m_ahb_trans_o)
   );

   // hwdata
   reg [DATA_WIDTH-1:0] hwdata_nxt;
   wire [DATA_WIDTH-1:0] hwdata_pipe;
   iob_reg_r #(
      .DATA_W (DATA_WIDTH),
      .RST_VAL(0)
   ) hwdata_pipe_reg (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (rst_i),
      .data_i(hwdata_nxt),
      .data_o(hwdata_pipe)
   );
   iob_reg_r #(
      .DATA_W (DATA_WIDTH),
      .RST_VAL(0)
   ) hwdata_reg (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (rst_i),
      .data_i(hwdata_pipe),
      .data_o(m_ahb_wdata_o)
   );

   // hwstrb
   reg [STRB_WIDTH-1:0] hwstrb_nxt;
   wire [STRB_WIDTH-1:0] hwstrb_pipe;
   iob_reg_r #(
      .DATA_W (STRB_WIDTH),
      .RST_VAL(0)
   ) hwstrb_pipe_reg (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (rst_i),
      .data_i(hwstrb_nxt),
      .data_o(hwstrb_pipe)
   );
   iob_reg_r #(
      .DATA_W (STRB_WIDTH),
      .RST_VAL(0)
   ) hwstrb_reg (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (rst_i),
      .data_i(hwstrb_pipe),
      .data_o(m_ahb_wstrb_o)
   );

   // hwrite
   reg hwrite_nxt;
   iob_reg_r #(
      .DATA_W (1),
      .RST_VAL(0)
   ) hwrite_reg (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (rst_i),
      .data_i(hwrite_nxt),
      .data_o(m_ahb_write_o)
   );

   // config registers
   reg [length_WIDTH-1:0] config_out_length_nxt;
   wire [length_WIDTH-1:0] config_out_length_int;
   iob_reg_r #(
      .DATA_W (STRB_WIDTH),
      .RST_VAL(0)
   ) config_out_length_reg (
      .clk_i (clk_i),
      .arst_i(arst_i),
      .cke_i (cke_i),
      .rst_i (rst_i),
      .data_i(config_out_length_nxt),
      .data_o(config_out_length_int)
   );


   // state register
   wire [STATE_W-1:0] state;
   reg [STATE_W-1:0] state_nxt;
   iob_reg_r #(
       .DATA_W(STATE_W),
       .RST_VAL(0)
   ) state_reg (
       .clk_i(clk_i),
       .arst_i(arst_i),
       .cke_i(cke_i),
       .rst_i(rst_i),
       .data_i(state_nxt),
       .data_o(state)
   );

   reg in_axis_ready_int;
   reg out_axis_valid_int;
   reg [DATA_WIDTH-1] out_axis_data_int;
   reg out_axis_last_int;

   reg config_in_ready_int;
   reg config_out_ready_int;

   // AXIS OUTPUTS
   assign in_axis_ready_o = in_axis_ready_int;
   assign out_axis_valid_o = out_axis_valid_int;
   assign out_axis_data_o = out_axis_data_int;
   assign out_axis_last_o = out_axis_last_int;

   // CONFIG OUTPUTS
   assign config_in_ready_o = config_in_ready_int;
   assign config_out_ready_o = config_out_ready_int;

   // state machine
   always @* begin
       state_nxt  = state;

       haddr_nxt  = m_ahb_addr_o;
       htrans_nxt = m_ahb_trans_o;
       hwdata_nxt = hwdata_pipe;
       hwstrb_nxt = hwstrb_pipe;
       hwrite_nxt = m_ahb_write_o;

       in_axis_ready_int = 1'b0;
       out_axis_valid_int = 1'b0;
       out_axis_last_int = 1'b0;

       config_in_ready_int = 1'b0;
       config_out_ready_int = 1'b0;
       config_out_length_nxt = config_out_length_int;

       case(state)
            // wait for address/length configuration
            WAIT_CONFIG: begin
                hwrite_nxt = 1'b0;
                hwstrb_nxt = {STRB_WIDTH{1'b0}};
                // AXIS IN priority
                if (config_in_valid_i) begin // write access
                    config_in_ready_int = 1'b1;

                    haddr_nxt = config_in_addr_i;
                    state_nxt = START_TRANSFER;
                end else if (config_out_valid_i) begin // read access
                    config_out_ready_int = 1'b1;
                    config_out_length_nxt = config_out_length_i;

                    haddr_nxt = config_out_addr_i;
                    htrans_nxt = TRANS_NONSEQ;
                    state_nxt = TRANSFER;
                end
            end
            // wait for data from AXIS (write only)
            WAIT_DATA: begin
                if (m_ahb_write_o) begin
                    in_axis_ready_o = 1'b1;
                    if (in_axis_valid_i) begin
                        htrans_nxt = TRANS_NONSEQ;
                        hwdata_nxt = in_axis_data_i;
                        hwstrb_nxt = {STRB_WIDTH{1'b1}};
                        hwrite_nxt = 1'b1;

                        state_nxt = TRANSFER;
                    end
                end
            end
            TRANSFER: begin
                if (m_ahb_write_o) begin // write access
                    // wait for hready
                    if (m_ahb_readyout_i) begin
                        // get next data
                        in_axis_ready_o = 1'b1;
                        if (m_ahb_trans_o != TRANS_BUSY) begin
                            haddr_nxt = haddr_nxt + ADDR_STEP;
                        end
                        if (in_axis_valid_i) begin
                            htrans_nxt = TRANS_SEQ;
                            hwdata_nxt = in_axis_data_i;
                            hwstrb_nxt = {STRB_WIDTH{1'b1}};

                            if (in_axis_tlast_i) begin
                                state_nxt = LAST_DATA;
                            end
                        end else begin
                            htrans_nxt = TRANS_BUSY;
                        end
                    end
                end else begin // read access
                    // wait for hready
                    if (m_ahb_readyout_i) begin
                        out_axis_valid_int = 1'b1;
                        out_axis_data_int = m_ahb_rdata_i;

                        if (m_ahb_trans_o != TRANS_BUSY) begin
                            haddr_nxt = haddr_nxt + ADDR_STEP;
                        end

                        // busy until AXIS OUT reads data
                        if (~out_axis_ready_i) begin
                            htrans_nxt = TRANS_BUSY;
                        end else begin
                            config_out_length_nxt = config_out_length_nxt - 1'b1;
                            htrans_nxt = TRANS_SEQ;
                        end


                        if (config_out_length_nxt == 0) begin
                            out_axis_last_int = 1'b1;

                            htrans_nxt = TRANS_IDLE;
                            state_nxt = WAIT_CONFIG;
                        end
                    end
                end
            end
            // no address and control, last data (write only)
            LAST_DATA: begin
                if (m_ahb_write_o) begin
                    // wait for hready
                    if (m_ahb_readyout_i) begin
                        htrans_nxt = TRANS_IDLE;
                        hwstrb_nxt = STRB_WIDTH{1'b0};
                        hwrite_nxt = 1'b0;

                        state_nxt = LAST_DATA;
                    end
                end
            end
       endcase
   end
endmodule