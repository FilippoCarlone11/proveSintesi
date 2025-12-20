#!/bin/bash
set -e  

# --- 1. PATH CONFIG ---
# search config.cfg
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.cfg"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "ERROR: config.cfg '$CONFIG_FILE' not found."
    exit 1
fi


CURRENT_PATH=$(pwd)

# Controllo argomenti
if [ -z "$3" ]; then
    echo "Usage: ./script.sh <nm> <circuit_name> <yosys_template>"
    echo "Example: ./script.sh 130nm register.c synth.ys"
    exit 1
fi

# Library selection (Liberty per sintesi, Verilog per simulazione)
if [[ "$1" == "15nm" ]]; then
    # Percorsi per 15nm (Esempio - controlla se il file verilog esiste!)
    LIBERTY_PATH="$LIB_15NM"
    VERILOG_LIB="$VERILOG_15NM"
else
    # Percorsi per 130nm
    LIBERTY_PATH="$LIB_130NM"
    VERILOG_LIB="$VERILOG_130NM"
fi


# --- 1. SYNTHESIS ---
echo "--- Synthesis generation ---"
yosys -s "$3" &> /dev/null


# --- 2. FAULT EXECUTION (Scan Chain Insertion) ---
NAME_ONLY=${2%.v}
SYNTH_OUTPUT_NAME="${NAME_ONLY}.s.v"
SCAN_OUTPUT_NAME="${NAME_ONLY}.sc.v"

# start the virtual machine for fault
source "$VENV_PATH"

echo "--- Scan Chain insertion ---"
fault chain --liberty "$LIBERTY_PATH" --clock clk "$SYNTH_OUTPUT_NAME" -o "${CURRENT_PATH}/${SCAN_OUTPUT_NAME}" &> /dev/null

deactivate
# clear temp file
rm -f *-intermediate.v *attrs *.out *.py


# --- 3. Image generation ---
echo "--- Images Generation ---"
mkdir -p img
yosys -p "read_verilog ${CURRENT_PATH}/${SCAN_OUTPUT_NAME}; hierarchy -auto-top; proc; show -format png -prefix img/${NAME_ONLY}_sc" > /dev/null
yosys -p "read_verilog ${CURRENT_PATH}/${SYNTH_OUTPUT_NAME}; hierarchy -auto-top; proc; show -format png -prefix img/${NAME_ONLY}_s" > /dev/null




