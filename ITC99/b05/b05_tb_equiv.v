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

    // --- USCITE GOLDEN E SCAN --- 
    wire SIGN;
    wire SIGN_scan;
    wire DISPMAX1;
    wire DISPMAX1_scan;
    wire DISPMAX2;
    wire DISPMAX2_scan;
    wire DISPMAX3;
    wire DISPMAX3_scan;
    wire DISPNUM1;
    wire DISPNUM1_scan;
    wire DISPNUM2;
    wire DISPNUM2_scan;

    // --- ISTANZA GOLDEN (Circuito Sintetizzato) ---
    b05 inst_golden (
        .CLOCK(CLOCK), .RESET(RESET), .START(START), .SIGN(SIGN), .DISPMAX1(DISPMAX1), .DISPMAX2(DISPMAX2), .DISPMAX3(DISPMAX3), .DISPNUM1(DISPNUM1), .DISPNUM2(DISPNUM2)
    );

    // --- ISTANZA SCAN (Circuito con Chain) ---
    // Aggiunto suffisso _scan in modo da allinearsi con il comando sed di bash
    b05_scan inst_scan (
        .CLOCK(CLOCK), .RESET(RESET), .test(test), .shift(shift), .tck(tck), .sin(sin), .sout(sout), .START(START), .SIGN(SIGN_scan), .DISPMAX1(DISPMAX1_scan), .DISPMAX2(DISPMAX2_scan), .DISPMAX3(DISPMAX3_scan), .DISPNUM1(DISPNUM1_scan), .DISPNUM2(DISPNUM2_scan)
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

        #20;
        RESET = 1; // Rilascia il RESET
        #10;

        // Inietta 1000 input casuali
        repeat(1000) begin
            @(negedge CLOCK);
            START = $random;
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
            if ((SIGN !== SIGN_scan) || (DISPMAX1 !== DISPMAX1_scan) || (DISPMAX2 !== DISPMAX2_scan) || (DISPMAX3 !== DISPMAX3_scan) || (DISPNUM1 !== DISPNUM1_scan) || (DISPNUM2 !== DISPNUM2_scan)) begin
                $display("\n[!] ERROR: Discrepanza trovata al tempo %0t!", $time);
                $display(" -> SIGN (Golden: %b, Scan: %b)", SIGN, SIGN_scan);
                $display(" -> DISPMAX1 (Golden: %b, Scan: %b)", DISPMAX1, DISPMAX1_scan);
                $display(" -> DISPMAX2 (Golden: %b, Scan: %b)", DISPMAX2, DISPMAX2_scan);
                $display(" -> DISPMAX3 (Golden: %b, Scan: %b)", DISPMAX3, DISPMAX3_scan);
                $display(" -> DISPNUM1 (Golden: %b, Scan: %b)", DISPNUM1, DISPNUM1_scan);
                $display(" -> DISPNUM2 (Golden: %b, Scan: %b)", DISPNUM2, DISPNUM2_scan);
                $stop;
            end
        end
    end

endmodule
