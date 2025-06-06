// SPDX-FileCopyrightText: 2025 IObundle
//
// SPDX-License-Identifier: MIT

`timescale 1 ns / 1 ps


module iob_regarray_at2p #(
   parameter ADDR_W = 3,
   parameter DATA_W = 21
) (
   // Write Port
   input              w_clk_i,
   input              w_cke_i,
   input              w_arst_i,
   input [ADDR_W-1:0] w_addr_i,
   input [DATA_W-1:0] w_data_i,

   // Read Port
   input               r_clk_i,
   input               r_cke_i,
   input               r_arst_i,
   input  [ADDR_W-1:0] r_addr_i,
   output [DATA_W-1:0] r_data_o
);

   //write
   wire [((2**ADDR_W)*DATA_W)-1:0] regarray_in;
   wire [         (2**ADDR_W)-1:0] regarray_en;

   genvar addr;
   generate
      for (addr = 0; addr < (2 ** ADDR_W); addr = addr + 1) begin : gen_register_file
         assign regarray_en[addr] = (w_addr_i == addr);
         iob_reg_cae #(
            .DATA_W (DATA_W),
            .RST_VAL({DATA_W{1'd0}})
         ) rdata (
            .clk_i (w_clk_i),
            .cke_i (w_cke_i),
            .arst_i(w_arst_i),
            .en_i  (regarray_en[addr]),
            .data_i(w_data_i),
            .data_o(regarray_in[addr*DATA_W+:DATA_W])
         );
      end
   endgenerate

   wire [DATA_W-1:0] r_data;
   assign r_data = regarray_in[r_addr_i*DATA_W+:DATA_W];

   //read
   iob_reg_ca #(
      .DATA_W (DATA_W),
      .RST_VAL({DATA_W{1'd0}})
   ) rdata (
      .clk_i (r_clk_i),
      .cke_i (r_cke_i),
      .arst_i(r_arst_i),
      .data_i(r_data),
      .data_o(r_data_o)
   );

endmodule
