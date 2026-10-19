#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
from ps5_store_setup import store_setup_main
from ps5_install_lib import run_cli

if __name__ == '__main__':
    run_cli(lambda: store_setup_main('PPSA99620'))
