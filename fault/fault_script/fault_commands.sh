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
if [ -z "$2" ]; then
    echo "Usage: $0 <nm> <path/to/circuit_name.v>"
    echo "Example: $0 130nm ../src/register.v"
    exit 1
fi

NODE="$1"
INPUT_VERILOG="$2"


CIRCUIT_DIR="$(cd "$(dirname "$INPUT_VERILOG")" && pwd)"
CIRCUIT_BASENAME="$(basename "$INPUT_VERILOG" .v)"

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
YOSYS_SCRIPT_ABS="${CIRCUIT_DIR}/${CIRCUIT_BASENAME}_synth.ys" 

mkdir -p "${CIRCUIT_DIR}/log"
mkdir -p "${CIRCUIT_DIR}/img"

# --- 1.5 GENERAZIONE SCRIPT YOSYS ---
echo "--- Generazione script Yosys  ---"
# Creiamo il file .ys iniettando le variabili bash corrette
cat <<EOF > "$YOSYS_SCRIPT_ABS"
read_verilog $INPUT_VERILOG
synth -top $CIRCUIT_BASENAME
flatten
dfflibmap -liberty $LIBERTY_PATH
abc -liberty $LIBERTY_PATH
clean
write_verilog $SYNTH_OUTPUT
EOF

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

YAML_PATH="${SCRIPT_DIR}/${LIBRARY_CONFIG}"
if [ ! -f "$YAML_PATH" ]; then
    echo "ERRORE FATALE: Il file YAML '$YAML_PATH' non esiste!"
    exit 1
fi
echo "Utilizzo file di configurazione YAML: $YAML_PATH"

# --- 3. SCAN CHAIN INSERTION ---
source "$VENV_PATH"
echo "--- Scan Chain insertion ---"
fault chain \
    --clock clock \
    --reset reset \
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
    sed -i "s/module ${CIRCUIT_BASENAME}\b/module ${CIRCUIT_BASENAME}_scan/" "$SCAN_OUTPUT" #cambio il nome del secondo modulo senno icarus crasha
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

# --- 5. GENERAZIONE TESTBENCH E SIMULAZIONE ---
TB_OUTPUT="${CIRCUIT_DIR}/${CIRCUIT_BASENAME}_tb_equiv.v"

echo "--- Generazione Testbench Equivalenza ---"
python3 "${SCRIPT_DIR}/generate_tb.py" "$INPUT_VERILOG" "$TB_OUTPUT"

echo "--- Simulazione Icarus Verilog ---"
# N.B. Assicurati che il percorso della libreria Verilog ($VERILOG_LIB) sia corretto per la simulazione
iverilog -o "${CIRCUIT_DIR}/sim.vvp" "$TB_OUTPUT" "$SYNTH_OUTPUT" "$SCAN_OUTPUT" "$VERILOG_LIB"

if [ $? -eq 0 ]; then
    vvp "${CIRCUIT_DIR}/sim.vvp"
else
    echo "ERRORE: Compilazione Icarus Verilog fallita."
fi

