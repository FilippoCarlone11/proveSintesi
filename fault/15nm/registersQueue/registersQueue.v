module registersQueue (
    input clk,
    input rst,
    input D,
    output Q
);
    wire Q1;
    register reg1 (
        .clk(clk),
        .rst(rst),
        .D(D),
        .Q(Q1)
    );
    
    register reg2 (
        .clk(clk),
        .rst(rst),
        .D(Q1),
        .Q(Q)
    );

endmodule