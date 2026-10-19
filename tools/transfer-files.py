#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Optional FTP transfer only: consumes an already prepared title folder."""
from ps5_install_lib import transfer_main, run_cli
if __name__ == '__main__':
    run_cli(transfer_main)
