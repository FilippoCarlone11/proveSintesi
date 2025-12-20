module JkFlipFlop(
    input J,
    input K,
    input clk,
    input rst,
    output reg Q,
    output Qn
);

    assign Qn = ~Q;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            Q <= 1'b0;
        end else begin
            if(J == 0 && K == 0) begin
                Q <= Q;
            end else if (J == 0 && K == 1)begin
                Q <= 0;
            end else if (J == 1 && K == 0) begin
                Q <= 1;
            end else begin
                Q <= ~Q;
            end
        end
    end
    
endmodule