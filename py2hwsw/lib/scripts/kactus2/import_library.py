#!/usr/bin/env python3

# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT

# Kactus2 Python automation script.
# This script automatically imports the 'ipxact_lib' library generated by py2hwsw.
#
# Kactus2 Python API functions: https://github.com/kactus2/kactus2dev/blob/main/PythonAPI/PythonAPI.cpp

import configparser
import os
import sys


def add_path_to_ini(file_path, new_paths, section, key):
    config = configparser.ConfigParser()
    config.optionxform = str  # Preserve case for keys
    config.read(file_path)

    # Check if the section exists
    if not config.has_section(section):
        # config.add_section(section)
        print(f"Did not find '{section}' section in '{file_path}'")
        exit(1)

    # Get the current 'key' value
    active_locations = config.get(section, key, fallback="")

    # Split the current 'key' value into a list of paths
    current_paths = [path.strip() for path in active_locations.split(",")]

    # Add the new paths to the list if they don't exist yet
    for new_path in new_paths:
        if new_path.strip() not in current_paths:
            current_paths.append(new_path.strip())

    # Join the list of paths back into a string
    updated_active_locations = ", ".join(current_paths)

    # Update the 'key' value in the config
    config.set(section, key, updated_active_locations)

    # Write the updated config to the file
    with open(file_path, "w") as config_file:
        config.write(config_file)


# Main code
kactus2_config = os.path.join(os.path.expanduser("~"), ".config/TUT/Kactus2.ini")

# new_libraries = ["/path/to/new/location1", "/path/to/new/location2"]

if not sys.argv[1]:
    print("Please specify the path to the new library")
    exit(1)

new_libraries = [sys.argv[1]]

add_path_to_ini(kactus2_config, new_libraries, "Library", "ActiveLocations")
add_path_to_ini(kactus2_config, new_libraries, "Library", "Locations")
