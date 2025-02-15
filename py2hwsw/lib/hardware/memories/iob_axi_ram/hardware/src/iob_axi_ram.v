// SPDX-FileCopyrightText: 2018 Alex Forencich
// SPDX-FileCopyrightText: 2025 IObundle
//
// SPDX-License-Identifier: MIT

/*
Changes made (2023 Pedro Antunes):
- formated the code with Verible;
- removed intialization in "reg" type signals declaration;
- added reset to registers that did not previously have a reset value;
- separated memory writes and reads from the registers always block
- added support for memories that can not read and write at the same time
*/

// Language: Verilog 2001

`timescale 1ns / 1ps

/*
 * AXI4 RAM
 */
module iob_axi_ram #(
   parameter DATA_WIDTH      = 32,
   parameter ADDR_WIDTH      = 16,
   parameter STRB_WIDTH      = (DATA_WIDTH / 8),
   parameter READ_ON_WRITE   = 1,
   // Width of AXI signals
   parameter ID_WIDTH        = 8,
   parameter LEN_WIDTH       = 8,
   // Extra pipeline register on output
   parameter PIPELINE_OUTPUT = 0,
   // File with which to preload RAM
   parameter FILE            = "none"
) (
   input wire clk_i,
   input wire rst_i,

   input  wire [  ID_WIDTH-1:0] axi_awid_i,
   input  wire [ADDR_WIDTH-1:0] axi_awaddr_i,
   input  wire [ LEN_WIDTH-1:0] axi_awlen_i,
   input  wire [           2:0] axi_awsize_i,
   input  wire [           1:0] axi_awburst_i,
   input  wire [           1:0] axi_awlock_i,
   input  wire [           3:0] axi_awcache_i,
   input  wire [           2:0] axi_awprot_i,
   input  wire [           3:0] axi_awqos_i,
   input  wire                  axi_awvalid_i,
   output wire                  axi_awready_o,

   input  wire [DATA_WIDTH-1:0] axi_wdata_i,
   input  wire [STRB_WIDTH-1:0] axi_wstrb_i,
   input  wire                  axi_wlast_i,
   input  wire                  axi_wvalid_i,
   output wire                  axi_wready_o,

   output wire [  ID_WIDTH-1:0] axi_bid_o,
   output wire [           1:0] axi_bresp_o,
   output wire                  axi_bvalid_o,
   input  wire                  axi_bready_i,
   input  wire [  ID_WIDTH-1:0] axi_arid_i,
   input  wire [ADDR_WIDTH-1:0] axi_araddr_i,
   input  wire [ LEN_WIDTH-1:0] axi_arlen_i,
   input  wire [           2:0] axi_arsize_i,
   input  wire [           1:0] axi_arburst_i,
   input  wire [           1:0] axi_arlock_i,
   input  wire [           3:0] axi_arcache_i,
   input  wire [           2:0] axi_arprot_i,
   input  wire [           3:0] axi_arqos_i,
   input  wire                  axi_arvalid_i,
   output wire                  axi_arready_o,
   output wire [  ID_WIDTH-1:0] axi_rid_o,
   output wire [DATA_WIDTH-1:0] axi_rdata_o,
   output wire [           1:0] axi_rresp_o,
   output wire                  axi_rlast_o,
   output wire                  axi_rvalid_o,
   input  wire                  axi_rready_i
);

   localparam VALID_ADDR_WIDTH = ADDR_WIDTH - $clog2(STRB_WIDTH);
   localparam WORD_WIDTH = STRB_WIDTH;
   localparam WORD_SIZE = DATA_WIDTH / WORD_WIDTH;
   localparam CLOG2_STRB_WIDTH = $clog2(STRB_WIDTH);

   // bus width assertions
   initial begin
      if (WORD_SIZE * STRB_WIDTH != DATA_WIDTH) begin
         $error("Error: AXI data width not evenly divisble (instance %m)");
         $finish();
      end

      if (2 ** $clog2(WORD_WIDTH) != WORD_WIDTH) begin
         $error("Error: AXI word width must be even power of two (instance %m)");
         $finish();
      end
   end

   localparam [0:0] READ_STATE_IDLE = 1'd0, READ_STATE_BURST = 1'd1;

   reg [0:0] read_state_reg, read_state_next;

   localparam [1:0] WRITE_STATE_IDLE = 2'd0, WRITE_STATE_BURST = 2'd1, WRITE_STATE_RESP = 2'd2;

   reg [1:0] write_state_reg, write_state_next;

   reg mem_wr_en;

   reg [ID_WIDTH-1:0] read_id_reg, read_id_next;
   reg [ADDR_WIDTH-1:0] read_addr_reg, read_addr_next;
   reg [LEN_WIDTH-1:0] read_count_reg, read_count_next;
   reg [2:0] read_size_reg, read_size_next;
   reg [1:0] read_burst_reg, read_burst_next;
   reg [ID_WIDTH-1:0] write_id_reg, write_id_next;
   reg [ADDR_WIDTH-1:0] write_addr_reg, write_addr_next;
   reg [LEN_WIDTH-1:0] write_count_reg, write_count_next;
   reg [2:0] write_size_reg, write_size_next;
   reg [1:0] write_burst_reg, write_burst_next;

   reg axi_awready_reg, axi_awready_next;
   reg axi_wready_reg, axi_wready_next;
   reg [ID_WIDTH-1:0] axi_bid_reg, axi_bid_next;
   reg axi_bvalid_reg, axi_bvalid_next;
   reg axi_arready_reg, axi_arready_next;
   reg [ID_WIDTH-1:0] axi_rid_reg, axi_rid_next;
   reg [DATA_WIDTH-1:0] axi_rdata_reg, axi_rdata_next;
   reg axi_rlast_reg, axi_rlast_next;
   reg axi_rvalid_reg, axi_rvalid_next;
   reg [ID_WIDTH-1:0] axi_rid_pipe_reg;
   reg [DATA_WIDTH-1:0] axi_rdata_pipe_reg;
   reg axi_rlast_pipe_reg;
   reg axi_rvalid_pipe_reg;

   // (* RAM_STYLE="BLOCK" *)
   reg [DATA_WIDTH-1:0] mem[2**VALID_ADDR_WIDTH];

   wire [VALID_ADDR_WIDTH-1:0] read_addr_valid = read_addr_reg[(ADDR_WIDTH - VALID_ADDR_WIDTH)+:VALID_ADDR_WIDTH];
   wire [VALID_ADDR_WIDTH-1:0] write_addr_valid = write_addr_reg[(ADDR_WIDTH - VALID_ADDR_WIDTH)+:VALID_ADDR_WIDTH];

   assign axi_awready_o = axi_awready_reg;
   assign axi_wready_o  = axi_wready_reg;
   assign axi_bid_o     = axi_bid_reg;
   assign axi_bresp_o   = 2'b00;
   assign axi_bvalid_o  = axi_bvalid_reg;
   assign axi_arready_o = axi_arready_reg;
   assign axi_rid_o     = PIPELINE_OUTPUT ? axi_rid_pipe_reg : axi_rid_reg;
   assign axi_rdata_o   = PIPELINE_OUTPUT ? axi_rdata_pipe_reg : axi_rdata_reg;
   assign axi_rresp_o   = 2'b00;
   assign axi_rlast_o   = PIPELINE_OUTPUT ? axi_rlast_pipe_reg : axi_rlast_reg;
   assign axi_rvalid_o  = PIPELINE_OUTPUT ? axi_rvalid_pipe_reg : axi_rvalid_reg;

   generate
      genvar i;
      if (READ_ON_WRITE) begin : g_always_read
         localparam mem_init_file_int = {FILE, ".hex"};
         initial begin
            if (FILE != "none") begin
               $readmemh(mem_init_file_int, mem, 0, 2 ** VALID_ADDR_WIDTH - 1);
            end
         end
         for (i = 0; i < WORD_WIDTH; i = i + 1) begin : g_Bytes_in_word
            always @(posedge clk_i) begin
               if (mem_wr_en & axi_wstrb_i[i]) begin
                  mem[write_addr_valid][WORD_SIZE*i+:WORD_SIZE] <= axi_wdata_i[WORD_SIZE*i+:WORD_SIZE];
               end
               axi_rdata_reg[WORD_SIZE*i+:WORD_SIZE] <= mem[read_addr_valid][WORD_SIZE*i+:WORD_SIZE];
            end
         end
      end else begin : g_no_read_on_write
         localparam file_suffix = {"7", "6", "5", "4", "3", "2", "1", "0"};
         for (i = 0; i < WORD_WIDTH; i = i + 1) begin : g_Bytes_in_word
            localparam mem_init_file_int = (FILE != "none") ?
             {FILE, "_", file_suffix[8*(i+1)-1-:8], ".hex"} : "none";
            iob_ram_t2p #(
               .HEXFILE(mem_init_file_int),
               .ADDR_W (VALID_ADDR_WIDTH),
               .DATA_W (WORD_SIZE)
            ) ram (
               .clk_i(clk_i),

               // Read port
               .r_en_i  (read_state_reg == READ_STATE_BURST),
               .r_addr_i(read_addr_valid),
               .r_data_o(axi_rdata_reg[WORD_SIZE*i+:WORD_SIZE]),
               // Write port
               .w_en_i  (mem_wr_en & axi_wstrb_i[i]),
               .w_addr_i(write_addr_valid),
               .w_data_i(axi_wdata_i[WORD_SIZE*i+:WORD_SIZE])
            );
         end
      end
   endgenerate

   // always_comb in SystemVerilog
   always @(*) begin
      write_state_next = WRITE_STATE_IDLE;

      mem_wr_en        = 1'b0;

      write_id_next    = write_id_reg;
      write_addr_next  = write_addr_reg;
      write_count_next = write_count_reg;
      write_size_next  = write_size_reg;
      write_burst_next = write_burst_reg;

      axi_awready_next = 1'b0;
      axi_wready_next  = 1'b0;
      axi_bid_next     = axi_bid_reg;
      axi_bvalid_next  = axi_bvalid_reg && !axi_bready_i;

      case (write_state_reg)
         WRITE_STATE_IDLE: begin
            axi_awready_next = 1'b1;

            if (axi_awready_o && axi_awvalid_i) begin
               write_id_next = axi_awid_i;
               write_addr_next = axi_awaddr_i;
               write_count_next = axi_awlen_i;
               write_size_next = axi_awsize_i < CLOG2_STRB_WIDTH ? axi_awsize_i :
                   CLOG2_STRB_WIDTH[2:0];
               write_burst_next = axi_awburst_i;

               axi_awready_next = 1'b0;
               axi_wready_next = 1'b1;
               write_state_next = WRITE_STATE_BURST;
            end else begin
               write_state_next = WRITE_STATE_IDLE;
            end
         end
         WRITE_STATE_BURST: begin
            axi_wready_next = 1'b1;

            if (axi_wready_o && axi_wvalid_i) begin
               mem_wr_en = 1'b1;
               if (write_burst_reg != 2'b00) begin
                  write_addr_next = write_addr_reg + (1 << write_size_reg);
               end
               write_count_next = write_count_reg - 1'b1;
               if (write_count_reg > 0) begin
                  write_state_next = WRITE_STATE_BURST;
               end else begin
                  axi_wready_next = 1'b0;
                  if (axi_bready_i || !axi_bvalid_o) begin
                     axi_bid_next     = write_id_reg;
                     axi_bvalid_next  = 1'b1;
                     axi_awready_next = 1'b1;
                     write_state_next = WRITE_STATE_IDLE;
                  end else begin
                     write_state_next = WRITE_STATE_RESP;
                  end
               end
            end else begin
               write_state_next = WRITE_STATE_BURST;
            end
         end
         WRITE_STATE_RESP: begin
            if (axi_bready_i || !axi_bvalid_o) begin
               axi_bid_next     = write_id_reg;
               axi_bvalid_next  = 1'b1;
               axi_awready_next = 1'b1;
               write_state_next = WRITE_STATE_IDLE;
            end else begin
               write_state_next = WRITE_STATE_RESP;
            end
         end
         default: ;
      endcase
   end

   always @(posedge clk_i, posedge rst_i) begin
      if (rst_i) begin
         write_state_reg <= WRITE_STATE_IDLE;
         axi_awready_reg <= 1'b0;
         axi_wready_reg  <= 1'b0;
         axi_bvalid_reg  <= 1'b0;

         write_id_reg    <= {ID_WIDTH{1'b0}};
         write_addr_reg  <= {ADDR_WIDTH{1'b0}};
         write_count_reg <= {LEN_WIDTH{1'b0}};
         write_size_reg  <= 3'd0;
         write_burst_reg <= 2'd0;

         axi_bid_reg     <= {ID_WIDTH{1'b0}};
      end else begin
         write_state_reg <= write_state_next;
         axi_awready_reg <= axi_awready_next;
         axi_wready_reg  <= axi_wready_next;
         axi_bvalid_reg  <= axi_bvalid_next;

         write_id_reg    <= write_id_next;
         write_addr_reg  <= write_addr_next;
         write_count_reg <= write_count_next;
         write_size_reg  <= write_size_next;
         write_burst_reg <= write_burst_next;

         axi_bid_reg     <= axi_bid_next;
      end
   end

   // always_comb in SystemVerilog
   always @(*) begin
      read_state_next = READ_STATE_IDLE;

      axi_rid_next = axi_rid_reg;
      axi_rlast_next = axi_rlast_reg;
      axi_rvalid_next = axi_rvalid_reg && !(axi_rready_i || (PIPELINE_OUTPUT && !axi_rvalid_pipe_reg));

      read_id_next = read_id_reg;
      read_addr_next = read_addr_reg;
      read_count_next = read_count_reg;
      read_size_next = read_size_reg;
      read_burst_next = read_burst_reg;

      axi_arready_next = 1'b0;

      case (read_state_reg)
         READ_STATE_IDLE: begin
            axi_arready_next = 1'b1;

            if (axi_arready_o && axi_arvalid_i) begin
               read_id_next = axi_arid_i;
               read_addr_next = axi_araddr_i;
               read_count_next = axi_arlen_i;
               read_size_next = axi_arsize_i < CLOG2_STRB_WIDTH ? axi_arsize_i :
                   CLOG2_STRB_WIDTH[2:0];
               read_burst_next = axi_arburst_i;

               axi_arready_next = 1'b0;
               read_state_next = READ_STATE_BURST;
            end else begin
               read_state_next = READ_STATE_IDLE;
            end
         end
         READ_STATE_BURST: begin
            if (axi_rready_i || (PIPELINE_OUTPUT && !axi_rvalid_pipe_reg) || !axi_rvalid_reg) begin
               axi_rvalid_next = 1'b1;
               axi_rid_next    = read_id_reg;
               axi_rlast_next  = read_count_reg == 0;
               if (read_burst_reg != 2'b00) begin
                  read_addr_next = read_addr_reg + (1 << read_size_reg);
               end
               read_count_next = read_count_reg - 1'b1;
               if (read_count_reg > 0) begin
                  read_state_next = READ_STATE_BURST;
               end else begin
                  axi_arready_next = 1'b1;
                  read_state_next  = READ_STATE_IDLE;
               end
            end else begin
               read_state_next = READ_STATE_BURST;
            end
         end  // case: READ_STATE_BURST
         default: ;
      endcase
   end

   always @(posedge clk_i, posedge rst_i) begin
      if (rst_i) begin
         read_state_reg      <= READ_STATE_IDLE;
         axi_arready_reg     <= 1'b0;
         axi_rvalid_reg      <= 1'b0;
         axi_rvalid_pipe_reg <= 1'b0;

         read_id_reg         <= {ID_WIDTH{1'b0}};
         read_addr_reg       <= {ADDR_WIDTH{1'b0}};
         read_count_reg      <= 0;
         read_size_reg       <= 3'd0;
         read_burst_reg      <= 2'd0;

         axi_rid_reg         <= {ID_WIDTH{1'b0}};
         axi_rlast_reg       <= 1'b0;
         axi_rid_pipe_reg    <= {ID_WIDTH{1'b0}};
         axi_rdata_pipe_reg  <= {DATA_WIDTH{1'b0}};
         axi_rlast_pipe_reg  <= 1'b0;
      end else begin
         read_state_reg  <= read_state_next;
         axi_arready_reg <= axi_arready_next;
         axi_rvalid_reg  <= axi_rvalid_next;

         if (!axi_rvalid_pipe_reg || axi_rready_i) begin
            axi_rvalid_pipe_reg <= axi_rvalid_reg;
         end

         read_id_reg    <= read_id_next;
         read_addr_reg  <= read_addr_next;
         read_count_reg <= read_count_next;
         read_size_reg  <= read_size_next;
         read_burst_reg <= read_burst_next;

         axi_rid_reg    <= axi_rid_next;
         axi_rlast_reg  <= axi_rlast_next;

         if (!axi_rvalid_pipe_reg || axi_rready_i) begin
            axi_rid_pipe_reg   <= axi_rid_reg;
            axi_rdata_pipe_reg <= axi_rdata_reg;
            axi_rlast_pipe_reg <= axi_rlast_reg;
         end
      end
   end

endmodule
