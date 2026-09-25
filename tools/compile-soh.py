#!/usr/bin/env python3
"""Build SoH's objects and libraries without CMake's unsupported PS5 final link."""
import argparse
import subprocess
from pathlib import Path


def link_dependencies(query):
    dependencies = []
    in_inputs = False
    for line in query.splitlines():
        if line.startswith("  input:"):
            in_inputs = True
        elif line.startswith("  outputs:"):
            break
        elif in_inputs and line.startswith("    "):
            path = line.strip().lstrip("| ")
            if path.endswith((".o", ".a")):
                dependencies.append(path)
    if not dependencies:
        raise ValueError("No objects or archives in SoH's Ninja link dependencies")
    return list(dict.fromkeys(dependencies))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("build", type=Path)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    query = subprocess.check_output(["ninja", "-C", str(args.build), "-t", "query", "soh/soh"], text=True)
    dependencies = link_dependencies(query)
    command = ["ninja", "-C", str(args.build)]
    if args.dry_run:
        command.append("-n")
    print(f"Building {len(dependencies)} SoH link dependencies", flush=True)
    subprocess.run(command + dependencies, check=True)


if __name__ == "__main__":
    main()
