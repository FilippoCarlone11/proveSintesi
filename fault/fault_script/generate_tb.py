import sys
import re
import os

def parse_verilog(filepath, clk_name="clk", rst_name="rst"):
    with open(filepath, 'r') as f:
        content = f.read()

    # Rimuovi i commenti per evitare falsi positivi nel parsing
    content = re.sub(r'//.*', '', content)
    content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)

    # trova il nome del modulo direttamente dal nome del file (dunque il file .v deve chiamarsi come il modulo)
    module_name = os.path.splitext(os.path.basename(filepath))[0]

    # isola il componente principale
    # Ignora eventuali dichiarazioni di module DFF(...) a fine file
    pattern = r'\bmodule\s+' + re.escape(module_name) + r'\b(.*?)\bendmodule\b'
    match = re.search(pattern, content, re.DOTALL)
    if match:
        module_body = match.group(0)
    else:
        module_body = content # Fallback di sicurezza

    # Estrai gli input SOLO dal corpo del modulo principale
    inputs = []
    for m in re.finditer(r'\binput\b\s+([^;]+);', module_body):
        ports = m.group(1).split(',')
        for p in ports:
            p_clean = re.sub(r'\[.*?\]', '', p).strip().split()[-1]
            if p_clean: inputs.append(p_clean)

    # Estrai gli output SOLO dal corpo del modulo principale
    outputs = []
    for m in re.finditer(r'\boutput\b\s+([^;]+);', module_body):
        ports = m.group(1).split(',')
        for p in ports:
            p_clean = re.sub(r'\[.*?\]', '', p).strip().split()[-1]
            if p_clean: outputs.append(p_clean)

    # Rimuovi TUTTE le occorrenze di clock e reset dalla lista degli input generici
    inputs = [p for p in inputs if p != clk_name and p != rst_name]
    
    # Rimuoviamo eventuali duplicati per sicurezza
    inputs = list(dict.fromkeys(inputs))
    outputs = list(dict.fromkeys(outputs))

    return module_name, inputs, outputs

def generate_testbench(module_name, inputs, outputs, tb_path, clk_name="CK", rst_name="rst"):
    # Prepara le stringhe di mappatura dei pin
    golden_ports = f".{clk_name}({clk_name}), .{rst_name}({rst_name})"
    
    # Aggiornato con i pin esatti generati dall'infrastruttura di Fault
    scan_ports = f".{clk_name}({clk_name}), .{rst_name}({rst_name}), .test(test), .shift(shift), .tck(tck), .sin(sin), .sout(sout)"
    
    for pin in inputs + outputs:
        golden_ports += f", .{pin}({pin})"
        scan_ports += f", .{pin}({pin}_scan)" if pin in outputs else f", .{pin}({pin})"

    # Creazione del Verilog Testbench
    tb_code = f"""`timescale 1ns / 1ps

module tb_equiv;

    // --- SEGNALI DI CONTROLLO BASE ---
    reg {clk_name};
    reg {rst_name};

    // --- SEGNALI DI CONTROLLO FAULT SCAN CHAIN ---
    reg test;
    reg shift;
    reg tck;
    reg sin;
    wire sout;

    // --- INGRESSI FUNZIONALI ---
"""
    for pin in inputs:
        tb_code += f"    reg {pin};\n"

    tb_code += "\n    // --- USCITE GOLDEN E SCAN --- \n"
    for pin in outputs:
        tb_code += f"    wire {pin};\n"
        tb_code += f"    wire {pin}_scan;\n"

    tb_code += f"""
    // --- ISTANZA GOLDEN (Circuito Sintetizzato) ---
    {module_name} inst_golden (
        {golden_ports}
    );

    // --- ISTANZA SCAN (Circuito con Chain) ---
    // Aggiunto suffisso _scan in modo da allinearsi con il comando sed di bash
    {module_name}_scan inst_scan (
        {scan_ports}
    );

    // Generazione Clock Principale
    initial begin
        {clk_name} = 0;
        forever #5 {clk_name} = ~{clk_name};
    end

    // Generazione Test Clock (tck)
    initial begin
        tck = 0;
        forever #7 tck = ~tck;
    end

    // Generazione Stimoli
    initial begin
        $dumpfile("equiv_test.vcd");
        $dumpvars(0, tb_equiv);

        // INIZIALIZZAZIONE RIGOROSA
        // Modalità funzionale: test e shift rigorosamente a 0
        test = 0;
        shift = 0;
        sin = 0;
        {rst_name} = 0; // Reset Active Low
"""
    for pin in inputs:
        tb_code += f"        {pin} = 0;\n"

    tb_code += f"""
        #20;
        {rst_name} = 1; // Rilascia il reset
        #10;

        // Inietta 1000 input casuali
        repeat(1000) begin
            @(negedge {clk_name});
"""
    for pin in inputs:
        tb_code += f"            {pin} = $random;\n"

    tb_code += f"""        end

        $display("\\n==============================================");
        $display(" SUCCESS: Test completato senza discrepanze!  ");
        $display("==============================================\\n");
        $finish;
    end

    // Monitoraggio Equivalenza
    always @(posedge {clk_name}) begin
        if ({rst_name} == 1) begin
            #1; // Delay di propagazione
"""
    # Crea il blocco if per controllare che TUTTE le uscite coincidano
    condizioni = " || ".join([f"({pin} !== {pin}_scan)" for pin in outputs])
    tb_code += f"            if ({condizioni}) begin\n"
    tb_code += f"                $display(\"\\n[!] ERROR: Discrepanza trovata al tempo %0t!\", $time);\n"
    for pin in outputs:
         tb_code += f"                $display(\" -> {pin} (Golden: %b, Scan: %b)\", {pin}, {pin}_scan);\n"
    tb_code += """                $stop;
            end
        end
    end

endmodule
"""
    with open(tb_path, 'w') as f:
        f.write(tb_code)
    print(f"Testbench generato con successo: {tb_path}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Uso: python generate_tb.py <input_verilog.v> <output_tb.v>")
        sys.exit(1)
        
    in_verilog = sys.argv[1]
    out_tb = sys.argv[2]
    
    # Assicuriamoci che usi "CK" come clock di default per i tuoi test con s27
    mod_name, in_ports, out_ports = parse_verilog(in_verilog, clk_name="CK", rst_name="rst")
    generate_testbench(mod_name, in_ports, out_ports, out_tb, clk_name="CK", rst_name="rst")