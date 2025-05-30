// SPDX-FileCopyrightText: 2025 IObundle
//
// SPDX-License-Identifier: MIT

`timescale 1ns / 1ps

module iob_pack #(
    parameter DATA_W = 21
) (
    `include "iob_pack_iob_clk_s_port.vs"

    input                    rst_i,
    input                    wrap_i,
    input [$clog2(DATA_W):0] width_i,

    //read unpacked data to be packed
    output              read_o,
    input               rready_i,
    input  [DATA_W-1:0] rdata_i,

    //write packed data
    output              write_o,
    input               wready_i,
    output [DATA_W-1:0] wdata_o
);

  localparam CALC_POP_WIDTH = 2'd0;
  localparam WAIT_DATA = 2'd1;
  localparam PUSH_DATA = 2'd2;
  localparam WAIT_POP = 2'd3;

  //input fifo read
  reg                       read;

  //bit fifo control
  wire [$clog2(2*DATA_W):0] push_level;
  reg                       push;

  wire [$clog2(2*DATA_W):0] pop_level;
  reg  [  $clog2(DATA_W):0] pop_width;
  reg                       pop;

  //wrap control accumulator
  reg  [  $clog2(DATA_W):0] wrap_acc_nxt;
  wire [  $clog2(DATA_W):0] wrap_acc;
  reg  [$clog2(DATA_W)+1:0] wrap_acc_int;

  //program counter
  wire [               1:0] pcnt;
  reg  [               1:0] pcnt_nxt;

  //read unpacked data from external input fifo
  assign read_o  = read;
  //write packed data to external output fifo
  assign write_o = pop;

  //control logic
  always @* begin
    pop_width    = wrap_i ? wrap_acc : DATA_W;
    wrap_acc_int = {1'd0, wrap_acc} + {1'd0, width_i};

    //defaults
    pop          = 1'b0;
    push         = 1'b0;
    read         = 1'b0;
    wrap_acc_nxt = wrap_acc;
    pcnt_nxt     = pcnt + 1'b1;

    case (pcnt)
      CALC_POP_WIDTH: begin  //compute pop width
        if (wrap_i && (wrap_acc_int <= DATA_W)) begin
          pcnt_nxt     = pcnt;
          wrap_acc_nxt = wrap_acc_int[0+:$clog2(DATA_W)+1];
        end
      end
      WAIT_DATA: begin  //wait to read data from input fifo
        if (rready_i && (push_level >= {1'd0, width_i})) begin
          read = 1'b1;
        end else begin
          pcnt_nxt = WAIT_POP;
        end
      end
      PUSH_DATA: begin  //push data to bit fifo
        push = 1'b1;
      end
      default: begin  //wait to pop data from bit fifo
        if ((pop_level >= {1'd0, pop_width}) && wready_i) begin
          pop = 1'b1;
        end
        pcnt_nxt = WAIT_DATA;
      end
    endcase
  end

  //bit fifo
  iob_bfifo #(
      .DATA_W(DATA_W)
  ) bfifo (
      `include "iob_pack_iob_clk_s_s_portmap.vs"
      .rst_i   (rst_i),
      //push unpacked data to be packed
      .write_i (push),
      .wwidth_i(width_i),
      .wdata_i (rdata_i),
      .wlevel_o(push_level),
      //pop packed data to be output
      .read_i  (pop),
      .rwidth_i(pop_width),
      .rdata_o (wdata_o),
      .rlevel_o(pop_level)
  );

  //wrap control accumulator
  iob_reg_car #(
      .DATA_W ($clog2(DATA_W) + 1),
      .RST_VAL({$clog2(DATA_W) + 1{1'b0}})
  ) wrap_acc_reg (
      `include "iob_pack_iob_clk_s_s_portmap.vs"
      .rst_i (rst_i),
      .data_i(wrap_acc_nxt),
      .data_o(wrap_acc)
  );

  //pcnt register (state counter)
  iob_reg_car #(
      .DATA_W (2),
      .RST_VAL(2'b0)
  ) pcnt_reg (
      `include "iob_pack_iob_clk_s_s_portmap.vs"
      .rst_i (rst_i),
      .data_i(pcnt_nxt),
      .data_o(pcnt)
  );

endmodule


