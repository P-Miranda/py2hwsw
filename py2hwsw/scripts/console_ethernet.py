#!/usr/bin/env python3

# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT

import os
import sys

if __name__ == "__main__":
    # Save argv and override it with new values because ethBase requires them
    saved_argv = sys.argv
    cnsl_mac_addr = (
        sys.argv[sys.argv.index("-m") + 1] if "-m" in sys.argv else "88431eafa897"
    )
    eth_interface = sys.argv[sys.argv.index("-i") + 1]
    timeout = sys.argv[sys.argv.index("-t") + 1] if "-t" in sys.argv else "0.1"
    try:
        sys.argv = [
            "eth_comm.py",
            cnsl_mac_addr,
            eth_interface,
            timeout,
        ]
        from ethBase import CreateSocket, SyncAckFirst, SyncAckLast
        from ethRcvData import RcvFile
        from ethSendData import SendFile
    finally:
        sys.argv = saved_argv

    if "-c" in sys.argv:
        # Get console filepath
        console_path = os.path.realpath(sys.argv[sys.argv.index("-c") + 1])
        # Save current __name__ and override it to run code from console module
        name_backup = __name__
        __name__ = "console"
        # Run code from console module
        exec(open(console_path).read())
        # Restore __name__
        __name__ = name_backup
        del name_backup
    else:
        console_path = ""

    if "-e" in sys.argv:
        eth2file_path = os.path.realpath(sys.argv[sys.argv.index("-e") + 1])
        # Save current __name__ and override it to run code from eth2file module
        name_backup = __name__
        __name__ = "eth2file"
        # Run code from eth2file script
        exec(open(eth2file_path).read())
        # Restore __name__
        __name__ = name_backup
        del name_backup

# Global variables
EFTX = b"\x12"  # Receive file by ethernet request
EFRX = b"\x13"  # Send file by ethernet request


# Send file to target by ethernet
def cnsl_sendfile_ethernet():
    file_size = 0
    name = b""
    socket = CreateSocket()

    # receive file name
    name = cnsl_recvstr()

    file_size = os.path.getsize(name)

    print(PROGNAME, end="")
    print(": file of size {0} bytes".format(file_size))
    if SerialFlag:
        ser.write(file_size.to_bytes(4, byteorder="little"))  # send file size
        while ser.read() != ACK:
            pass
    else:
        tb_write(file_size.to_bytes(4, byteorder="little"), 4)
        while tb_read.read(1) != ACK:
            pass

    # Send Data File
    SyncAckFirst(socket)
    SendFile(socket, name)

    print(PROGNAME, end="")
    print(": file sent")

    # Close Socket
    socket.close()


def cnsl_recvfile_ethernet():
    file_size = 0
    name = ""
    socket = CreateSocket()

    # receive file name
    name = cnsl_recvstr()

    if SerialFlag:
        file_size = int.from_bytes(serial_read(4), byteorder="little", signed=False)
        print(PROGNAME, end=" ")
        print(": file size: {0} bytes".format(file_size))
    else:
        file_size = int.from_bytes(tb_read.read(4), byteorder="little", signed=False)
        print(PROGNAME, end=" ")
        print(": file size: {0} bytes".format(file_size))

    # Receive Data File
    SyncAckLast(socket)
    RcvFile(socket, name, file_size)

    print(PROGNAME, end="")
    print(": file received")

    # Close Socket
    socket.close()


def usage(message):
    print(
        "{}:{}".format(
            PROGNAME,
            "usage: ./console_ethernet.py -s <serial port> -c <console path> [ -f ] [ -L/--local ] -m <ethernet mac address> -i <interface> -t <socket_timeout>",
        )
    )
    print(message)
    exit(1)


# Main function.
def main():
    if not console_path:
        usage("PROGNAME: requires console path")

    init_console()
    gotENQ = False
    input_thread = Thread(target=getUserInput, args=[], daemon=True)
    # Launch eth2file python script (for simulation)
    if "-e" in sys.argv:
        eth2file_thread = Thread(
            target=relay_frames,
            args=[eth_interface, "soc2eth", "eth2soc", "01606e11020f"],
            daemon=True,
        )
        eth2file_thread.start()

    # Reading the data from the serial port or FIFO files. This will be running in an infinite loop.
    while True:
        byte = b"\x00"

        # get byte from target
        if not SerialFlag:
            byte = tb_read.read(1)
        elif ser.isOpen():
            byte = ser.read()

        # process command
        if byte == ENQ:
            if not gotENQ:
                gotENQ = True
                if SerialFlag:
                    ser.write(ACK)
                else:
                    tb_write(ACK)
        elif byte == EOT:
            print(f"{PROGNAME}: exiting...")
            clean_exit()
        elif byte == FTX:
            print(f"{PROGNAME}: got file receive request")
            cnsl_recvfile()
        elif byte == FRX:
            print(f"{PROGNAME}: got file send request")
            cnsl_sendfile()
        elif byte == EFTX:
            print(f"{PROGNAME}: got file receive by ethernet request")
            cnsl_recvfile_ethernet()
        elif byte == EFRX:
            print(f"{PROGNAME}: got file send by ethernet request")
            cnsl_sendfile_ethernet()
        elif byte == DC1:
            print(f"{PROGNAME}: disabling IOB-SOC exclusive identifiers")
            endFileTransfer()
            script_arguments = ["python3", "../../scripts/terminalMode.py"]
            subprocess.run(script_arguments)
            print(f"{PROGNAME}: start reading user input")
            input_thread.start()
        else:
            print(str(byte, "iso-8859-1"), end="", flush=True)


if __name__ == "__main__":
    main()
