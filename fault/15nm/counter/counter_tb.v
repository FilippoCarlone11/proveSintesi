`timescale 1ns / 1ps
module counter_tb;

    reg clk;
    reg rst;
    wire [3:0] out;


    Counter4Bits UUT (
        .clk(clk),
        .rst(rst),
        .data_out(out)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("counter_waveform.vcd");
        $dumpvars(0, counter_tb);
        clk = 0;
        rst = 1;

        #20
        rst = 0;

        #150 $finish;
    end


endmodule