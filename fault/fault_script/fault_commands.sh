#!/bin/bash

# --- 1. PATH CONFIG ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.cfg"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "ERROR: config.cfg '$CONFIG_FILE' not found."
    exit 1
fi

# Controllo argomenti
if [ -z "$3" ]; then
    echo "Usage: $0 <nm> <path/to/circuit_name.v> <path/to/yosys_template.ys>"
    echo "Example: $0 130nm ../src/register.v ../scripts/synth.ys"
    exit 1
fi

NODE="$1"
INPUT_VERILOG="$2"
YOSYS_SCRIPT="$3"

CIRCUIT_DIR="$(cd "$(dirname "$INPUT_VERILOG")" && pwd)"
CIRCUIT_BASENAME="$(basename "$INPUT_VERILOG" .v)"
YOSYS_SCRIPT_ABS="$(cd "$(dirname "$YOSYS_SCRIPT")" && pwd)/$(basename "$YOSYS_SCRIPT")"

# Library selection
if [[ "$NODE" == "15nm" ]]; then
    LIBERTY_PATH="$LIB_15NM"
    VERILOG_LIB="$VERILOG_15NM"
    LIBRARY_CONFIG="15nm_lib.yml"
else
    LIBERTY_PATH="$LIB_130NM"
    VERILOG_LIB="$VERILOG_130NM"
    LIBRARY_CONFIG="ihp-sg13g2.yml"
fi

SYNTH_OUTPUT="${CIRCUIT_DIR}/${CIRCUIT_BASENAME}.synth.v"
SCAN_OUTPUT="${CIRCUIT_DIR}/${CIRCUIT_BASENAME}.scan.v"

mkdir -p "${CIRCUIT_DIR}/log"
mkdir -p "${CIRCUIT_DIR}/img"

# --- 2. SYNTHESIS ---
echo "--- Synthesis generation ---"
cd "$CIRCUIT_DIR"
yosys -s "$YOSYS_SCRIPT_ABS" &> log/synthesis.log
if [ $? -eq 0 ]; then
    echo "--- Synthesis done ---"
else
    echo "ERROR: Synthesis failed. Check ${CIRCUIT_DIR}/log/synthesis.log"
    exit 1
fi

# --- 3. SCAN CHAIN INSERTION ---
source "$VENV_PATH"
echo "--- Scan Chain insertion ---"
fault chain \
    --clock clk --reset rst \
    --activeLow \
    -l "$LIBERTY_PATH" \
    -c "$VERILOG_LIB" \
    -s "${SCRIPT_DIR}/${LIBRARY_CONFIG}" \
    -o "$SCAN_OUTPUT" \
    "$SYNTH_OUTPUT" &> log/scan.log
FAULT_STATUS=$?
deactivate

# Fault esce con errore anche solo per la verifica fallita,
# quindi controlliamo che il file .scan.v sia stato prodotto
if [ -f "$SCAN_OUTPUT" ] && grep -q "Internal scan chain successfully constructed" "${CIRCUIT_DIR}/log/scan.log"; then
    echo "--- Scan Chain inserted ---"
else
    echo "ERROR: Scan chain insertion failed. Check ${CIRCUIT_DIR}/log/scan.log"
    exit 1
fi

# Clear temp files
rm -f "${CIRCUIT_DIR}"/*-intermediate.v "${CIRCUIT_DIR}"/*.attrs "${CIRCUIT_DIR}"/*+attrs "${CIRCUIT_DIR}"/*.out "${CIRCUIT_DIR}"/*.py "${CIRCUIT_DIR}"/*tb.v "${CIRCUIT_DIR}"/*.sv "${CIRCUIT_DIR}"/*.log 

# --- 4. IMAGE GENERATION ---
echo "--- Images Generation ---"
yosys -p "read_verilog ${SCAN_OUTPUT}; hierarchy -auto-top; proc; show -format png -prefix img/${CIRCUIT_BASENAME}_scan" &> log/img_scan.log
if [ $? -ne 0 ]; then
    echo "WARNING: Image generation for scan netlist failed. Check ${CIRCUIT_DIR}/log/img_scan.log"
fi

yosys -p "read_verilog ${SYNTH_OUTPUT}; hierarchy -auto-top; proc; show -format png -prefix img/${CIRCUIT_BASENAME}_synth" &> log/img_synth.log
if [ $? -ne 0 ]; then
    echo "WARNING: Image generation for synth netlist failed. Check ${CIRCUIT_DIR}/log/img_synth.log"
fi
echo "--- Images Generated ---"
echo "Success! All files generated in: $CIRCUIT_DIR"