def setup(py_params_dict):
    attributes_dict = {
        "original_name": "iob_acc",
        "name": "iob_acc",
        "version": "0.1",
        "confs": [
            {
                "name": "DATA_W",
                "type": "P",
                "val": "21",
                "min": "NA",
                "max": "NA",
                "descr": "Data bus width",
            },
            {
                "name": "RST_VAL",
                "type": "P",
                "val": "{DATA_W{1'b0}}",
                "min": "NA",
                "max": "NA",
                "descr": "Reset value.",
            },
        ],
        "ports": [
            {
                "name": "clk_en_rst_s",
                "interface": {
                    "type": "clk_en_rst",
                    "subtype": "slave",
                },
                "descr": "clock, clock enable and reset",
            },
            {
                "name": "en_rst_i",
                "descr": "Enable and Synchronous reset interface",
                "signals": [
                    {
                        "name": "en",
                        "direction": "input",
                        "width": 1,
                        "descr": "Enable input",
                    },
                    {
                        "name": "rst",
                        "direction": "input",
                        "width": 1,
                        "descr": "Synchronous reset input",
                    },
                ],
            },
            {
                "name": "incr_i",
                "descr": "Input port",
                "signals": [
                    {
                        "name": "incr",
                        "width": "DATA_W",
                        "direction": "input",
                    },
                ],
            },
            {
                "name": "data_o",
                "descr": "Output port",
                "signals": [
                    {
                        "name": "data",
                        "width": "DATA_W",
                        "direction": "output",
                    },
                ],
            },
        ],
        "wires": [
            {
                "name": "data_nxt",
                "descr": "Sum result",
                "signals": [
                    {
                        "name": "data_nxt",
                        "width": "DATA_W+1",
                    },
                ],
            },
            {
                "name": "data_int",
                "descr": "data_int wire",
                "signals": [
                    {"name": "data_int", "width": "DATA_W"},
                ],
            },
        ],
        "blocks": [
            """
            iob_reg_re reg0 -p DATA_W:DATA_W RST_VAL:RST_VAL -c
            clk_en_rst_s:clk_en_rst_s 
            en_rst_i:en_rst_i
            data_i_i:data_int
            data_o_o:data_o
            'Accomulator register with synchronous reset and enable'
            """
        ],
        "snippets": [
            {
                "verilog_code": f"""
       assign data_nxt = data_o + incr_i;
       assign data_int = data_nxt_o[DATA_W-1:0];
            """,
            },
        ],
    }

    return attributes_dict