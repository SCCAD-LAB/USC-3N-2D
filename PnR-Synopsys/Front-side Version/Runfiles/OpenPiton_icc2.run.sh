#!/bin/bash
# Synopsys IC Compiler II launcher for OpenPiton tile (SCCAD Lab release)
#
# Usage:
#   export PDK_ROOT=/path/to/USC-3N-2D
#   bash OpenPiton_icc2.run.sh
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

# Source your Synopsys environment here (adapt path to your site):
#   source /tools/software/synopsys/setup.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
mkdir -p impl log log/pnr output/global

icc2_shell -f OpenPiton_icc2.tcl -output_log_file icc2.normal2D.log
