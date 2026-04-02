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
    reg eql;
    reg cont_eql;

    // --- USCITE GOLDEN E SCAN --- 
    wire cc_mux;
    wire cc_mux_scan;
    wire uscite;
    wire uscite_scan;
    wire enable_count;
    wire enable_count_scan;
    wire ackout;
    wire ackout_scan;

    // --- ISTANZA GOLDEN (Circuito Sintetizzato) ---
    b06 inst_golden (
        .clock(clock), .reset(reset), .eql(eql), .cont_eql(cont_eql), .cc_mux(cc_mux), .uscite(uscite), .enable_count(enable_count), .ackout(ackout)
    );

    // --- ISTANZA SCAN (Circuito con Chain) ---
    // Aggiunto suffisso _scan in modo da allinearsi con il comando sed di bash
    b06_scan inst_scan (
        .clock(clock), .reset(reset), .test(test), .shift(shift), .tck(tck), .sin(sin), .sout(sout), .eql(eql), .cont_eql(cont_eql), .cc_mux(cc_mux_scan), .uscite(uscite_scan), .enable_count(enable_count_scan), .ackout(ackout_scan)
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
        eql = 0;
        cont_eql = 0;

        #20;
        reset = 1; // Rilascia il reset
        #10;

        // Inietta 1000 input casuali
        repeat(1000) begin
            @(negedge clock);
            eql = $random;
            cont_eql = $random;
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
            if ((cc_mux !== cc_mux_scan) || (uscite !== uscite_scan) || (enable_count !== enable_count_scan) || (ackout !== ackout_scan)) begin
                $display("\n[!] ERROR: Discrepanza trovata al tempo %0t!", $time);
                $display(" -> cc_mux (Golden: %b, Scan: %b)", cc_mux, cc_mux_scan);
                $display(" -> uscite (Golden: %b, Scan: %b)", uscite, uscite_scan);
                $display(" -> enable_count (Golden: %b, Scan: %b)", enable_count, enable_count_scan);
                $display(" -> ackout (Golden: %b, Scan: %b)", ackout, ackout_scan);
                $stop;
            end
        end
    end

endmodule
