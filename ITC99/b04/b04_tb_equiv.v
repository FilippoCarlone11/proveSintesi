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
    reg RESTART;
    reg AVERAGE;
    reg ENABLE;
    reg DATA_IN;

    // --- USCITE GOLDEN E SCAN --- 
    wire DATA_OUT;
    wire DATA_OUT_scan;

    // --- ISTANZA GOLDEN (Circuito Sintetizzato) ---
    b04 inst_golden (
        .CLOCK(CLOCK), .RESET(RESET), .RESTART(RESTART), .AVERAGE(AVERAGE), .ENABLE(ENABLE), .DATA_IN(DATA_IN), .DATA_OUT(DATA_OUT)
    );

    // --- ISTANZA SCAN (Circuito con Chain) ---
    // Aggiunto suffisso _scan in modo da allinearsi con il comando sed di bash
    b04_scan inst_scan (
        .CLOCK(CLOCK), .RESET(RESET), .test(test), .shift(shift), .tck(tck), .sin(sin), .sout(sout), .RESTART(RESTART), .AVERAGE(AVERAGE), .ENABLE(ENABLE), .DATA_IN(DATA_IN), .DATA_OUT(DATA_OUT_scan)
    );

    // Generazione Clock Principale
    initial begin
        CLOCK = 0;
        forever #5 CLOCK = ~CLOCK;
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
        RESET = 0; // Reset Active Low
        RESTART = 0;
        AVERAGE = 0;
        ENABLE = 0;
        DATA_IN = 0;

        #20;
        RESET = 1; // Rilascia il reset
        #10;

        // Inietta 1000 input casuali
        repeat(1000) begin
            @(negedge CLOCK);
            RESTART = $random;
            AVERAGE = $random;
            ENABLE = $random;
            DATA_IN = $random;
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
            if ((DATA_OUT !== DATA_OUT_scan)) begin
                $display("\n[!] ERROR: Discrepanza trovata al tempo %0t!", $time);
                $display(" -> DATA_OUT (Golden: %b, Scan: %b)", DATA_OUT, DATA_OUT_scan);
                $stop;
            end
        end
    end

endmodule
