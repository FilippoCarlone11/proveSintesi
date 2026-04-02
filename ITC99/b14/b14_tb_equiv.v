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

    // --- USCITE GOLDEN E SCAN --- 
    wire addr;
    wire addr_scan;
    wire datao;
    wire datao_scan;
    wire rd;
    wire rd_scan;
    wire wr;
    wire wr_scan;

    // --- ISTANZA GOLDEN (Circuito Sintetizzato) ---
    b14 inst_golden (
        .clock(clock), .reset(reset), .datai(datai), .addr(addr), .datao(datao), .rd(rd), .wr(wr)
    );

    // --- ISTANZA SCAN (Circuito con Chain) ---
    // Aggiunto suffisso _scan in modo da allinearsi con il comando sed di bash
    b14_scan inst_scan (
        .clock(clock), .reset(reset), .test(test), .shift(shift), .tck(tck), .sin(sin), .sout(sout), .datai(datai), .addr(addr_scan), .datao(datao_scan), .rd(rd_scan), .wr(wr_scan)
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

        #20;
        reset = 1; // Rilascia il reset
        #10;

        // Inietta 1000 input casuali
        repeat(1000) begin
            @(negedge clock);
            datai = $random;
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
            if ((addr !== addr_scan) || (datao !== datao_scan) || (rd !== rd_scan) || (wr !== wr_scan)) begin
                $display("\n[!] ERROR: Discrepanza trovata al tempo %0t!", $time);
                $display(" -> addr (Golden: %b, Scan: %b)", addr, addr_scan);
                $display(" -> datao (Golden: %b, Scan: %b)", datao, datao_scan);
                $display(" -> rd (Golden: %b, Scan: %b)", rd, rd_scan);
                $display(" -> wr (Golden: %b, Scan: %b)", wr, wr_scan);
                $stop;
            end
        end
    end

endmodule
