#!/bin/bash
# Cadence Innovus launcher for ECG point_scalar_mult (SCCAD Lab release)
#
# Usage:
#   export PDK_ROOT=/path/to/USC-3N-2D
#   bash ECG_innovus.run.sh
#
# Required inputs in current working directory:
#   - point_scalar_mult.netlist.v
#   - point_scalar_mult.sdc

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

innovus -files ECG_innovus.tcl 2>&1 | tee innovus.normal2D.log
