module MAC
#(
    parameter DATA_BW = 8
)(
    input CLK,
    input RSTN,
    input MUL,

    input signed [DATA_BW-1:0] IFMAP_DATA_IN1,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN2,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN3,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN4,
    input signed [DATA_BW-1:0] IFMAP_DATA_IN5,

    input signed [DATA_BW-1:0] FILTER_DATA_IN1,
    input signed [DATA_BW-1:0] FILTER_DATA_IN2,
    input signed [DATA_BW-1:0] FILTER_DATA_IN3,
    input signed [DATA_BW-1:0] FILTER_DATA_IN4,
    input signed [DATA_BW-1:0] FILTER_DATA_IN5,

    output signed [2*DATA_BW-1:0] MUL_DATA_OUT
);

reg signed [2*DATA_BW-1:0] mul_reg1;
reg signed [2*DATA_BW-1:0] mul_reg2;
reg signed [2*DATA_BW-1:0] mul_reg3;
reg signed [2*DATA_BW-1:0] mul_reg4;
reg signed [2*DATA_BW-1:0] mul_reg5;
reg signed [2*DATA_BW-1:0] sum_reg;

assign MUL_DATA_OUT = sum_reg;

always @(posedge CLK or negedge RSTN) begin
    if(!RSTN) begin
        mul_reg1 <= 0;
        mul_reg2 <= 0;
        mul_reg3 <= 0;
        mul_reg4 <= 0;
        mul_reg5 <= 0;
        sum_reg <= 0;
    end
    else begin
        sum_reg <= mul_reg1 + mul_reg2 + mul_reg3 + mul_reg4 + mul_reg5;
        if(MUL) begin
            mul_reg1 <= IFMAP_DATA_IN1 * FILTER_DATA_IN1;
            mul_reg2 <= IFMAP_DATA_IN2 * FILTER_DATA_IN2;
            mul_reg3 <= IFMAP_DATA_IN3 * FILTER_DATA_IN3;
            mul_reg4 <= IFMAP_DATA_IN4 * FILTER_DATA_IN4;
            mul_reg5 <= IFMAP_DATA_IN5 * FILTER_DATA_IN5;
        end
    end
end

endmodule
