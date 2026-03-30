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
    reg line1;
    reg line2;

    // --- USCITE GOLDEN E SCAN --- 
    wire outp;
    wire outp_scan;
    wire overflw;
    wire overflw_scan;

    // --- ISTANZA GOLDEN (Circuito Sintetizzato) ---
    b01 inst_golden (
        .clock(clock), .reset(reset), .line1(line1), .line2(line2), .outp(outp), .overflw(overflw)
    );

    // --- ISTANZA SCAN (Circuito con Chain) ---
    // Aggiunto suffisso _scan in modo da allinearsi con il comando sed di bash
    b01_scan inst_scan (
        .clock(clock), .reset(reset), .test(test), .shift(shift), .tck(tck), .sin(sin), .sout(sout), .line1(line1), .line2(line2), .outp(outp_scan), .overflw(overflw_scan)
    );

    // Generazione Clock Principale
    initial begin
        clock = 0;
        forever #5 clock = ~clock;
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
        reset = 0; // Reset Active Low
        line1 = 0;
        line2 = 0;

        #20;
        reset = 1; // Rilascia il reset
        #10;

        // Inietta 1000 input casuali
        repeat(1000) begin
            @(negedge clock);
            line1 = $random;
            line2 = $random;
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
            if ((outp !== outp_scan) || (overflw !== overflw_scan)) begin
                $display("\n[!] ERROR: Discrepanza trovata al tempo %0t!", $time);
                $display(" -> outp (Golden: %b, Scan: %b)", outp, outp_scan);
                $display(" -> overflw (Golden: %b, Scan: %b)", overflw, overflw_scan);
                $stop;
            end
        end
    end

endmodule
