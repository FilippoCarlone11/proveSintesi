`timescale 1ns / 1ps

module tb_equiv;

    // --- SEGNALI DI CONTROLLO BASE ---
    reg CK;
    reg rst;

    // --- SEGNALI DI CONTROLLO FAULT SCAN CHAIN ---
    reg test;
    reg shift;
    reg tck;
    reg sin;
    wire sout;

    // --- INGRESSI FUNZIONALI ---
    reg G0;
    reg G1;
    reg G2;
    reg G3;

    // --- USCITE GOLDEN E SCAN --- 
    wire G17;
    wire G17_scan;

    // --- ISTANZA GOLDEN (Circuito Sintetizzato) ---
    s27 inst_golden (
        .CK(CK), .rst(rst), .G0(G0), .G1(G1), .G2(G2), .G3(G3), .G17(G17)
    );

    // --- ISTANZA SCAN (Circuito con Chain) ---
    // Aggiunto suffisso _scan in modo da allinearsi con il comando sed di bash
    s27_scan inst_scan (
        .CK(CK), .rst(rst), .test(test), .shift(shift), .tck(tck), .sin(sin), .sout(sout), .G0(G0), .G1(G1), .G2(G2), .G3(G3), .G17(G17_scan)
    );

    // Generazione Clock Principale
    initial begin
        CK = 0;
        forever #5 CK = ~CK;
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
        rst = 0; // Reset Active Low
        G0 = 0;
        G1 = 0;
        G2 = 0;
        G3 = 0;

        #20;
        rst = 1; // Rilascia il reset
        #10;

        // Inietta 1000 input casuali
        repeat(1000) begin
            @(negedge CK);
            G0 = $random;
            G1 = $random;
            G2 = $random;
            G3 = $random;
        end

        $display("\n==============================================");
        $display(" SUCCESS: Test completato senza discrepanze!  ");
        $display("==============================================\n");
        $finish;
    end

    // Monitoraggio Equivalenza
    always @(posedge CK) begin
        if (rst == 1) begin
            #1; // Delay di propagazione
            if ((G17 !== G17_scan)) begin
                $display("\n[!] ERROR: Discrepanza trovata al tempo %0t!", $time);
                $display(" -> G17 (Golden: %b, Scan: %b)", G17, G17_scan);
                $stop;
            end
        end
    end

endmodule
