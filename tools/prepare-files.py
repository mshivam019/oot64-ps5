#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Local preparation only: produces a normal folder; never connects to a PS5."""
from ps5_install_lib import prepare_main, run_cli
if __name__ == '__main__':
    run_cli(prepare_main)
