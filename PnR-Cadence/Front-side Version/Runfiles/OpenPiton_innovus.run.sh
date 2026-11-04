#!/bin/bash
# Cadence Innovus launcher for OpenPiton tile (SCCAD Lab release)
#
# Usage:
#   export PDK_ROOT=/path/to/USC-3N-2D
#   bash OpenPiton_innovus.run.sh
#
# Required inputs in current working directory:
#   - tile.netlist.v
#   - tile.sdc
#   - tile.pin.tcl                (shipped alongside)
#   - impl/FloorPlan.def          (pre-placed SRAM macros)

set -e

if [ -z "${PDK_ROOT:-}" ]; then
    echo "ERROR: set PDK_ROOT before running (e.g. export PDK_ROOT=/path/to/USC-3N-2D)"
    exit 1
fi

# Source your Cadence environment here (adapt path to your site):
#   source /tools/software/cadence/setup.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
mkdir -p impl log RPT

innovus -files OpenPiton_innovus.tcl 2>&1 | tee innovus.normal2D.log
