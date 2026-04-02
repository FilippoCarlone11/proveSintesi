#!/usr/bin/env python3
import argparse
import subprocess
import sys
import os
import re
import shutil
from pathlib import Path

def parse_config(config_path):
    """Legge il file config.cfg e risolve le variabili al suo interno (es. ${VAR})."""
    config = {}
    if not config_path.exists():
        print(f"ERROR: config.cfg '{config_path}' not found.")
        sys.exit(1)
        
    with open(config_path, 'r') as f:
        for line in f:
            line = line.strip()
            # Ignora righe vuote e commenti
            if line and not line.startswith('#'):
                # Ignora l'eventuale comando bash 'export' se presente
                if line.startswith("export "):
                    line = line[7:]
                    
                if '=' in line:
                    key, val = line.split('=', 1)
                    key = key.strip()
                    val = val.strip().strip('"\'')
                    
                    # Espansione manuale delle variabili stile Bash
                    # Sostituisce ${CHIAVE} o $CHIAVE con il valore precedentemente salvato
                    for k, v in config.items():
                        val = val.replace(f"${{{k}}}", v)
                        val = val.replace(f"${k}", v)
                        
                    # Se ci sono variabili d'ambiente di sistema (es. $HOME), espande anche quelle
                    val = os.path.expandvars(val)
                    
                    config[key] = val
    return config

def run_cmd(cmd, log_file, cwd=None, exit_on_fail=True):
    """Esegue un comando di shell, salva il log e gestisce gli errori."""
    print(f"Esecuzione: {' '.join(cmd)}")
    with open(log_file, 'w') as f:
        result = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, cwd=cwd, text=True)
    
    if result.returncode != 0 and exit_on_fail:
        print(f"ERRORE: Comando fallito. Controlla {log_file}")
        sys.exit(1)
    return result.returncode

def clear_workspace(target_dir):
    """Pulisce tutti i file generati nella cartella specificata."""
    print(f"--- Pulizia Workspace in {target_dir.name} ---")
    
    # 1. Rimuove le cartelle log e img
    for folder in ['log', 'img']:
        d = target_dir / folder
        if d.exists() and d.is_dir():
            shutil.rmtree(d)
            print(f"Rimossa cartella: {folder}/")

    # 2. Rimuove i file generati (ma NON il file .v originale)
    suffixes_to_remove = [
        '.synth.v', '.scan.v', '.cut.v', '.bench', '_synth.ys', 
        '_tb_equiv.v', '.test', 'sim.vvp', '.sv', '.out', '.py', '.vcd', '.v+attributes', '.v+attrs','.chain-intermediate.v', '.log', '.ys'
    ]
    
    count = 0
    for f in target_dir.iterdir():
        if f.is_file():
            # Controlla se la fine del file corrisponde a uno dei nostri suffissi spazzatura
            if any(f.name.endswith(suffix) for suffix in suffixes_to_remove):
                f.unlink()
                print(f"Rimosso: {f.name}")
                count += 1
                
    print(f"--- Pulizia Completata ({count} file rimossi) ---")

def main():
    parser = argparse.ArgumentParser(description="DFT Flow Automation Script")
    
    parser.add_argument("node", nargs="?", choices=["15nm", "130nm"], help="Technology node")
    parser.add_argument("input_verilog", nargs="?", type=str, help="Path to the Verilog circuit")
    
    parser.add_argument("--clock", default="clock", help="Clock signal name (default: clock)")
    parser.add_argument("--reset", default="reset", help="Reset signal name (default: reset)")
    parser.add_argument("--images", action="store_true", help="Generate RTL images with Yosys")
    parser.add_argument("--clear", action="store_true", help="Clean up generated files in the current directory")
    
    args = parser.parse_args()

    # Se l'utente ha chiesto solo la pulizia, usa la directory in cui ti trovi ora (cwd)
    if args.clear:
        clear_workspace(Path.cwd())
        sys.exit(0)

    # Se NON stiamo facendo la pulizia, controlliamo che abbia inserito i dati per la simulazione
    if not args.node or not args.input_verilog:
        parser.error("I parametri 'node' e 'input_verilog' sono obbligatori per l'esecuzione normale.")

    # Setup Paths
    script_dir = Path(__file__).parent.resolve()
    input_verilog = Path(args.input_verilog).resolve()
    circuit_dir = input_verilog.parent
    basename = input_verilog.stem

    # Se l'utente ha chiesto solo la pulizia, la facciamo ed esciamo
    if args.clear:
        clear_workspace(circuit_dir, basename)
        sys.exit(0)

    # Assicuriamoci che le cartelle esistano
    (circuit_dir / "log").mkdir(exist_ok=True)
    if args.images:
        (circuit_dir / "img").mkdir(exist_ok=True)

    # Leggi Config
    config = parse_config(script_dir / "config.cfg")
    
    if args.node == "15nm":
        liberty_path = config.get("LIB_15NM")
        verilog_lib = config.get("VERILOG_15NM")
        library_config = "15nm_lib.yml"
    else:
        liberty_path = config.get("LIB_130NM")
        verilog_lib = config.get("VERILOG_130NM")
        library_config = "ihp-sg13g2.yml"
        
    yaml_path = script_dir / library_config

    # Nomi dei file di output
    synth_output = circuit_dir / f"{basename}.synth.v"
    scan_output = circuit_dir / f"{basename}.scan.v"
    cut_output = circuit_dir / f"{basename}.cut.v"
    bench_output = circuit_dir / f"{basename}.bench"
    yosys_script = circuit_dir / f"{basename}_synth.ys"
    tb_output = circuit_dir / f"{basename}_tb_equiv.v"
    test_patterns = circuit_dir / f"{basename}.test"

    # --- 1. SCRIPT YOSYS ---
    print("--- 1. Generazione script Yosys ---")
    ys_content = f"""read_verilog {input_verilog}
hierarchy -check -top {basename}
synth -top {basename}
splitnets -ports
opt_clean -purge
dfflibmap -liberty {liberty_path}
abc -liberty {liberty_path}
flatten
setundef -zero
clean -purge
write_verilog {synth_output}
"""
    yosys_script.write_text(ys_content)

    # --- 2. SYNTHESIS ---
    print("--- 2. Sintesi Yosys ---")
    run_cmd(["yosys", "-s", str(yosys_script)], circuit_dir / "log/synthesis.log")

    # --- 3. SCAN CHAIN ---
    print("--- 3. Inserimento Scan Chain ---")
    run_cmd(["fault", "chain", "--clock", args.clock, "--reset", args.reset,
             "-l", liberty_path, "-c", verilog_lib, "-s", str(yaml_path),
             "-o", str(scan_output), str(synth_output)], circuit_dir / "log/scan.log")
    
    # Rinomina modulo top nel file scan
    content = scan_output.read_text()
    scan_output.write_text(content.replace(f"module {basename}", f"module {basename}_scan", 1))

    # --- 4. IMMAGINI (Opzionale) ---
    if args.images:
        print("--- 4. Generazione Immagini ---")
        cmd_scan = ["yosys", "-p", f"read_verilog {scan_output}; hierarchy -auto-top; proc; show -format png -prefix img/{basename}_scan"]
        run_cmd(cmd_scan, circuit_dir / "log/img_scan.log", cwd=circuit_dir, exit_on_fail=False)
        cmd_synth = ["yosys", "-p", f"read_verilog {synth_output}; hierarchy -auto-top; proc; show -format png -prefix img/{basename}_synth"]
        run_cmd(cmd_synth, circuit_dir / "log/img_synth.log", cwd=circuit_dir, exit_on_fail=False)

    # --- 5. TESTBENCH E SIMULAZIONE ---
    print("--- 5. Generazione Testbench e Sim ---")
    run_cmd(["python3", str(script_dir / "generate_tb.py"), str(input_verilog), str(tb_output)], circuit_dir / "log/tb_gen.log")
    run_cmd(["iverilog", "-o", str(circuit_dir / "sim.vvp"), str(tb_output), str(synth_output), str(scan_output), verilog_lib], circuit_dir / "log/iverilog.log")
    run_cmd(["vvp", str(circuit_dir / "sim.vvp")], circuit_dir / "log/vvp.log")

    # --- 6. CUT ---
    print("--- 6. Cut Insertion ---")
    run_cmd(["fault", "cut", "--scl-config", str(yaml_path), "--clock", args.clock,
             "-o", str(cut_output), str(scan_output)], circuit_dir / "log/cut.log")

    # --- 7. BENCH ---
    print("--- 7. Bench Generation ---")
    run_cmd(["nl2bench", "-o", str(bench_output), "-l", liberty_path, str(cut_output)], circuit_dir / "log/bench.log")

    # --- 8. ATALANTA AUTO-PATCHER ---
    print("--- 8. Atalanta Standalone (Auto-Patching) ---")
    with open(bench_output, "a") as f:
        f.write(f"\nOUTPUT({args.clock})\nOUTPUT({args.reset})\nOUTPUT(__uuf__.__clk_source__)\n")

    max_retries = 10
    success = False
    
    for attempt in range(1, max_retries + 1):
        log_path = circuit_dir / "log/atalanta.log"
        ret_code = run_cmd(["atalanta", "-t", str(test_patterns), str(bench_output)], log_path, exit_on_fail=False)
        
        log_content = log_path.read_text()
        
        # Regex per trovare l'errore "floating net" o "floating output"
        match = re.search(r"floating (?:net|output) ['\"]?([\w\.\[\]_]+)['\"]?", log_content, re.IGNORECASE)
        
        if match:
            bad_net = match.group(1)
            print(f"-> [Tentativo {attempt}] Trovato nodo fluttuante: {bad_net}. Applico la patch...")
            with open(bench_output, "a") as f:
                f.write(f"OUTPUT({bad_net})\n")
        elif ret_code == 0 and test_patterns.exists():
            success = True
            break
        else:
            print("ERRORE: Atalanta ha fallito per un motivo sconosciuto.")
            break

    if success:
        print(f"=== SUCCESSO! Atalanta ha terminato in {attempt} tentativi ===")
        print(f"I test pattern sono in: {test_patterns}")
    else:
        print(f"ERRORE FATALE: Atalanta non è riuscito a processare il file. Controlla {log_path}")
        sys.exit(1)

if __name__ == "__main__":
    main()