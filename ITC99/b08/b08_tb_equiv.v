`timescale 1ns / 1ps

module tb_equiv;

    // --- SEGNALI DI CONTROLLO BASE ---
    reg CLOCK;
    reg RESET;

    // --- SEGNALI DI CONTROLLO FAULT SCAN CHAIN ---
    reg test;
    reg shift;
    reg tck;
    reg sin;
    wire sout;

    // --- INGRESSI FUNZIONALI ---
    reg START;
    reg I;

    // --- USCITE GOLDEN E SCAN --- 
    wire O;
    wire O_scan;

    // --- ISTANZA GOLDEN (Circuito Sintetizzato) ---
    b08 inst_golden (
        .CLOCK(CLOCK), .RESET(RESET), .START(START), .I(I), .O(O)
    );

    // --- ISTANZA SCAN (Circuito con Chain) ---
    // Aggiunto suffisso _scan in modo da allinearsi con il comando sed di bash
    b08_scan inst_scan (
        .CLOCK(CLOCK), .RESET(RESET), .test(test), .shift(shift), .tck(tck), .sin(sin), .sout(sout), .START(START), .I(I), .O(O_scan)
    );

    // Generazione CLOCK Principale
    initial begin
        CLOCK = 0;
        forever #5 CLOCK = ~CLOCK;
    end

    // Generazione Test CLOCK (tck)
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
        RESET = 0; // RESET Active Low
        START = 0;
        I = 0;

        #20;
        RESET = 1; // Rilascia il RESET
        #10;

        // Inietta 1000 input casuali
        repeat(1000) begin
            @(negedge CLOCK);
            START = $random;
            I = $random;
        end

        $display("\n==============================================");
        $display(" SUCCESS: Test completato senza discrepanze!  ");
        $display("==============================================\n");
        $finish;
    end

    // Monitoraggio Equivalenza
    always @(posedge CLOCK) begin
        if (RESET == 1) begin
            #1; // Delay di propagazione
            if ((O !== O_scan)) begin
                $display("\n[!] ERROR: Discrepanza trovata al tempo %0t!", $time);
                $display(" -> O (Golden: %b, Scan: %b)", O, O_scan);
                $stop;
            end
        end
    end

endmodule
