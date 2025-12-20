module Counter4Bits(
    input clk,
    input rst,
    output [3:0] data_out
);
    wire high = 1'b1;
    wire andD2, andD3;

    JkFlipFlop d0(
    .J(high),
    .K(high),
    .clk(clk),
    .rst(rst),
    .Q(data_out[0]),
    .Qn()
    );

    JkFlipFlop d1(
    .J(data_out[0]),
    .K(data_out[0]),
    .clk(clk),
    .rst(rst),
    .Q(data_out[1]),
    .Qn()
    );
    assign andD2 = data_out[0] & data_out[1];

    JkFlipFlop d2(
    .J(andD2),
    .K(andD2),
    .clk(clk),
    .rst(rst),
    .Q(data_out[2]),
    .Qn()
    );

    assign andD3 = data_out[0] & data_out[1] & data_out[2];

    JkFlipFlop d3(
    .J(andD3),
    .K(andD3),
    .clk(clk),
    .rst(rst),
    .Q(data_out[3]),
    .Qn()
    );

endmodule