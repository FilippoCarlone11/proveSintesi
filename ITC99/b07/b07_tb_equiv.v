`timescale 1ns / 1ps

module tb_equiv;

    // --- SEGNALI DI CONTROLLO BASE ---
    reg clock;
    reg reset;

    // --- SEGNALI DI CONTROLLO FAULT SCAN CHAIN ---
    reg test;
    reg shift;
    reg tck;
    reg sin;
    wire sout;

    // --- INGRESSI FUNZIONALI ---
    reg start;

    // --- USCITE GOLDEN E SCAN --- 
    wire punti_retta;
    wire punti_retta_scan;

    // --- ISTANZA GOLDEN (Circuito Sintetizzato) ---
    b07 inst_golden (
        .clock(clock), .reset(reset), .start(start), .punti_retta(punti_retta)
    );

    // --- ISTANZA SCAN (Circuito con Chain) ---
    // Aggiunto suffisso _scan in modo da allinearsi con il comando sed di bash
    b07_scan inst_scan (
        .clock(clock), .reset(reset), .test(test), .shift(shift), .tck(tck), .sin(sin), .sout(sout), .start(start), .punti_retta(punti_retta_scan)
    );

    // Generazione clock Principale
    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end

    // Generazione Test clock (tck)
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
        reset = 0; // reset Active Low
        start = 0;

        #20;
        reset = 1; // Rilascia il reset
        #10;

        // Inietta 1000 input casuali
        repeat(1000) begin
            @(negedge clock);
            start = $random;
        end

        $display("\n==============================================");
        $display(" SUCCESS: Test completato senza discrepanze!  ");
        $display("==============================================\n");
        $finish;
    end

    // Monitoraggio Equivalenza
    always @(posedge clock) begin
        if (reset == 1) begin
            #1; // Delay di propagazione
            if ((punti_retta !== punti_retta_scan)) begin
                $display("\n[!] ERROR: Discrepanza trovata al tempo %0t!", $time);
                $display(" -> punti_retta (Golden: %b, Scan: %b)", punti_retta, punti_retta_scan);
                $stop;
            end
        end
    end

endmodule
