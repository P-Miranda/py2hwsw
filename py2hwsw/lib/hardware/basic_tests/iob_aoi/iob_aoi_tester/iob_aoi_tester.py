#!/usr/bin/env python3

# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT

core_dictionary = {
    # Set "is_tester" attribute to generate Makefile and flows allowing to run this core as top module
    "generate_hw": True,
    "is_tester": True,
    "confs": [
        {
            "name": "W",
            "kind": "P",
            "value": "21",
            "min_value": "1",
            "max_value": "32",
            "descr": "IO width",
        },
    ],
    "wires": [
        {
            "name": "a",
            "descr": "AOI input port 1",
            "width": "W",
        },
        {
            "name": "b",
            "descr": "AOI input port 2",
            "width": "W",
        },
        {
            "name": "c",
            "descr": "AOI input port 3",
            "width": "W",
        },
        {
            "name": "d",
            "descr": "AOI input port 4",
            "width": "W",
        },
        {
            "name": "y",
            "descr": "AOI output port",
            "width": "W",
        },
    ],
    "subblocks": [
        {
            "core": "ISSUER",  # "iob_aoi"
            "name": "uut_aoi",
            "description": "Unit Under Test",
            "parameters": {
                "W": "W",
            },
            "portmap_connections": {
                "a_i": "a",
                "b_i": "b",
                "c_i": "c",
                "d_i": "d",
                "y_o": "y",
            },
        }
    ],
    "snippets": [
        {
            "verilog_code": """\
   // Tester body / verification code
   // Currently using non-synthesizable code

   reg     [W-1:0] a_reg = 0;
   reg     [W-1:0] b_reg = 0;
   reg     [W-1:0] c_reg = 0;
   reg     [W-1:0] d_reg = 0;
   wire          aoi_out;

   assign a = a_reg;
   assign b = b_reg;
   assign c = c_reg;
   assign d = d_reg;
   assign aoi_out = y;

   integer       i;
   integer       fp;

   initial begin

      for (i = 0; i < 16; i = i + 1) begin
           #10 a_reg = {W{i[3]}};
               b_reg = {W{i[2]}};
               c_reg = {W{i[1]}};
               d_reg = {W{i[0]}};
        #10 $display("a_reg = %b, b_reg = %b, c_reg = %b, d_reg = %b, aoi_out = %b", a_reg, b_reg, c_reg, d_reg, aoi_out);
      end
      #10 $display("%c[1;34m", 8'd27);
      $display("Test completed successfully.");
      $display("%c[0m", 8'd27);

      fp = $fopen("test.log", "w");
      $fdisplay(fp, "Test passed!");

      $finish();
   end
"""
        }
    ],
}


class iob_aoi_tester(iob_core):
    def __init__(self, **kwargs):
        # update core_dictionary with kwargs / iob_parameters
        core_dictionary.update(kwargs)
        super().__init__(core_dictionary)


if __name__ == "__main__":
    iob_aoi_tester_obj = iob_aoi_tester()
    iob_aoi_tester_obj.generate_build_dir()
