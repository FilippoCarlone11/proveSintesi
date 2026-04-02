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
    reg NA_n;
    reg BS16_n;
    reg READY_n;
    reg HOLD;
    reg Datai;

    // --- USCITE GOLDEN E SCAN --- 
    wire BE_n;
    wire BE_n_scan;
    wire Address;
    wire Address_scan;
    wire W_R_n;
    wire W_R_n_scan;
    wire D_C_n;
    wire D_C_n_scan;
    wire M_IO_n;
    wire M_IO_n_scan;
    wire ADS_n;
    wire ADS_n_scan;
    wire Datao;
    wire Datao_scan;

    // --- ISTANZA GOLDEN (Circuito Sintetizzato) ---
    b15 inst_golden (
        .CLOCK(CLOCK), .RESET(RESET), .NA_n(NA_n), .BS16_n(BS16_n), .READY_n(READY_n), .HOLD(HOLD), .Datai(Datai), .BE_n(BE_n), .Address(Address), .W_R_n(W_R_n), .D_C_n(D_C_n), .M_IO_n(M_IO_n), .ADS_n(ADS_n), .Datao(Datao)
    );

    // --- ISTANZA SCAN (Circuito con Chain) ---
    // Aggiunto suffisso _scan in modo da allinearsi con il comando sed di bash
    b15_scan inst_scan (
        .CLOCK(CLOCK), .RESET(RESET), .test(test), .shift(shift), .tck(tck), .sin(sin), .sout(sout), .NA_n(NA_n), .BS16_n(BS16_n), .READY_n(READY_n), .HOLD(HOLD), .Datai(Datai), .BE_n(BE_n_scan), .Address(Address_scan), .W_R_n(W_R_n_scan), .D_C_n(D_C_n_scan), .M_IO_n(M_IO_n_scan), .ADS_n(ADS_n_scan), .Datao(Datao_scan)
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
        NA_n = 0;
        BS16_n = 0;
        READY_n = 0;
        HOLD = 0;
        Datai = 0;

        #20;
        RESET = 1; // Rilascia il RESET
        #10;

        // Inietta 1000 input casuali
        repeat(1000) begin
            @(negedge CLOCK);
            NA_n = $random;
            BS16_n = $random;
            READY_n = $random;
            HOLD = $random;
            Datai = $random;
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
            if ((BE_n !== BE_n_scan) || (Address !== Address_scan) || (W_R_n !== W_R_n_scan) || (D_C_n !== D_C_n_scan) || (M_IO_n !== M_IO_n_scan) || (ADS_n !== ADS_n_scan) || (Datao !== Datao_scan)) begin
                $display("\n[!] ERROR: Discrepanza trovata al tempo %0t!", $time);
                $display(" -> BE_n (Golden: %b, Scan: %b)", BE_n, BE_n_scan);
                $display(" -> Address (Golden: %b, Scan: %b)", Address, Address_scan);
                $display(" -> W_R_n (Golden: %b, Scan: %b)", W_R_n, W_R_n_scan);
                $display(" -> D_C_n (Golden: %b, Scan: %b)", D_C_n, D_C_n_scan);
                $display(" -> M_IO_n (Golden: %b, Scan: %b)", M_IO_n, M_IO_n_scan);
                $display(" -> ADS_n (Golden: %b, Scan: %b)", ADS_n, ADS_n_scan);
                $display(" -> Datao (Golden: %b, Scan: %b)", Datao, Datao_scan);
                $stop;
            end
        end
    end

endmodule
