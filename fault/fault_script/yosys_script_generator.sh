#!/bin/bash


if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <input_verilog> <circuit_basename> <liberty_path> <synth_output> <yosys_script_abs>"
    exit 1
fi

INPUT_VERILOG="$1"
CIRCUIT_BASENAME="$2"
LIBERTY_PATH="$3"
SYNTH_OUTPUT="$4"
YOSYS_SCRIPT_ABS="$5"

echo "-> Creazione del file: $YOSYS_SCRIPT_ABS"

cat <<EOF > "$YOSYS_SCRIPT_ABS"
read_verilog $INPUT_VERILOG
hierarchy -check -top $CIRCUIT_BASENAME
synth -top $CIRCUIT_BASENAME

splitnets -ports
opt_clean -purge

dfflibmap -liberty $LIBERTY_PATH
abc -liberty $LIBERTY_PATH

flatten
setundef -zero
clean -purge

write_verilog $SYNTH_OUTPUT
EOF