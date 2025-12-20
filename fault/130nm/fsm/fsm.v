module fsm(
    input i,
    input clk,
    input rst,
    output reg q
);

    reg [1:0] state;
    reg [1:0] nextState;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= 2'b00;
        end
        else begin
            state <= nextState;
        end
    end

    always @(*) begin
            case (state)
                2'b00: nextState = (i == 0) ? 2'b00 : 2'b01;
                2'b01: nextState = (i == 0) ? 2'b00 : 2'b10;
                2'b10: nextState = (i == 0) ? 2'b11 : 2'b10; 
                2'b11: nextState = (i == 0) ? 2'b00 : 2'b01;
                default: nextState = 2'b00;
            endcase
    end

    always @(posedge clk or posedge rst) begin
        if(rst) q <= 0;
        else begin
            if (state == 2'b11 && i == 1 ) q <= 1;
            else q <= 0;
        end
    end

endmodule