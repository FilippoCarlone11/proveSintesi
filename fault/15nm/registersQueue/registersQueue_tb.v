`timescale 1ns / 1ps
module registerQueue_tb;

    reg clk;
    reg rst;
    reg inp;
    wire out;

    always #5 clk = ~clk;

    registersQueue UUT(
    .clk(clk),
    .rst(rst),
    .D(inp),
    .Q(out)
    );

    initial begin
        $dumpfile("registerQueue_waveform.vcd");
        $dumpvars(0, registerQueue_tb);

        clk = 0;
        inp = 0;
        rst = 1;
        #20 
        rst = 0;

        #10 inp = 1;
        #10 inp = 1;
        #10 inp = 0;
        #10 inp = 1;
        #10 inp = 0;
        #50 $finish;
    end

endmodule