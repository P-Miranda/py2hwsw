# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT


def setup(py_params_dict):
    attributes_dict = {
        "generate_hw": False,
        "subblocks": [
            {
                "core_name": "iob_sync",
                "instance_name": "iob_sync_inst",
            },
            {
                "core_name": "iob_reg_e",
                "instance_name": "iob_reg_e_inst",
            },
        ],
    }

    return attributes_dict
