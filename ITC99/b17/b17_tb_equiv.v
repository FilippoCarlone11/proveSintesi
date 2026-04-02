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
    reg datai;
    reg hold;
    reg na;
    reg bs16;
    reg ready1;
    reg ready2;

    // --- USCITE GOLDEN E SCAN --- 
    wire datao;
    wire datao_scan;
    wire address1;
    wire address1_scan;
    wire address2;
    wire address2_scan;
    wire wr;
    wire wr_scan;
    wire dc;
    wire dc_scan;
    wire mio;
    wire mio_scan;
    wire ast1;
    wire ast1_scan;
    wire ast2;
    wire ast2_scan;

    // --- ISTANZA GOLDEN (Circuito Sintetizzato) ---
    b17 inst_golden (
        .clock(clock), .reset(reset), .datai(datai), .hold(hold), .na(na), .bs16(bs16), .ready1(ready1), .ready2(ready2), .datao(datao), .address1(address1), .address2(address2), .wr(wr), .dc(dc), .mio(mio), .ast1(ast1), .ast2(ast2)
    );

    // --- ISTANZA SCAN (Circuito con Chain) ---
    // Aggiunto suffisso _scan in modo da allinearsi con il comando sed di bash
    b17_scan inst_scan (
        .clock(clock), .reset(reset), .test(test), .shift(shift), .tck(tck), .sin(sin), .sout(sout), .datai(datai), .hold(hold), .na(na), .bs16(bs16), .ready1(ready1), .ready2(ready2), .datao(datao_scan), .address1(address1_scan), .address2(address2_scan), .wr(wr_scan), .dc(dc_scan), .mio(mio_scan), .ast1(ast1_scan), .ast2(ast2_scan)
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
        datai = 0;
        hold = 0;
        na = 0;
        bs16 = 0;
        ready1 = 0;
        ready2 = 0;

        #20;
        reset = 1; // Rilascia il reset
        #10;

        // Inietta 1000 input casuali
        repeat(1000) begin
            @(negedge clock);
            datai = $random;
            hold = $random;
            na = $random;
            bs16 = $random;
            ready1 = $random;
            ready2 = $random;
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
            if ((datao !== datao_scan) || (address1 !== address1_scan) || (address2 !== address2_scan) || (wr !== wr_scan) || (dc !== dc_scan) || (mio !== mio_scan) || (ast1 !== ast1_scan) || (ast2 !== ast2_scan)) begin
                $display("\n[!] ERROR: Discrepanza trovata al tempo %0t!", $time);
                $display(" -> datao (Golden: %b, Scan: %b)", datao, datao_scan);
                $display(" -> address1 (Golden: %b, Scan: %b)", address1, address1_scan);
                $display(" -> address2 (Golden: %b, Scan: %b)", address2, address2_scan);
                $display(" -> wr (Golden: %b, Scan: %b)", wr, wr_scan);
                $display(" -> dc (Golden: %b, Scan: %b)", dc, dc_scan);
                $display(" -> mio (Golden: %b, Scan: %b)", mio, mio_scan);
                $display(" -> ast1 (Golden: %b, Scan: %b)", ast1, ast1_scan);
                $display(" -> ast2 (Golden: %b, Scan: %b)", ast2, ast2_scan);
                $stop;
            end
        end
    end

endmodule
