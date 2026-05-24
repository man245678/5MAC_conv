module MAC
#(
    parameter DATA_BW = 8
)(
    input CLK,
    input RSTN,
    input LOAD,
    input MUL,
    input SUM,

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

reg signed [DATA_BW-1:0] ifmap_reg1;
reg signed [DATA_BW-1:0] ifmap_reg2;
reg signed [DATA_BW-1:0] ifmap_reg3;
reg signed [DATA_BW-1:0] ifmap_reg4;
reg signed [DATA_BW-1:0] ifmap_reg5;
reg signed [DATA_BW-1:0] filter_reg1;
reg signed [DATA_BW-1:0] filter_reg2;
reg signed [DATA_BW-1:0] filter_reg3;
reg signed [DATA_BW-1:0] filter_reg4;
reg signed [DATA_BW-1:0] filter_reg5;

reg signed [2*DATA_BW-1:0] mul_reg1;
reg signed [2*DATA_BW-1:0] mul_reg2;
reg signed [2*DATA_BW-1:0] mul_reg3;
reg signed [2*DATA_BW-1:0] mul_reg4;
reg signed [2*DATA_BW-1:0] mul_reg5;
reg signed [2*DATA_BW-1:0] result_reg;

assign MUL_DATA_OUT = result_reg;

always @(posedge CLK or negedge RSTN) begin
    if(!RSTN) begin
        ifmap_reg1 <= 0;
        ifmap_reg2 <= 0;
        ifmap_reg3 <= 0;
        ifmap_reg4 <= 0;
        ifmap_reg5 <= 0;
        filter_reg1 <= 0;
        filter_reg2 <= 0;
        filter_reg3 <= 0;
        filter_reg4 <= 0;
        filter_reg5 <= 0;
        mul_reg1 <= 0;
        mul_reg2 <= 0;
        mul_reg3 <= 0;
        mul_reg4 <= 0;
        mul_reg5 <= 0;
        result_reg <= 0;
    end
    else begin
        if(LOAD) begin
            ifmap_reg1 <= IFMAP_DATA_IN1;
            ifmap_reg2 <= IFMAP_DATA_IN2;
            ifmap_reg3 <= IFMAP_DATA_IN3;
            ifmap_reg4 <= IFMAP_DATA_IN4;
            ifmap_reg5 <= IFMAP_DATA_IN5;
            filter_reg1 <= FILTER_DATA_IN1;
            filter_reg2 <= FILTER_DATA_IN2;
            filter_reg3 <= FILTER_DATA_IN3;
            filter_reg4 <= FILTER_DATA_IN4;
            filter_reg5 <= FILTER_DATA_IN5;
        end

        if(MUL) begin
            mul_reg1 <= ifmap_reg1 * filter_reg1;
            mul_reg2 <= ifmap_reg2 * filter_reg2;
            mul_reg3 <= ifmap_reg3 * filter_reg3;
            mul_reg4 <= ifmap_reg4 * filter_reg4;
            mul_reg5 <= ifmap_reg5 * filter_reg5;
        end

        if(SUM) begin
            result_reg <= mul_reg1 + mul_reg2 + mul_reg3 + mul_reg4 + mul_reg5;
        end
    end
end

endmodule
