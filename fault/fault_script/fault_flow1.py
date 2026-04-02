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
    with open(yosys_script, "w") as f:
        f.write(ys_content)

def clear_workspace():




def load_config(file_path):
    config = {}
    with open(file_path, 'r') as f:
        for line in f:
            line = line.strip()
            # Salta righe vuote e commenti
            if not line or line.startswith('#'):
                continue
            
            # Gestisce sia "CHIAVE=VALORE" che "export CHIAVE=VALORE"
            if "export " in line:
                line = line.replace("export ", "")
            
            if '=' in line:
                key, value = line.split('=', 1)
                # .strip() rimuove spazi bianchi e le virgolette superflue
                config[key.strip()] = value.strip().strip('"').strip("'")
    return config





def main():

    # arguments parsing
    parser = argparse.ArgumentParser(description="DFT Flow Automation Script")
    
    parser.add_argument("node", nargs="?", choices=["15nm", "130nm"], help="Technology node")
    parser.add_argument("input_verilog", nargs="?", type=str, help="Path to the Verilog circuit")
    
    parser.add_argument("--clock", default="clock", help="Clock signal name (default: clock)")
    parser.add_argument("--reset", default="reset", help="Reset signal name (default: reset)")
    parser.add_argument("--images", action="store_true", help="Generate RTL images with Yosys")
    parser.add_argument("--clear", action="store_true", help="Clean up generated files in the current directory")
    
    args = parser.parse_args()

    # clear option
    if args.clear:
        clear_workspace(circuit_dir, basename)
        sys.exit(0)

    #input handling
    if not args.node or not args.input_verilog:
        parser.error("I parametri 'node' e 'input_verilog' sono obbligatori per l'esecuzione normale.")

    # Setup Paths
    script_dir = Path(__file__).parent.resolve()
    input_verilog = Path(args.input_verilog).resolve()
    circuit_dir = input_verilog.parent
    basename = input_verilog.stem

    # directory generation
    (circuit_dir / "log").mkdir(exist_ok=True)
    if args.images:
        (circuit_dir / "img").mkdir(exist_ok=True)

    cfg = load_config("config.cfg")

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
    


    


