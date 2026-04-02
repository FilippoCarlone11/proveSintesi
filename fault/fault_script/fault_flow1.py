#!/usr/bin/env python3

import argparse
import subprocess
import sys
import os
import re
import shutil
from pathlib import Path

""" FUNZIONI UTILI"""

#funzione per eseguire comandi shell usando subprocess.run
def run_cmd(cmd, log_file, cwd=None, exit_on_fail=True):
    """Esegue un comando di shell, salva il log e gestisce gli errori."""
    #print(f"Esecuzione: {' '.join(cmd)}")
    #scrivo sul file di log per poter osservare eventuali problemi
    with open(log_file, 'w') as f:
        result = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT, cwd=cwd, text=True)
    
    #gestisco l'errore
    if result.returncode != 0 and exit_on_fail:
        print(f"ERRORE: Comando fallito. Controlla {log_file}")
        sys.exit(1)
    return result.returncode

# funzione che pulisce tutti quant i file 
def clear_workspace(target_dir):
    print(f"--- Pulizia Workspace in {target_dir.name} ---")
    
    # elimino le cartelle log e img con tutto il contenuto
    for folder in ['log', 'img']:
        d = target_dir / folder
        if d.exists() and d.is_dir():
            shutil.rmtree(d)
            print(f"Rimossa cartella: {folder}/")

    # elimino tutti i file che hanno i suffissi nella tabella( file che sono stati creati a runtime )
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

# funzione che legge il file config e ritorna un dizionario con nome variabile contenuto
# risolvendo anche variabili annidate
def load_config(file_path):
    
    config = {}
    #controllo che esista
    if not file_path.exists():
        print(f"ERROR: config.cfg '{file_path}' not found.")
        sys.exit(1)
    
    with open(file_path, 'r') as f:
        for line in f:
            line = line.strip()

            # gestione commenti multiriga
            if line.startswith('"""'):
                # caso in cui li ho tutti e due sulla stessa riga 
                if line.count('"""') >= 2:
                    continue
                
                # se ne ho solo una uso una variabile che switcha
                in_multiline_comment = not in_multiline_comment
                continue
                
            # se l'interruttore è acceso, salta la riga e passa alla successiva
            if in_multiline_comment:
                continue

            #ignoro i commenti
            if line and not line.startswith('#'):
                # Gestisce sia "CHIAVE=VALORE" che "export CHIAVE=VALORE"
                if "export " in line:
                    line = line.replace("export ", "")
                
                # trovo tutte le righe in cui assegno le variabili
                if '=' in line:
                    key, val = line.split('=', 1)
                    key = key.strip()
                    val = val.strip().strip('"\'')
                    
                    # espando tutte le variabili presenti per evitare problemi
                    # Sostituisce ${CHIAVE} o $CHIAVE con il valore precedentemente salvato
                    for k, v in config.items():
                        val = val.replace(f"${{{k}}}", v)
                        val = val.replace(f"${k}", v)
                        
                    # Se ci sono variabili d'ambiente di sistema (es. $HOME), espande anche quelle
                    # queste si trovano interne all os
                    val = os.path.expandvars(val)
                    
                    config[key] = val
    return config

#funzione che tenta l'esecuzione più volte di atalanta e nel caso fallisce per colpa di segnali pendenti
# li attacca come output
def atalanta(circuit_dir, test_patterns, bench_output):
    max_retries = 10
    success = False
    
    #ciclo per x volte
    for attempt in range(1, max_retries + 1):
        log_path = circuit_dir / "log/atalanta.log"
        ret_code = run_cmd(["atalanta", "-t", str(test_patterns), str(bench_output)], log_path, exit_on_fail=False)
        
        log_content = log_path.read_text()
        
        # Regex per trovare l'errore "floating net" o "floating output"
        match = re.search(r"floating (?:net|output) ['\"]?([\w\.\[\]_]+)['\"]?", log_content, re.IGNORECASE)
        
        if match:
            # caso in cui trovo un errore: ricavo il segnale e lo metto come output
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

""" FUNZIONI PER IL TOOL """

#funzione che genera il file yosys
def yosys_script_generation(yosys_script, input_verilog, basename, liberty_path, synth_output):
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
    #scrivo
    with open(yosys_script, "w") as f:
        f.write(ys_content)

#funzione che esegue la sintesi
def synthesys(yosys_script, circuit_dir): 
    print("--- 2. Sintesi Yosys ---")
    run_cmd(["yosys", "-s", str(yosys_script)], circuit_dir / "log/synthesis.log")

# funzione che esegue la scan chain
def scan_chain(args, liberty_path, verilog_lib, yaml_path, scan_output, synth_output, circuit_dir, basename):
    
    # vera e propria scan chain
    print("--- 3. Inserimento Scan Chain ---")
    run_cmd(["fault", "chain", "--clock", args.clock, "--reset", args.reset,
             "-l", liberty_path, "-c", verilog_lib, "-s", str(yaml_path),
             "-o", str(scan_output), str(synth_output)], circuit_dir / "log/scan.log")
    
    # cambio nome al top dato il _scan
    content = scan_output.read_text()
    scan_output.write_text(content.replace(f"module {basename}", f"module {basename}_scan", 1))

# funzione di generazione di immagini
def image_generation(circuit_dir, scan_output, basename, synth_output):
    
        print("--- 4. Generazione Immagini ---")
        cmd_scan = ["yosys", "-p", f"read_verilog {scan_output}; hierarchy -auto-top; proc; show -format png -prefix img/{basename}_scan"]
        run_cmd(cmd_scan, circuit_dir / "log/img_scan.log", cwd=circuit_dir, exit_on_fail=False)
        cmd_synth = ["yosys", "-p", f"read_verilog {synth_output}; hierarchy -auto-top; proc; show -format png -prefix img/{basename}_synth"]
        run_cmd(cmd_synth, circuit_dir / "log/img_synth.log", cwd=circuit_dir, exit_on_fail=False)

# funzione che genera i testbench e fa una simulazione
def tb_n_sim(script_dir, input_verilog, tb_output, circuit_dir, synth_output, scan_output, verilog_lib):
    
    print("--- 5. Generazione Testbench e Sim ---")
    # tramite il codice python genero i testbench
    run_cmd(["python3", str(script_dir / "generate_tb.py"), str(input_verilog), str(tb_output)], circuit_dir / "log/tb_gen.log")
    # eseguo la simulazione
    run_cmd(["iverilog", "-o", str(circuit_dir / "sim.vvp"), str(tb_output), str(synth_output), str(scan_output), verilog_lib], circuit_dir / "log/iverilog.log")
    run_cmd(["vvp", str(circuit_dir / "sim.vvp")], circuit_dir / "log/vvp.log")

# funzione che esegue la cut insertion
def cut_insertion(cut_output ,yaml_path, args, scan_output, circuit_dir):
    print("--- 6. Cut Insertion ---")
    run_cmd(["fault", "cut", "--scl-config", str(yaml_path), "--clock", args.clock,
             "-o", str(cut_output), str(scan_output)], circuit_dir / "log/cut.log")

# funzione che genera il file bench per atalanta
def bench(bench_output, liberty_path, cut_output, circuit_dir):
    print("--- 7. Bench Generation ---")
    run_cmd(["nl2bench", "-o", str(bench_output), "-l", liberty_path, str(cut_output)], circuit_dir / "log/bench.log")

# funzione che genera i test tramite atalanta
def atpg_gen(bench_output, args, circuit_dir, test_patterns):
    
    print("--- 8. Atalanta Standalone (Auto-Patching) ---")
    # attacco nel bench come output il clock ed il reset perchè non devono
    # esserci segnali pendenti
    with open(bench_output, "a") as f:
        f.write(f"\nOUTPUT({args.clock})\nOUTPUT({args.reset})\nOUTPUT(__uuf__.__clk_source__)\n")

    # utilizzo atalanta
    atalanta(circuit_dir, test_patterns, bench_output)


def main():

    # arguments parsing
    # serve per capire cosa il codice si aspetta in input fa il controllo che sia stato messo l input giusto
    # e da anche la funzione help
    parser = argparse.ArgumentParser(description="DFT Flow Automation Script")
    
    parser.add_argument("node", nargs="?", choices=["15nm", "130nm"], help="Technology node")
    parser.add_argument("input_verilog", nargs="?", type=str, help="Path to the Verilog circuit")
    
    parser.add_argument("--clock", default="clock", help="Clock signal name (default: clock)")
    parser.add_argument("--reset", default="reset", help="Reset signal name (default: reset)")
    parser.add_argument("--images", action="store_true", help="Generate RTL images with Yosys")
    parser.add_argument("--clear", action="store_true", help="Clean up generated files in the current directory")
    
    args = parser.parse_args()

    #input handling
    if not args.node or not args.input_verilog:
        parser.error("I parametri 'node' e 'input_verilog' sono obbligatori per l'esecuzione normale.")

    # Setup Paths
    script_dir = Path(__file__).parent.resolve()
    input_verilog = Path(args.input_verilog).resolve()
    circuit_dir = input_verilog.parent
    basename = input_verilog.stem

    # pulisco tutti i file se richiesto in input
    if args.clear:
        clear_workspace(circuit_dir)
        sys.exit(0)


    # genero le cartelle log e img 
    (circuit_dir / "log").mkdir(exist_ok=True)
    if args.images:
        (circuit_dir / "img").mkdir(exist_ok=True)

    #carico il file di config 
    cfg = load_config("config.cfg")

    #fase in cui comprendo la libreria da usare
    if args.node == "15nm":
        liberty_path = cfg.get("LIB_15NM")
        verilog_lib = cfg.get("VERILOG_15NM")
        library_config = "15nm_lib.yml"
    else:
        liberty_path = cfg.get("LIB_130NM")
        verilog_lib = cfg.get("VERILOG_130NM")
        library_config = "ihp-sg13g2.yml"

    # we should include what happens for a 130nm library
    yaml_path = script_dir / library_config

    #output file names
    synth_output = circuit_dir / f"{basename}.synth.v"
    scan_output = circuit_dir / f"{basename}.scan.v"
    cut_output = circuit_dir / f"{basename}.cut.v"
    bench_output = circuit_dir / f"{basename}.bench"
    yosys_script = circuit_dir / f"{basename}.ys"
    tb_output = circuit_dir / f"{basename}_tb_equiv.v"
    test_patterns = circuit_dir / f"{basename}.test"


    # 1: script Yosys
    yosys_script_generation(yosys_script, input_verilog, basename, liberty_path, synth_output)

    # 2: synthesis
    synthesys(yosys_script, circuit_dir)

    # 3: scan chain
    scan_chain(args, liberty_path, verilog_lib, yaml_path, scan_output, synth_output, circuit_dir, basename)

    #4 : immagini
    if args.images:
        image_generation(circuit_dir, scan_output, basename, synth_output)

    # 5 : testbench e simulazione
    tb_n_sim(script_dir, input_verilog, tb_output, circuit_dir, synth_output, scan_output, verilog_lib)

    # 6: Cut insertion
    cut_insertion(cut_output ,yaml_path, args, scan_output, circuit_dir)

    # 7 creazione bench
    bench(bench_output, liberty_path, cut_output, circuit_dir)

    # 8: ATPG con atalanta
    atpg_gen(bench_output, args)