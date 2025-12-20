`timescale 1ns/1ns
module registersQueue_sc_tb;

    reg clk;
    reg rst;
    reg Din;
    wire out;
    reg sin;
    reg shift;
    wire sout;
    reg tck;
    reg test;

    registersQueue UUT(
        .clk(clk), 
        .rst(rst), 
        .D(Din), 
        .Q(out), 
        .sin(sin), 
        .shift(shift), 
        .sout(sout), 
        .tck(tck), 
        .test(test)
    );

    always #5 clk = ~clk;
    always #5 tck = ~tck;

    initial begin
        clk = 0;
        rst = 0;
        sin = 0;
        shift = 0;
        tck = 0;
        test = 0;

        #5 rst = 1;
        @(negedge clk) Din = 1;
        @(negedge clk) Din = 0;
        @(negedge clk) Din = 1;
        #20

        test = 1;
        sin = 1;
        #20 shift = 1;
        sin = 0;
        #20 shift = 1;
        #50 $finish;
    end

endmodule
    
    
