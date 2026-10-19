#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Legacy transfer-only entry point; no PS5 Upload dependency or default drive."""
from ps5_install_lib import legacy_main, run_cli
if __name__ == '__main__':
    run_cli(legacy_main)
