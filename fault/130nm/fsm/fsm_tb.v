`timescale 1ns / 1ps

module fsm_tb;
    reg clk;
    reg rst;
    reg inp;

    wire out;

    fsm uut(
        .i(inp),
        .clk(clk),
        .rst(rst),
        .q(out)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("fsm_waveform.vcd");
        $dumpvars(0, fsm_tb);
        clk = 0;
        rst = 1;
        inp = 0;

        #20
        rst = 0;

        #10 inp = 1;
        #10 inp = 1;
        #10 inp = 0;
        #10 inp = 1;
        #10 inp = 0;
        #10 inp = 0;
        #10 inp = 0;
        #10 inp = 0;
        #10 inp = 1;
        #10 inp = 0;
        #10 inp = 1;
        #50 $finish;

    end

    


endmodule