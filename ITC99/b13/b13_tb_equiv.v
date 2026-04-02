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
    reg eoc;
    reg dsr;
    reg data_in;

    // --- USCITE GOLDEN E SCAN --- 
    wire soc;
    wire soc_scan;
    wire load_dato;
    wire load_dato_scan;
    wire add_mpx2;
    wire add_mpx2_scan;
    wire mux_en;
    wire mux_en_scan;
    wire errorr;
    wire errorr_scan;
    wire data_out;
    wire data_out_scan;
    wire canale;
    wire canale_scan;

    // --- ISTANZA GOLDEN (Circuito Sintetizzato) ---
    b13 inst_golden (
        .clock(clock), .reset(reset), .eoc(eoc), .dsr(dsr), .data_in(data_in), .soc(soc), .load_dato(load_dato), .add_mpx2(add_mpx2), .mux_en(mux_en), .errorr(errorr), .data_out(data_out), .canale(canale)
    );

    // --- ISTANZA SCAN (Circuito con Chain) ---
    // Aggiunto suffisso _scan in modo da allinearsi con il comando sed di bash
    b13_scan inst_scan (
        .clock(clock), .reset(reset), .test(test), .shift(shift), .tck(tck), .sin(sin), .sout(sout), .eoc(eoc), .dsr(dsr), .data_in(data_in), .soc(soc_scan), .load_dato(load_dato_scan), .add_mpx2(add_mpx2_scan), .mux_en(mux_en_scan), .errorr(errorr_scan), .data_out(data_out_scan), .canale(canale_scan)
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
        eoc = 0;
        dsr = 0;
        data_in = 0;

        #20;
        reset = 1; // Rilascia il reset
        #10;

        // Inietta 1000 input casuali
        repeat(1000) begin
            @(negedge clock);
            eoc = $random;
            dsr = $random;
            data_in = $random;
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
            if ((soc !== soc_scan) || (load_dato !== load_dato_scan) || (add_mpx2 !== add_mpx2_scan) || (mux_en !== mux_en_scan) || (errorr !== errorr_scan) || (data_out !== data_out_scan) || (canale !== canale_scan)) begin
                $display("\n[!] ERROR: Discrepanza trovata al tempo %0t!", $time);
                $display(" -> soc (Golden: %b, Scan: %b)", soc, soc_scan);
                $display(" -> load_dato (Golden: %b, Scan: %b)", load_dato, load_dato_scan);
                $display(" -> add_mpx2 (Golden: %b, Scan: %b)", add_mpx2, add_mpx2_scan);
                $display(" -> mux_en (Golden: %b, Scan: %b)", mux_en, mux_en_scan);
                $display(" -> errorr (Golden: %b, Scan: %b)", errorr, errorr_scan);
                $display(" -> data_out (Golden: %b, Scan: %b)", data_out, data_out_scan);
                $display(" -> canale (Golden: %b, Scan: %b)", canale, canale_scan);
                $stop;
            end
        end
    end

endmodule
