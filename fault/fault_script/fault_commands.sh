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

CLOCK_NAME="clock"
RESET_NAME="reset"
GENERATE_IMAGES=0

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --clock)
      CLOCK_NAME="$2"
      shift 2 # Salta la flag e il suo valore
      ;;
    --reset)
      RESET_NAME="$2"
      shift 2
      ;;
    --images)
      GENERATE_IMAGES=1
      shift 1 # Salta solo la flag
      ;;
    -*|--*)
      echo "ERRORE: Opzione sconosciuta $1"
      echo "Usage: $0 [--clock <name>] [--reset <name>] [--images] <nm> <path/to/circuit_name.v>"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # Salva gli argomenti posizionali
      shift 1
      ;;
  esac
done

# Ripristina gli argomenti posizionali
set -- "${POSITIONAL_ARGS[@]}"

# Controllo argomenti obbligatori
if [ -z "$2" ]; then
    echo "Usage: $0 [--clock <name>] [--reset <name>] [--images] <nm> <path/to/circuit_name.v>"
    echo "Example: $0 --clock clk --reset rst_n --images 130nm ../src/register.v"
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
CUT_OUTPUT="${CIRCUIT_DIR}/${CIRCUIT_BASENAME}.cut.v"
BENCH_OUTPUT="${CIRCUIT_DIR}/${CIRCUIT_BASENAME}.bench"
YOSYS_SCRIPT_ABS="${CIRCUIT_DIR}/${CIRCUIT_BASENAME}_script.ys" 

mkdir -p "${CIRCUIT_DIR}/log"
mkdir -p "${CIRCUIT_DIR}/img"

# --- 1.5 GENERAZIONE SCRIPT YOSYS ---

echo "--- Yosys script generation ---"
bash "${SCRIPT_DIR}/yosys_script_generator.sh" "$INPUT_VERILOG" "$CIRCUIT_BASENAME" "$LIBERTY_PATH" "$SYNTH_OUTPUT" "$YOSYS_SCRIPT_ABS"

if [ ! -f "$YOSYS_SCRIPT_ABS" ]; then
    echo "ERROR: Yosys script generation failed."
    exit 1
else
    echo "--- Yosys script generation completed ---"
fi

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
    echo "FATAL ERROR: YAML file '$YAML_PATH' does not exist!"
    exit 1
fi
echo "YAML configuration file used: $YAML_PATH"

# --- 3. SCAN CHAIN INSERTION ---
source "$VENV_PATH"
echo "--- Scan Chain insertion ---"
fault chain \
    --clock "$CLOCK_NAME" \
    --reset "$RESET_NAME" \
    -l "$LIBERTY_PATH" \
    -c "$VERILOG_LIB" \
    -s "${SCRIPT_DIR}/${LIBRARY_CONFIG}" \
    -o "$SCAN_OUTPUT" \
    "$SYNTH_OUTPUT" &> log/scan.log
FAULT_STATUS=$?
deactivate

if [ -f "$SCAN_OUTPUT" ] && grep -q "Internal scan chain successfully constructed" "${CIRCUIT_DIR}/log/scan.log"; then
    echo "--- Scan Chain inserted ---"
    sed -i "s/module ${CIRCUIT_BASENAME}\b/module ${CIRCUIT_BASENAME}_scan/" "$SCAN_OUTPUT"
else
    echo "ERROR: Scan chain insertion failed. Check ${CIRCUIT_DIR}/log/scan.log"
    exit 1
fi



if [ "$GENERATE_IMAGES" -eq 1 ]; then
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

fi


# --- 5. GENERAZIONE TESTBENCH E SIMULAZIONE ---
TB_OUTPUT="${CIRCUIT_DIR}/${CIRCUIT_BASENAME}_tb_equiv.v"

echo "--- Testbench generation ---"
python3 "${SCRIPT_DIR}/generate_tb.py" "$INPUT_VERILOG" "$TB_OUTPUT"

echo "--- Icarus Verilog Simulation ---"
iverilog -o "${CIRCUIT_DIR}/sim.vvp" "$TB_OUTPUT" "$SYNTH_OUTPUT" "$SCAN_OUTPUT" "$VERILOG_LIB"

if [ $? -eq 0 ]; then
    vvp "${CIRCUIT_DIR}/sim.vvp"
else
    echo "ERROR: Icarus Verilog compilation failed"
fi

# --- 6. CUT INSERTION ---
source "$VENV_PATH"
echo "--- Cut insertion ---"
fault cut \
  --scl-config $YAML_PATH \
  --clock "$CLOCK_NAME" \
  -o "$CUT_OUTPUT" \
  "$SCAN_OUTPUT" &> log/cut.log
deactivate

if [ -f "$CUT_OUTPUT" ] ; then
    echo "--- Cut inserted ---"
else
    echo "ERROR: cut insertion failed. Check ${CIRCUIT_DIR}/log/cut.log"
    exit 1
fi

# --- 7. BENCH CREATION ---
source "$VENV_PATH"
echo "--- Bench generation ---"
nl2bench -o "$BENCH_OUTPUT" -l "$LIBERTY_PATH" "$CUT_OUTPUT" &> log/bench.log
deactivate

if [ -f "$BENCH_OUTPUT" ] ; then
    echo "--- Bench generated ---"
else
    echo "ERROR: bench generation failed. Check ${CIRCUIT_DIR}/log/bench.log"
    exit 1
fi

# --- 8. ATALANTA STANDALONE ---
source "$VENV_PATH"
echo "--- Start Atalanta Standalone ---"

# 1. Applichiamo la patch al file bench per non far crashare Atalanta
echo "OUTPUT($CLOCK_NAME)" >> "$BENCH_OUTPUT"
echo "OUTPUT($RESET_NAME)" >> "$BENCH_OUTPUT"
echo "OUTPUT(__uuf__.__clk_source__)" >> "$BENCH_OUTPUT"

# 2. Lanciamo Atalanta DIRETTAMENTE (senza passare per fault)
ATALANTA_PATTERNS="${CIRCUIT_DIR}/${CIRCUIT_BASENAME}.test"
atalanta -t "$ATALANTA_PATTERNS" "$BENCH_OUTPUT" &> log/atalanta.log
ATALANTA_STATUS=$?

deactivate

# 3. Check di validazione per Atalanta
if grep -q -i "fatal error" "log/atalanta.log"; then
    echo "ERROR: Atalanta failed with a fatal error. Check ${CIRCUIT_DIR}/log/atalanta.log"
    exit 1
elif [ $ATALANTA_STATUS -eq 0 ] && [ -f "$ATALANTA_PATTERNS" ]; then
    echo "--- Atalanta completed successfully ---"
    echo "I test pattern sono stati salvati in: $ATALANTA_PATTERNS"
else
    echo "ERROR: Atalanta encountered an unexpected issue. Check ${CIRCUIT_DIR}/log/atalanta.log"
    exit 1
fi

# Clear temp files
rm -f "${CIRCUIT_DIR}"/*-intermediate.v "${CIRCUIT_DIR}"/*.attrs "${CIRCUIT_DIR}"/*+attrs "${CIRCUIT_DIR}"/*.out "${CIRCUIT_DIR}"/*.py "${CIRCUIT_DIR}"/*tb.v "${CIRCUIT_DIR}"/*.sv "${CIRCUIT_DIR}"/*.log 
